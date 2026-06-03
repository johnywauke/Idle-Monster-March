extends Node
# AUTOLOAD: GameState
# Estado central da partida: moedas, progresso, equipe, inventário e upgrades de prestígio.
# É a única fonte de verdade — todos os outros sistemas leem/escrevem aqui.

# --- Moedas ---
var gold: float = 0.0
var gems: int = 0
var soul_coins: int = 0

# --- Progresso ---
var current_phase: int = 1
var max_phase: int = 1
var pity_counter: int = 0        # puxadas em Caixas de Gemas sem Lendário (v2 §8)
var tutorial_done: bool = false  # tutorial 10x scriptado já realizado

# --- Equipe: slot 0 = frente, slot 6 = retaguarda. (v2 §6) ---
const TEAM_SIZE := 7
var team: Array[MonsterInstance] = []

# --- Inventário: monstros possuídos fora do time ---
var inventory: Array[MonsterInstance] = []
var fragments: Dictionary = {}    # monster_id -> int (fragmentos de duplicatas)

# --- Máquina de estado do combate (boss, farm mode, fever) ---
var combat: CombatState = CombatState.new()

# --- Loja de Prestígio (v2 §4) — frações: 0.10 = +10% ---
var prestige_global_damage: float = 0.0
var prestige_gold_drop: float = 0.0
var prestige_rare_egg_chance: float = 0.0

# RNG compartilhado (para gacha, etc.)
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()

func prestige_global_damage_pct() -> float:
	return prestige_global_damage

# --- DPS e dano de clique ---

# DPS base da equipe: permanente, SEM estados temporários (Fever, ultimate). (v2 §5)
func team_base_dps() -> float:
	var total := 0.0
	for m in team:
		if m != null:
			total += m.expected_dps()
	return total

func click_damage() -> float:
	return Formulas.click_damage(team_base_dps())

# A equipe consegue limpar a fase atual passivamente? (v2 §1/7)
func can_clear_current_phase() -> bool:
	var dps := team_base_dps()
	if current_phase % 10 == 0:
		return BattleSimulator.can_beat_boss(dps, current_phase)
	return dps > 0.0

# --- Gerenciamento do time ---

# Adiciona monstro ao final do time. Recalcula sinergias. Retorna true se adicionado.
func add_to_team(inst: MonsterInstance) -> bool:
	if team.size() >= TEAM_SIZE:
		return false
	team.append(inst)
	_recalc_synergies()
	return true

# Remove do time pelo índice de slot e move para inventário.
func remove_from_team(slot_idx: int) -> bool:
	if slot_idx < 0 or slot_idx >= team.size():
		return false
	inventory.append(team[slot_idx])
	team.remove_at(slot_idx)
	_recalc_synergies()
	return true

# Troca dois slots do time. Permite reordenação tática. (v2 §1/6)
func swap_team_slots(a: int, b: int) -> void:
	if a == b or a < 0 or b < 0 or a >= team.size() or b >= team.size():
		return
	var tmp := team[a]
	team[a] = team[b]
	team[b] = tmp
	_recalc_synergies()

# Move um monstro do inventário para o time (pelo índice no inventário).
func move_to_team(inv_idx: int) -> bool:
	if inv_idx < 0 or inv_idx >= inventory.size() or team.size() >= TEAM_SIZE:
		return false
	team.append(inventory[inv_idx])
	inventory.remove_at(inv_idx)
	_recalc_synergies()
	return true

# Injeta bônus de sinergia em cada slot do time. Chamado ao modificar o time. (v2 §6)
func _recalc_synergies() -> void:
	for i in team.size():
		var m := team[i]
		if m == null:
			continue
		m.synergy_atk_pct      = SynergySystem.get_atk_pct(i, team)
		m.synergy_hp_pct       = SynergySystem.get_hp_pct(i, team)
		m.synergy_def_pct      = SynergySystem.get_def_pct(i, team)
		m.synergy_aspd_pct     = SynergySystem.get_aspd_pct(i, team)
		m.synergy_crit_rate_add = SynergySystem.get_crit_rate_add(i, team)

# --- Gacha e inventário ---

# Concede um monstro obtido no gacha.
# Se já possuído (time ou inventário), converte em fragmentos.
# Retorna true se adicionado ao inventário, false se virou fragmento.
func grant_monster(md: MonsterData) -> bool:
	if _owns(md.id):
		GachaSystem.add_dupe_fragments(md, fragments)
		return false
	inventory.append(MonsterInstance.new(md, 1, 1))
	return true

func _owns(id: String) -> bool:
	for m in team:
		if m != null and m.data != null and m.data.id == id:
			return true
	for m in inventory:
		if m != null and m.data != null and m.data.id == id:
			return true
	return false

# --- Upgrade de nível com OURO (dreno ativo do loop idle; v2 §4) ---

func level_up_cost(inst: MonsterInstance) -> float:
	if inst == null or inst.data == null:
		return INF
	return Formulas.level_up_cost(inst.level, Formulas.rarity_level_mult(inst.data.rarity))

func can_level_up(inst: MonsterInstance) -> bool:
	return inst != null and gold >= level_up_cost(inst)

# Sobe 1 nível gastando ouro. Retorna true se conseguiu.
func try_level_up(inst: MonsterInstance) -> bool:
	if not can_level_up(inst):
		return false
	gold -= level_up_cost(inst)
	inst.level += 1
	_recalc_synergies()
	return true

# Sobe o máximo de níveis que o ouro permitir. Retorna quantos níveis subiu.
func level_up_max(inst: MonsterInstance, max_steps: int = 5000) -> int:
	if inst == null or inst.data == null:
		return 0
	var n := 0
	while n < max_steps and gold >= level_up_cost(inst):
		gold -= level_up_cost(inst)
		inst.level += 1
		n += 1
	if n > 0:
		_recalc_synergies()
	return n

# --- Prestígio (v2 §4) ---

# Executa o prestígio. Só chame quando max_phase >= PRESTIGE_UNLOCK_PHASE.
func do_prestige() -> void:
	if max_phase < Formulas.PRESTIGE_UNLOCK_PHASE:
		return
	soul_coins += Formulas.soul_coins(max_phase)
	current_phase = 1
	gold = 0.0
	# Reset nível dos monstros (v2 §4).
	for m in team:
		if m != null:
			m.level = 1
			m.xp = 0.0
	for m in inventory:
		if m != null:
			m.level = 1
			m.xp = 0.0
	combat = CombatState.new()
	_recalc_synergies()

# --- Serialização ---

func to_save_dict() -> Dictionary:
	var team_arr: Array = []
	for m in team:
		if m != null and m.data != null:
			team_arr.append(_inst_to_dict(m))
	var inv_arr: Array = []
	for m in inventory:
		if m != null and m.data != null:
			inv_arr.append(_inst_to_dict(m))
	return {
		"gold": gold, "gems": gems, "soul_coins": soul_coins,
		"current_phase": current_phase, "max_phase": max_phase,
		"pity_counter": pity_counter, "tutorial_done": tutorial_done,
		"prestige_global_damage": prestige_global_damage,
		"prestige_gold_drop": prestige_gold_drop,
		"prestige_rare_egg_chance": prestige_rare_egg_chance,
		"team": team_arr,
		"inventory": inv_arr,
		"fragments": fragments,
		"combat": combat.to_dict(),
	}

func _inst_to_dict(m: MonsterInstance) -> Dictionary:
	return {
		"id": m.data.id,
		"level": m.level,
		"stars": m.stars,
		"xp": m.xp,
		"ult_energy": m.ult_energy,
		"talent": m.talent.id if m.talent != null else "",
	}

func from_save_dict(d: Dictionary) -> void:
	gold = float(d.get("gold", 0.0))
	gems = int(d.get("gems", 0))
	soul_coins = int(d.get("soul_coins", 0))
	current_phase = int(d.get("current_phase", 1))
	max_phase = int(d.get("max_phase", 1))
	pity_counter = int(d.get("pity_counter", 0))
	tutorial_done = bool(d.get("tutorial_done", false))
	prestige_global_damage = float(d.get("prestige_global_damage", 0.0))
	prestige_gold_drop = float(d.get("prestige_gold_drop", 0.0))
	prestige_rare_egg_chance = float(d.get("prestige_rare_egg_chance", 0.0))
	fragments = d.get("fragments", {})

	team.clear()
	for entry in d.get("team", []):
		var inst := _dict_to_inst(entry)
		if inst != null:
			team.append(inst)

	inventory.clear()
	for entry in d.get("inventory", []):
		var inst := _dict_to_inst(entry)
		if inst != null:
			inventory.append(inst)

	_recalc_synergies()

	var combat_data: Variant = d.get("combat", null)
	if combat_data is Dictionary:
		combat.from_dict(combat_data)

func _dict_to_inst(entry: Dictionary) -> MonsterInstance:
	var md: MonsterData = ContentDB.get_monster(entry.get("id", ""))
	if md == null:
		return null
	var inst := MonsterInstance.new(md, int(entry.get("level", 1)), int(entry.get("stars", 1)))
	inst.xp         = float(entry.get("xp", 0.0))
	inst.ult_energy = clampf(float(entry.get("ult_energy", 0.0)), 0.0, 1.0)
	var tid: String = entry.get("talent", "")
	if tid != "":
		inst.talent = ContentDB.talents.get(tid, null)
	return inst
