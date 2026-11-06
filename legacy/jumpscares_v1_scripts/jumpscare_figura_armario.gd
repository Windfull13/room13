extends JumpscareBase

## La puerta del armario se abre de golpe y la figura sale de dentro.

const DOOR_OPEN_TIME := 0.28
const DOOR_OPEN_DEGREES := -78.0
const FIGURE_DELAY := 0.2
const FIGURE_ORIGIN := Vector2(520, 400)
const FIGURE_TARGET := Vector2(620, 300)

@onready var _figura: Sprite2D = $Visual/Figura
@onready var _puerta: Sprite2D = $Visual/Puerta


func _on_start() -> void:
	_puerta.rotation_degrees = 0.0
	_figura.position = FIGURE_ORIGIN
	_figura.scale = Vector2(0.8, 0.8)
	_figura.modulate = Color(0.7, 0.7, 0.76, 1.0)


func _on_update(elapsed: float) -> void:
	_puerta.rotation_degrees = DOOR_OPEN_DEGREES * clampf(elapsed / DOOR_OPEN_TIME, 0.0, 1.0)
	var emerging := clampf((elapsed - FIGURE_DELAY) / (total_duration() - FIGURE_DELAY), 0.0, 1.0)
	var eased := emerging * emerging * (3.0 - 2.0 * emerging)
	_figura.scale = Vector2.ONE * lerpf(0.8, 7.0, eased)
	_figura.position = FIGURE_ORIGIN.lerp(FIGURE_TARGET, eased)