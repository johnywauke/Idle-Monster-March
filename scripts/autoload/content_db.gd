extends Node
# AUTOLOAD: ContentDB
# Carrega todo o conteudo data-driven (JSON) no startup e oferece consultas.
# Roda ANTES de GameState e SaveManager (ordem definida no project.godot).

var monsters: Dictionary = {}   # id -> MonsterData
var enemies: Dictionary = {}    # id -> EnemyData
var talents: Dictionary = {}    # id -> TalentData

func _ready() -> void:
	_load_monsters("res://data/monsters.json")
	_load_enemies("res://data/enemies.json")
	_load_talents("res://data/talents.json")
	print("[ContentDB] Carregado: %d monstros, %d inimigos, %d talentos." % [
		monsters.size(), enemies.size(), talents.size()])

func _read_json_array(path: String) -> Array:
	if not FileAccess.file_exists(path):
		push_error("[ContentDB] Arquivo nao encontrado: " + path)
		return []
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_ARRAY:
		push_error("[ContentDB] JSON invalido (esperava um array): " + path)
		return []
	return parsed

func _load_monsters(path: String) -> void:
	for d in _read_json_array(path):
		var m := MonsterData.from_dict(d)
		_validate_monster(m)
		monsters[m.id] = m

func _validate_monster(m: MonsterData) -> void:
	if not GameEnums.ELEMENTS.has(m.element):
		push_warning("[ContentDB] Elemento desconhecido '%s' em '%s'." % [m.element, m.id])
	if not GameEnums.RARITIES.has(m.rarity):
		push_warning("[ContentDB] Raridade desconhecida '%s' em '%s'." % [m.rarity, m.id])
	if not GameEnums.ROLES.has(m.role):
		push_warning("[ContentDB] Papel desconhecido '%s' em '%s'." % [m.role, m.id])

func _load_enemies(path: String) -> void:
	for d in _read_json_array(path):
		var e := EnemyData.from_dict(d)
		enemies[e.id] = e

func _load_talents(path: String) -> void:
	for d in _read_json_array(path):
		var t := TalentData.from_dict(d)
		talents[t.id] = t

func get_monster(id: String) -> MonsterData:
	return monsters.get(id, null)

func all_monsters() -> Array:
	return monsters.values()

func monsters_by_rarity(rarity: String) -> Array:
	var out := []
	for m in monsters.values():
		if m.rarity == rarity:
			out.append(m)
	return out
