class_name TeamScreen
extends Control

# Tela de gestão do time: slots + inventário + seção de talentos com picker.

signal team_changed

var _selected_slot: int = -1
var _team_grid: GridContainer          # referência direta para rebuild
var _team_buttons: Array = []          # Button por slot (para highlight de seleção)
var _synergy_lbl: Label
var _inv_grid: GridContainer
var _talent_list: VBoxContainer        # lista de linhas de talento
var _selected_info_lbl: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	refresh()

# ---------------------------------------------------------------------------
# Construção do UI
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = ThemeHelper.BG_ROOT
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root_scroll := ScrollContainer.new()
	root_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(root_scroll)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 0)
	root_scroll.add_child(root)

	_build_team_section(root)
	_build_talent_section(root)
	_build_inventory_section(root)

func _build_team_section(parent: VBoxContainer) -> void:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)
	section.add_theme_stylebox_override("panel", ThemeHelper.flat_margin(ThemeHelper.BG_PANEL, 10))
	parent.add_child(section)

	# Cabeçalho
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 8)
	section.add_child(hdr)
	hdr.add_child(ThemeHelper.label("TIME", ThemeHelper.TEXT_MAIN, 16))
	_synergy_lbl = ThemeHelper.label("", ThemeHelper.TEXT_DIM, 11)
	_synergy_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_synergy_lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_RIGHT
	hdr.add_child(_synergy_lbl)

	# Grid de slots 4×2
	_team_grid = GridContainer.new()
	_team_grid.columns = 4
	_team_grid.add_theme_constant_override("h_separation", 5)
	_team_grid.add_theme_constant_override("v_separation", 5)
	section.add_child(_team_grid)

	# Dica de seleção
	_selected_info_lbl = ThemeHelper.label("", ThemeHelper.TEXT_DIM, 11)
	_selected_info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	section.add_child(_selected_info_lbl)

	# Botão de prestígio (se disponível)
	if GameState.max_phase >= Formulas.PRESTIGE_UNLOCK_PHASE:
		var sc := Formulas.soul_coins(GameState.max_phase)
		var pb := ThemeHelper.button("Prestigiar (+%d Soul Coins)" % sc, Color(0.48, 0.12, 0.58), 13)
		pb.pressed.connect(_on_prestige_pressed)
		section.add_child(pb)

func _build_talent_section(parent: VBoxContainer) -> void:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 5)
	section.add_theme_stylebox_override("panel", ThemeHelper.flat_margin(ThemeHelper.BG_PANEL, 10))
	parent.add_child(section)

	section.add_child(ThemeHelper.label("TALENTOS", ThemeHelper.TEXT_MAIN, 15))

	_talent_list = VBoxContainer.new()
	_talent_list.add_theme_constant_override("separation", 4)
	section.add_child(_talent_list)

func _build_inventory_section(parent: VBoxContainer) -> void:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)
	section.add_theme_stylebox_override("panel", ThemeHelper.flat_margin(ThemeHelper.BG_PANEL, 10))
	parent.add_child(section)

	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 6)
	section.add_child(hdr)
	hdr.add_child(ThemeHelper.label("INVENTÁRIO", ThemeHelper.TEXT_MAIN, 15))

	_inv_grid = GridContainer.new()
	_inv_grid.columns = 4
	_inv_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inv_grid.add_theme_constant_override("h_separation", 5)
	_inv_grid.add_theme_constant_override("v_separation", 5)
	section.add_child(_inv_grid)

# ---------------------------------------------------------------------------
# Construção de cards
# ---------------------------------------------------------------------------

func _make_slot_card(slot_idx: int) -> Button:
	var m: MonsterInstance = GameState.team[slot_idx] if slot_idx < GameState.team.size() else null
	var el_color := ThemeHelper.element_color(m.data.element if m != null and m.data != null else "FOGO")
	var r_color  := ThemeHelper.rarity_color(m.data.rarity   if m != null and m.data != null else "COMUM")
	var border   := r_color if m != null else ThemeHelper.TEXT_DIM.darkened(0.5)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 100)
	btn.add_theme_stylebox_override("normal",  ThemeHelper.flat(ThemeHelper.BG_CARD, border, 2, 6))
	btn.add_theme_stylebox_override("hover",   ThemeHelper.flat(ThemeHelper.BG_CARD.lightened(0.07), border, 2, 6))
	btn.add_theme_stylebox_override("pressed", ThemeHelper.flat(ThemeHelper.BG_CARD, el_color, 2, 6))
	btn.add_theme_stylebox_override("focus",   ThemeHelper.flat(ThemeHelper.BG_CARD, border, 2, 6))
	btn.pressed.connect(func(): _on_team_slot_pressed(slot_idx))

	var inner := VBoxContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", 2)
	btn.add_child(inner)

	if m != null and m.data != null:
		var el_strip := ColorRect.new()
		el_strip.color = el_color.darkened(0.25)
		el_strip.custom_minimum_size = Vector2(0, 5)
		inner.add_child(el_strip)

		var nm := ThemeHelper.label(m.data.display_name, ThemeHelper.TEXT_MAIN, 12)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.clip_text = true
		inner.add_child(nm)

		inner.add_child(ThemeHelper.label("★".repeat(m.stars), ThemeHelper.GOLD_COLOR, 10))
		inner.add_child(ThemeHelper.label("Nv.%d  T%d" % [m.level, m.tier()], ThemeHelper.TEXT_DIM, 10))

		var ult_frac_lbl := ThemeHelper.label(
			"ULT: %.0f%%" % (m.ult_energy * 100.0), ThemeHelper.FEVER_CLR.darkened(0.1), 10)
		ult_frac_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inner.add_child(ult_frac_lbl)

		# Botão remover (canto superior direito)
		var rm := Button.new()
		rm.text = "x"
		rm.custom_minimum_size = Vector2(22, 18)
		rm.add_theme_font_size_override("font_size", 10)
		rm.add_theme_color_override("font_color", ThemeHelper.TEXT_MAIN)
		rm.add_theme_stylebox_override("normal",  ThemeHelper.flat(ThemeHelper.DANGER_CLR.darkened(0.3), Color.TRANSPARENT, 0, 3))
		rm.add_theme_stylebox_override("hover",   ThemeHelper.flat(ThemeHelper.DANGER_CLR, Color.TRANSPARENT, 0, 3))
		rm.add_theme_stylebox_override("pressed", ThemeHelper.flat(ThemeHelper.DANGER_CLR, Color.TRANSPARENT, 0, 3))
		rm.add_theme_stylebox_override("focus",   ThemeHelper.flat(ThemeHelper.DANGER_CLR.darkened(0.3), Color.TRANSPARENT, 0, 3))
		rm.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		rm.position = Vector2(-25, 2)
		rm.pressed.connect(func(): _on_remove_pressed(slot_idx))
		btn.add_child(rm)
	else:
		inner.add_child(ThemeHelper.label("— vazio —", ThemeHelper.TEXT_DIM, 11))

	return btn

func _make_inv_card(inv_idx: int) -> Button:
	var m := GameState.inventory[inv_idx]
	var el_color := ThemeHelper.element_color(m.data.element if m.data != null else "FOGO")
	var r_color  := ThemeHelper.rarity_color(m.data.rarity   if m.data != null else "COMUM")

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 100)
	btn.add_theme_stylebox_override("normal",  ThemeHelper.flat(ThemeHelper.BG_CARD, r_color, 2, 6))
	btn.add_theme_stylebox_override("hover",   ThemeHelper.flat(ThemeHelper.BG_CARD.lightened(0.07), r_color, 2, 6))
	btn.add_theme_stylebox_override("pressed", ThemeHelper.flat(ThemeHelper.BG_CARD, el_color, 2, 6))
	btn.add_theme_stylebox_override("focus",   ThemeHelper.flat(ThemeHelper.BG_CARD, r_color, 2, 6))
	btn.pressed.connect(func(): _on_inv_card_pressed(inv_idx))

	var inner := VBoxContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", 2)
	btn.add_child(inner)

	var el_strip := ColorRect.new()
	el_strip.color = el_color.darkened(0.25)
	el_strip.custom_minimum_size = Vector2(0, 4)
	inner.add_child(el_strip)

	var nm := ThemeHelper.label(m.data.display_name if m.data != null else "?", ThemeHelper.TEXT_MAIN, 11)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.clip_text = true
	inner.add_child(nm)

	inner.add_child(ThemeHelper.label(m.data.rarity if m.data != null else "?", r_color, 10))
	inner.add_child(ThemeHelper.label("★".repeat(m.stars), ThemeHelper.GOLD_COLOR, 10))

	var frags := int(GameState.fragments.get(m.data.id, 0)) if m.data != null else 0
	if frags > 0:
		inner.add_child(ThemeHelper.label("Frag: %d" % frags, ThemeHelper.GEM_COLOR, 10))

	return btn

# ---------------------------------------------------------------------------
# Interação de slots
# ---------------------------------------------------------------------------

func _on_team_slot_pressed(slot_idx: int) -> void:
	if _selected_slot == -1:
		_selected_slot = slot_idx
		_highlight_slot(slot_idx, true)
		var m: MonsterInstance = GameState.team[slot_idx] if slot_idx < GameState.team.size() else null
		_selected_info_lbl.text = ("Selecionado: %s — toque em outro para trocar" %
			m.data.display_name) if m != null else "Slot vazio selecionado."
	elif _selected_slot == slot_idx:
		_deselect()
	else:
		GameState.swap_team_slots(_selected_slot, slot_idx)
		_deselect()
		emit_signal("team_changed")
		refresh()

func _on_remove_pressed(slot_idx: int) -> void:
	GameState.remove_from_team(slot_idx)
	_deselect()
	emit_signal("team_changed")
	refresh()

func _on_inv_card_pressed(inv_idx: int) -> void:
	if GameState.team.size() >= GameState.TEAM_SIZE:
		_selected_info_lbl.text = "Time cheio! Remova um monstro primeiro."
		return
	GameState.move_to_team(inv_idx)
	_deselect()
	emit_signal("team_changed")
	refresh()

func _on_prestige_pressed() -> void:
	GameState.do_prestige()
	emit_signal("team_changed")
	refresh()

func _highlight_slot(slot_idx: int, on: bool) -> void:
	if slot_idx >= _team_buttons.size():
		return
	var btn: Button = _team_buttons[slot_idx]
	var m: MonsterInstance = GameState.team[slot_idx] if slot_idx < GameState.team.size() else null
	var el := ThemeHelper.element_color(m.data.element if m != null and m.data != null else "FOGO")
	var r  := ThemeHelper.rarity_color(m.data.rarity   if m != null and m.data != null else "COMUM")
	var bw := 3 if on else 2
	var bg := ThemeHelper.BG_CARD.lightened(0.12 if on else 0.0)
	btn.add_theme_stylebox_override("normal", ThemeHelper.flat(bg, el if on else r, bw, 6))

func _deselect() -> void:
	if _selected_slot >= 0:
		_highlight_slot(_selected_slot, false)
	_selected_slot = -1
	_selected_info_lbl.text = ""

# ---------------------------------------------------------------------------
# Picker de Talentos
# ---------------------------------------------------------------------------

func _show_talent_picker(slot_idx: int) -> void:
	var m: MonsterInstance = GameState.team[slot_idx] if slot_idx < GameState.team.size() else null
	if m == null:
		return

	# Overlay escuro cobrindo a tela inteira
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var dark := ColorRect.new()
	dark.color = Color(0, 0, 0, 0.80)
	dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dark)

	# Popup centralizado
	var popup := PanelContainer.new()
	popup.custom_minimum_size = Vector2(580, 680)
	popup.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	popup.add_theme_stylebox_override("panel", ThemeHelper.flat(ThemeHelper.BG_PANEL, ThemeHelper.TEXT_DIM, 1, 10))
	overlay.add_child(popup)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	popup.add_child(col)

	# Título
	col.add_child(ThemeHelper.label("Talento — %s" % (m.data.display_name if m.data != null else "?"),
		ThemeHelper.TEXT_MAIN, 16))

	# Lista de talentos rolável
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	var talent_col := VBoxContainer.new()
	talent_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	talent_col.add_theme_constant_override("separation", 5)
	scroll.add_child(talent_col)

	# Opção: remover talento
	talent_col.add_child(_make_talent_option(null, m, slot_idx, overlay))

	# Opções dos talentos disponíveis
	for talent in ContentDB.talents.values():
		talent_col.add_child(_make_talent_option(talent, m, slot_idx, overlay))

	# Botão fechar
	var close_btn := ThemeHelper.button("Fechar", ThemeHelper.BG_BUTTON.darkened(0.2), 14)
	close_btn.pressed.connect(func(): overlay.queue_free())
	col.add_child(close_btn)

	add_child(overlay)

func _make_talent_option(talent: TalentData, m: MonsterInstance, slot_idx: int, overlay: Control) -> Button:
	var is_current := (m.talent == talent)
	var title  := talent.display_name if talent != null else "Sem Talento"
	var desc   := talent.description  if talent != null else "Remove o talento equipado."
	var border := ThemeHelper.GOLD_COLOR if is_current else Color.TRANSPARENT
	var bw     := 2 if is_current else 0
	var bg     := ThemeHelper.BG_CARD.lightened(0.08 if is_current else 0.0)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 58)
	btn.add_theme_stylebox_override("normal",  ThemeHelper.flat(bg, border, bw, 6))
	btn.add_theme_stylebox_override("hover",   ThemeHelper.flat(bg.lightened(0.08), border, bw, 6))
	btn.add_theme_stylebox_override("pressed", ThemeHelper.flat(bg.darkened(0.06), border, bw, 6))
	btn.add_theme_stylebox_override("focus",   ThemeHelper.flat(bg, border, bw, 6))

	var inner := VBoxContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", 2)
	btn.add_child(inner)

	var t_lbl := ThemeHelper.label(title, ThemeHelper.GOLD_COLOR if is_current else ThemeHelper.TEXT_MAIN, 13)
	t_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(t_lbl)

	var d_lbl := ThemeHelper.label(desc, ThemeHelper.TEXT_DIM, 11)
	d_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(d_lbl)

	btn.pressed.connect(func():
		m.talent = talent
		GameState._recalc_synergies()
		emit_signal("team_changed")
		overlay.queue_free()
		_refresh_talent_list()
	)
	return btn

# ---------------------------------------------------------------------------
# Refresh
# ---------------------------------------------------------------------------

func refresh() -> void:
	_refresh_team_slots()
	_refresh_talent_list()
	_refresh_inventory()
	_synergy_lbl.text = SynergySystem.synergy_report(GameState.team)

func _refresh_team_slots() -> void:
	for child in _team_grid.get_children():
		_team_grid.remove_child(child)
		child.queue_free()
	_team_buttons.clear()

	for i in GameState.TEAM_SIZE:
		var btn := _make_slot_card(i)
		_team_grid.add_child(btn)
		_team_buttons.append(btn)

func _refresh_talent_list() -> void:
	for child in _talent_list.get_children():
		child.queue_free()

	for i in GameState.team.size():
		var m := GameState.team[i]
		if m == null:
			continue
		_talent_list.add_child(_build_talent_row(i, m))

	if GameState.team.is_empty():
		_talent_list.add_child(ThemeHelper.label("Nenhum monstro no time.", ThemeHelper.TEXT_DIM, 12))

func _build_talent_row(slot_idx: int, m: MonsterInstance) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 42)
	row.add_theme_constant_override("separation", 8)
	row.add_theme_stylebox_override("panel", ThemeHelper.flat_margin(ThemeHelper.BG_CARD, 8))

	# Indicador de elemento
	var el_strip := ColorRect.new()
	el_strip.color = ThemeHelper.element_color(m.data.element if m.data != null else "FOGO")
	el_strip.custom_minimum_size = Vector2(6, 0)
	row.add_child(el_strip)

	# Nome do monstro
	var nm := ThemeHelper.label(m.data.display_name if m.data != null else "?", ThemeHelper.TEXT_MAIN, 12)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.clip_text = true
	row.add_child(nm)

	# Talento atual
	var t_text  := m.talent.display_name if m.talent != null else "Nenhum"
	var t_color := ThemeHelper.GOLD_COLOR if m.talent != null else ThemeHelper.TEXT_DIM
	var t_lbl := ThemeHelper.label(t_text, t_color, 11)
	t_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t_lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_RIGHT
	t_lbl.clip_text = true
	row.add_child(t_lbl)

	# Botão Alterar
	var ch_btn := ThemeHelper.button("Alterar", Color(0.28, 0.28, 0.48), 11)
	ch_btn.custom_minimum_size = Vector2(72, 0)
	ch_btn.pressed.connect(func(): _show_talent_picker(slot_idx))
	row.add_child(ch_btn)

	return row

func _refresh_inventory() -> void:
	for child in _inv_grid.get_children():
		child.queue_free()
	for i in GameState.inventory.size():
		_inv_grid.add_child(_make_inv_card(i))
