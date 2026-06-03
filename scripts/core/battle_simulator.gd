class_name BattleSimulator
extends RefCounted

# Modelo CALCULAVEL do combate e da economia (sem precisar desenhar nada).
# E o que sustenta o progresso offline (v2 1): rodamos a mesma matematica.
# Os coeficientes de ouro sao placeholders de tuning (v2 10).

const GOLD_PER_KILL_BASE := 10.0
const GOLD_PER_KILL_GROWTH := 1.12

static func gold_per_kill(phase: int) -> float:
	return GOLD_PER_KILL_BASE * pow(GOLD_PER_KILL_GROWTH, float(phase))

static func time_to_kill(team_dps: float, phase: int) -> float:
	if team_dps <= 0.0:
		return INF
	return Formulas.enemy_hp(phase) / team_dps

static func gold_per_second(team_dps: float, phase: int) -> float:
	var ttk := time_to_kill(team_dps, phase)
	if not is_finite(ttk) or ttk <= 0.0:
		return 0.0
	return gold_per_kill(phase) / ttk

static func time_to_kill_boss(team_dps: float, phase: int) -> float:
	if team_dps <= 0.0:
		return INF
	return Formulas.boss_hp(phase) / team_dps

# Vence o boss passivamente antes do Enrage? (v2 1/7)
static func can_beat_boss(team_dps: float, phase: int) -> bool:
	return time_to_kill_boss(team_dps, phase) <= Formulas.ENRAGE_SECONDS
