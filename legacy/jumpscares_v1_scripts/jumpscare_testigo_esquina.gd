extends JumpscareBase

## El Testigo entra torcido desde la esquina inferior derecha y se lanza.

@onready var _figura: Sprite2D = $Visual/Figura

const ORIGIN := Vector2(1210, 880)
const TARGET := Vector2(560, 300)
const START_ROTATION := 40.0
const END_ROTATION := -6.0


func _on_start() -> void:
	_figura.position = ORIGIN
	_figura.rotation_degrees = START_ROTATION
	_figura.scale = Vector2(2, 2)
	_figura.modulate = Color(0.6, 0.6, 0.68, 1.0)


func _on_update(elapsed: float) -> void:
	var progress := clampf(elapsed / total_duration(), 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - progress, 3.0)
	_figura.position = ORIGIN.lerp(TARGET, eased)
	_figura.rotation_degrees = lerpf(START_ROTATION, END_ROTATION, eased)
	_figura.scale = Vector2.ONE * lerpf(2.0, 6.0, eased)