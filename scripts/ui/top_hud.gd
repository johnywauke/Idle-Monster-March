class_name TopHUD
extends PanelContainer

# Barra superior: Fase | Ouro | Gemas. Atualizada pelo ScreenManager a cada frame.

var _phase_lbl: Label
var _gold_lbl: Label
var _gems_lbl: Label
var _sc_lbl: Label

func _ready() -> void:
	custom_minimum_size = Vector2(0, 72)
	add_theme_stylebox_override("panel", ThemeHelper.flat(ThemeHelper.BG_ROOT))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	add_child(row)

	# Fase (fixo, esquerda)
	var phase_box := _section(130)
	_phase_lbl = ThemeHelper.label("Fase 1", ThemeHelper.TEXT_DIM, 13)
	_phase_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_phase_lbl.size_flags_vertical  = Control.SIZE_EXPAND_FILL
	phase_box.add_child(_phase_lbl)
	row.add_child(phase_box)

	# Ouro (expande, centro)
	var gold_box := PanelContainer.new()
	gold_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gold_box.add_theme_stylebox_override("panel", ThemeHelper.flat_margin(ThemeHelper.BG_PANEL, 8))
	var gold_row := HBoxContainer.new()
	gold_row.alignment = BoxContainer.ALIGNMENT_CENTER
	gold_row.add_theme_constant_override("separation", 6)
	gold_box.add_child(gold_row)
	gold_row.add_child(ThemeHelper.label("G:", ThemeHelper.GOLD_COLOR, 14))
	_gold_lbl = ThemeHelper.label("0", ThemeHelper.GOLD_COLOR, 20)
	gold_row.add_child(_gold_lbl)
	row.add_child(gold_box)

	# Gemas + Soul Coins (fixo, direita)
	var right_box := _section(130)
	var right_col := VBoxContainer.new()
	right_col.alignment = BoxContainer.ALIGNMENT_CENTER
	right_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_box.add_child(right_col)
	var gem_row := HBoxContainer.new()
	gem_row.alignment = BoxContainer.ALIGNMENT_CENTER
	gem_row.add_theme_constant_override("separation", 4)
	gem_row.add_child(ThemeHelper.label("Gem:", ThemeHelper.GEM_COLOR, 12))
	_gems_lbl = ThemeHelper.label("0", ThemeHelper.GEM_COLOR, 15)
	gem_row.add_child(_gems_lbl)
	right_col.add_child(gem_row)
	_sc_lbl = ThemeHelper.label("SC: 0", ThemeHelper.TEXT_DIM, 11)
	_sc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_col.add_child(_sc_lbl)
	row.add_child(right_box)

func _section(min_w: int) -> PanelContainer:
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(min_w, 0)
	box.add_theme_stylebox_override("panel", ThemeHelper.flat_margin(ThemeHelper.BG_PANEL, 8))
	return box

func refresh() -> void:
	var phase := GameState.current_phase
	var is_boss := (phase % 10 == 0)
	_phase_lbl.text = ("BOSS %d" % phase) if is_boss else ("Fase %d" % phase)
	_phase_lbl.add_theme_color_override("font_color",
		ThemeHelper.BOSS_CLR if is_boss else ThemeHelper.TEXT_DIM)
	_gold_lbl.text = Numbers.format(GameState.gold)
	_gems_lbl.text = str(GameState.gems)
	_sc_lbl.text   = "SC: %d" % GameState.soul_coins
