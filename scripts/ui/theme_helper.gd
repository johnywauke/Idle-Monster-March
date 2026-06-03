class_name ThemeHelper
extends RefCounted

# Paleta visual e fábrica de estilos para todo o UI do jogo.

# --- Cores de elemento ---
const ELEMENT_COLORS := {
	"FOGO":  Color(1.00, 0.35, 0.05),
	"AGUA":  Color(0.15, 0.55, 1.00),
	"TERRA": Color(0.55, 0.38, 0.10),
	"VENTO": Color(0.45, 0.85, 0.45),
	"RAIO":  Color(1.00, 0.88, 0.00),
}

# --- Cores de raridade ---
const RARITY_COLORS := {
	"COMUM":    Color(0.60, 0.60, 0.60),
	"INCOMUM":  Color(0.20, 0.85, 0.30),
	"RARO":     Color(0.25, 0.50, 1.00),
	"EPICO":    Color(0.75, 0.20, 1.00),
	"LENDARIO": Color(1.00, 0.72, 0.00),
}

# --- Cores de UI ---
const BG_ROOT    := Color(0.07, 0.07, 0.11)
const BG_PANEL   := Color(0.13, 0.13, 0.19)
const BG_CARD    := Color(0.17, 0.17, 0.24)
const BG_BUTTON  := Color(0.22, 0.34, 0.60)
const TEXT_MAIN  := Color(0.95, 0.95, 0.95)
const TEXT_DIM   := Color(0.55, 0.55, 0.65)
const GOLD_COLOR := Color(1.00, 0.84, 0.22)
const GEM_COLOR  := Color(0.40, 0.80, 1.00)
const HP_FULL    := Color(0.18, 0.82, 0.35)
const HP_LOW     := Color(0.90, 0.22, 0.15)
const FEVER_CLR  := Color(1.00, 0.52, 0.00)
const BOSS_CLR   := Color(0.90, 0.15, 0.15)
const DANGER_CLR := Color(1.00, 0.30, 0.10)

# --- Fábrica de StyleBoxFlat ---
static func flat(bg: Color, border: Color = Color.TRANSPARENT, bw: int = 0, radius: int = 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.corner_radius_top_left    = radius
	s.corner_radius_top_right   = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	if bw > 0:
		s.border_width_left   = bw
		s.border_width_right  = bw
		s.border_width_top    = bw
		s.border_width_bottom = bw
		s.border_color = border
	return s

static func flat_margin(bg: Color, margin: int = 8, radius: int = 6) -> StyleBoxFlat:
	var s := flat(bg, Color.TRANSPARENT, 0, radius)
	s.content_margin_left   = margin
	s.content_margin_right  = margin
	s.content_margin_top    = margin / 2
	s.content_margin_bottom = margin / 2
	return s

# --- Fábrica de nós ---
static func label(text: String, color: Color = TEXT_MAIN, size: int = 14) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", size)
	return l

static func button(text: String, bg: Color = BG_BUTTON, size: int = 16) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_stylebox_override("normal",  flat_margin(bg, 12, 8))
	b.add_theme_stylebox_override("hover",   flat_margin(bg.lightened(0.12), 12, 8))
	b.add_theme_stylebox_override("pressed", flat_margin(bg.darkened(0.12), 12, 8))
	b.add_theme_stylebox_override("focus",   flat_margin(bg, 12, 8))
	b.add_theme_color_override("font_color", TEXT_MAIN)
	b.add_theme_font_size_override("font_size", size)
	return b

static func progress_bar(fill: Color, min_h: int = 10) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.value = 1.0
	bar.custom_minimum_size = Vector2(0, min_h)
	bar.add_theme_stylebox_override("fill",       flat(fill,    Color.TRANSPARENT, 0, 3))
	bar.add_theme_stylebox_override("background", flat(BG_PANEL, Color.TRANSPARENT, 0, 3))
	return bar

static func element_color(el: String) -> Color:
	return ELEMENT_COLORS.get(el, Color.WHITE)

static func rarity_color(r: String) -> Color:
	return RARITY_COLORS.get(r, Color.WHITE)

# HP bar color: verde acima de 40%, vermelho abaixo
static func hp_color(fraction: float) -> Color:
	return HP_FULL if fraction > 0.4 else HP_LOW

# --- Biomas (v2 §7) — cor de fundo por fase/10 mod BIOMES.size() ---
const BIOME_BG_COLORS := [
	Color(0.07, 0.14, 0.07),  # 0: Floresta
	Color(0.20, 0.13, 0.04),  # 1: Deserto
	Color(0.05, 0.05, 0.10),  # 2: Caverna
	Color(0.12, 0.17, 0.24),  # 3: Neve
	Color(0.18, 0.04, 0.03),  # 4: Vulcão
]
const BIOME_NAMES := ["Floresta", "Deserto", "Caverna", "Neve", "Vulcão"]

static func biome_color(phase: int) -> Color:
	return BIOME_BG_COLORS[(phase / 10) % BIOME_BG_COLORS.size()]

static func biome_name(phase: int) -> String:
	return BIOME_NAMES[(phase / 10) % BIOME_NAMES.size()]

# --- Tipos de inimigo ---
const ENEMY_TYPE_COLORS := {
	"NORMAL":  Color(0.60, 0.18, 0.18),
	"SWARM":   Color(0.55, 0.42, 0.08),
	"BRUISER": Color(0.72, 0.10, 0.10),
	"DIVER":   Color(0.12, 0.42, 0.72),
	"HEALER":  Color(0.18, 0.62, 0.32),
}
const ENEMY_TYPE_LABELS := {
	"NORMAL": "●", "SWARM": "◆", "BRUISER": "■", "DIVER": "▼", "HEALER": "✦"
}

static func enemy_type_color(type: String) -> Color:
	return ENEMY_TYPE_COLORS.get(type, Color(0.5, 0.2, 0.2))

static func enemy_type_label(type: String) -> String:
	return ENEMY_TYPE_LABELS.get(type, "?")
