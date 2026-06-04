
Conversa com o Gemini
class_name SynergySystem

extends RefCounted



# Sistema de sinergias de elemento e adjacência (v2 §6).

# Funções puras — GameState._recalc_synergies() injeta os bônus em cada MonsterInstance.

# Todos os valores são placeholders de tuning (v2 §10).



# Limiares de acumulação: 2, 4 ou 6 monstros do mesmo elemento.

const THRESHOLDS := [2, 4, 6]



# Bônus por limiar de cada elemento. Entram no bucket % aditivo do pipeline (v2 §2).

# FOGO: ofensivo (ATK) | ÁGUA: sustain (HP + revive @6 no combate) | TERRA: armadura (DEF)

# VENTO: velocidade (ASPD) | RAIO: crítico (Crit Rate, flat add ao cap)

const ELEMENT_SYNERGY := {

"FOGO": {

2: {"atk_pct": 0.08},

4: {"atk_pct": 0.20},

6: {"atk_pct": 0.40},

},

"AGUA": {

2: {"hp_pct": 0.08},

4: {"hp_pct": 0.20},

6: {"hp_pct": 0.40},

},

"TERRA": {

2: {"def_pct": 0.10},

4: {"def_pct": 0.25},

6: {"def_pct": 0.50},

},

"VENTO": {

2: {"aspd_pct": 0.08},

4: {"aspd_pct": 0.18},

6: {"aspd_pct": 0.35},

},

"RAIO": {

2: {"crit_rate_add": 0.04},

4: {"crit_rate_add": 0.10},

6: {"crit_rate_add": 0.20},

},

}



# Adjacência: dois vizinhos do mesmo elemento se dão +5% ATK mutuamente. (v2 §6)

const ADJACENCY_ATK_PCT := 0.05



# Retorna dicionário elemento -> limiar ativo (2, 4 ou 6) para o time dado.

static func active_synergies(team: Array) -> Dictionary:

var count := {}

for m in team:

if m != null and m.data != null:

var el: String = m.data.element

count[el] = count.get(el, 0) + 1

var active := {}

for el in count:

var highest := 0

for t in THRESHOLDS:

if int(count[el]) >= t:

highest = t

if highest > 0:

active[el] = highest

return active



static func _element_stat(element: String, team: Array, key: String) -> float:

var active := active_synergies(team)

if not active.has(element):

return 0.0

var el_dict: Dictionary = ELEMENT_SYNERGY.get(element, {})

var tier_dict: Dictionary = el_dict.get(active[element], {})

return float(tier_dict.get(key, 0.0))



static func _adjacency_atk(idx: int, team: Array) -> float:

if idx < 0 or idx >= team.size():

return 0.0

var m = team[idx]

if m == null or m.data == null:

return 0.0

var el: String = m.data.element

var pct := 0.0

for offset in [-1, 1]:

var ni := idx + offset

if ni >= 0 and ni < team.size():

var nb = team[ni]

if nb != null and nb.data != null and nb.data.element == el:

pct += ADJACENCY_ATK_PCT

return pct



static func get_atk_pct(idx: int, team: Array) -> float:

if idx < 0 or idx >= team.size() or team[idx] == null or team[idx].data == null:

return 0.0

return _element_stat(team[idx].data.element, team, "atk_pct") + _adjacency_atk(idx, team)



static func get_hp_pct(idx: int, team: Array) -> float:

if idx < 0 or idx >= team.size() or team[idx] == null or team[idx].data == null:

return 0.0

return _element_stat(team[idx].data.element, team, "hp_pct")



static func get_def_pct(idx: int, team: Array) -> float:

if idx < 0 or idx >= team.size() or team[idx] == null or team[idx].data == null:

return 0.0

return _element_stat(team[idx].data.element, team, "def_pct")



static func get_aspd_pct(idx: int, team: Array) -> float:

if idx < 0 or idx >= team.size() or team[idx] == null or team[idx].data == null:

return 0.0

return _element_stat(team[idx].data.element, team, "aspd_pct")



static func get_crit_rate_add(idx: int, team: Array) -> float:

if idx < 0 or idx >= team.size() or team[idx] == null or team[idx].data == null:

return 0.0

return _element_stat(team[idx].data.element, team, "crit_rate_add")



# Relatório legível para debug/demo.

static func synergy_report(team: Array) -> String:

var active := active_synergies(team)

if active.is_empty():

return "Nenhuma sinergia ativa."

var parts := []

for el in active:

parts.append("%s(%d)" % [el, active[el]])

return "Sinergias ativas: " + ", ".join(parts)





Error at (79, 13): Cannot infer the type of "ni" variable because the value doesn't have a set type.

This is a very common strict typing gotcha in GDScript 2.0 (Godot 4).

The error occurs because you are using the static inference operator (:=) to assign a value to ni, but GDScript cannot guarantee the type of the result at compile time. Here is the breakdown of why it fails:

idx is strictly typed as an int.

[-1, 1] is an untyped Array, which means the offset variable in your for loop defaults to the Variant type.

int + Variant results in a Variant.

var ni := demands a strict, recognizable type, so it throws an error when it receives a Variant.

The Fix
To resolve this, you just need to explicitly type ni as an int rather than relying on inference (:=).

Here is the corrected _adjacency_atk function:

GDScript
static func _adjacency_atk(idx: int, team: Array) -> float:
	if idx < 0 or idx >= team.size():
		return 0.0
	var m = team[idx]
	if m == null or m.data == null:
		return 0.0
	var el: String = m.data.element
	var pct := 0.0
	
	for offset in [-1, 1]:
		# FIXED: Explicitly typed as 'int' instead of using ':='
		var ni: int = idx + offset 
		
		if ni >= 0 and ni < team.size():
			var nb = team[ni]
			if nb != null and nb.data != null and nb.data.element == el:
				pct += ADJACENCY_ATK_PCT
	return pct
Alternative solutions
If you strictly want to keep using the := inference operator, you would need to ensure the right side of the equation resolves to an integer. You can do this by:

Casting the offset to an int: var ni := idx + int(offset)

Using a strictly typed array for the loop: for offset in ([-1, 1] as Array[int]):

Explicitly typing var ni: int = ... is usually the cleanest and most readable approach for this scenario!

retorne completo

Aqui está o script SynergySystem completo com a correção aplicada. Você pode copiar e substituir todo o conteúdo do seu arquivo:

GDScript
class_name SynergySystem
extends RefCounted

# Sistema de sinergias de elemento e adjacência (v2 §6).
# Funções puras — GameState._recalc_synergies() injeta os bônus em cada MonsterInstance.
# Todos os valores são placeholders de tuning (v2 §10).

# Limiares de acumulação: 2, 4 ou 6 monstros do mesmo elemento.
const THRESHOLDS := [2, 4, 6]

# Bônus por limiar de cada elemento. Entram no bucket % aditivo do pipeline (v2 §2).
# FOGO: ofensivo (ATK) | ÁGUA: sustain (HP + revive @6 no combate) | TERRA: armadura (DEF)
# VENTO: velocidade (ASPD) | RAIO: crítico (Crit Rate, flat add ao cap)
const ELEMENT_SYNERGY := {
	"FOGO": {
		2: {"atk_pct": 0.08},
		4: {"atk_pct": 0.20},
		6: {"atk_pct": 0.40},
	},
	"AGUA": {
		2: {"hp_pct": 0.08},
		4: {"hp_pct": 0.20},
		6: {"hp_pct": 0.40},
	},
	"TERRA": {
		2: {"def_pct": 0.10},
		4: {"def_pct": 0.25},
		6: {"def_pct": 0.50},
	},
	"VENTO": {
		2: {"aspd_pct": 0.08},
		4: {"aspd_pct": 0.18},
		6: {"aspd_pct": 0.35},
	},
	"RAIO": {
		2: {"crit_rate_add": 0.04},
		4: {"crit_rate_add": 0.10},
		6: {"crit_rate_add": 0.20},
	},
}

# Adjacência: dois vizinhos do mesmo elemento se dão +5% ATK mutuamente. (v2 §6)
const ADJACENCY_ATK_PCT := 0.05

# Retorna dicionário elemento -> limiar ativo (2, 4 ou 6) para o time dado.
static func active_synergies(team: Array) -> Dictionary:
	var count := {}
	for m in team:
		if m != null and m.data != null:
			var el: String = m.data.element
			count[el] = count.get(el, 0) + 1
	var active := {}
	for el in count:
		var highest := 0
		for t in THRESHOLDS:
			if int(count[el]) >= t:
				highest = t
		if highest > 0:
			active[el] = highest
	return active

static func _element_stat(element: String, team: Array, key: String) -> float:
	var active := active_synergies(team)
	if not active.has(element):
		return 0.0
	var el_dict: Dictionary = ELEMENT_SYNERGY.get(element, {})
	var tier_dict: Dictionary = el_dict.get(active[element], {})
	return float(tier_dict.get(key, 0.0))

static func _adjacency_atk(idx: int, team: Array) -> float:
	if idx < 0 or idx >= team.size():
		return 0.0
	var m = team[idx]
	if m == null or m.data == null:
		return 0.0
	var el: String = m.data.element
	var pct := 0.0
	for offset in [-1, 1]:
		# CORREÇÃO: Variável tipada explicitamente como int
		var ni: int = idx + offset
		if ni >= 0 and ni < team.size():
			var nb = team[ni]
			if nb != null and nb.data != null and nb.data.element == el:
				pct += ADJACENCY_ATK_PCT
	return pct

static func get_atk_pct(idx: int, team: Array) -> float:
	if idx < 0 or idx >= team.size() or team[idx] == null or team[idx].data == null:
		return 0.0
	return _element_stat(team[idx].data.element, team, "atk_pct") + _adjacency_atk(idx, team)

static func get_hp_pct(idx: int, team: Array) -> float:
	if idx < 0 or idx >= team.size() or team[idx] == null or team[idx].data == null:
		return 0.0
	return _element_stat(team[idx].data.element, team, "hp_pct")

static func get_def_pct(idx: int, team: Array) -> float:
	if idx < 0 or idx >= team.size() or team[idx] == null or team[idx].data == null:
		return 0.0
	return _element_stat(team[idx].data.element, team, "def_pct")

static func get_aspd_pct(idx: int, team: Array) -> float:
	if idx < 0 or idx >= team.size() or team[idx] == null or team[idx].data == null:
		return 0.0
	return _element_stat(team[idx].data.element, team, "aspd_pct")

static func get_crit_rate_add(idx: int, team: Array) -> float:
	if idx < 0 or idx >= team.size() or team[idx] == null or team[idx].data == null:
		return 0.0
	return _element_stat(team[idx].data.element, team, "crit_rate_add")

# Relatório legível para debug/demo.
static func synergy_report(team: Array) -> String:
	var active := active_synergies(team)
	if active.is_empty():
		return "Nenhuma sinergia ativa."
	var parts := []
	for el in active:
		parts.append("%s(%d)" % [el, active[el]])
	return "Sinergias ativas: " + ", ".join(parts)
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



# Ícone de elemento + emoji do monstro

var icon := ColorRect.new()

icon.color = e_color

icon.custom_minimum_size = Vector2(40, 40)

row.add_child(icon)

var face := EmojiDB.make_label(EmojiDB.for_monster(md.id, md.element), 28)

face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

icon.add_child(face)



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





Error at (137, 16): Cannot infer the type of "border" variable because the value doesn't have a set type.

Esse é mais um caso clássico das limitações da inferência de tipos do GDScript 2.0, muito parecido com o problema anterior!

Por que isso acontece?
O erro ocorre na linha var border := ... porque o GDScript não consegue ter 100% de certeza do tipo final que sairá dessa expressão no momento da compilação. O motivo é uma reação em cadeia:

BOX_COLORS é um dicionário. A função .get() sempre retorna um tipo genérico Variant.

Como resultado, a variável base acaba sendo inferida como Variant.

Chamar o método .lightened(0.3) em um Variant retorna outro Variant.

O operador ternário (if ... else) tenta combinar um Variant de um lado com um Color do outro (ThemeHelper.TEXT_DIM), e entrega um Variant no final.

O operador := exige um tipo estrito reconhecível, então ele falha.

A Solução
A correção é abandonar o := nessa função e tipar explicitamente as variáveis como Color (e int para a espessura da borda, pelo mesmo motivo).

Aqui está o script completo corrigido. Você pode copiar e substituir tudo:

GDScript
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
	# CORREÇÃO: Variáveis tipadas explicitamente como Color e int
	var base: Color = BOX_COLORS.get(box_type, ThemeHelper.BG_CARD)
	var border: Color = base.lightened(0.3) if selected else ThemeHelper.TEXT_DIM.darkened(0.4)
	var bw: int = 3 if selected else 1
	
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

	# Ícone de elemento + emoji do monstro
	var icon := ColorRect.new()
	icon.color = e_color
	icon.custom_minimum_size = Vector2(40, 40)
	row.add_child(icon)
	var face := EmojiDB.make_label(EmojiDB.for_monster(md.id, md.element), 28)
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.add_child(face)

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

# CORREÇÃO: Variáveis tipadas explicitamente como Color e int

var base: Color = BOX_COLORS.get(box_type, ThemeHelper.BG_CARD)

var border: Color = base.lightened(0.3) if selected else ThemeHelper.TEXT_DIM.darkened(0.4)

var bw: int = 3 if selected else 1


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



# Ícone de elemento + emoji do monstro

var icon := ColorRect.new()

icon.color = e_color

icon.custom_minimum_size = Vector2(40, 40)

row.add_child(icon)

var face := EmojiDB.make_label(EmojiDB.for_monster(md.id, md.element), 28)

face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

icon.add_child(face)



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





Error at (158, 20): Cannot infer the type of "total_cost" variable because the value doesn't have a set type.

Mais uma vez, o mesmo comportamento de inferência do GDScript!

Como BOX_COSTS é um dicionário, o método .get() retorna um Variant. Ao multiplicar esse Variant por count (que é um int), o resultado continua sendo um Variant, o que faz o operador := falhar na linha do total_cost.

Eu já aproveitei e varri o seu script para corrigir outros dois lugares exatos onde esse mesmo erro iria acontecer logo em seguida (na linha do frags := GachaSystem...get() e na linha do cost := BOX_COSTS.get()).

Aqui está o código completo e 100% corrigido. Basta copiar e colar:

GDScript
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
	var base: Color = BOX_COLORS.get(box_type, ThemeHelper.BG_CARD)
	var border: Color = base.lightened(0.3) if selected else ThemeHelper.TEXT_DIM.darkened(0.4)
	var bw: int = 3 if selected else 1
	
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
	# CORREÇÃO: Forçar a tipagem como 'int' para evitar Variants vindos do dicionário
	var cost_per: int = BOX_COSTS.get(_selected_box, 0)
	var total_cost: int = cost_per * count
	
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

	# Ícone de elemento + emoji do monstro
	var icon := ColorRect.new()
	icon.color = e_color
	icon.custom_minimum_size = Vector2(40, 40)
	row.add_child(icon)
	var face := EmojiDB.make_label(EmojiDB.for_monster(md.id, md.element), 28)
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.add_child(face)

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
		# CORREÇÃO: Prevenir erro idêntico em Dictionaries retornando Variant
		var frags: int = GachaSystem.DUPE_FRAGMENTS.get(md.rarity, 5)
		var frag_lbl := ThemeHelper.label("+%d Frag" % frags, ThemeHelper.GEM_COLOR, 12)
		row.add_child(frag_lbl)

	return panel

# ---------------------------------------------------------------------------
# Refresh
# ---------------------------------------------------------------------------

func _refresh_selection() -> void:
	# CORREÇÃO: Prevenir erro idêntico em Dictionaries retornando Variant
	var cost: int = BOX_COSTS.get(_selected_box, 0)
	
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



O Gemini é uma IA e pode cometer erros.
