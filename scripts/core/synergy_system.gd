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
		# FIXED: Explicitly typed as 'int' instead of using ':='
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
