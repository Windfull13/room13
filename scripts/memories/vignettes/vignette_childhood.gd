extends MemoryVignette

## Recuerdo 1 (infancia): un pasillo de escuela; una figura pequeña con mochila
## pegada a la pared, tres siluetas altas a un lado y, más lejos, otra de
## espaldas y quieta. Con el tiempo la figura pequeña se encoge un poco más.

const WALL := Color(0.16, 0.17, 0.22)
const FLOOR := Color(0.1, 0.1, 0.13)
const LOCKER := Color(0.21, 0.23, 0.29)
const OUTLINE := Color(0.03, 0.03, 0.05)
const SMALL := Color(0.55, 0.52, 0.6)
const TALL := Color(0.07, 0.07, 0.09)
const DISTANT := Color(0.24, 0.24, 0.29)
const LIGHT := Color(0.85, 0.85, 0.7)
const FLOOR_Y := 86.0


func _paint(canvas: CanvasItem, t: float) -> void:
	fill_background(canvas, WALL)
	canvas.draw_rect(Rect2(0, FLOOR_Y, RESOLUTION.x, RESOLUTION.y - FLOOR_Y), FLOOR)
	for i in range(9):
		outlined_rect(canvas, Rect2(6 + i * 21, 30, 17, 52), LOCKER, OUTLINE)
	canvas.draw_rect(Rect2(150, 8, 34, 4), Color(LIGHT, 0.35))
	figure(canvas, Vector2(160, FLOOR_Y - 6), 24.0, DISTANT, OUTLINE)
	var sway := sin(t * TAU * 2.0) * 0.8
	for i in range(3):
		figure(canvas, Vector2(78 + i * 15 + sway, FLOOR_Y + 2), 52.0 - i * 2.0, TALL, OUTLINE)
	var shrink := 1.0 - 0.08 * ease_in_out(t)
	var small_height := 30.0 * shrink
	figure(canvas, Vector2(26, FLOOR_Y + 2), small_height, SMALL, OUTLINE)
	outlined_rect(canvas, Rect2(17, FLOOR_Y + 2 - small_height * 0.72, 6, 9), Color(0.35, 0.25, 0.22), OUTLINE)
