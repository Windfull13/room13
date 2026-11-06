extends JumpscareBase

## La figura sale de debajo de la cama y se lanza hacia la cámara.
## El dibujo de la cama va detrás en el orden de hijos, así que la tapa
## mientras sube.

@onready var _figura: Sprite2D = $Visual/Figura

const ORIGIN := Vector2(600, 790)
const TARGET := Vector2(620, 250)


func _on_start() -> void:
	_figura.position = ORIGIN
	_figura.rotation_degrees = 4.0
	_figura.scale = Vector2(2.5, 2.5)
	_figura.modulate = Color(0.72, 0.72, 0.78, 1.0)


func _on_update(elapsed: float) -> void:
	var progress := clampf(elapsed / total_duration(), 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - progress, 2.0)
	_figura.position = ORIGIN.lerp(TARGET, eased)
	_figura.scale = Vector2.ONE * lerpf(2.5, 6.0, eased)
	_figura.rotation_degrees = lerpf(4.0, -3.0, eased)