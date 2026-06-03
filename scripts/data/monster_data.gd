class_name MonsterData
extends RefCounted

# Ficha imutavel de um monstro (vem do JSON). O estado de jogo fica em MonsterInstance.

var id: String
var display_name: String
var element: String      # ver GameEnums.ELEMENTS
var rarity: String       # ver GameEnums.RARITIES
var role: String         # ver GameEnums.ROLES
var base_hp: float
var base_atk: float
var base_def: float
var growth_hp: float
var growth_atk: float
var growth_def: float
var aspd: float
var range_px: float      # Alcance (RANGE) - Melee ~50, Ranged ~200 (v2 9)
var crit_rate: float     # 0.05 = 5%
var crit_dmg: float      # 1.5 = 150%
var eva: float
var ultimate_name: String
var ultimate_desc: String

static func from_dict(d: Dictionary) -> MonsterData:
	var m := MonsterData.new()
	m.id = d.get("id", "")
	m.display_name = d.get("display_name", d.get("id", ""))
	m.element = d.get("element", "FOGO")
	m.rarity = d.get("rarity", "COMUM")
	m.role = d.get("role", "MELEE_DPS")
	m.base_hp = float(d.get("base_hp", 100.0))
	m.base_atk = float(d.get("base_atk", 10.0))
	m.base_def = float(d.get("base_def", 0.0))
	m.growth_hp = float(d.get("growth_hp", 10.0))
	m.growth_atk = float(d.get("growth_atk", 2.0))
	m.growth_def = float(d.get("growth_def", 0.5))
	m.aspd = float(d.get("aspd", 1.0))
	m.range_px = float(d.get("range_px", 50.0))
	m.crit_rate = float(d.get("crit_rate", 0.05))
	m.crit_dmg = float(d.get("crit_dmg", 1.5))
	m.eva = float(d.get("eva", 0.0))
	m.ultimate_name = d.get("ultimate_name", "")
	m.ultimate_desc = d.get("ultimate_desc", "")
	return m
