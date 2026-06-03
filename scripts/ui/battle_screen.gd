class_name BattleScreen
extends Control

# Tela de batalha com simulação em tempo real.
# Novidades: barras de ULT, números flutuantes, fundo de bioma, Farm Mode, level-up.

# --- Estado de combate ---
var _enemy_hp: float       = 0.0
var _enemy_max_hp: float   = 1.0
var _enemy_type: EnemyData = null
var _kills_this_phase: int = 0

const KILLS_PER_PHASE := 10

# --- Referências de nós (atribuídas em _build_ui) ---
var _bg_rect: ColorRect                          # fundo com lerp de bioma
var _biome_lbl: Label
var _team_cards_container: VBoxContainer         # rebuilding limpo
var _monster_slots: Array = []                   # [{ult_bar, ult_lbl}] por slot
var _enemy_name_lbl: Label
var _enemy_hp_bar: ProgressBar
var _enemy_hp_lbl: Label
var _enemy_panel: Button
var _enemy_type_icon: ColorRect                  # cor/tamanho varia por tipo
var _enemy_type_lbl: Label
var _enemy_info_lbl: Label
var _enrage_bar: ProgressBar
var _enrage_lbl: Label
var _phase_lbl: Label
var _kill_lbl: Label
var _farm_banner: PanelContainer
var _farm_lbl: Label
var _dps_lbl: Label
var _gps_lbl: Label
var _click_lbl: Label
var _fever_bar: ProgressBar
var _fever_status_lbl: Label
var _overlay: Control                            # números flutuantes aparecem aqui

signal hud_needs_refresh

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_spawn_enemy()

# ---------------------------------------------------------------------------
# Loop principal
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not visible:
		return

	# Ouro em tempo real
	GameState.gold += BattleSimulator.gold_per_second(
		GameState.team_base_dps(), GameState.current_phase) * delta

	# Máquina de estado (fever, enrage)
	var events := GameState.combat.update(delta)
	if events.get("boss_enraged", false):
		_on_boss_enraged()

	# Deprecia HP do inimigo
	if _enemy_max_hp > 0.0:
		_enemy_hp -= GameState.team_base_dps() * delta
		if _enemy_hp <= 0.0:
			_on_enemy_killed()

	# Processa ULT de cada monstro
	_process_ultimates(delta)

	# Transição suave de bioma
	var target_bg := ThemeHelper.biome_color(GameState.current_phase)
	_bg_rect.color = _bg_rect.color.lerp(target_bg, delta * 1.5)

	_refresh_combat_ui()
	emit_signal("hud_needs_refresh")

# --- Ultimates ---

func _process_ultimates(delta: float) -> void:
	for i in GameState.team.size():
		var m := GameState.team[i]
		if m == null:
			continue
		var just_ready := m.add_ult_energy(m.effective_aspd() * MonsterInstance.ULT_ENERGY_PER_ATTACK * delta)
		if just_ready:
			_on_ult_ready(i)
		elif m.is_ult_ready():
			m._ult_auto_timer += delta
			if m._ult_auto_timer >= MonsterInstance.ULT_AUTO_DELAY:
				_fire_ultimate_slot(i)

func _on_ult_ready(slot_idx: int) -> void:
	if slot_idx < _monster_slots.size():
		_monster_slots[slot_idx]["ult_lbl"].visible = true
	var pos := _card_center_pos(slot_idx)
	_spawn_number(pos + Vector2(0, -8), "ULT!", ThemeHelper.FEVER_CLR)

func _fire_ultimate_slot(slot_idx: int) -> void:
	var m := GameState.team[slot_idx] if slot_idx < GameState.team.size() else null
	if m == null:
		return
	var ult_name := m.fire_ultimate()
	if ult_name.is_empty():
		return
	if slot_idx < _monster_slots.size():
		_monster_slots[slot_idx]["ult_lbl"].visible = false
	# Efeito placeholder: burst de dano = 3× DPS do monstro
	var dmg := m.expected_dps() * 3.0
	_enemy_hp = maxf(_enemy_hp - dmg, 0.0)
	var ep := _enemy_panel_center()
	_spawn_number(ep, "-%s" % Numbers.format(dmg), ThemeHelper.FEVER_CLR.lightened(0.2))
	_spawn_number(ep + Vector2(0, -40), ult_name, ThemeHelper.FEVER_CLR)

# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _on_enemy_clicked() -> void:
	if _enemy_max_hp <= 0.0:
		return
	var dmg := GameState.click_damage()
	_enemy_hp = maxf(_enemy_hp - dmg, 0.0)
	GameState.combat.add_fever_click()
	_spawn_number(_enemy_panel_center(), "-%s" % Numbers.format(dmg), ThemeHelper.HP_LOW)
	_flash_enemy()

func _on_monster_clicked(slot_idx: int) -> void:
	if slot_idx >= GameState.team.size():
		return
	var m := GameState.team[slot_idx]
	if m == null:
		return
	var pos := _card_center_pos(slot_idx)
	if m.is_ult_ready():
		# Disparo manual da ultimate (v2 §1)
		_fire_ultimate_slot(slot_idx)
	else:
		# Clique no aliado carrega +5% da barra de Ultimate (v2 §5)
		if m.add_ult_energy(0.05):
			_on_ult_ready(slot_idx)
		var el := m.data.element if m.data != null else "FOGO"
		_spawn_number(pos, "+ULT", ThemeHelper.element_color(el))

# Flash branco rápido no inimigo ao receber clique (game feel).
func _flash_enemy() -> void:
	if _enemy_type_icon == null:
		return
	_enemy_type_icon.modulate = Color(2.0, 2.0, 2.0)
	var tw := create_tween()
	tw.tween_property(_enemy_type_icon, "modulate", Color.WHITE, 0.15)

# ---------------------------------------------------------------------------
# Lógica de inimigos e fases
# ---------------------------------------------------------------------------

func _spawn_enemy() -> void:
	var phase    := GameState.current_phase
	var is_boss  := (phase % 10 == 0)
	var enemies  := ContentDB.enemies.values()
	if enemies.is_empty():
		return
	_enemy_type = enemies[GameState.rng.randi() % enemies.size()]
	_enemy_max_hp = _enemy_type.hp_mult * (
		Formulas.boss_hp(phase) if is_boss else Formulas.enemy_hp(phase))
	_enemy_hp = _enemy_max_hp

	if is_boss:
		GameState.combat.enter_phase(phase)
	else:
		GameState.combat.phase_state = CombatState.PhaseState.COMBAT

	_refresh_enemy_ui()
	_update_enemy_icon()

func _update_enemy_icon() -> void:
	if _enemy_type == null:
		return
	var c := ThemeHelper.enemy_type_color(_enemy_type.type)
	_enemy_type_icon.color = c
	# BRUISER: ícone grande, SWARM: pequeno
	match _enemy_type.type:
		"BRUISER": _enemy_type_icon.custom_minimum_size = Vector2(90, 90)
		"SWARM":   _enemy_type_icon.custom_minimum_size = Vector2(50, 50)
		"DIVER":   _enemy_type_icon.custom_minimum_size = Vector2(65, 75)
		_:         _enemy_type_icon.custom_minimum_size = Vector2(70, 70)
	_enemy_type_lbl.text = ThemeHelper.enemy_type_label(_enemy_type.type)

func _on_enemy_killed() -> void:
	var phase   := GameState.current_phase
	var is_boss := (phase % 10 == 0)
	var gold    := BattleSimulator.gold_per_kill(phase)
	GameState.gold += gold
	_spawn_number(_enemy_panel_center(), "+%s G" % Numbers.format(gold), ThemeHelper.GOLD_COLOR)

	if is_boss:
		_advance_phase()
	else:
		_kills_this_phase += 1
		if _kills_this_phase >= KILLS_PER_PHASE:
			_advance_phase()
		else:
			_spawn_enemy()

func _advance_phase() -> void:
	_kills_this_phase = 0
	GameState.current_phase += 1
	if GameState.current_phase > GameState.max_phase:
		GameState.max_phase = GameState.current_phase
	_biome_lbl.text = ThemeHelper.biome_name(GameState.current_phase)
	GameState.combat.enter_phase(GameState.current_phase)
	_spawn_enemy()

func _on_boss_enraged() -> void:
	# Wipe → Farm Mode (v2 §7)
	GameState.current_phase = GameState.combat.farm_phase()
	_kills_this_phase = 0
	_spawn_enemy()

func _on_challenge_boss() -> void:
	var boss_phase := GameState.combat.boss_wipe_phase
	GameState.current_phase = boss_phase
	GameState.combat.challenge_boss(boss_phase)
	_spawn_enemy()

# ---------------------------------------------------------------------------
# Construção do UI
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	# Fundo de bioma (lerpa para a cor do bioma atual)
	_bg_rect = ColorRect.new()
	_bg_rect.color = ThemeHelper.biome_color(GameState.current_phase)
	_bg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_bg_rect)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	var battle_row := HBoxContainer.new()
	battle_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	battle_row.add_theme_constant_override("separation", 2)
	root.add_child(battle_row)

	_build_monster_column(battle_row)
	_build_enemy_area(battle_row)
	_build_bottom_bar(root)

	# Overlay de números flutuantes (deve ser o último filho — desenhado por cima)
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

func _build_monster_column(parent: HBoxContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(268, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_theme_stylebox_override("panel", ThemeHelper.flat(Color(0, 0, 0, 0.35)))
	parent.add_child(scroll)

	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", 2)
	scroll.add_child(outer)

	# Cabeçalho: TIME + bioma
	var hdr_row := HBoxContainer.new()
	hdr_row.add_theme_constant_override("separation", 6)
	outer.add_child(hdr_row)
	hdr_row.add_child(ThemeHelper.label("TIME", ThemeHelper.TEXT_DIM, 12))
	_biome_lbl = ThemeHelper.label(ThemeHelper.biome_name(GameState.current_phase),
		ThemeHelper.biome_color(GameState.current_phase).lightened(0.5), 11)
	_biome_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_biome_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hdr_row.add_child(_biome_lbl)

	# Container dos cards (referência direta para rebuild limpo)
	_team_cards_container = VBoxContainer.new()
	_team_cards_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_team_cards_container.add_theme_constant_override("separation", 2)
	outer.add_child(_team_cards_container)

	_rebuild_monster_cards()

func _rebuild_monster_cards() -> void:
	for child in _team_cards_container.get_children():
		_team_cards_container.remove_child(child)
		child.queue_free()
	_monster_slots.clear()
	for i in GameState.TEAM_SIZE:
		_team_cards_container.add_child(_build_monster_card(i))

func _build_monster_card(slot_idx: int) -> Control:
	var m: MonsterInstance = GameState.team[slot_idx] if slot_idx < GameState.team.size() else null
	var el_color := ThemeHelper.element_color(m.data.element if m != null and m.data != null else "FOGO")
	var r_color  := ThemeHelper.rarity_color(m.data.rarity   if m != null and m.data != null else "COMUM")

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 88)
	btn.add_theme_stylebox_override("normal",  ThemeHelper.flat(Color(0, 0, 0, 0.50), r_color, 2, 4))
	btn.add_theme_stylebox_override("hover",   ThemeHelper.flat(Color(0, 0, 0, 0.40), r_color, 2, 4))
	btn.add_theme_stylebox_override("pressed", ThemeHelper.flat(Color(0, 0, 0, 0.60), el_color, 2, 4))
	btn.add_theme_stylebox_override("focus",   ThemeHelper.flat(Color(0, 0, 0, 0.50), r_color, 2, 4))
	btn.pressed.connect(func(): _on_monster_clicked(slot_idx))

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 1)
	btn.add_child(vbox)

	# Faixa de elemento
	var el_strip := ColorRect.new()
	el_strip.color = el_color.darkened(0.2)
	el_strip.custom_minimum_size = Vector2(0, 4)
	vbox.add_child(el_strip)

	if m != null and m.data != null:
		# Linha: Nome + indicador ULT
		var name_row := HBoxContainer.new()
		name_row.add_theme_constant_override("separation", 2)
		name_row.add_theme_constant_override("margin_left", 6)
		vbox.add_child(name_row)
		var nm := ThemeHelper.label(m.data.display_name, ThemeHelper.TEXT_MAIN, 12)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.clip_text = true
		name_row.add_child(nm)
		var ult_lbl := ThemeHelper.label("ULT!", el_color.lightened(0.3), 11)
		ult_lbl.visible = m.is_ult_ready()
		name_row.add_child(ult_lbl)

		# Estrelas + Nível
		var sub_row := HBoxContainer.new()
		sub_row.add_theme_constant_override("separation", 6)
		sub_row.add_theme_constant_override("margin_left", 6)
		vbox.add_child(sub_row)
		sub_row.add_child(ThemeHelper.label("★".repeat(m.stars), ThemeHelper.GOLD_COLOR, 10))
		sub_row.add_child(ThemeHelper.label("Nv.%d T%d" % [m.level, m.tier()], ThemeHelper.TEXT_DIM, 10))

		# HP bar (placeholder — sem dano de inimigos ainda)
		var hp_bar := ThemeHelper.progress_bar(ThemeHelper.HP_FULL, 6)
		hp_bar.add_theme_constant_override("margin_left",  5)
		hp_bar.add_theme_constant_override("margin_right", 5)
		hp_bar.value = 1.0
		vbox.add_child(hp_bar)

		# ULT bar (cor do elemento)
		var ult_bar := ThemeHelper.progress_bar(el_color, 5)
		ult_bar.add_theme_constant_override("margin_left",  5)
		ult_bar.add_theme_constant_override("margin_right", 5)
		ult_bar.value = m.ult_energy
		vbox.add_child(ult_bar)

		_monster_slots.append({"ult_bar": ult_bar, "ult_lbl": ult_lbl, "hp_bar": hp_bar})
	else:
		var empty := ThemeHelper.label("— vazio —", ThemeHelper.TEXT_DIM, 11)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(empty)
		_monster_slots.append({"ult_bar": null, "ult_lbl": null, "hp_bar": null})

	return btn

func _build_enemy_area(parent: HBoxContainer) -> void:
	var area := VBoxContainer.new()
	area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	area.add_theme_constant_override("separation", 4)
	parent.add_child(area)

	# Fase + kill counter
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	area.add_child(top_row)
	_phase_lbl = ThemeHelper.label("Fase 1", ThemeHelper.TEXT_DIM, 14)
	top_row.add_child(_phase_lbl)
	_kill_lbl = ThemeHelper.label("", ThemeHelper.TEXT_DIM, 13)
	_kill_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_kill_lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_RIGHT
	top_row.add_child(_kill_lbl)

	# Banner de boss
	_enemy_info_lbl = ThemeHelper.label("BOSS", ThemeHelper.BOSS_CLR, 14)
	_enemy_info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_enemy_info_lbl.visible = false
	area.add_child(_enemy_info_lbl)

	# Painel do inimigo (clicável para dano)
	_enemy_panel = Button.new()
	_enemy_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_enemy_panel.add_theme_stylebox_override("normal",  ThemeHelper.flat(Color(0,0,0,0.40), ThemeHelper.TEXT_DIM, 1, 10))
	_enemy_panel.add_theme_stylebox_override("hover",   ThemeHelper.flat(Color(0,0,0,0.30), ThemeHelper.TEXT_DIM, 1, 10))
	_enemy_panel.add_theme_stylebox_override("pressed", ThemeHelper.flat(Color(0,0,0,0.55), ThemeHelper.TEXT_DIM, 1, 10))
	_enemy_panel.add_theme_stylebox_override("focus",   ThemeHelper.flat(Color(0,0,0,0.40), ThemeHelper.TEXT_DIM, 1, 10))
	_enemy_panel.pressed.connect(_on_enemy_clicked)
	area.add_child(_enemy_panel)

	var inner := VBoxContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", 8)
	_enemy_panel.add_child(inner)

	# Ícone do inimigo (varia por tipo)
	var icon_center := HBoxContainer.new()
	icon_center.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_child(icon_center)
	_enemy_type_icon = ColorRect.new()
	_enemy_type_icon.custom_minimum_size = Vector2(70, 70)
	icon_center.add_child(_enemy_type_icon)

	_enemy_type_lbl = ThemeHelper.label("", Color.WHITE, 30)
	_enemy_type_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_enemy_type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_enemy_type_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_enemy_type_icon.add_child(_enemy_type_lbl)

	_enemy_name_lbl = ThemeHelper.label("...", ThemeHelper.TEXT_MAIN, 18)
	_enemy_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(_enemy_name_lbl)

	_enemy_hp_lbl = ThemeHelper.label("", ThemeHelper.HP_FULL, 13)
	_enemy_hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(_enemy_hp_lbl)

	_enemy_hp_bar = ThemeHelper.progress_bar(ThemeHelper.HP_FULL, 12)
	_enemy_hp_bar.add_theme_constant_override("margin_left",  16)
	_enemy_hp_bar.add_theme_constant_override("margin_right", 16)
	inner.add_child(_enemy_hp_bar)

	var hint_lbl := ThemeHelper.label("[ toque para atacar ]", ThemeHelper.TEXT_DIM, 11)
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(hint_lbl)

	# Barras de enrage do boss
	_enrage_lbl = ThemeHelper.label("", ThemeHelper.DANGER_CLR, 13)
	_enrage_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_enrage_lbl.visible = false
	area.add_child(_enrage_lbl)

	_enrage_bar = ThemeHelper.progress_bar(ThemeHelper.DANGER_CLR, 10)
	_enrage_bar.visible = false
	area.add_child(_enrage_bar)

	# Banner Farm Mode
	_build_farm_banner(area)

func _build_farm_banner(parent: VBoxContainer) -> void:
	_farm_banner = PanelContainer.new()
	_farm_banner.visible = false
	_farm_banner.add_theme_stylebox_override("panel",
		ThemeHelper.flat(Color(0.12, 0.06, 0.02), ThemeHelper.FEVER_CLR, 2, 8))
	parent.add_child(_farm_banner)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_farm_banner.add_child(col)

	col.add_child(ThemeHelper.label("FARM MODE", ThemeHelper.FEVER_CLR, 15))
	_farm_lbl = ThemeHelper.label("", ThemeHelper.TEXT_DIM, 13)
	_farm_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_farm_lbl)

	var challenge_btn := ThemeHelper.button("Desafiar Boss", ThemeHelper.BOSS_CLR, 14)
	challenge_btn.pressed.connect(_on_challenge_boss)
	col.add_child(challenge_btn)

func _build_bottom_bar(parent: VBoxContainer) -> void:
	var bar := HBoxContainer.new()
	bar.custom_minimum_size = Vector2(0, 108)
	bar.add_theme_constant_override("separation", 0)
	parent.add_child(bar)

	# Fever (esquerda)
	var fever_col := VBoxContainer.new()
	fever_col.custom_minimum_size = Vector2(185, 0)
	fever_col.add_theme_constant_override("separation", 4)
	fever_col.add_theme_stylebox_override("panel", ThemeHelper.flat_margin(Color(0,0,0,0.45), 10))
	bar.add_child(fever_col)

	fever_col.add_child(ThemeHelper.label("FEVER MODE", ThemeHelper.FEVER_CLR, 13))
	_fever_bar = ThemeHelper.progress_bar(ThemeHelper.FEVER_CLR, 16)
	fever_col.add_child(_fever_bar)
	_fever_status_lbl = ThemeHelper.label("Toque no inimigo", ThemeHelper.TEXT_DIM, 11)
	_fever_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fever_col.add_child(_fever_status_lbl)

	bar.add_child(VSeparator.new())

	# Info de combate (direita)
	var info_col := VBoxContainer.new()
	info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_col.add_theme_constant_override("separation", 5)
	info_col.add_theme_stylebox_override("panel", ThemeHelper.flat_margin(Color(0,0,0,0.40), 10))
	bar.add_child(info_col)

	_dps_lbl   = ThemeHelper.label("DPS: —", ThemeHelper.TEXT_MAIN, 14)
	_gps_lbl   = ThemeHelper.label("Ouro/s: —", ThemeHelper.GOLD_COLOR, 13)
	_click_lbl = ThemeHelper.label("Clique: —", ThemeHelper.TEXT_DIM, 12)
	info_col.add_child(_dps_lbl)
	info_col.add_child(_gps_lbl)
	info_col.add_child(_click_lbl)

# ---------------------------------------------------------------------------
# Atualização do UI
# ---------------------------------------------------------------------------

func _refresh_combat_ui() -> void:
	_refresh_enemy_ui()
	_refresh_slots_ui()
	_refresh_fever_ui()
	_refresh_info_ui()

func _refresh_enemy_ui() -> void:
	if _enemy_max_hp <= 0.0 or _enemy_type == null:
		return

	var frac := clampf(_enemy_hp / _enemy_max_hp, 0.0, 1.0)
	_enemy_hp_bar.value = frac
	_enemy_hp_bar.add_theme_stylebox_override("fill",
		ThemeHelper.flat(ThemeHelper.hp_color(frac), Color.TRANSPARENT, 0, 3))
	_enemy_hp_lbl.text = "%s / %s" % [Numbers.format(maxf(_enemy_hp, 0.0)), Numbers.format(_enemy_max_hp)]
	_enemy_hp_lbl.add_theme_color_override("font_color", ThemeHelper.hp_color(frac))
	_enemy_name_lbl.text = _enemy_type.display_name

	var phase    := GameState.current_phase
	var is_boss  := (phase % 10 == 0)
	var in_fight := GameState.combat.phase_state == CombatState.PhaseState.BOSS_FIGHT
	var in_farm  := GameState.combat.phase_state == CombatState.PhaseState.FARM_MODE

	# Enrage bar
	if is_boss and in_fight:
		var timer := GameState.combat.boss_timer
		var ratio := 1.0 - clampf(timer / Formulas.ENRAGE_SECONDS, 0.0, 1.0)
		_enrage_bar.value = ratio
		_enrage_bar.visible = true
		_enrage_lbl.text = "Enrage em %.1fs" % (Formulas.ENRAGE_SECONDS - timer)
		_enrage_lbl.visible = true
		_enemy_info_lbl.visible = true
		var dc := ThemeHelper.DANGER_CLR.lerp(ThemeHelper.BOSS_CLR, 1.0 - ratio)
		_enrage_bar.add_theme_stylebox_override("fill", ThemeHelper.flat(dc, Color.TRANSPARENT, 0, 3))
	else:
		_enrage_bar.visible = false
		_enrage_lbl.visible = false
		_enemy_info_lbl.visible = is_boss and not in_farm

	# Farm Mode banner
	_farm_banner.visible = in_farm
	if in_farm:
		_farm_lbl.text = "Farmando fase %d — boss bloqueado em %d" % [
			GameState.combat.farm_phase(), GameState.combat.boss_wipe_phase]

	_phase_lbl.text = "Fase %d" % phase
	_phase_lbl.add_theme_color_override("font_color",
		ThemeHelper.BOSS_CLR if (is_boss and in_fight) else ThemeHelper.TEXT_DIM)
	if not is_boss:
		_kill_lbl.text = "%d / %d" % [_kills_this_phase, KILLS_PER_PHASE]
	else:
		_kill_lbl.text = ""

func _refresh_slots_ui() -> void:
	for i in _monster_slots.size():
		var slot: Dictionary = _monster_slots[i]
		var m: MonsterInstance = GameState.team[i] if i < GameState.team.size() else null
		if m == null or slot["ult_bar"] == null:
			continue
		slot["ult_bar"].value = m.ult_energy
		slot["ult_lbl"].visible = m.is_ult_ready()

func _refresh_fever_ui() -> void:
	var c := GameState.combat
	_fever_bar.value = 1.0 if c.fever_active else c.fever_bar
	if c.fever_active:
		_fever_bar.add_theme_stylebox_override("fill", ThemeHelper.flat(ThemeHelper.FEVER_CLR.lightened(0.3)))
		_fever_status_lbl.text = "ATIVO! (%.1fs)" % c.fever_timer
		_fever_status_lbl.add_theme_color_override("font_color", ThemeHelper.FEVER_CLR)
	elif c.fever_cooldown > 0.0:
		_fever_bar.add_theme_stylebox_override("fill", ThemeHelper.flat(ThemeHelper.TEXT_DIM))
		_fever_status_lbl.text = "Cooldown: %.0fs" % c.fever_cooldown
		_fever_status_lbl.add_theme_color_override("font_color", ThemeHelper.TEXT_DIM)
	else:
		_fever_bar.add_theme_stylebox_override("fill", ThemeHelper.flat(ThemeHelper.FEVER_CLR))
		_fever_status_lbl.text = "Toque no inimigo"
		_fever_status_lbl.add_theme_color_override("font_color", ThemeHelper.TEXT_DIM)

func _refresh_info_ui() -> void:
	var dps := GameState.team_base_dps()
	var gps := BattleSimulator.gold_per_second(dps, GameState.current_phase)
	_dps_lbl.text   = "DPS: %s" % Numbers.format(dps)
	_gps_lbl.text   = "Ouro/s: %s" % Numbers.format(gps)
	_click_lbl.text = "Clique: %s" % Numbers.format(GameState.click_damage())

# ---------------------------------------------------------------------------
# Números flutuantes
# ---------------------------------------------------------------------------

func _spawn_number(pos: Vector2, text: String, color: Color) -> void:
	var lbl := ThemeHelper.label(text, color, 17)
	lbl.position = pos - Vector2(30, 10)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(lbl)
	var drift := Vector2(GameState.rng.randf_range(-22.0, 22.0), -72.0)
	var tween := create_tween()
	tween.tween_property(lbl, "position", lbl.position + drift, 0.85)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 0.85)
	tween.tween_callback(lbl.queue_free)

# ---------------------------------------------------------------------------
# Posições de referência (aproximadas, sem overhead de get_global_rect)
# ---------------------------------------------------------------------------

func _card_center_pos(slot_idx: int) -> Vector2:
	return Vector2(134.0, 28.0 + slot_idx * 92.0)

func _enemy_panel_center() -> Vector2:
	if _enemy_panel == null:
		return Vector2(430, 350)
	var r := _enemy_panel.get_global_rect()
	return r.get_center() - get_global_rect().position

# ---------------------------------------------------------------------------
# API pública
# ---------------------------------------------------------------------------

func notify_team_changed() -> void:
	_rebuild_monster_cards()
