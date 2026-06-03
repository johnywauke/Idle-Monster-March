class_name MonsterInstance
extends RefCounted

# Estado de jogo de um monstro que o jogador possui: nível, estrelas, XP.
# Aponta para a ficha (MonsterData) e calcula stats finais via Formulas.

var data: MonsterData
var level: int = 1
var stars: int = 1
var xp: float = 0.0

# Injetado por GameState._recalc_synergies() ao alterar o time. (v2 §6)
var synergy_atk_pct: float = 0.0
var synergy_hp_pct: float = 0.0
var synergy_def_pct: float = 0.0
var synergy_aspd_pct: float = 0.0
var synergy_crit_rate_add: float = 0.0

# Talento roguelike equipado. Efeitos entram no bucket % do pipeline. (v2 §2)
var talent: TalentData = null

func _init(p_data: MonsterData = null, p_level: int = 1, p_stars: int = 1) -> void:
	data = p_data
	level = p_level
	stars = p_stars

# --- Bucket % do pipeline (v2 §2, passo 4) ---

func _atk_bonus_pct() -> float:
	var pct := GameState.prestige_global_damage_pct()
	pct += synergy_atk_pct
	if talent != null:
		pct += float(talent.effects.get("atk_pct", 0.0))
	return pct

func _hp_bonus_pct() -> float:
	var pct := synergy_hp_pct
	if talent != null:
		pct += float(talent.effects.get("hp_pct", 0.0))
	return pct

func _def_bonus_pct() -> float:
	return synergy_def_pct

# --- Stats finais ---

func final_hp() -> float:
	if data == null:
		return 0.0
	return Formulas.compute_stat(data.base_hp, data.growth_hp, level, stars, _hp_bonus_pct())

func final_def() -> float:
	if data == null:
		return 0.0
	return Formulas.compute_stat(data.base_def, data.growth_def, level, stars, _def_bonus_pct())

func final_atk() -> float:
	if data == null:
		return 0.0
	var base_stat := Formulas.compute_stat(data.base_atk, data.growth_atk, level, stars, _atk_bonus_pct())
	# Talento "Pele de Titã": conversão hp_to_atk usa HP FINAL pós-passo 4 (v2 §2 passo 5).
	var flat := 0.0
	if talent != null:
		var pct := float(talent.effects.get("hp_to_atk_pct", 0.0))
		if pct > 0.0:
			flat = final_hp() * pct
	return base_stat + flat

# ASPD efetivo: aplica bônus de sinergia VENTO e respeita o cap. (v2 §9)
func effective_aspd() -> float:
	if data == null:
		return 0.0
	return minf(data.aspd * (1.0 + synergy_aspd_pct), Formulas.ASPD_CAP)

# Crit Rate efetivo: base + bônus RAIO, capado em 100%. (v2 §9)
func effective_crit_rate() -> float:
	if data == null:
		return Formulas.CRIT_CAP
	return minf(data.crit_rate + synergy_crit_rate_add, Formulas.CRIT_CAP)

# DPS esperado com crítico médio. (v2 §5)
func expected_dps() -> float:
	if data == null:
		return 0.0
	return Formulas.expected_dps(final_atk(), effective_aspd(), effective_crit_rate(), data.crit_dmg)

func xp_to_next_level() -> float:
	return Formulas.xp_for_level(level)

func tier() -> int:
	return Formulas.tier_from_level(level)
