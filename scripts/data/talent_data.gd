class_name TalentData
extends RefCounted

# Talento Roguelike (v2 9). Os efeitos sao um dicionario livre de modificadores
# que o motor de combate vai interpretar (ex.: {"atk_pct": 0.5, "hp_pct": -0.3}).

var id: String
var display_name: String
var description: String
var effects: Dictionary

static func from_dict(d: Dictionary) -> TalentData:
	var t := TalentData.new()
	t.id = d.get("id", "")
	t.display_name = d.get("display_name", d.get("id", ""))
	t.description = d.get("description", "")
	t.effects = d.get("effects", {})
	return t
