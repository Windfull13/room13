class_name MemoryVignette
extends Control

## Viñeta de recuerdo en pixel art de siluetas. Se pinta en un SubViewport de
## baja resolución (192×108) y se amplía con filtro «nearest», así cada píxel
## del dibujo se ve como un bloque nítido. Las subclases solo implementan
## _paint(canvas, t), con t de 0 a 1 a lo largo de la viñeta.

signal finished

const RESOLUTION := Vector2i(192, 108)
const OUTLINE_WIDTH := 1.0

## Tamaño en pantalla (múltiplo de la resolución para que los píxeles sean iguales).
@export var display_size: Vector2 = Vector2(288, 162)
## Sonido que acompaña a la viñeta (SoundCatalog). Vacío: silencio.
@export var sound_name: String = ""
## Momento (0-1) en que el sonido se corta de golpe. Negativo: suena hasta el final.
@export var sound_cut_at: float = -1.0

var progress: float = 0.0
var _viewport: SubViewport
var _painter: Node2D
var _playing: bool = false
var _sound_cut: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = display_size
	size = display_size
	_viewport = SubViewport.new()
	_viewport.size = RESOLUTION
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_painter = Node2D.new()
	_painter.draw.connect(func() -> void: _paint(_painter, progress))
	_viewport.add_child(_painter)
	var screen := TextureRect.new()
	screen.texture = _viewport.get_texture()
	screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	screen.stretch_mode = TextureRect.STRETCH_SCALE
	screen.size = display_size
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen)


## Reproduce la viñeta en `duration` segundos (0 = al instante) y emite finished.
func play(duration: float) -> void:
	_playing = true
	_sound_cut = false
	if not sound_name.is_empty():
		AudioManager.play(sound_name)
	if duration > 0.0:
		var tween := create_tween()
		tween.tween_method(set_progress, 0.0, 1.0, duration)
		await tween.finished
	else:
		set_progress(1.0)
		await get_tree().process_frame
	_stop_sound()
	_playing = false
	finished.emit()


func is_playing() -> bool:
	return _playing


## Para escenas que llevan la viñeta a mano (la cinemática final).
func set_progress(value: float) -> void:
	progress = clampf(value, 0.0, 1.0)
	if sound_cut_at >= 0.0 and progress >= sound_cut_at:
		_stop_sound()
	if _painter != null:
		_painter.queue_redraw()


func _exit_tree() -> void:
	_stop_sound()


func _stop_sound() -> void:
	if _sound_cut or sound_name.is_empty():
		return
	_sound_cut = true
	AudioManager.stop(sound_name)


## Dibujo de la viñeta. t va de 0 a 1.
func _paint(_canvas: CanvasItem, _t: float) -> void:
	pass

# ---------------------------------------------------------------------------
# Piezas de dibujo comunes (todas con contorno, como el resto del juego)
# ---------------------------------------------------------------------------

static func fill_background(canvas: CanvasItem, color: Color) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(RESOLUTION)), color)


## Rectángulo relleno con un contorno de un píxel.
static func outlined_rect(canvas: CanvasItem, rect: Rect2, fill: Color, outline: Color) -> void:
	canvas.draw_rect(rect.grow(OUTLINE_WIDTH), outline)
	canvas.draw_rect(rect, fill)


## Silueta de pie: cabeza, hombros, brazos, tronco y dos piernas. `feet` es el
## punto entre los pies; las proporciones son las de una persona (cabeza ~1/7).
static func figure(canvas: CanvasItem, feet: Vector2, height: float, fill: Color, outline: Color) -> void:
	var head := maxf(height * 0.075, 1.5)
	var top := feet.y - height
	var shoulder_y := top + head * 2.0 + height * 0.03
	var hip_y := feet.y - height * 0.47
	var shoulders := height * 0.12
	var hips := height * 0.085
	var leg := height * 0.055
	var torso := PackedVector2Array([
		Vector2(feet.x - shoulders, shoulder_y), Vector2(feet.x + shoulders, shoulder_y),
		Vector2(feet.x + hips, hip_y), Vector2(feet.x - hips, hip_y),
	])
	for side: float in [-1.0, 1.0]:
		var arm := PackedVector2Array([
			Vector2(feet.x + side * shoulders, shoulder_y), Vector2(feet.x + side * (shoulders + leg * 0.9), shoulder_y + height * 0.04),
			Vector2(feet.x + side * (shoulders + leg * 0.5), hip_y + height * 0.04), Vector2(feet.x + side * (shoulders - leg * 0.4), hip_y + height * 0.04),
		])
		_outlined_polygon(canvas, arm, fill, outline)
		var leg_x := feet.x + side * (hips - leg * 0.5)
		var leg_rect := Rect2(leg_x - leg * 0.5, hip_y - 1.0, leg, feet.y - hip_y + 1.0)
		canvas.draw_rect(leg_rect.grow(OUTLINE_WIDTH), outline)
		canvas.draw_rect(leg_rect, fill)
	_outlined_polygon(canvas, torso, fill, outline)
	var head_center := Vector2(feet.x, top + head)
	canvas.draw_circle(head_center, head + OUTLINE_WIDTH, outline)
	canvas.draw_circle(head_center, head, fill)


## Silueta sentada (de perfil), mirando a la derecha.
static func seated_figure(canvas: CanvasItem, seat: Vector2, height: float, fill: Color, outline: Color) -> void:
	var head := height * 0.2
	var back := PackedVector2Array([
		Vector2(seat.x - height * 0.18, seat.y), Vector2(seat.x - height * 0.14, seat.y - height * 0.62),
		Vector2(seat.x + height * 0.12, seat.y - height * 0.62), Vector2(seat.x + height * 0.16, seat.y - height * 0.1),
		Vector2(seat.x + height * 0.42, seat.y - height * 0.08), Vector2(seat.x + height * 0.42, seat.y + height * 0.32),
		Vector2(seat.x + height * 0.3, seat.y + height * 0.32), Vector2(seat.x + height * 0.3, seat.y + height * 0.06),
		Vector2(seat.x - height * 0.18, seat.y + height * 0.06),
	])
	_outlined_polygon(canvas, back, fill, outline)
	var head_center := Vector2(seat.x, seat.y - height * 0.62 - head * 0.8)
	canvas.draw_circle(head_center, head + OUTLINE_WIDTH, outline)
	canvas.draw_circle(head_center, head, fill)


## Una silla vacía de perfil.
static func chair(canvas: CanvasItem, base: Vector2, height: float, fill: Color, outline: Color) -> void:
	outlined_rect(canvas, Rect2(base.x - height * 0.3, base.y - height * 0.55, height * 0.6, height * 0.08), fill, outline)
	outlined_rect(canvas, Rect2(base.x - height * 0.3, base.y - height, height * 0.08, height), fill, outline)
	outlined_rect(canvas, Rect2(base.x + height * 0.22, base.y - height * 0.55, height * 0.08, height * 0.55), fill, outline)


## Un teléfono pequeño con la pantalla encendida (`glow` de 0 a 1).
static func phone(canvas: CanvasItem, center: Vector2, glow: float, outline: Color) -> void:
	var light := Color(0.75, 0.88, 1.0)
	if glow > 0.0:
		canvas.draw_circle(center, 9.0, Color(light, 0.12 * glow))
		canvas.draw_circle(center, 5.5, Color(light, 0.22 * glow))
	outlined_rect(canvas, Rect2(center - Vector2(3, 5), Vector2(6, 10)), Color(0.08, 0.08, 0.1), outline)
	canvas.draw_rect(Rect2(center - Vector2(2, 4), Vector2(4, 7)), Color(light, 0.25 + 0.75 * glow))


## Un reloj de pared detenido.
static func stopped_clock(canvas: CanvasItem, center: Vector2, radius: float, fill: Color, outline: Color) -> void:
	canvas.draw_circle(center, radius + OUTLINE_WIDTH, outline)
	canvas.draw_circle(center, radius, fill)
	canvas.draw_line(center, center + Vector2(0, -radius * 0.75), outline, 1.0)
	canvas.draw_line(center, center + Vector2(radius * 0.5, radius * 0.2), outline, 1.0)


static func _outlined_polygon(canvas: CanvasItem, points: PackedVector2Array, fill: Color, outline: Color) -> void:
	canvas.draw_colored_polygon(points, fill)
	var closed := points.duplicate()
	closed.append(points[0])
	canvas.draw_polyline(closed, outline, OUTLINE_WIDTH)


static func ease_in_out(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


## Parte de t que cae entre `from` y `to`, normalizada de 0 a 1.
static func span(t: float, from: float, to: float) -> float:
	return clampf((t - from) / (to - from), 0.0, 1.0)
