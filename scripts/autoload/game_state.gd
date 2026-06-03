extends Node
# AUTOLOAD: GameState
# Estado central da partida: moedas, progresso, equipe e upgrades de prestigio.
# Conhece o pipeline de stats e sabe se serializar para o save.

# --- Moedas ---
var gold: float = 0.0
var gems: int = 0
var soul_coins: int = 0

# --- Progresso ---
var current_phase: int = 1
var max_phase: int = 1
var pity_counter: int = 0       # caixas de Gemas, 0..100 (v2 8)
var in_farm_mode: bool = false

# --- Equipe: ate 7 slots. slot 0 = frente (encara inimigos), slot 6 = retaguarda (v2 6) ---
const TEAM_SIZE := 7
var team: Array[MonsterInstance] = []

# --- Loja de Prestigio (v2 4); fracoes: 0.10 = +10% ---
var prestige_global_damage: float = 0.0
var prestige_gold_drop: float = 0.0
var prestige_rare_egg_chance: float = 0.0

func prestige_global_damage_pct() -> float:
	return prestige_global_damage

# DPS base da equipe: permanente, SEM estados temporarios (Fever, ultimate) - v2 5.
func team_base_dps() -> float:
	var total := 0.0
	for m in team:
		if m != null:
			total += m.expected_dps()
	return total

func click_damage() -> float:
	return Formulas.click_damage(team_base_dps())

# Limpa a fase atual passivamente? Em multiplos de 10, depende de vencer o boss (v2 7).
func can_clear_current_phase() -> bool:
	var dps := team_base_dps()
	if current_phase % 10 == 0:
		return BattleSimulator.can_beat_boss(dps, current_phase)
	return dps > 0.0

func add_to_team(inst: MonsterInstance) -> bool:
	if team.size() >= TEAM_SIZE:
		return false
	team.append(inst)
	return true

# --- Serializacao para o save ---
func to_save_dict() -> Dictionary:
	var team_arr: Array = []
	for m in team:
		if m != null and m.data != null:
			team_arr.append({"id": m.data.id, "level": m.level, "stars": m.stars, "xp": m.xp})
	return {
		"gold": gold, "gems": gems, "soul_coins": soul_coins,
		"current_phase": current_phase, "max_phase": max_phase,
		"pity_counter": pity_counter, "in_farm_mode": in_farm_mode,
		"prestige_global_damage": prestige_global_damage,
		"prestige_gold_drop": prestige_gold_drop,
		"prestige_rare_egg_chance": prestige_rare_egg_chance,
		"team": team_arr,
	}

func from_save_dict(d: Dictionary) -> void:
	gold = float(d.get("gold", 0.0))
	gems = int(d.get("gems", 0))
	soul_coins = int(d.get("soul_coins", 0))
	current_phase = int(d.get("current_phase", 1))
	max_phase = int(d.get("max_phase", 1))
	pity_counter = int(d.get("pity_counter", 0))
	in_farm_mode = bool(d.get("in_farm_mode", false))
	prestige_global_damage = float(d.get("prestige_global_damage", 0.0))
	prestige_gold_drop = float(d.get("prestige_gold_drop", 0.0))
	prestige_rare_egg_chance = float(d.get("prestige_rare_egg_chance", 0.0))
	team.clear()
	for entry in d.get("team", []):
		var md: MonsterData = ContentDB.get_monster(entry.get("id", ""))
		if md != null:
			var inst := MonsterInstance.new(md, int(entry.get("level", 1)), int(entry.get("stars", 1)))
			inst.xp = float(entry.get("xp", 0.0))
			team.append(inst)
