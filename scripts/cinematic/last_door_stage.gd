class_name LastDoorStage
extends MemoryVignette

## Escenario de la cinemática final, en el mismo pixel art de siluetas que las
## viñetas. No avanza solo: la cinemática le pasa cada valor (de 0 a 1).

const ROOM := Color(0.05, 0.05, 0.07)
const FLOOR := Color(0.03, 0.03, 0.04)
const OUTLINE := Color(0.0, 0.0, 0.0)
const DOOR := Color(0.16, 0.13, 0.12)
const LIGHT := Color(1.0, 0.98, 0.92)
const YOU := Color(0.1, 0.1, 0.12)
const FAMILY := Color(0.86, 0.8, 0.7)
const SMILE := Color(0.45, 0.36, 0.3)
const RAIN := Color(0.5, 0.6, 0.75, 0.5)
const FLOOR_Y := 92.0
const DOOR_RECT := Rect2(82, 30, 28, 62)
const RAIN_DROPS := 40

var rain: float = 1.0
var door_open: float = 0.0
var light: float = 0.0
var stand: float = 0.0
var family: float = 0.0
var time: float = 0.0


func _paint(canvas: CanvasItem, _t: float) -> void:
	fill_background(canvas, ROOM.lerp(LIGHT, light * 0.35))
	canvas.draw_rect(Rect2(0, FLOOR_Y, RESOLUTION.x, RESOLUTION.y - FLOOR_Y), FLOOR.lerp(LIGHT, light * 0.25))
	_paint_door(canvas)
	_paint_light(canvas)
	_paint_you(canvas)
	_paint_family(canvas)
	_paint_rain(canvas)


func _paint_door(canvas: CanvasItem) -> void:
	outlined_rect(canvas, DOOR_RECT, LIGHT, OUTLINE)
	var leaf := DOOR_RECT.size.x * (1.0 - door_open * 0.85)
	canvas.draw_rect(Rect2(DOOR_RECT.position, Vector2(leaf, DOOR_RECT.size.y)), DOOR)


func _paint_light(canvas: CanvasItem) -> void:
	var strength := maxf(door_open * 0.5, light)
	if strength <= 0.0:
		return
	var center := DOOR_RECT.get_center()
	for ring in range(6):
		canvas.draw_circle(center, 10.0 + ring * 16.0 * (0.4 + light), Color(LIGHT, 0.07 * strength))


## Tú: sentado al principio; con la luz, te pones de pie.
func _paint_you(canvas: CanvasItem) -> void:
	if stand < 0.5:
		seated_figure(canvas, Vector2(48, 78), 30.0, YOU, OUTLINE)
	else:
		figure(canvas, Vector2(52, FLOOR_Y), lerpf(40.0, 46.0, span(stand, 0.5, 1.0)), YOU, OUTLINE)


## Una silueta adulta y una niña en la luz, que te sonríen y se desvanecen.
func _paint_family(canvas: CanvasItem) -> void:
	if family <= 0.0:
		return
	var adult := Color(FAMILY, family)
	var outline := Color(SMILE, family)
	figure(canvas, Vector2(130, FLOOR_Y), 46.0, adult, outline)
	figure(canvas, Vector2(146, FLOOR_Y), 28.0, adult, outline)
	_smile(canvas, _head_center(130.0, 46.0), outline)
	_smile(canvas, _head_center(146.0, 28.0), outline)


func _head_center(x: float, height: float) -> Vector2:
	return Vector2(x, FLOOR_Y - height + maxf(height * 0.075, 1.5))


func _smile(canvas: CanvasItem, center: Vector2, color: Color) -> void:
	canvas.draw_arc(center, 1.6, 0.3, PI - 0.3, 5, color, 1.0)


func _paint_rain(canvas: CanvasItem) -> void:
	if rain <= 0.0:
		return
	for i in range(RAIN_DROPS):
		var x := fmod(i * 37.0 + time * 20.0, float(RESOLUTION.x))
		var y := fmod(i * 29.0 + time * 160.0, float(RESOLUTION.y))
		canvas.draw_line(Vector2(x, y), Vector2(x - 1, y + 5), Color(RAIN, RAIN.a * rain), 1.0)
