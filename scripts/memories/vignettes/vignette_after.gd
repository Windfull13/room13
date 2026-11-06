extends MemoryVignette

## Recuerdo 4 (el después): una mesa con dos sillas vacías y una figura sentada
## sola; un reloj detenido en la pared y un teléfono que brilla sobre la mesa.

const ROOM := Color(0.11, 0.11, 0.13)
const FLOOR := Color(0.07, 0.07, 0.08)
const OUTLINE := Color(0.02, 0.02, 0.03)
const FURNITURE := Color(0.2, 0.17, 0.15)
const FIGURE_FILL := Color(0.05, 0.05, 0.06)
const CLOCK_FACE := Color(0.62, 0.6, 0.55)
const FLOOR_Y := 92.0
const TABLE_TOP := 64.0


func _paint(canvas: CanvasItem, t: float) -> void:
	fill_background(canvas, ROOM)
	canvas.draw_rect(Rect2(0, FLOOR_Y, RESOLUTION.x, RESOLUTION.y - FLOOR_Y), FLOOR)
	canvas.draw_circle(Vector2(96, 30), 40.0, Color(0.6, 0.6, 0.65, 0.06))
	stopped_clock(canvas, Vector2(150, 24), 9.0, CLOCK_FACE, OUTLINE)
	seated_figure(canvas, Vector2(44, 70), 34.0, FIGURE_FILL, OUTLINE)
	chair(canvas, Vector2(124, FLOOR_Y), 30.0, FURNITURE, OUTLINE)
	chair(canvas, Vector2(156, FLOOR_Y), 30.0, FURNITURE, OUTLINE)
	outlined_rect(canvas, Rect2(62, TABLE_TOP, 80, 5), FURNITURE, OUTLINE)
	outlined_rect(canvas, Rect2(68, TABLE_TOP + 5, 4, FLOOR_Y - TABLE_TOP - 5), FURNITURE, OUTLINE)
	outlined_rect(canvas, Rect2(132, TABLE_TOP + 5, 4, FLOOR_Y - TABLE_TOP - 5), FURNITURE, OUTLINE)
	phone(canvas, Vector2(104, TABLE_TOP - 4), 0.45 + 0.55 * absf(sin(t * TAU * 2.0)), OUTLINE)
