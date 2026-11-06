extends JumpscareBase

## La figura aparece pegada al cristal y lo atraviesa.

@onready var _figura: Sprite2D = $Visual/Figura

const GLASS_COLOR := Color(0.72, 0.78, 0.95, 1.0)
const CLOSE_COLOR := Color(0.92, 0.94, 1.0, 1.0)
const ORIGIN := Vector2(640, 330)
const TARGET := Vector2(620, 520)


func _on_start() -> void:
	_figura.position = ORIGIN
	_figura.scale = Vector2.ONE
	_figura.modulate = GLASS_COLOR


func _on_update(elapsed: float) -> void:
	var progress := clampf(elapsed / total_duration(), 0.0, 1.0)
	var eased := progress * progress
	_figura.scale = Vector2.ONE * lerpf(1.0, 8.0, eased)
	_figura.position = ORIGIN.lerp(TARGET, eased)
	_figura.modulate = GLASS_COLOR.lerp(CLOSE_COLOR, eased)