extends JumpscareBase

## La sombra del armario: lo que se evita recordar. Las dos hojas se abren de
## golpe y dentro solo hay oscuridad con dos ojos que se acercan.

const DOORS_OPEN_TIME := 0.28
const EYES_APPEAR := 0.3
const EYES_FROM := Vector2(40.0, 250.0)
const EYES_TO := Vector2(190.0, 340.0)
const EYE_SCALE_FROM := 1.2
const EYE_SCALE_TO := 11.0
const INTERIOR_SCALE_FROM := Vector2(30.0, 70.0)
const INTERIOR_SCALE_TO := Vector2(170.0, 100.0)
const EYE_SPLIT_X := 640.0
const EYE_WIDTH := 1.7
const EYE_HEIGHT := 0.55
const GLOW_PER_EYE := 11.0
const EYE_GLOW := Color(1.0, 0.82, 0.45, 0.45)

@onready var _izquierda: Sprite2D = $Visual/PuertaIzq
@onready var _derecha: Sprite2D = $Visual/PuertaDer
@onready var _interior: Sprite2D = $Visual/Interior
@onready var _ojo_izq: Sprite2D = $Visual/OjoIzq
@onready var _ojo_der: Sprite2D = $Visual/OjoDer

var _glow_izq: Sprite2D
var _glow_der: Sprite2D


func _on_start() -> void:
	_glow_izq = add_glow(_ojo_izq.position, 10.0, EYE_GLOW)
	_glow_der = add_glow(_ojo_der.position, 10.0, EYE_GLOW)
	_glow_izq.modulate.a = 0.0
	_glow_der.modulate.a = 0.0
	_izquierda.scale.x = 5.5
	_derecha.scale.x = 5.5
	_interior.scale = INTERIOR_SCALE_FROM
	_ojo_izq.modulate.a = 0.0
	_ojo_der.modulate.a = 0.0


func _on_update(elapsed: float) -> void:
	var opening := smooth(ramp(elapsed, 0.0, DOORS_OPEN_TIME))
	_izquierda.scale.x = lerpf(5.5, 0.4, opening)
	_derecha.scale.x = lerpf(5.5, 0.4, opening)
	var approach := smooth(ramp(elapsed, EYES_APPEAR, total_duration()))
	var spread := lerpf(EYES_FROM.x, EYES_TO.x, approach)
	var height := lerpf(EYES_FROM.y, EYES_TO.y, approach)
	_ojo_izq.position = Vector2(EYE_SPLIT_X - spread, height)
	_ojo_der.position = Vector2(EYE_SPLIT_X + spread, height)
	var eye_size := lerpf(EYE_SCALE_FROM, EYE_SCALE_TO, approach * approach)
	var eye_scale := Vector2(eye_size * EYE_WIDTH, eye_size * EYE_HEIGHT)
	_ojo_izq.scale = eye_scale
	_ojo_der.scale = eye_scale
	var visible_eyes := ramp(elapsed, EYES_APPEAR, EYES_APPEAR + 0.08)
	_ojo_izq.modulate.a = visible_eyes
	_ojo_der.modulate.a = visible_eyes
	_glow_izq.position = _ojo_izq.position
	_glow_der.position = _ojo_der.position
	_glow_izq.scale = Vector2.ONE * eye_size * GLOW_PER_EYE / GLOW_SIZE
	_glow_der.scale = _glow_izq.scale
	_glow_izq.modulate.a = visible_eyes
	_glow_der.modulate.a = visible_eyes
	_interior.scale = INTERIOR_SCALE_FROM.lerp(INTERIOR_SCALE_TO, approach * approach)