class_name GameEnums
extends RefCounted

# Valores validos para os campos das fichas (usados na validacao do ContentDB).
# Mantidos como String para o JSON ser facil de editar a mao.

const ELEMENTS := ["FOGO", "AGUA", "TERRA", "VENTO", "RAIO"]
const RARITIES := ["COMUM", "INCOMUM", "RARO", "EPICO", "LENDARIO"]
const ROLES := [
	"MELEE_TANK", "MELEE_DPS", "MELEE_ASSASSINO", "MELEE_BRUISER",
	"RANGED_DPS", "RANGED_HEALER", "RANGED_SUPORTE", "RANGED_NUKE",
]
const ENEMY_TYPES := ["NORMAL", "SWARM", "BRUISER", "DIVER", "HEALER"]
