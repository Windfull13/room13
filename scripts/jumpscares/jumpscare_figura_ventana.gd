extends JumpscareBase

## Alguien que mira desde fuera: la sensación de ser observado. Un rostro
## aparece al otro lado del cristal y se lanza contra él; el exterior se
## ilumina de golpe, como un relámpago.

const FACE_START := Vector2(640, 345)
const FACE_END := Vector2(640, 330)
const FADE_IN := 0.25
const BANG_AT := 0.55
const BANG_TIME := 0.12
const SCALE_FROM := 2.4
const SCALE_BANG := 8.5
const NIGHT := Color(0.02, 0.03, 0.07)
const LIGHTNING := Color(0.3, 0.38, 0.6)
const RATTLE := 5.0

@onready var _fondo: Sprite2D = $Visual/Fondo
@onready var _rostro: Sprite2D = $Visual/Rostro


func _on_start() -> void:
	_fondo.modulate = NIGHT
	_rostro.position = FACE_START
	_rostro.scale = Vector2.ONE * SCALE_FROM
	_rostro.modulate.a = 0.0


func _on_update(elapsed: float) -> void:
	_rostro.modulate.a = ramp(elapsed, 0.0, FADE_IN)
	var bang := smooth(ramp(elapsed, BANG_AT, BANG_AT + BANG_TIME))
	_rostro.scale = Vector2.ONE * lerpf(SCALE_FROM, SCALE_BANG, bang)
	_rostro.position = FACE_START.lerp(FACE_END, bang)
	_rostro.position.x += sin(elapsed * 90.0) * RATTLE * bang
	var lightning := bang * (1.0 - ramp(elapsed, BANG_AT + 0.35, total_duration()))
	_fondo.modulate = NIGHT.lerp(LIGHTNING, lightning)