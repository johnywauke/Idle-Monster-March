extends Node
# Cena de bootstrap. Carrega o save (creditando offline) ou cria um estado de
# demonstracao, e imprime/mostra um relatorio provando que o nucleo esta vivo.
# Aqui no futuro entra a cena de gameplay de verdade.

func _ready() -> void:
	var offline_gold := SaveManager.load_game()
	if GameState.team.is_empty():
		_seed_demo_state()

	var lines := _build_demo_report(offline_gold)
	for l in lines:
		print(l)
	_show_on_screen("\n".join(lines))

func _seed_demo_state() -> void:
	GameState.current_phase = 10   # multiplo de 10 -> fase com boss (so para a demo)
	GameState.max_phase = 10
	GameState.gold = 0.0
	var demo_ids := ["emberfox", "ignis_knight", "slurp", "pebble", "zappcat"]
	for id in demo_ids:
		var md := ContentDB.get_monster(id)
		if md != null:
			GameState.add_to_team(MonsterInstance.new(md, 25, 1))

func _build_demo_report(offline_gold: float) -> Array:
	var dps := GameState.team_base_dps()
	var phase := GameState.current_phase
	var lines: Array = []
	lines.append("=== Idle Monster March - nucleo rodando ===")
	lines.append("Fase atual: %d" % phase)
	lines.append("Equipe (%d/%d):" % [GameState.team.size(), GameState.TEAM_SIZE])
	for m in GameState.team:
		if m == null or m.data == null:
			continue
		lines.append("  - %s [%s/%s] Nv.%d *%d | DPS %s | Tier %d" % [
			m.data.display_name, m.data.element, m.data.rarity,
			m.level, m.stars, Numbers.format(m.expected_dps()), m.tier()])
	lines.append("DPS base da equipe: %s" % Numbers.format(dps))
	lines.append("Dano de clique (10%%): %s" % Numbers.format(GameState.click_damage()))
	lines.append("HP inimigo comum (fase %d): %s" % [phase, Numbers.format(Formulas.enemy_hp(phase))])
	lines.append("HP do boss (fase %d): %s" % [phase, Numbers.format(Formulas.boss_hp(phase))])
	lines.append("Tempo p/ matar o boss: %.1fs -> vence antes do Enrage (30s)? %s" % [
		BattleSimulator.time_to_kill_boss(dps, phase),
		"SIM" if BattleSimulator.can_beat_boss(dps, phase) else "NAO (precisa upar)"])
	lines.append("Ouro/segundo (regime estavel): %s" % Numbers.format(BattleSimulator.gold_per_second(dps, phase)))
	if offline_gold > 0.0:
		lines.append("Ganho offline creditado: %s de ouro" % Numbers.format(offline_gold))
	lines.append("Prestigio desbloqueia na fase %d. Soul Coins agora: %d" % [
		Formulas.PRESTIGE_UNLOCK_PHASE, Formulas.soul_coins(GameState.max_phase)])
	return lines

func _show_on_screen(text: String) -> void:
	var label := Label.new()
	label.position = Vector2(16, 16)
	label.add_theme_font_size_override("font_size", 14)
	label.text = text
	add_child(label)
