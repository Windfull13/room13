extends MemoryVignette

## Recuerdo 3 (la noche): lluvia; dos círculos de luz que se acercan; un
## destello blanco y negro. Después, solo un teléfono que brilla en la
## oscuridad. No hay impacto ni cuerpos: luz, lluvia y silencio.

const NIGHT := Color(0.04, 0.05, 0.08)
const RAIN := Color(0.5, 0.6, 0.75, 0.55)
const HEADLIGHT := Color(1.0, 0.95, 0.8)
const OUTLINE := Color(0.0, 0.0, 0.0)
const APPROACH_END := 0.52
const FLASH_END := 0.6
const DARK_END := 0.68
const RAIN_DROPS := 46


func _paint(canvas: CanvasItem, t: float) -> void:
	if t < APPROACH_END:
		_paint_approach(canvas, span(t, 0.0, APPROACH_END), t)
	elif t < FLASH_END:
		fill_background(canvas, Color.WHITE if span(t, APPROACH_END, FLASH_END) < 0.5 else Color.BLACK)
	elif t < DARK_END:
		fill_background(canvas, Color.BLACK)
	else:
		fill_background(canvas, Color.BLACK)
		var after := span(t, DARK_END, 1.0)
		phone(canvas, Vector2(96, 58), 0.5 + 0.5 * sin(after * TAU * 3.0), OUTLINE)


func _paint_approach(canvas: CanvasItem, near: float, t: float) -> void:
	fill_background(canvas, NIGHT)
	var radius := lerpf(3.0, 22.0, ease_in_out(near))
	var gap := lerpf(10.0, 46.0, ease_in_out(near))
	for side: float in [-1.0, 1.0]:
		var center := Vector2(96 + side * gap * 0.5, 62)
		canvas.draw_circle(center, radius * 1.8, Color(HEADLIGHT, 0.12))
		canvas.draw_circle(center, radius, Color(HEADLIGHT, 0.85))
	for i in range(RAIN_DROPS):
		var x := fmod(i * 41.0 + t * 30.0, float(RESOLUTION.x))
		var y := fmod(i * 23.0 + t * 900.0, float(RESOLUTION.y))
		canvas.draw_line(Vector2(x, y), Vector2(x - 1, y + 5), RAIN, 1.0)
