class_name Player
extends CharacterBody2D

## Protagonista controlable.
##
## Movimiento en ocho direcciones con vector normalizado, colisiones reales
## contra paredes y muebles, animaciones idle/walk por dirección y detección
## del objeto interactivo más cercano.

signal interactable_changed(interactable: Interactable)
## Un pie toca el suelo (fotogramas de apoyo de la animación de caminar).
signal footstep

const WALK_PREFIX := "walk_"
const STEP_FRAMES: Array[int] = [0, 2]

@export var speed: float = 190.0

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _interaction_area: Area2D = $InteractionArea

## Si es falso, el personaje no responde al movimiento (mensajes, pausa...).
var can_move: bool = true

var _facing: String = "down"
var _current_interactable: Interactable = null

func _ready() -> void:
	_sprite.frame_changed.connect(_on_frame_changed)

func _on_frame_changed() -> void:
	if String(_sprite.animation).begins_with(WALK_PREFIX) and _sprite.frame in STEP_FRAMES:
		footstep.emit()

func _physics_process(_delta: float) -> void:
	var direction := Vector2.ZERO
	if can_move:
		# Input.get_vector ya normaliza las diagonales y aplica el deadzone.
		direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_update_animation(direction)
	velocity = direction * speed
	move_and_slide()
	_update_nearest_interactable()

func _update_animation(direction: Vector2) -> void:
	if not can_move or direction == Vector2.ZERO:
		if _sprite.animation != "idle_" + _facing:
			_sprite.play("idle_" + _facing)
		return
	if absf(direction.x) > absf(direction.y):
		_facing = "side"
		_sprite.flip_h = direction.x < 0.0
	else:
		_facing = "up" if direction.y < 0.0 else "down"
		_sprite.flip_h = false
	var walk_anim := "walk_" + _facing
	if _sprite.animation != walk_anim:
		_sprite.play(walk_anim)

func _update_nearest_interactable() -> void:
	var best: Interactable = null
	var best_distance := INF
	for area in _interaction_area.get_overlapping_areas():
		var candidate := area as Interactable
		if candidate == null or not candidate.is_active():
			continue
		var distance := global_position.distance_to(candidate.global_position)
		if best == null or candidate.pick_priority > best.pick_priority or (candidate.pick_priority == best.pick_priority and distance < best_distance):
			best_distance = distance
			best = candidate
	if best != _current_interactable:
		_current_interactable = best
		interactable_changed.emit(_current_interactable)

## El objeto interactivo más cercano, o null.
func get_interactable() -> Interactable:
	return _current_interactable

## Orienta al personaje hacia un punto (se usa al interactuar).
func face_towards(point: Vector2) -> void:
	var to_point := point - global_position
	if absf(to_point.x) > absf(to_point.y):
		_facing = "side"
		_sprite.flip_h = to_point.x < 0.0
	else:
		_facing = "up" if to_point.y < 0.0 else "down"
		_sprite.flip_h = false
	_sprite.play("idle_" + _facing)

## Restablece el estado visual y de movimiento.
func reset_state() -> void:
	velocity = Vector2.ZERO
	_facing = "down"
	_sprite.flip_h = false
	_sprite.play("idle_down")
	_current_interactable = null
	interactable_changed.emit(null)
