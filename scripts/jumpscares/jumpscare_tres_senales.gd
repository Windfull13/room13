extends JumpscareBase

## Las tres señales: el acoso. Dos golpes en la pared, una mano marcada, un
## teléfono que no deja de sonar... y de repente las manos están por todas
## partes: no hay sitio donde nadie te deje en paz.

const KNOCKS: Array[float] = [0.0, 0.33]
const HAND_AT := 0.55
const PHONE_AT := 0.95
const RING_SPEED := 75.0
const RING_DEGREES := 7.0
const SWARM_AT := 1.2
const SWARM_COUNT := 26
const SWARM_SEED := 13
const SWARM_SCALE_MIN := 3.5
const SWARM_SCALE_MAX := 8.0
const KNOCK_FLASH := Color(0.12, 0.12, 0.2)
## Manos pálidas, no rojas: es el cerco de las miradas, no un crimen.
const HAND_TINT := Color(1, 1, 1, 0.0)

@onready var _fondo: Sprite2D = $Visual/Fondo
@onready var _mano: Sprite2D = $Visual/Mano
@onready var _telefono: Sprite2D = $Visual/Telefono

var _swarm: Array[Sprite2D] = []


func _on_start() -> void:
	_mano.modulate.a = 0.0
	_telefono.modulate.a = 0.0
	_build_swarm()


func _on_update(elapsed: float) -> void:
	var knock := 0.0
	for at in KNOCKS:
		knock = maxf(knock, 1.0 - ramp(elapsed, at, at + 0.12))
	_fondo.modulate = Color(0.03, 0.025, 0.03).lerp(KNOCK_FLASH, knock)
	_mano.modulate.a = ramp(elapsed, HAND_AT, HAND_AT + 0.2)
	var ringing := ramp(elapsed, PHONE_AT, PHONE_AT + 0.05)
	_telefono.modulate.a = ramp(elapsed, PHONE_AT - 0.1, PHONE_AT)
	_telefono.rotation_degrees = sin(elapsed * RING_SPEED) * RING_DEGREES * ringing
	_telefono.scale = Vector2.ONE * lerpf(6.0, 8.0, ramp(elapsed, PHONE_AT, PHONE_AT + 0.25))
	for i in range(_swarm.size()):
		var appear := SWARM_AT + float(i) / _swarm.size() * (total_duration() - SWARM_AT) * 0.8
		_swarm[i].modulate.a = ramp(elapsed, appear, appear + 0.05)


## Manos repartidas por la pantalla con una semilla fija: siempre el mismo susto.
func _build_swarm() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SWARM_SEED
	for i in range(SWARM_COUNT):
		var hand := Sprite2D.new()
		hand.texture = _mano.texture
		hand.position = Vector2(rng.randf_range(0.0, 1280.0), rng.randf_range(0.0, 720.0))
		hand.scale = Vector2.ONE * rng.randf_range(SWARM_SCALE_MIN, SWARM_SCALE_MAX)
		hand.rotation_degrees = rng.randf_range(-35.0, 35.0)
		hand.modulate = HAND_TINT
		_visual.add_child(hand)
		_swarm.append(hand)