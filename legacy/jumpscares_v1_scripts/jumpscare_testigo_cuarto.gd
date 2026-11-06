extends JumpscareBase

## El Testigo se acerca de frente y llena la pantalla.

@onready var _figura: Sprite2D = $Visual/Figura


func _on_start() -> void:
	_figura.position = Vector2(640, 520)
	_figura.scale = Vector2(1.2, 1.2)
	_figura.modulate = Color(0.78, 0.78, 0.84, 1.0)


func _on_update(elapsed: float) -> void:
	var progress := clampf(elapsed / total_duration(), 0.0, 1.0)
	var eased := progress * progress
	_figura.scale = Vector2.ONE * lerpf(1.2, 9.0, eased)
	_figura.position.y = lerpf(520.0, 360.0, eased)