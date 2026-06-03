class_name TeamScreen
extends Control

# Tela de gestão: slots do time + inventário. Tap em qualquer card abre o
# MonsterDetail (hub de nível/estrela/talento/formação).

signal team_changed

var _team_grid: GridContainer
var _inv_grid: GridContainer
var _synergy_lbl: Label
var _inv_count_lbl: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	refresh()

# ---------------------------------------------------------------------------
# Construção
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = ThemeHelper.BG_ROOT
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 0)
	scroll.add_child(root)

	_build_team_section(root)
	_build_inventory_section(root)

func _build_team_section(parent: VBoxContainer) -> void:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)
	section.add_theme_stylebox_override("panel", ThemeHelper.flat_margin(ThemeHelper.BG_PANEL, 10))
	parent.add_child(section)

	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 8)
	section.add_child(hdr)
	hdr.add_child(ThemeHelper.label("TIME", ThemeHelper.TEXT_MAIN, 16))
	_synergy_lbl = ThemeHelper.label("", ThemeHelper.TEXT_DIM, 11)
	_synergy_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_synergy_lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_RIGHT
	hdr.add_child(_synergy_lbl)

	section.add_child(ThemeHelper.label("Slot 1 = frente · Slot 7 = retaguarda", ThemeHelper.TEXT_DIM, 10))

	_team_grid = GridContainer.new()
	_team_grid.columns = 4
	_team_grid.add_theme_constant_override("h_separation", 5)
	_team_grid.add_theme_constant_override("v_separation", 5)
	section.add_child(_team_grid)

	if GameState.max_phase >= Formulas.PRESTIGE_UNLOCK_PHASE:
		var sc := Formulas.soul_coins(GameState.max_phase)
		var pb := ThemeHelper.button("Prestigiar (+%d Soul Coins)" % sc, Color(0.48, 0.12, 0.58), 13)
		pb.pressed.connect(_on_prestige_pressed)
		section.add_child(pb)

func _build_inventory_section(parent: VBoxContainer) -> void:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)
	section.add_theme_stylebox_override("panel", ThemeHelper.flat_margin(ThemeHelper.BG_PANEL, 10))
	parent.add_child(section)

	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 6)
	section.add_child(hdr)
	hdr.add_child(ThemeHelper.label("INVENTÁRIO", ThemeHelper.TEXT_MAIN, 16))
	_inv_count_lbl = ThemeHelper.label("", ThemeHelper.TEXT_DIM, 12)
	_inv_count_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inv_count_lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_RIGHT
	hdr.add_child(_inv_count_lbl)

	_inv_grid = GridContainer.new()
	_inv_grid.columns = 4
	_inv_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inv_grid.add_theme_constant_override("h_separation", 5)
	_inv_grid.add_theme_constant_override("v_separation", 5)
	section.add_child(_inv_grid)

# ---------------------------------------------------------------------------
# Cards
# ---------------------------------------------------------------------------

func _make_slot_card(slot_idx: int) -> Button:
	var m: MonsterInstance = GameState.team[slot_idx] if slot_idx < GameState.team.size() else null
	var el_color := ThemeHelper.element_color(m.data.element if m != null and m.data != null else "FOGO")
	var r_color  := ThemeHelper.rarity_color(m.data.rarity   if m != null and m.data != null else "COMUM")
	var border   := r_color if m != null else ThemeHelper.TEXT_DIM.darkened(0.5)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 104)
	btn.add_theme_stylebox_override("normal",  ThemeHelper.flat(ThemeHelper.BG_CARD, border, 2, 6))
	btn.add_theme_stylebox_override("hover",   ThemeHelper.flat(ThemeHelper.BG_CARD.lightened(0.07), border, 2, 6))
	btn.add_theme_stylebox_override("pressed", ThemeHelper.flat(ThemeHelper.BG_CARD, el_color, 2, 6))
	btn.add_theme_stylebox_override("focus",   ThemeHelper.flat(ThemeHelper.BG_CARD, border, 2, 6))

	var inner := VBoxContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", 2)
	btn.add_child(inner)

	# Marcador de slot (1..7)
	var slot_tag := ThemeHelper.label("#%d" % (slot_idx + 1), ThemeHelper.TEXT_DIM, 9)
	slot_tag.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	slot_tag.position = Vector2(5, 3)
	btn.add_child(slot_tag)

	if m != null and m.data != null:
		var el_strip := ColorRect.new()
		el_strip.color = el_color.darkened(0.25)
		el_strip.custom_minimum_size = Vector2(0, 5)
		inner.add_child(el_strip)

		var nm := ThemeHelper.label(m.data.display_name, ThemeHelper.TEXT_MAIN, 12)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.clip_text = true
		inner.add_child(nm)
		inner.add_child(_center(ThemeHelper.label("★".repeat(m.stars), ThemeHelper.GOLD_COLOR, 10)))
		inner.add_child(_center(ThemeHelper.label("Nv.%d  T%d" % [m.level, m.tier()], ThemeHelper.TEXT_DIM, 10)))
		inner.add_child(_center(ThemeHelper.label("DPS %s" % Numbers.format(m.expected_dps()), el_color.lightened(0.25), 10)))

		btn.pressed.connect(func(): _open_detail(m, {"in_team": true, "slot_idx": slot_idx}))
	else:
		inner.add_child(_center(ThemeHelper.label("vazio", ThemeHelper.TEXT_DIM, 11)))
		btn.disabled = true

	return btn

func _make_inv_card(inv_idx: int) -> Button:
	var m := GameState.inventory[inv_idx]
	var el_color := ThemeHelper.element_color(m.data.element if m.data != null else "FOGO")
	var r_color  := ThemeHelper.rarity_color(m.data.rarity   if m.data != null else "COMUM")

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 104)
	btn.add_theme_stylebox_override("normal",  ThemeHelper.flat(ThemeHelper.BG_CARD, r_color, 2, 6))
	btn.add_theme_stylebox_override("hover",   ThemeHelper.flat(ThemeHelper.BG_CARD.lightened(0.07), r_color, 2, 6))
	btn.add_theme_stylebox_override("pressed", ThemeHelper.flat(ThemeHelper.BG_CARD, el_color, 2, 6))
	btn.add_theme_stylebox_override("focus",   ThemeHelper.flat(ThemeHelper.BG_CARD, r_color, 2, 6))
	btn.pressed.connect(func(): _open_detail(m, {"in_team": false, "inv_idx": inv_idx}))

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
	inner.add_child(_center(ThemeHelper.label(m.data.rarity if m.data != null else "?", r_color, 10)))
	inner.add_child(_center(ThemeHelper.label("★".repeat(m.stars), ThemeHelper.GOLD_COLOR, 10)))

	var frags := int(GameState.fragments.get(m.data.id, 0)) if m.data != null else 0
	if frags > 0:
		inner.add_child(_center(ThemeHelper.label("Frag: %d" % frags, ThemeHelper.GEM_COLOR, 10)))

	return btn

# ---------------------------------------------------------------------------
# Detail popup
# ---------------------------------------------------------------------------

func _open_detail(m: MonsterInstance, opts: Dictionary) -> void:
	MonsterDetail.open(self, m, opts, _on_detail_changed)

func _on_detail_changed() -> void:
	emit_signal("team_changed")
	refresh()

func _on_prestige_pressed() -> void:
	GameState.do_prestige()
	emit_signal("team_changed")
	refresh()

# ---------------------------------------------------------------------------
# Refresh
# ---------------------------------------------------------------------------

func refresh() -> void:
	for c in _team_grid.get_children():
		c.queue_free()
	for i in GameState.TEAM_SIZE:
		_team_grid.add_child(_make_slot_card(i))

	for c in _inv_grid.get_children():
		c.queue_free()
	for i in GameState.inventory.size():
		_inv_grid.add_child(_make_inv_card(i))

	_synergy_lbl.text = SynergySystem.synergy_report(GameState.team)
	_inv_count_lbl.text = "(%d)" % GameState.inventory.size()

func _center(lbl: Label) -> Label:
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return lbl
