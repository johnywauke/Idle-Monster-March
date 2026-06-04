class_name MonsterDetail
extends Control

# Popup-hub de um monstro: stats, subir nível (ouro), subir estrela (fragmentos),
# trocar talento e mover na formação. Reutilizável a partir de qualquer tela.
#
# Uso:
#   MonsterDetail.open(self, instance, {"in_team": true, "slot_idx": 2}, on_change)
#   on_change: Callable chamado após qualquer alteração (pra tela-mãe se atualizar).

var _inst: MonsterInstance
var _opts: Dictionary
var _on_change: Callable
var _body: VBoxContainer        # conteúdo reconstruído a cada ação

static func open(host: Control, inst: MonsterInstance, opts: Dictionary, on_change: Callable) -> MonsterDetail:
	var d := MonsterDetail.new()
	d._inst = inst
	d._opts = opts
	d._on_change = on_change
	host.add_child(d)
	d._setup()
	return d

func _setup() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dark := ColorRect.new()
	dark.color = Color(0, 0, 0, 0.82)
	dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dark)

	# Clique fora fecha
	var backdrop := Button.new()
	backdrop.flat = true
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.pressed.connect(_close)
	add_child(backdrop)

	# Painel central
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(600, 720)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	var border := ThemeHelper.rarity_color(_inst.data.rarity if _inst.data != null else "COMUM")
	panel.add_theme_stylebox_override("panel", ThemeHelper.flat(ThemeHelper.BG_PANEL, border, 2, 12))
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 8)
	margin.add_child(_body)

	_rebuild()

# ---------------------------------------------------------------------------
# Reconstrução do corpo (após cada ação, pra refletir custos/stats atualizados)
# ---------------------------------------------------------------------------

func _rebuild() -> void:
	for c in _body.get_children():
		c.queue_free()

	var m := _inst
	if m == null or m.data == null:
		_close()
		return

	var el_color := ThemeHelper.element_color(m.data.element)
	var r_color  := ThemeHelper.rarity_color(m.data.rarity)

	# --- Cabeçalho ---
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	_body.add_child(head)

	var icon := ColorRect.new()
	icon.color = el_color
	icon.custom_minimum_size = Vector2(54, 54)
	head.add_child(icon)
	var face := EmojiDB.make_label(EmojiDB.for_monster(m.data.id, m.data.element), 38)
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.add_child(face)

	var head_col := VBoxContainer.new()
	head_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_col.add_theme_constant_override("separation", 2)
	head.add_child(head_col)
	head_col.add_child(ThemeHelper.label(m.data.display_name, ThemeHelper.TEXT_MAIN, 20))
	var tag_row := HBoxContainer.new()
	tag_row.add_theme_constant_override("separation", 8)
	head_col.add_child(tag_row)
	tag_row.add_child(ThemeHelper.label(m.data.element, el_color.lightened(0.2), 12))
	tag_row.add_child(ThemeHelper.label(m.data.rarity, r_color, 12))
	tag_row.add_child(ThemeHelper.label(m.data.role, ThemeHelper.TEXT_DIM, 12))
	head_col.add_child(ThemeHelper.label("★".repeat(m.stars), ThemeHelper.GOLD_COLOR, 14))

	_body.add_child(_hsep())

	# --- Stats ---
	_body.add_child(_stat_row("DPS", Numbers.format(m.expected_dps()), ThemeHelper.TEXT_MAIN))
	_body.add_child(_stat_row("ATK", Numbers.format(m.final_atk()), ThemeHelper.TEXT_DIM))
	_body.add_child(_stat_row("HP", Numbers.format(m.final_hp()), ThemeHelper.TEXT_DIM))
	_body.add_child(_stat_row("DEF", Numbers.format(m.final_def()), ThemeHelper.TEXT_DIM))
	_body.add_child(_stat_row("ASPD", "%.2f" % m.effective_aspd(), ThemeHelper.TEXT_DIM))
	_body.add_child(_stat_row("Crit", "%.0f%% / %.0f%%" % [
		m.effective_crit_rate() * 100.0, m.data.crit_dmg * 100.0], ThemeHelper.TEXT_DIM))

	_body.add_child(_hsep())

	# --- Subir Nível (ouro) — o dreno principal ---
	_body.add_child(_build_level_section(m))

	# --- Subir Estrela (fragmentos) ---
	_body.add_child(_build_star_section(m))

	# --- Talento ---
	_body.add_child(_build_talent_section(m))

	_body.add_child(_hsep())

	# --- Formação / inventário ---
	if bool(_opts.get("in_team", false)):
		_body.add_child(_build_formation_section())
	else:
		var add_btn := ThemeHelper.button("Adicionar ao Time", Color(0.25, 0.55, 0.25), 15)
		add_btn.disabled = GameState.team.size() >= GameState.TEAM_SIZE
		if add_btn.disabled:
			add_btn.text = "Time Cheio"
		add_btn.pressed.connect(_on_add_to_team)
		_body.add_child(add_btn)

	# --- Fechar ---
	var close_btn := ThemeHelper.button("Fechar", ThemeHelper.BG_BUTTON.darkened(0.25), 14)
	close_btn.pressed.connect(_close)
	_body.add_child(close_btn)

# ---------------------------------------------------------------------------
# Seções
# ---------------------------------------------------------------------------

func _card_panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", ThemeHelper.flat_margin(ThemeHelper.BG_CARD, 10))
	return p

func _build_level_section(m: MonsterInstance) -> Control:
	var panel := _card_panel()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)

	var top := HBoxContainer.new()
	box.add_child(top)
	top.add_child(ThemeHelper.label("Nível %d  (Tier %d)" % [m.level, m.tier()], ThemeHelper.TEXT_MAIN, 14))

	var cost := GameState.level_up_cost(m)
	var affordable := GameState.gold >= cost
	var cost_lbl := ThemeHelper.label("Custo: %s" % Numbers.format(cost),
		ThemeHelper.GOLD_COLOR if affordable else ThemeHelper.DANGER_CLR, 13)
	cost_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cost_lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(cost_lbl)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	box.add_child(btn_row)

	var up1 := ThemeHelper.button("Subir Nível", Color(0.25, 0.50, 0.25), 15)
	up1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	up1.disabled = not affordable
	up1.pressed.connect(_on_level_up_one)
	btn_row.add_child(up1)

	var upmax := ThemeHelper.button("Máx", Color(0.40, 0.30, 0.55), 15)
	upmax.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upmax.disabled = not affordable
	upmax.pressed.connect(_on_level_up_max)
	btn_row.add_child(upmax)

	return panel

func _build_star_section(m: MonsterInstance) -> Control:
	var panel := _card_panel()
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var have := int(GameState.fragments.get(m.data.id, 0))
	var cost_idx := m.stars - 1
	var max_star := cost_idx >= GachaSystem.STAR_UPGRADE_COST.size()

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	box.add_child(info)
	info.add_child(ThemeHelper.label("Estrelas: %s" % "★".repeat(m.stars), ThemeHelper.GOLD_COLOR, 14))

	if max_star:
		info.add_child(ThemeHelper.label("Estrelas no máximo!", ThemeHelper.TEXT_DIM, 12))
		return panel

	var cost: int = GachaSystem.STAR_UPGRADE_COST[cost_idx]
	var can := have >= cost
	info.add_child(ThemeHelper.label("Fragmentos: %d / %d" % [have, cost],
		ThemeHelper.GEM_COLOR if can else ThemeHelper.DANGER_CLR, 12))

	var btn := ThemeHelper.button("Subir Estrela", ThemeHelper.GOLD_COLOR.darkened(0.35), 14)
	btn.custom_minimum_size = Vector2(150, 0)
	btn.disabled = not can
	btn.pressed.connect(_on_star_up)
	box.add_child(btn)

	return panel

func _build_talent_section(m: MonsterInstance) -> Control:
	var panel := _card_panel()
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	box.add_child(info)
	info.add_child(ThemeHelper.label("Talento", ThemeHelper.TEXT_DIM, 11))
	var t_name := m.talent.display_name if m.talent != null else "Nenhum"
	info.add_child(ThemeHelper.label(t_name,
		ThemeHelper.GOLD_COLOR if m.talent != null else ThemeHelper.TEXT_MAIN, 14))
	if m.talent != null:
		var d := ThemeHelper.label(m.talent.description, ThemeHelper.TEXT_DIM, 11)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(d)

	var btn := ThemeHelper.button("Alterar", Color(0.28, 0.28, 0.48), 13)
	btn.custom_minimum_size = Vector2(110, 0)
	btn.pressed.connect(_show_talent_picker)
	box.add_child(btn)

	return panel

func _build_formation_section() -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)

	var slot_idx := int(_opts.get("slot_idx", 0))

	var fwd := ThemeHelper.button("◀ Frente", Color(0.30, 0.40, 0.55), 13)
	fwd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fwd.disabled = slot_idx <= 0
	fwd.pressed.connect(func(): _move_in_formation(-1))
	box.add_child(fwd)

	var back := ThemeHelper.button("Trás ▶", Color(0.30, 0.40, 0.55), 13)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.disabled = slot_idx >= GameState.team.size() - 1
	back.pressed.connect(func(): _move_in_formation(1))
	box.add_child(back)

	var rm := ThemeHelper.button("Remover", ThemeHelper.DANGER_CLR.darkened(0.15), 13)
	rm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rm.pressed.connect(_on_remove)
	box.add_child(rm)

	return box

# ---------------------------------------------------------------------------
# Ações
# ---------------------------------------------------------------------------

func _on_level_up_one() -> void:
	if GameState.try_level_up(_inst):
		_notify()
		_rebuild()

func _on_level_up_max() -> void:
	var n := GameState.level_up_max(_inst)
	if n > 0:
		_notify()
		_rebuild()

func _on_star_up() -> void:
	if GachaSystem.upgrade_star(_inst, GameState.fragments):
		_notify()
		_rebuild()

func _move_in_formation(dir: int) -> void:
	var slot_idx := int(_opts.get("slot_idx", 0))
	var target := slot_idx + dir
	if target < 0 or target >= GameState.team.size():
		return
	GameState.swap_team_slots(slot_idx, target)
	_opts["slot_idx"] = target
	_notify()
	_rebuild()

func _on_remove() -> void:
	GameState.remove_from_team(int(_opts.get("slot_idx", 0)))
	_notify()
	_close()

func _on_add_to_team() -> void:
	if GameState.move_to_team(int(_opts.get("inv_idx", 0))):
		_notify()
		_close()

# ---------------------------------------------------------------------------
# Sub-picker de talento
# ---------------------------------------------------------------------------

func _show_talent_picker() -> void:
	var sub := Control.new()
	sub.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sub.mouse_filter = Control.MOUSE_FILTER_STOP

	var dark := ColorRect.new()
	dark.color = Color(0, 0, 0, 0.6)
	dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sub.add_child(dark)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(540, 600)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.add_theme_stylebox_override("panel", ThemeHelper.flat(ThemeHelper.BG_PANEL, ThemeHelper.TEXT_DIM, 1, 10))
	sub.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	col.add_child(ThemeHelper.label("Escolher Talento", ThemeHelper.TEXT_MAIN, 16))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)

	list.add_child(_talent_option(null, sub))
	for t in ContentDB.talents.values():
		list.add_child(_talent_option(t, sub))

	var close := ThemeHelper.button("Cancelar", ThemeHelper.BG_BUTTON.darkened(0.25), 13)
	close.pressed.connect(sub.queue_free)
	col.add_child(close)

	add_child(sub)

func _talent_option(t: TalentData, sub: Control) -> Button:
	var is_cur := (_inst.talent == t)
	var title := t.display_name if t != null else "Sem Talento"
	var desc  := t.description  if t != null else "Remove o talento atual."
	var border := ThemeHelper.GOLD_COLOR if is_cur else Color.TRANSPARENT
	var bw := 2 if is_cur else 0

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 56)
	btn.add_theme_stylebox_override("normal",  ThemeHelper.flat(ThemeHelper.BG_CARD, border, bw, 6))
	btn.add_theme_stylebox_override("hover",   ThemeHelper.flat(ThemeHelper.BG_CARD.lightened(0.08), border, bw, 6))
	btn.add_theme_stylebox_override("pressed", ThemeHelper.flat(ThemeHelper.BG_CARD.darkened(0.06), border, bw, 6))
	btn.add_theme_stylebox_override("focus",   ThemeHelper.flat(ThemeHelper.BG_CARD, border, bw, 6))

	var inner := VBoxContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", 2)
	btn.add_child(inner)
	var tl := ThemeHelper.label(title, ThemeHelper.GOLD_COLOR if is_cur else ThemeHelper.TEXT_MAIN, 13)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(tl)
	var dl := ThemeHelper.label(desc, ThemeHelper.TEXT_DIM, 11)
	dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(dl)

	btn.pressed.connect(func():
		_inst.talent = t
		GameState._recalc_synergies()
		_notify()
		sub.queue_free()
		_rebuild()
	)
	return btn

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _stat_row(name: String, value: String, value_color: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_child(ThemeHelper.label(name, ThemeHelper.TEXT_DIM, 13))
	var v := ThemeHelper.label(value, value_color, 14)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.horizontal_alignment  = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(v)
	return row

func _hsep() -> Control:
	var s := HSeparator.new()
	s.add_theme_color_override("color", ThemeHelper.BG_CARD.lightened(0.1))
	return s

func _notify() -> void:
	if _on_change.is_valid():
		_on_change.call()

func _close() -> void:
	queue_free()
