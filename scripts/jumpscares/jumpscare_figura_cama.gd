extends JumpscareBase

## La mano de debajo de la cama: el miedo de la infancia que nunca se fue. Solo
## asoma una mano por debajo del somier; luego se lanza hacia la cámara.

const HAND_START := Vector2(640, 495)
const HAND_END := Vector2(640, 585)
const SCALE_START := 3.0
const SCALE_END := 10.0
const LUNGE_START := 0.5
const TWITCH_DEGREES := 3.5
const TWITCH_SPEED := 40.0

@onready var _mano: Sprite2D = $Visual/Mano


func _on_start() -> void:
	_mano.position = HAND_START
	_mano.scale = Vector2.ONE * SCALE_START


func _on_update(elapsed: float) -> void:
	var lunge := smooth(ramp(elapsed, LUNGE_START, total_duration()))
	_mano.scale = Vector2.ONE * lerpf(SCALE_START, SCALE_END, lunge * lunge)
	_mano.position = HAND_START.lerp(HAND_END, lunge)
	_mano.rotation_degrees = sin(elapsed * TWITCH_SPEED) * TWITCH_DEGREES * (1.0 - lunge)