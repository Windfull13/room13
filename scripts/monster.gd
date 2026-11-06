class_name Monster
extends Node2D

## Criatura estática integrada en el escenario.
##
## Avisa cuando el jugador entra en su radio de aviso y en su radio letal. No
## persigue: respira, y mientras el jugador está en su radio de aviso se inclina
## hacia él y le mira. Al acertar la ronda se retira: deja de avisar y de matar
## y se desvanece.

signal player_entered_danger
signal player_entered_warning
signal player_exited_warning

const BREATH_SPEED := 1.6
const BREATH_DEPTH := 0.012
const LEAN_ANGLE := 0.05
const LEAN_SPEED := 0.5
const EYE_LOOK_SHIFT := 1.6
const EYE_CALM := Color(0.95, 0.86, 0.6, 1)
const EYE_ALERT := Color(1.0, 0.78, 0.4, 1)

@onready var _danger_area: Area2D = $DangerArea
@onready var _warn_area: Area2D = $WarnArea
@onready var _body_shape: CollisionShape2D = $Body/CollisionShape2D
@onready var _sprite: Sprite2D = $Sprite2D
@onready var _eyes: Array[Sprite2D] = [$Sprite2D/OjoIzq, $Sprite2D/OjoDer]

var _retired := false
## El jugador mientras está dentro del radio de aviso (null si no lo está).
var _watched: Node2D = null
var _eye_home: Array[float] = []
var _base_scale := Vector2.ONE
var _breath_phase := 0.0


func _ready() -> void:
	_danger_area.body_entered.connect(_on_danger_body_entered)
	_warn_area.body_entered.connect(_on_warn_body_entered)
	_warn_area.body_exited.connect(_on_warn_body_exited)
	_base_scale = _sprite.scale
	for eye in _eyes:
		_eye_home.append(eye.position.x)
	_breath_phase = randf() * TAU


func _process(delta: float) -> void:
	if _retired:
		return
	_breath_phase += delta * BREATH_SPEED
	_sprite.scale = Vector2(_base_scale.x, _base_scale.y * (1.0 + sin(_breath_phase) * BREATH_DEPTH))
	var direction := _direction_to_watched()
	_sprite.rotation = move_toward(_sprite.rotation, direction * LEAN_ANGLE, delta * LEAN_SPEED)
	for i in range(_eyes.size()):
		_eyes[i].position.x = _eye_home[i] + direction * EYE_LOOK_SHIFT / _base_scale.x
		_eyes[i].modulate = _eyes[i].modulate.lerp(EYE_ALERT if direction != 0.0 else EYE_CALM, delta * 4.0)


## -1 si el jugador está a la izquierda, 1 a la derecha y 0 si no mira a nadie.
func _direction_to_watched() -> float:
	if _watched == null or not is_instance_valid(_watched):
		return 0.0
	return signf(_watched.global_position.x - global_position.x)


## Deja de ser una amenaza y se desvanece en `fade_time` segundos.
func retire(fade_time: float) -> void:
	_retired = true
	_watched = null
	_danger_area.set_deferred("monitoring", false)
	_warn_area.set_deferred("monitoring", false)
	_body_shape.set_deferred("disabled", true)
	if fade_time <= 0.0:
		visible = false
		return
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_time)
	tween.tween_callback(hide)


func is_retired() -> bool:
	return _retired


func _on_danger_body_entered(_body: Node2D) -> void:
	if not _retired:
		player_entered_danger.emit()


func _on_warn_body_entered(body: Node2D) -> void:
	if not _retired:
		_watched = body
		player_entered_warning.emit()


func _on_warn_body_exited(_body: Node2D) -> void:
	if not _retired:
		_watched = null
		player_exited_warning.emit()