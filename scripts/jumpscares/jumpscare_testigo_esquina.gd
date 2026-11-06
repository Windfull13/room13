extends JumpscareBase

## El Vigilante de la esquina: lo que nos juzga cuando fingimos no verlo. Está de
## espaldas, cara a la esquina; inclina la cabeza como si escuchara y, sin
## girarse, retrocede hacia la cámara.

const HOME := Vector2(900, 470)
const CENTER := Vector2(640, 360)
const SCALE_HOME := 4.5
const SCALE_END := 12.0
const TILT_AT := 0.45
const BACK_AT := 0.75
const TILT_DEGREES := 11.0
const SWAY := 0.7
const JITTER := 5.0

@onready var _figura: Sprite2D = $Visual/Figura


func _on_start() -> void:
	_figura.position = HOME
	_figura.scale = Vector2.ONE * SCALE_HOME


func _on_update(elapsed: float) -> void:
	var tilt := smooth(ramp(elapsed, TILT_AT, TILT_AT + 0.25))
	var back := smooth(ramp(elapsed, BACK_AT, total_duration()))
	_figura.scale = Vector2.ONE * lerpf(SCALE_HOME, SCALE_END, back * back)
	_figura.position = HOME.lerp(CENTER, back)
	_figura.position.x += sin(elapsed * 70.0) * JITTER * back
	_figura.rotation_degrees = TILT_DEGREES * tilt + sin(elapsed * 3.0) * SWAY