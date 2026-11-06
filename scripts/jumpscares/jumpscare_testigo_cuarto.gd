extends JumpscareBase

## El Testigo: la sensación de ser juzgado. Está quieto, a lo lejos, como en la
## habitación; ladea la cabeza, y en un instante está encima, con los ojos
## ocupando la pantalla.

const STILL_UNTIL := 0.6
const TILT_AT := 0.6
const SNAP_AT := 0.85
const HOME := Vector2(640, 500)
const SCALE_HOME := 2.4
const SCALE_SNAP := 5.5
const SCALE_END := 11.0
const TILT_DEGREES := 7.0
const BREATH := 0.02

@onready var _figura: Sprite2D = $Visual/Figura
@onready var _fondo: Sprite2D = $Visual/Fondo


func _on_start() -> void:
	_figura.position = HOME
	_figura.scale = Vector2.ONE * SCALE_HOME


func _on_update(elapsed: float) -> void:
	var breath := 1.0 + sin(elapsed * 7.0) * BREATH * (1.0 - ramp(elapsed, STILL_UNTIL, TILT_AT))
	var tilt := smooth(ramp(elapsed, TILT_AT, TILT_AT + 0.15))
	var snap := smooth(ramp(elapsed, SNAP_AT, SNAP_AT + 0.1))
	var loom := smooth(ramp(elapsed, SNAP_AT + 0.1, total_duration()))
	var size := lerpf(SCALE_HOME, SCALE_SNAP, snap)
	size = lerpf(size, SCALE_END, loom * loom)
	_figura.scale = Vector2.ONE * size * Vector2(1.0, breath)
	_figura.rotation_degrees = TILT_DEGREES * tilt * (1.0 - snap)
	_figura.position = HOME.lerp(Vector2(640, 330), snap)
	_fondo.modulate = Color(0.015, 0.015, 0.02).lerp(Color(0.1, 0.09, 0.1), snap * (1.0 - loom))