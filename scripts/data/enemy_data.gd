class_name EnemyData
extends RefCounted

var id: String
var display_name: String
var type: String        # ver GameEnums.ENEMY_TYPES
var hp_mult: float       # multiplica HP_Inimigo(fase)
var dmg_mult: float      # multiplica Dano_Inimigo(fase)
var def_value: float
var notes: String

static func from_dict(d: Dictionary) -> EnemyData:
	var e := EnemyData.new()
	e.id = d.get("id", "")
	e.display_name = d.get("display_name", d.get("id", ""))
	e.type = d.get("type", "NORMAL")
	e.hp_mult = float(d.get("hp_mult", 1.0))
	e.dmg_mult = float(d.get("dmg_mult", 1.0))
	e.def_value = float(d.get("def_value", 0.0))
	e.notes = d.get("notes", "")
	return e
