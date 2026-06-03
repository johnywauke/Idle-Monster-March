class_name MonsterInstance
extends RefCounted

# Estado de jogo de um monstro que o jogador possui: nivel, estrelas, XP.
# Aponta para a ficha (MonsterData) e calcula stats finais via Formulas.

var data: MonsterData
var level: int = 1
var stars: int = 1
var xp: float = 0.0

func _init(p_data: MonsterData = null, p_level: int = 1, p_stars: int = 1) -> void:
	data = p_data
	level = p_level
	stars = p_stars

# Soma dos bonus percentuais que entram no bucket % do pipeline (v2 2).
# Prestigio global vem do GameState; sinergias/equipamento/compendio = TODO.
func _atk_bonus_pct() -> float:
	var pct := 0.0
	pct += GameState.prestige_global_damage_pct()
	# TODO (v2 2/6): + sinergias de elemento/adjacencia, + equipamento%, + compendio%, + talentos%
	return pct

func final_atk() -> float:
	if data == null:
		return 0.0
	return Formulas.compute_stat(data.base_atk, data.growth_atk, level, stars, _atk_bonus_pct())

func final_hp() -> float:
	if data == null:
		return 0.0
	return Formulas.compute_stat(data.base_hp, data.growth_hp, level, stars, 0.0)  # TODO: sinergias de HP

func final_def() -> float:
	if data == null:
		return 0.0
	return Formulas.compute_stat(data.base_def, data.growth_def, level, stars, 0.0)

func expected_dps() -> float:
	if data == null:
		return 0.0
	return Formulas.expected_dps(final_atk(), data.aspd, data.crit_rate, data.crit_dmg)

func xp_to_next_level() -> float:
	return Formulas.xp_for_level(level)

func tier() -> int:
	return Formulas.tier_from_level(level)
