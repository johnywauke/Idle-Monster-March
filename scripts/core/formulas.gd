class_name Formulas
extends RefCounted

# Toda a matematica do GDD v2 num so lugar (funcoes puras, sem estado).
# Referencias de secao apontam para o documento "GDD v2 - Refinamento".

# --- Constantes de balanceamento (ajustaveis na fase de tuning, v2 10) ---
const ASPD_CAP := 5.0
const CRIT_CAP := 1.0          # 100%
const EVA_CAP := 0.75          # 75%
const TIER2_LEVEL := 30
const TIER3_LEVEL := 60
const TIER_MULT := {1: 1.0, 2: 1.5, 3: 2.0}      # v2 2
const STAR_BONUS_PER_STAR := 0.15                # v2 2 (Mult_Estrela)
const PRESTIGE_UNLOCK_PHASE := 50                # v2 4
const SOUL_COIN_BASE := 10.0                     # v2 4
const BOSS_HP_MULT := 6.0                        # +500% -> 6x (v2 7)
const ENRAGE_SECONDS := 30.0                     # v2 7
const DEF_K_BASE := 1000.0                       # v2 3
const CLICK_DMG_FRACTION := 0.10                 # v2 5

# --- Curvas de progressao ---
static func xp_for_level(level: int) -> float:
	return 100.0 * pow(float(level), 1.5)

static func enemy_hp(phase: int) -> float:
	return 50.0 * pow(1.15, float(phase))

static func enemy_damage(phase: int) -> float:
	return 5.0 * pow(1.10, float(phase))

static func boss_hp(phase: int) -> float:
	return enemy_hp(phase) * BOSS_HP_MULT

# Mitigacao com constante que escala com a fase (v2 3): nem inutil, nem imunidade.
static func def_mitigation(def_value: float, phase: int) -> float:
	var k := DEF_K_BASE * pow(1.10, float(phase))
	return def_value / (def_value + k)

# Curva de Soul Coins exponencial (v2 4). 0 antes de desbloquear o prestigio.
static func soul_coins(max_phase: int, base: float = SOUL_COIN_BASE) -> int:
	if max_phase < PRESTIGE_UNLOCK_PHASE:
		return 0
	return int(floor(base * pow(1.08, float(max_phase - PRESTIGE_UNLOCK_PHASE))))

# --- Tier e Estrela ---
static func tier_from_level(level: int) -> int:
	if level >= TIER3_LEVEL:
		return 3
	if level >= TIER2_LEVEL:
		return 2
	return 1

static func tier_multiplier(level: int) -> float:
	return float(TIER_MULT[tier_from_level(level)])

static func star_multiplier(stars: int) -> float:
	return 1.0 + STAR_BONUS_PER_STAR * float(max(stars - 1, 0))

# --- Pipeline unico de calculo de atributo (v2 2) ---
# base+crescimento -> x tier -> x estrela -> x(1 + soma%) -> + fixos -> (caps fora daqui)
static func compute_stat(base: float, growth: float, level: int, stars: int, bonus_pct_sum: float, flat_add: float = 0.0) -> float:
	var v := base + growth * float(level)
	v *= tier_multiplier(level)
	v *= star_multiplier(stars)
	v *= (1.0 + bonus_pct_sum)
	v += flat_add
	return v

# DPS esperado de um monstro (com critico medio), respeitando os caps. (v2 5)
static func expected_dps(atk_final: float, aspd: float, crit_rate: float, crit_dmg: float) -> float:
	var a := minf(aspd, ASPD_CAP)
	var cr := minf(crit_rate, CRIT_CAP)
	return atk_final * a * (1.0 + cr * (crit_dmg - 1.0))

static func click_damage(team_base_dps: float) -> float:
	return CLICK_DMG_FRACTION * team_base_dps
