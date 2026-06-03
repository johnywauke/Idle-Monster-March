extends Node
# Cena de bootstrap/demo. Prova que todos os sistemas do núcleo estão vivos.
# Aqui no futuro entra a cena de gameplay real.

func _ready() -> void:
	var offline_gold := SaveManager.load_game()
	if GameState.team.is_empty():
		_seed_demo_state()

	var lines := _build_report(offline_gold)
	for l in lines:
		print(l)
	_show_on_screen("\n".join(lines))

# --- Estado de demonstração ---

func _seed_demo_state() -> void:
	GameState.current_phase = 10
	GameState.max_phase = 10
	GameState.gold = 0.0

	# Time demo: 4 FOGO + 1 AGUA + 1 TERRA + 1 RAIO -> sinergia FOGO(4) ativa
	var demo_ids := ["emberfox", "ignis_knight", "flare_dragon", "cinder_imp", "slurp", "pebble", "zappcat"]
	for id in demo_ids:
		var md := ContentDB.get_monster(id)
		if md != null:
			GameState.add_to_team(MonsterInstance.new(md, 25, 2))

	# Demo gacha: tutorial 10x + coloca no inventário
	GameState.tutorial_done = true
	var pulled := GachaSystem.tutorial_pull(GameState.rng)
	for md in pulled:
		GameState.grant_monster(md)

	# Talento demo no Emberfox: Canhão de Vidro (+50% ATK, -30% HP)
	var talent_glass := ContentDB.talents.get("glass_cannon", null)
	if talent_glass != null and GameState.team.size() > 0:
		GameState.team[0].talent = talent_glass

# --- Relatório ---

func _build_report(offline_gold: float) -> Array:
	var lines: Array = []
	lines.append("=== Idle Monster March — Núcleo v2 ===")
	lines.append("")

	# Equipe
	lines.append("[ EQUIPE %d/%d ]" % [GameState.team.size(), GameState.TEAM_SIZE])
	for i in GameState.team.size():
		var m := GameState.team[i]
		if m == null or m.data == null:
			continue
		var talent_tag := (" +%s" % m.talent.display_name) if m.talent != null else ""
		lines.append("  [%d] %s [%s/%s] Nv.%d ★%d | DPS %s | ATK %s | HP %s | Tier %d%s" % [
			i + 1, m.data.display_name, m.data.element, m.data.rarity,
			m.level, m.stars,
			Numbers.format(m.expected_dps()),
			Numbers.format(m.final_atk()),
			Numbers.format(m.final_hp()),
			m.tier(), talent_tag])
	lines.append("")

	# Sinergias
	lines.append("[ SINERGIAS ]")
	lines.append("  " + SynergySystem.synergy_report(GameState.team))
	lines.append("")

	# Combate
	var dps := GameState.team_base_dps()
	var phase := GameState.current_phase
	lines.append("[ COMBATE — Fase %d ]" % phase)
	lines.append("  DPS base da equipe: %s" % Numbers.format(dps))
	lines.append("  Dano de clique (10%%): %s" % Numbers.format(GameState.click_damage()))
	lines.append("  HP inimigo comum: %s" % Numbers.format(Formulas.enemy_hp(phase)))
	lines.append("  HP do boss: %s" % Numbers.format(Formulas.boss_hp(phase)))
	var ttk_boss := BattleSimulator.time_to_kill_boss(dps, phase)
	var beats_passively := BattleSimulator.can_beat_boss(dps, phase)
	lines.append("  Tempo para matar o boss: %.1fs → Vence antes do Enrage? %s" % [
		ttk_boss, "SIM (passivo)" if beats_passively else "NÃO (precisa upar)"])
	lines.append("  Ouro/segundo: %s" % Numbers.format(BattleSimulator.gold_per_second(dps, phase)))
	lines.append("  DEF mitigation (Pebble, fase %d): %.1f%%" % [
		phase, Formulas.def_mitigation(GameState.team[5].final_def() if GameState.team.size() > 5 else 0.0, phase) * 100.0])
	lines.append("")

	# Fever Mode
	lines.append("[ FEVER MODE ]")
	lines.append("  Barra: %.0f%% | Ativo: %s | Cooldown: %.0fs" % [
		GameState.combat.fever_bar * 100.0,
		"SIM" if GameState.combat.fever_active else "NÃO",
		GameState.combat.fever_cooldown])
	lines.append("")

	# Inventário e gacha
	lines.append("[ INVENTÁRIO ]")
	lines.append("  %d monstros no inventário." % GameState.inventory.size())
	if not GameState.inventory.is_empty():
		for m in GameState.inventory.slice(0, mini(3, GameState.inventory.size())):
			lines.append("    - %s [%s/%s]" % [m.data.display_name, m.data.element, m.data.rarity])
		if GameState.inventory.size() > 3:
			lines.append("    ... (+%d)" % (GameState.inventory.size() - 3))
	lines.append("  Fragmentos: %d IDs com fragmentos." % GameState.fragments.size())
	lines.append("  Pity counter: %d/%d" % [GameState.pity_counter, GachaSystem.PITY_LIMIT])
	lines.append("")

	# Prestígio
	lines.append("[ PRESTÍGIO ]")
	lines.append("  Desbloqueio na fase %d. Fase máx atual: %d." % [
		Formulas.PRESTIGE_UNLOCK_PHASE, GameState.max_phase])
	lines.append("  Soul Coins ganhos se prestigiar agora: %d" % Formulas.soul_coins(GameState.max_phase))
	lines.append("  Soul Coins acumulados: %d" % GameState.soul_coins)
	lines.append("")

	# Offline
	if offline_gold > 0.0:
		lines.append("[ OFFLINE ]")
		lines.append("  Ouro creditado: %s" % Numbers.format(offline_gold))
		lines.append("")

	lines.append("Total de monstros no ContentDB: %d" % ContentDB.monsters.size())
	return lines

func _show_on_screen(text: String) -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	scroll.add_child(label)
	add_child(scroll)
