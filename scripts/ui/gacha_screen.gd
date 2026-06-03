class_name GachaScreen
extends Control

# Tela de gacha: escolha a caixa, puxe, veja os resultados coloridos por raridade.

const BOX_COSTS := { "BASICO": 0, "PREMIUM": 100, "LENDARIA": 500 }
const BOX_LABELS := {
	"BASICO":   "Ovo Básico",
	"PREMIUM":  "Ovo Premium",
	"LENDARIA": "Ovo Lendário",
}
const BOX_COLORS := {
	"BASICO":   Color(0.45, 0.40, 0.30),
	"PREMIUM":  Color(0.25, 0.45, 0.95),
	"LENDARIA": Color(0.75, 0.55, 0.00),
}

var _selected_box: String = "BASICO"
var _box_buttons: Dictionary = {}    # box_type -> Button
var _cost_lbl: Label
var _pity_lbl: Label
var _result_container: VBoxContainer
var _pull_one_btn: Button
var _pull_ten_btn: Button
var _feedback_lbl: Label

signal inventory_changed

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_refresh_selection()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = ThemeHelper.BG_ROOT
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	root.add_theme_stylebox_override("panel", ThemeHelper.flat_margin(ThemeHelper.BG_ROOT, 12))
	add_child(root)

	# ── Seleção de caixa ──────────────────────────────────────
	root.add_child(ThemeHelper.label("ESCOLHA A CAIXA", ThemeHelper.TEXT_DIM, 13))

	var box_row := HBoxContainer.new()
	box_row.add_theme_constant_override("separation", 8)
	root.add_child(box_row)

	for box_type in ["BASICO", "PREMIUM", "LENDARIA"]:
		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 80)
		_style_box_button(btn, box_type, false)
		btn.pressed.connect(func(): _on_box_selected(box_type))
		box_row.add_child(btn)
		_box_buttons[box_type] = btn

		var inner := VBoxContainer.new()
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		inner.add_theme_constant_override("separation", 3)
		btn.add_child(inner)

		var title := ThemeHelper.label(BOX_LABELS[box_type], ThemeHelper.TEXT_MAIN, 13)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inner.add_child(title)

		var cost_label: String
		if BOX_COSTS[box_type] == 0:
			cost_label = "Grátis (Ouro)"
		else:
			cost_label = "%d Gemas" % BOX_COSTS[box_type]
		var cost_lbl_n := ThemeHelper.label(cost_label, ThemeHelper.TEXT_DIM, 11)
		cost_lbl_n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inner.add_child(cost_lbl_n)

	# ── Info de custo e pity ──────────────────────────────────
	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 12)
	root.add_child(info_row)

	_cost_lbl = ThemeHelper.label("", ThemeHelper.GOLD_COLOR, 14)
	info_row.add_child(_cost_lbl)

	_pity_lbl = ThemeHelper.label("Pity: 0/100", ThemeHelper.GEM_COLOR, 14)
	_pity_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pity_lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_RIGHT
	info_row.add_child(_pity_lbl)

	# ── Botões de pull ────────────────────────────────────────
	var pull_row := HBoxContainer.new()
	pull_row.add_theme_constant_override("separation", 10)
	root.add_child(pull_row)

	_pull_one_btn = ThemeHelper.button("Puxar x1", Color(0.25, 0.45, 0.20), 16)
	_pull_one_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pull_one_btn.custom_minimum_size   = Vector2(0, 52)
	_pull_one_btn.pressed.connect(func(): _do_pull(1))
	pull_row.add_child(_pull_one_btn)

	_pull_ten_btn = ThemeHelper.button("Puxar x10", Color(0.45, 0.25, 0.55), 16)
	_pull_ten_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pull_ten_btn.custom_minimum_size   = Vector2(0, 52)
	_pull_ten_btn.pressed.connect(func(): _do_pull(10))
	pull_row.add_child(_pull_ten_btn)

	# Tutorial (se não feito)
	if not GameState.tutorial_done:
		var tut_btn := ThemeHelper.button("Tutorial 10x (garantido Épico)", Color(0.60, 0.40, 0.00), 14)
		tut_btn.pressed.connect(_do_tutorial_pull)
		root.add_child(tut_btn)

	# Feedback
	_feedback_lbl = ThemeHelper.label("", ThemeHelper.TEXT_DIM, 13)
	_feedback_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_feedback_lbl)

	# ── Resultados ───────────────────────────────────────────
	root.add_child(ThemeHelper.label("RESULTADOS", ThemeHelper.TEXT_DIM, 12))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	_result_container = VBoxContainer.new()
	_result_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_result_container.add_theme_constant_override("separation", 4)
	scroll.add_child(_result_container)

func _style_box_button(btn: Button, box_type: String, selected: bool) -> void:
	var base := BOX_COLORS.get(box_type, ThemeHelper.BG_CARD)
	var border := base.lightened(0.3) if selected else ThemeHelper.TEXT_DIM.darkened(0.4)
	var bw := 3 if selected else 1
	btn.add_theme_stylebox_override("normal",  ThemeHelper.flat(ThemeHelper.BG_CARD, border, bw, 8))
	btn.add_theme_stylebox_override("hover",   ThemeHelper.flat(ThemeHelper.BG_CARD.lightened(0.07), border, bw, 8))
	btn.add_theme_stylebox_override("pressed", ThemeHelper.flat(base.darkened(0.4), border, bw, 8))
	btn.add_theme_stylebox_override("focus",   ThemeHelper.flat(ThemeHelper.BG_CARD, border, bw, 8))

# ---------------------------------------------------------------------------
# Interação
# ---------------------------------------------------------------------------

func _on_box_selected(box_type: String) -> void:
	_selected_box = box_type
	for t in _box_buttons:
		_style_box_button(_box_buttons[t], t, t == box_type)
	_refresh_selection()

func _do_pull(count: int) -> void:
	var cost_per := BOX_COSTS.get(_selected_box, 0)
	var total_cost := cost_per * count
	if total_cost > 0 and GameState.gems < total_cost:
		_feedback_lbl.text = "Gemas insuficientes! Precisa: %d  Tem: %d" % [total_cost, GameState.gems]
		_feedback_lbl.add_theme_color_override("font_color", ThemeHelper.DANGER_CLR)
		return

	if total_cost > 0:
		GameState.gems -= total_cost

	var pulled: Array
	if _selected_box == "BASICO":
		# Caixa básica usa ouro (valor placeholder: 1000 de ouro por puxada)
		var gold_cost := 1000.0 * count
		if GameState.gold < gold_cost:
			_feedback_lbl.text = "Ouro insuficiente! Precisa: %s" % Numbers.format(gold_cost)
			_feedback_lbl.add_theme_color_override("font_color", ThemeHelper.DANGER_CLR)
			return
		GameState.gold -= gold_cost
		pulled = GachaSystem.pull_batch("BASICO", count, GameState.rng)
	else:
		pulled = GachaSystem.pull_batch(_selected_box, count, GameState.rng)

	_show_results(pulled)
	_refresh_selection()

func _do_tutorial_pull() -> void:
	if GameState.tutorial_done:
		return
	GameState.tutorial_done = true
	var pulled := GachaSystem.tutorial_pull(GameState.rng)
	_show_results(pulled)
	_refresh_selection()
	emit_signal("inventory_changed")

func _show_results(pulled: Array) -> void:
	for child in _result_container.get_children():
		child.queue_free()

	var new_count := 0
	var frag_total := 0

	for md in pulled:
		if md == null:
			continue
		var is_new := GameState.grant_monster(md)
		if is_new:
			new_count += 1
		else:
			frag_total += GachaSystem.DUPE_FRAGMENTS.get(md.rarity, 5)

		var row := _make_result_row(md, is_new)
		_result_container.add_child(row)

	var summary := ""
	if new_count > 0:
		summary += "+%d novo(s)  " % new_count
	if frag_total > 0:
		summary += "+%d fragmentos" % frag_total
	_feedback_lbl.text = summary
	_feedback_lbl.add_theme_color_override("font_color", ThemeHelper.HP_FULL if new_count > 0 else ThemeHelper.TEXT_DIM)

	emit_signal("inventory_changed")

func _make_result_row(md: MonsterData, is_new: bool) -> Control:
	var r_color := ThemeHelper.rarity_color(md.rarity)
	var e_color := ThemeHelper.element_color(md.element)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ThemeHelper.flat(ThemeHelper.BG_CARD, r_color, 2, 6))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	# Ícone de elemento
	var icon := ColorRect.new()
	icon.color = e_color
	icon.custom_minimum_size = Vector2(36, 36)
	row.add_child(icon)

	# Nome e raridade
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)

	var nm := ThemeHelper.label(md.display_name, ThemeHelper.TEXT_MAIN, 14)
	info.add_child(nm)

	var sub_row := HBoxContainer.new()
	sub_row.add_theme_constant_override("separation", 6)
	info.add_child(sub_row)

	var rar_lbl := ThemeHelper.label(md.rarity, r_color, 12)
	sub_row.add_child(rar_lbl)
	var el_lbl := ThemeHelper.label(md.element, e_color.lightened(0.2), 12)
	sub_row.add_child(el_lbl)

	# Tag NOVO ou fragmentos
	if is_new:
		var new_lbl := ThemeHelper.label("NOVO!", ThemeHelper.HP_FULL, 14)
		row.add_child(new_lbl)
	else:
		var frags := GachaSystem.DUPE_FRAGMENTS.get(md.rarity, 5)
		var frag_lbl := ThemeHelper.label("+%d Frag" % frags, ThemeHelper.GEM_COLOR, 12)
		row.add_child(frag_lbl)

	return panel

# ---------------------------------------------------------------------------
# Refresh
# ---------------------------------------------------------------------------

func _refresh_selection() -> void:
	var cost := BOX_COSTS.get(_selected_box, 0)
	if cost == 0:
		_cost_lbl.text = "Custo: 1.000 Ouro/puxada"
		_cost_lbl.add_theme_color_override("font_color", ThemeHelper.GOLD_COLOR)
	else:
		_cost_lbl.text = "Custo: %d Gemas/puxada" % cost
		_cost_lbl.add_theme_color_override("font_color", ThemeHelper.GEM_COLOR)

	var is_gem_box: bool = GachaSystem.GEM_BOX_TYPES.has(_selected_box)
	_pity_lbl.visible = is_gem_box
	if is_gem_box:
		_pity_lbl.text = "Pity: %d / %d" % [GameState.pity_counter, GachaSystem.PITY_LIMIT]
