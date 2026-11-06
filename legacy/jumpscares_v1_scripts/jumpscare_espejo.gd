extends JumpscareBase

## La figura atraviesa el espejo: empieza dentro del reflejo y lo rompe.
## El espejo va después en el orden de hijos, así que la tapa mientras está
## dentro y deja de taparla cuando la figura lo desborda.

@onready var _figura: Sprite2D = $Visual/Figura

const ORIGIN := Vector2(640, 380)
const TARGET := Vector2(640, 290)


func _on_start() -> void:
	_figura.position = ORIGIN
	_figura.scale = Vector2(0.9, 0.9)
	_figura.modulate = Color(0.62, 0.66, 0.74, 1.0)


func _on_update(elapsed: float) -> void:
	var progress := clampf(elapsed / total_duration(), 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - progress, 4.0)
	_figura.scale = Vector2.ONE * lerpf(0.9, 9.0, eased)
	_figura.position = ORIGIN.lerp(TARGET, eased)