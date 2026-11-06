extends JumpscareBase

## Los faros: un fragmento sensorial del accidente, sin imagen explícita. Se va
## la luz; dos faros se acercan entre la lluvia, la frenada, un golpe sordo y un
## blanco que lo borra todo. Nada de lo que se ve dice qué pasó.

const LIGHT_Y := 380.0
const SPACING_FROM := 24.0
const SPACING_TO := 430.0
const RADIUS_FROM := 26.0
const RADIUS_TO := 340.0
const SWERVE_AT := 0.85
const SWERVE_SHIFT := 190.0
const WHITEOUT_AT := 1.1
const BLACK_AT := 1.32
const RAIN_COUNT := 36
const RAIN_SEED := 3
const RAIN_SPEED := 900.0
const HEADLIGHT := Color(1.0, 0.92, 0.7, 0.9)

@onready var _fondo: Sprite2D = $Visual/Fondo

var _left: Sprite2D
var _right: Sprite2D
var _whiteout: Sprite2D
var _rain: Array[Sprite2D] = []
var _rain_offsets: Array[float] = []


func _on_start() -> void:
	_fondo.modulate = Color(0.0, 0.0, 0.01)
	_build_rain()
	_left = add_glow(Vector2(640, LIGHT_Y), RADIUS_FROM, HEADLIGHT)
	_right = add_glow(Vector2(640, LIGHT_Y), RADIUS_FROM, HEADLIGHT)
	_whiteout = add_block(Rect2(-40, -40, 1360, 800), Color(1, 1, 1, 0.0), 3)


func _on_update(elapsed: float) -> void:
	var near := ramp(elapsed, 0.1, WHITEOUT_AT)
	var swerve := smooth(ramp(elapsed, SWERVE_AT, WHITEOUT_AT)) * SWERVE_SHIFT
	var spacing := lerpf(SPACING_FROM, SPACING_TO, near * near)
	var radius := lerpf(RADIUS_FROM, RADIUS_TO, near * near)
	_left.position = Vector2(640 - spacing / 2.0 + swerve, LIGHT_Y)
	_right.position = Vector2(640 + spacing / 2.0 + swerve, LIGHT_Y)
	_left.scale = Vector2.ONE * radius * 2.0 / GLOW_SIZE
	_right.scale = _left.scale
	_whiteout.modulate.a = ramp(elapsed, WHITEOUT_AT, WHITEOUT_AT + 0.08) * (1.0 - ramp(elapsed, WHITEOUT_AT + 0.08, BLACK_AT))
	var gone := ramp(elapsed, WHITEOUT_AT, WHITEOUT_AT + 0.05)
	_left.modulate.a = 1.0 - gone
	_right.modulate.a = 1.0 - gone
	for i in range(_rain.size()):
		_rain[i].position.y = fposmod(_rain_offsets[i] + elapsed * RAIN_SPEED, 760.0) - 20.0
		_rain[i].modulate.a = 0.35 * (1.0 - gone)


func _build_rain() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = RAIN_SEED
	for i in range(RAIN_COUNT):
		var drop := add_block(Rect2(-1, -14, 2, 28), Color(0.7, 0.8, 1.0, 0.35), 1)
		drop.position.x = rng.randf_range(0.0, 1280.0)
		drop.rotation_degrees = 12.0
		_rain.append(drop)
		_rain_offsets.append(rng.randf_range(0.0, 760.0))