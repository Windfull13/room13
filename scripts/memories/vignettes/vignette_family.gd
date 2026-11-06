extends MemoryVignette

## Recuerdo 2 (familia): tres siluetas de la mano bajo una luz dorada. Motas de
## colores (los lápices de la niña) flotan despacio.

const BACKGROUND := Color(0.24, 0.15, 0.08)
const GOLD := Color(1.0, 0.78, 0.4)
const OUTLINE := Color(0.12, 0.06, 0.02)
const FIGURES := Color(0.18, 0.1, 0.05)
const SPECKS: Array[Color] = [Color(0.95, 0.45, 0.4), Color(0.45, 0.75, 0.95), Color(0.95, 0.85, 0.4), Color(0.55, 0.85, 0.5)]
const GROUND_Y := 90.0


func _paint(canvas: CanvasItem, t: float) -> void:
	fill_background(canvas, BACKGROUND)
	var glow := 0.75 + 0.25 * sin(t * TAU)
	for ring in range(5):
		canvas.draw_circle(Vector2(96, 44), 58.0 - ring * 10.0, Color(GOLD, 0.08 * glow + ring * 0.03))
	canvas.draw_rect(Rect2(0, GROUND_Y, RESOLUTION.x, RESOLUTION.y - GROUND_Y), Color(0.16, 0.09, 0.04))
	for i in range(12):
		var drift := fmod(t * 0.6 + i * 0.083, 1.0)
		var at := Vector2(20 + i * 14, 80 - drift * 70)
		canvas.draw_rect(Rect2(at, Vector2(2, 2)), Color(SPECKS[i % SPECKS.size()], 0.8 * (1.0 - drift)))
	var adults: Array[float] = [70.0, 122.0]
	figure(canvas, Vector2(adults[0], GROUND_Y), 50.0, FIGURES, OUTLINE)
	figure(canvas, Vector2(96, GROUND_Y), 30.0, FIGURES, OUTLINE)
	figure(canvas, Vector2(adults[1], GROUND_Y), 47.0, FIGURES, OUTLINE)
	canvas.draw_line(Vector2(adults[0] + 7, GROUND_Y - 24), Vector2(92, GROUND_Y - 15), FIGURES, 2.0)
	canvas.draw_line(Vector2(100, GROUND_Y - 15), Vector2(adults[1] - 7, GROUND_Y - 23), FIGURES, 2.0)
