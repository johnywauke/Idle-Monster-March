class_name EmojiDB
extends RefCounted

# Banco de "sprites" placeholder em emoji + fonte de emoji do sistema.
#
# Por que emoji: o documento pede arte de sprite, mas o projeto ainda nao tem
# spritesheets. Emoji coloridos sao um placeholder universal, leve e expressivo —
# cada monstro/inimigo ganha uma "cara" imediata, com movimento e ataque (ver
# CreatureSprite). Trocar por PNG/spritesheet depois e so mudar quem desenha.
#
# Renderizacao: usamos uma SystemFont apontando para as fontes de emoji COLORIDO
# de cada SO (Segoe UI Emoji no Windows, Apple Color Emoji no macOS, Noto no Linux).
# Se nenhuma existir, o CreatureSprite ainda mostra um corpo colorido por baixo —
# entao o jogo nunca fica "vazio", mesmo sem suporte a emoji.

# --- Emoji por id de monstro (fallback por elemento abaixo) ---
const MONSTER := {
	# FOGO
	"ember_pup": "🐶", "cinder_imp": "👺", "emberfox": "🦊",
	"ignis_knight": "🛡️", "flare_dragon": "🐲",
	# AGUA
	"slurp": "🫧", "driplet": "💦", "coral_striker": "🐠",
	"tidal_turtle": "🐢", "leviathan": "🐋",
	# TERRA
	"pebble": "🪨", "cobble": "🧱", "rockhorn": "🐏",
	"boulder_beast": "🗿", "gaia_titan": "🦏",
	# VENTO
	"puff": "☁️", "gust_bat": "🦇", "cyclone_hawk": "🦅",
	"storm_wyvern": "🐉", "tempest_lord": "🌪️",
	# RAIO
	"sparkling": "✨", "joltling": "⚡", "zappcat": "🐱",
	"volt_colossus": "🤖", "thunder_sovereign": "🦜",
}

# Fallback de monstro por elemento (caso um id novo nao esteja no mapa acima).
const ELEMENT_FALLBACK := {
	"FOGO": "🔥", "AGUA": "🐟", "TERRA": "🪨", "VENTO": "🌬️", "RAIO": "⚡",
}

# Emoji-simbolo do elemento (para HUD/sinergias).
const ELEMENT_ICON := {
	"FOGO": "🔥", "AGUA": "💧", "TERRA": "⛰️", "VENTO": "🌪️", "RAIO": "⚡",
}

# Projetil disparado por monstros ranged, por elemento.
const PROJECTILE := {
	"FOGO": "🔥", "AGUA": "💧", "TERRA": "🪨", "VENTO": "🌀", "RAIO": "⚡",
}

# Emoji por tipo de inimigo.
const ENEMY := {
	"NORMAL": "👾", "SWARM": "🦇", "BRUISER": "🗿", "DIVER": "🥷", "HEALER": "🧙",
}

const RARITY_ICON := {
	"COMUM": "⚪", "INCOMUM": "🟢", "RARO": "🔵", "EPICO": "🟣", "LENDARIO": "🟡",
}

static func for_monster(id: String, element: String = "FOGO") -> String:
	if MONSTER.has(id):
		return MONSTER[id]
	return ELEMENT_FALLBACK.get(element, "❓")

static func for_enemy(type: String) -> String:
	return ENEMY.get(type, "👾")

static func projectile(element: String) -> String:
	return PROJECTILE.get(element, "✶")

static func element_icon(element: String) -> String:
	return ELEMENT_ICON.get(element, "✦")

static func rarity_icon(rarity: String) -> String:
	return RARITY_ICON.get(rarity, "⚪")

# --- Fonte de emoji (carregada uma vez e reutilizada) ---
static var _emoji_font: Font = null

static func emoji_font() -> Font:
	if _emoji_font != null:
		return _emoji_font
	var f := SystemFont.new()
	# Ordem de preferencia: fontes de emoji COLORIDO de cada SO.
	f.font_names = PackedStringArray([
		"Segoe UI Emoji",      # Windows
		"Apple Color Emoji",   # macOS / iOS
		"Noto Color Emoji",    # Linux / Android
		"Segoe UI Symbol",     # fallback monocromatico (Windows)
		"Noto Emoji",          # fallback monocromatico
	])
	f.allow_system_fallback = true   # se nada acima existir, usa qualquer fonte do SO
	_emoji_font = f
	return _emoji_font

# Cria um Label de emoji pronto para uso (centralizado, com a fonte de emoji).
static func make_label(emoji: String, size: int) -> Label:
	var l := Label.new()
	l.text = emoji
	l.add_theme_font_override("font", emoji_font())
	l.add_theme_font_size_override("font_size", size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
