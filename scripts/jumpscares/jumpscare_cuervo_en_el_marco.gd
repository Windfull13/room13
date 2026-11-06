extends JumpscareBase

## El presagio: un cuervo posado donde estaba la foto. Lo asociamos con la
## muerte; aquí rompe su quietud, bate las alas y se echa encima entre plumas.

const PERCH := Vector2(930, 250)
const CENTER := Vector2(640, 360)
const SCALE_PERCHED := 3.0
const SCALE_END := 13.0
const TAKEOFF_AT := 0.4
const FLAP_SPEED := 38.0
const FLAP_DEPTH := 0.28
const FEATHER_COUNT := 18
const FEATHER_SEED := 7

@onready var _cuervo: Sprite2D = $Visual/Cuervo

var _feathers: Array[Sprite2D] = []
var _drift: Array[Vector2] = []


func _on_start() -> void:
	_cuervo.position = PERCH
	_cuervo.scale = Vector2.ONE * SCALE_PERCHED
	_build_feathers()


func _on_update(elapsed: float) -> void:
	var flight := smooth(ramp(elapsed, TAKEOFF_AT, total_duration()))
	var size := lerpf(SCALE_PERCHED, SCALE_END, flight * flight)
	var flap := 1.0 + sin(elapsed * FLAP_SPEED) * FLAP_DEPTH * ramp(elapsed, TAKEOFF_AT - 0.05, TAKEOFF_AT + 0.05)
	_cuervo.scale = Vector2(size, size * flap)
	_cuervo.position = PERCH.lerp(CENTER, flight)
	var fall := maxf(elapsed - TAKEOFF_AT, 0.0)
	for i in range(_feathers.size()):
		_feathers[i].modulate.a = ramp(elapsed, TAKEOFF_AT, TAKEOFF_AT + 0.05) * (1.0 - ramp(elapsed, total_duration() - 0.2, total_duration()))
		_feathers[i].position = _cuervo.position + _drift[i] * fall + Vector2(0, 260.0 * fall * fall)
		_feathers[i].rotation = fall * (2.0 + i % 5)


func _build_feathers() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = FEATHER_SEED
	for i in range(FEATHER_COUNT):
		var feather := add_block(Rect2(-5, -2, 10, 4), Color(0.03, 0.03, 0.05, 0.0), 1)
		feather.position = PERCH
		_feathers.append(feather)
		_drift.append(Vector2(rng.randf_range(-420.0, 420.0), rng.randf_range(-260.0, 40.0)))