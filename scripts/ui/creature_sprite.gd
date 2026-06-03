class_name CreatureSprite
extends Control

# "Sprite" animado de um monstro/inimigo (placeholder em emoji + corpo desenhado).
#
# Estrutura em camadas (resolve o conflito classico de animacao):
#   self (CreatureSprite)  -> a ARENA posiciona aqui (self.position = slot)
#     _rig (Control)       -> TODA a animacao acontece aqui (bob, lunge, flash...)
#       _body (_Body)      -> desenha sombra + disco de aura (cor do elemento)
#       _emoji (Label)     -> o emoji em si, na fonte de emoji do sistema
#
# O bob (respiracao/marcha) so escreve _rig.position.Y a cada frame.
# Lunge de ataque e dano usam tweens em X / scale / modulate.
# Como usam eixos/propriedades diferentes, nunca brigam pelo mesmo valor.

signal clicked
signal death_finished

var emoji: String = "❓"
var body_color: Color = Color(0.5, 0.5, 0.5)
var diameter: float = 80.0
var face_dir: int = 1          # +1 ataca para a direita (time), -1 para a esquerda (inimigo)

var _rig: Control
var _body: _Body
var _emoji_lbl: Label
var _t: float = 0.0
var _marching: bool = false
var _alive: bool = true
var _glowing: bool = false
var _action_tween: Tween

# ---------------------------------------------------------------------------

func _ready() -> void:
	custom_minimum_size = Vector2(diameter, diameter)
	size = Vector2(diameter, diameter)
	pivot_offset = size * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP   # recebe clique (filhos sao IGNORE)

	_rig = Control.new()
	_rig.size = size
	_rig.pivot_offset = size * 0.5
	_rig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rig)

	_body = _Body.new()
	_body.size = size
	_body.body_color = body_color
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rig.add_child(_body)
	_body.queue_redraw()

	_emoji_lbl = EmojiDB.make_label(emoji, int(diameter * 0.60))
	_emoji_lbl.size = size
	_emoji_lbl.position = Vector2.ZERO
	_rig.add_child(_emoji_lbl)

	set_process(true)

func _process(delta: float) -> void:
	if not _alive:
		return
	_t += delta
	# Bob: marcha = pulinhos rapidos; parado = respiracao suave.
	if _marching:
		_rig.position.y = -absf(sin(_t * 8.5)) * (diameter * 0.11)
	else:
		_rig.position.y = sin(_t * 3.0) * (diameter * 0.035)
	# Brilho de Ultimate pronta (pulsa).
	if _glowing:
		_body.glow = 0.45 + 0.55 * absf(sin(_t * 4.0))
		_body.queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		emit_signal("clicked")
		accept_event()

# ---------------------------------------------------------------------------
# API publica (usada pela arena)
# ---------------------------------------------------------------------------

func set_marching(m: bool) -> void:
	_marching = m

func set_ready_glow(on: bool) -> void:
	_glowing = on
	if not on:
		_body.glow = 0.0
		_body.queue_redraw()

func set_emoji(e: String) -> void:
	emoji = e
	if _emoji_lbl != null:
		_emoji_lbl.text = e

# Lunge de ataque: avanca na direcao de face_dir, estica e volta.
func play_attack() -> void:
	if not _alive or _rig == null:
		return
	_kill_action()
	var lunge := diameter * 0.42 * float(face_dir)
	_action_tween = create_tween()
	_action_tween.tween_property(_rig, "position:x", lunge, 0.07) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.parallel().tween_property(_rig, "scale", Vector2(1.18, 0.86), 0.07)
	_action_tween.tween_property(_rig, "position:x", 0.0, 0.20) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_action_tween.parallel().tween_property(_rig, "scale", Vector2.ONE, 0.20)

# Dano recebido: flash claro + leve squash.
func play_hurt() -> void:
	if not _alive or _rig == null:
		return
	_kill_action()
	_rig.modulate = Color(2.2, 1.4, 1.4)
	_action_tween = create_tween()
	_action_tween.tween_property(_rig, "scale", Vector2(0.84, 1.16), 0.06)
	_action_tween.parallel().tween_property(_rig, "modulate", Color.WHITE, 0.28)
	_action_tween.tween_property(_rig, "scale", Vector2.ONE, 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# Entrada em cena vinda do lado (inimigo marchando para dentro da tela).
func walk_in_from(dx: float, dur: float = 0.7) -> void:
	if _rig == null:
		return
	set_marching(true)
	_rig.position.x = dx
	_kill_action()
	_action_tween = create_tween()
	_action_tween.tween_property(_rig, "position:x", 0.0, dur).set_trans(Tween.TRANS_SINE)
	_action_tween.tween_callback(func(): set_marching(false))

# Morte: para o bob, estica, gira, some e cai. Emite death_finished no fim.
func die() -> void:
	if not _alive:
		return
	_alive = false
	_glowing = false
	_kill_action()
	var fall := diameter * 0.7
	var tw := create_tween()
	tw.tween_property(_rig, "scale", Vector2(1.3, 1.3), 0.08)
	tw.parallel().tween_property(_rig, "modulate", Color(1.6, 1.6, 1.6), 0.08)
	tw.tween_property(_rig, "modulate:a", 0.0, 0.34)
	tw.parallel().tween_property(_rig, "rotation", deg_to_rad(70.0 * float(-face_dir)), 0.34)
	tw.parallel().tween_property(_rig, "position:y", _rig.position.y + fall, 0.34) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): emit_signal("death_finished"))

func _kill_action() -> void:
	if _action_tween != null and _action_tween.is_valid():
		_action_tween.kill()

# ===========================================================================
# Camada de desenho (sombra + disco de aura) — classe interna
# ===========================================================================

class _Body extends Control:
	var body_color: Color = Color(0.5, 0.5, 0.5)
	var glow: float = 0.0

	func _draw() -> void:
		var s := size
		var cx := s.x * 0.5
		# Sombra no "chao".
		_draw_ellipse(Vector2(cx, s.y * 0.90), s.x * 0.33, s.y * 0.10, Color(0, 0, 0, 0.30))
		# Disco de aura (cor do elemento) atras do emoji.
		var r := minf(s.x, s.y) * 0.46
		var center := Vector2(cx, s.y * 0.48)
		draw_circle(center, r, Color(body_color, 0.30))
		draw_arc(center, r, 0.0, TAU, 36, Color(body_color, 0.85), 2.5, true)
		# Anel de brilho quando a Ultimate esta pronta.
		if glow > 0.0:
			draw_arc(center, r + 4.0, 0.0, TAU, 36, Color(1.0, 0.95, 0.4, glow), 3.0, true)

	func _draw_ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in 24:
			var a := TAU * float(i) / 24.0
			pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
		draw_colored_polygon(pts, col)
