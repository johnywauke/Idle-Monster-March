class_name GachaSystem
extends RefCounted

# Sistema de gacha: taxas de drop, pity, fragmentos de duplicatas. (v2 §8)
# Funções puras — usa ContentDB e GameState como autoloads.

# Taxas de drop por tipo de caixa (%, devem somar 100).
const DROP_RATES := {
	"BASICO":   { "COMUM": 70.0, "INCOMUM": 22.0, "RARO": 7.0, "EPICO": 1.0, "LENDARIO": 0.0 },
	"PREMIUM":  { "COMUM": 40.0, "INCOMUM": 30.0, "RARO": 20.0, "EPICO": 8.0, "LENDARIO": 2.0 },
	"LENDARIA": { "COMUM":  0.0, "INCOMUM":  0.0, "RARO": 40.0, "EPICO": 40.0, "LENDARIO": 20.0 },
}

# Caixas de Gemas ativam o pity compartilhado 0/100. (v2 §8)
const GEM_BOX_TYPES := ["PREMIUM", "LENDARIA"]
const PITY_LIMIT := 100

# Fragmentos gerados por duplicata, por raridade. (v2 §8)
const DUPE_FRAGMENTS := {
	"COMUM": 5, "INCOMUM": 10, "RARO": 25, "EPICO": 50, "LENDARIO": 100
}

# Custo de fragmentos para subir de estrela (índice = estrela_atual - 1). Placeholder §10.
const STAR_UPGRADE_COST := [20, 40, 80, 150, 250, 400, 600]

# --- Lógica de pull ---

static func _roll_rarity(box_type: String, rng: RandomNumberGenerator) -> String:
	var rates: Dictionary = DROP_RATES.get(box_type, DROP_RATES["BASICO"])
	var roll := rng.randf() * 100.0
	var cum := 0.0
	for rarity in ["COMUM", "INCOMUM", "RARO", "EPICO", "LENDARIO"]:
		cum += float(rates.get(rarity, 0.0))
		if roll <= cum:
			return rarity
	return "COMUM"

static func _pick_monster(rarity: String, rng: RandomNumberGenerator) -> MonsterData:
	var pool: Array = ContentDB.monsters_by_rarity(rarity)
	if pool.is_empty():
		push_warning("[GachaSystem] Pool vazia para raridade: " + rarity)
		return null
	return pool[rng.randi() % pool.size()]

# Realiza N puxadas de box_type. Gerencia GameState.pity_counter.
# Retorna Array[MonsterData].
static func pull_batch(box_type: String, count: int, rng: RandomNumberGenerator) -> Array:
	var results: Array = []
	var is_gem_box: bool = GEM_BOX_TYPES.has(box_type)
	for _i in count:
		var forced := ""
		if is_gem_box:
			GameState.pity_counter += 1
			if GameState.pity_counter >= PITY_LIMIT:
				forced = "LENDARIO"
		var rarity := forced if forced != "" else _roll_rarity(box_type, rng)
		var md := _pick_monster(rarity, rng)
		if md != null:
			results.append(md)
			if is_gem_box and md.rarity == "LENDARIO":
				GameState.pity_counter = 0
	return results

# Tutorial 10x scriptado: garante ≥ 1 EPICO. Fora das taxas normais. (v2 §8)
static func tutorial_pull(rng: RandomNumberGenerator) -> Array:
	var results: Array = []
	var has_epic := false
	for i in 10:
		var forced := ""
		if i == 9 and not has_epic:
			forced = "EPICO"
		var rarity := forced if forced != "" else _roll_rarity("BASICO", rng)
		var md := _pick_monster(rarity, rng)
		if md != null:
			results.append(md)
			if md.rarity in ["EPICO", "LENDARIO"]:
				has_epic = true
	return results

# --- Fragmentos e estrelas ---

static func can_upgrade_star(monster_id: String, current_stars: int, fragments: Dictionary) -> bool:
	var cost_idx := current_stars - 1
	if cost_idx < 0 or cost_idx >= STAR_UPGRADE_COST.size():
		return false
	return int(fragments.get(monster_id, 0)) >= STAR_UPGRADE_COST[cost_idx]

# Consome fragmentos e sobe uma estrela em 'instance'. Retorna true se bem-sucedido.
static func upgrade_star(instance: MonsterInstance, fragments: Dictionary) -> bool:
	var id := instance.data.id if instance.data != null else ""
	if id.is_empty() or not can_upgrade_star(id, instance.stars, fragments):
		return false
	fragments[id] = int(fragments.get(id, 0)) - STAR_UPGRADE_COST[instance.stars - 1]
	instance.stars += 1
	return true

# Converte duplicata em fragmentos. Retorna contagem adicionada.
static func add_dupe_fragments(md: MonsterData, fragments: Dictionary) -> int:
	var gained: int = DUPE_FRAGMENTS.get(md.rarity, 5)
	fragments[md.id] = int(fragments.get(md.id, 0)) + gained
	return gained
