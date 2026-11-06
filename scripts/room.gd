class_name Room
extends Node2D

## La habitación explorable.
##
## Contiene el mapa (suelo, paredes y muebles con colisiones), los objetos
## interactivos y los anclajes de anomalía. Sabe restablecerse a su estado
## normal y aplicar una anomalía concreta modificando objetos reales de la
## escena, además de instanciar la criatura correspondiente si la hay.

signal monster_entered_danger
signal monster_entered_warning
signal monster_warning_cleared

const DOOR_ACTION := "door_continue"
const ENTITY_GROUP := &"entidades"
const DOOR_NAME := "Puerta"
const REFERENCE_DOOR_MESSAGE := "La puerta está entreabierta. Cuando quieras, empieza a observar de verdad la habitación."
const OPEN_DOOR_MESSAGE := "La puerta se ha abierto. Al otro lado te espera la siguiente habitación."
const LOCKED_DOOR_MESSAGE := "La puerta está bloqueada mientras no tomes una decisión."
const CROSS_BUTTON_TEXT := "CRUZAR LA PUERTA"
const DOOR_LIGHT_FADE := 0.5

@onready var _world: Node2D = $World
@onready var _door_interactable: Interactable = $World/Door/Interactable
@onready var _door_lights: Array[CanvasItem] = [$World/Door/LightSlit, $World/Door/LightSpill]

var _monster: Monster = null
var _defaults: Dictionary = {}
var _ambience: EntityAmbience
## Recuerdo de objeto disponible ahora mismo (null si no hay).
var _memory_spot: MemorySpot = null


func _ready() -> void:
	_capture_defaults(_world)
	_ambience = EntityAmbience.new()
	_ambience.name = "Ambience"
	add_child(_ambience)
	_ambience.setup(_world)


## Guarda el estado inicial de todos los nodos 2D para poder restaurarlo.
func _capture_defaults(node: Node) -> void:
	for child in node.get_children():
		if child is Player:
			continue
		if child is Node2D:
			var n2d := child as Node2D
			var data := {
				"visible": n2d.visible,
				"rotation": n2d.rotation,
				"position": n2d.position,
				"scale": n2d.scale,
			}
			if child is CanvasItem:
				data["modulate"] = (child as CanvasItem).modulate
			if child is Sprite2D:
				var sprite := child as Sprite2D
				data["texture"] = sprite.texture
				data["flip_h"] = sprite.flip_h
			if child is CollisionShape2D:
				data["disabled"] = (child as CollisionShape2D).disabled
			_defaults[child] = data
		_capture_defaults(child)


## Devuelve la habitación a su estado normal (sin anomalías ni criaturas).
func reset() -> void:
	take_memory()
	if _ambience != null:
		_ambience.stop()
	if _monster != null and is_instance_valid(_monster):
		_monster.queue_free()
	_monster = null
	for node in _defaults.keys():
		if not is_instance_valid(node):
			continue
		var n2d := node as Node2D
		var data: Dictionary = _defaults[node]
		n2d.visible = data["visible"]
		n2d.rotation = data["rotation"]
		n2d.position = data["position"]
		n2d.scale = data["scale"]
		if node is CanvasItem and data.has("modulate"):
			(node as CanvasItem).modulate = data["modulate"]
		if node is Sprite2D and data.has("texture"):
			var sprite := node as Sprite2D
			sprite.texture = data["texture"]
			sprite.flip_h = data["flip_h"]
		if node is CollisionShape2D and data.has("disabled"):
			(node as CollisionShape2D).disabled = data["disabled"]


## Aplica una anomalía: modifica objetos y, si procede, añade una criatura.
func apply_anomaly(anomaly: AnomalyData) -> void:
	for modification in anomaly.modifications:
		if modification is AnomalyModification:
			_apply_modification(modification as AnomalyModification)
	if anomaly.monster_scene != null:
		_spawn_monster(anomaly.monster_scene, get_monster_spawn(anomaly.monster_spawn_index))
	_ambience.start(anomaly.ambience)


func _apply_modification(modification: AnomalyModification) -> void:
	var node := _world.get_node_or_null(NodePath(modification.target_node))
	if node == null:
		push_warning("Anomalía: no se encontró el nodo '%s'." % modification.target_node)
		return
	match modification.mode:
		AnomalyModification.Mode.ROTATE:
			if node is Node2D:
				(node as Node2D).rotation_degrees = modification.rotation_degrees
		AnomalyModification.Mode.SET_TEXTURE:
			if node is Sprite2D:
				(node as Sprite2D).texture = modification.texture
		AnomalyModification.Mode.SHOW:
			if node is CanvasItem:
				(node as CanvasItem).visible = true
		AnomalyModification.Mode.HIDE:
			if node is CanvasItem:
				(node as CanvasItem).visible = false
		AnomalyModification.Mode.SET_POSITION:
			if node is Node2D:
				(node as Node2D).position = modification.position
		AnomalyModification.Mode.SET_MODULATE:
			if node is CanvasItem:
				(node as CanvasItem).modulate = modification.color
		AnomalyModification.Mode.SET_SCALE:
			if node is Node2D:
				(node as Node2D).scale = modification.scale
		AnomalyModification.Mode.SET_FLIP_H:
			if node is Sprite2D:
				(node as Sprite2D).flip_h = modification.flip
		AnomalyModification.Mode.SET_COLLISION_DISABLED:
			if node is CollisionShape2D:
				(node as CollisionShape2D).disabled = true


## El aviso de la criatura llega a la interfaz y al entorno a la vez.
func _on_monster_warning(active: bool) -> void:
	_ambience.set_alert(active)
	if active:
		monster_entered_warning.emit()
	else:
		monster_warning_cleared.emit()


func _spawn_monster(scene: PackedScene, spawn_position: Vector2) -> void:
	var instance := scene.instantiate()
	if instance is Monster:
		_monster = instance as Monster
		_monster.position = spawn_position
		_world.add_child(_monster)
		_monster.player_entered_danger.connect(func() -> void: monster_entered_danger.emit())
		_monster.player_entered_warning.connect(_on_monster_warning.bind(true))
		_monster.player_exited_warning.connect(_on_monster_warning.bind(false))
	else:
		push_warning("monster_scene no contiene un Monster.")
		instance.queue_free()

# ---------------------------------------------------------------------------
# Consultas sobre la habitación
# ---------------------------------------------------------------------------

## Posición donde aparece el jugador al entrar en la habitación.
func get_player_spawn() -> Vector2:
	return _marker_position("PlayerSpawn", Vector2(640, 380))


## Posición del punto de aparición de criatura indicado por la anomalía.
func get_monster_spawn(index: int) -> Vector2:
	return _marker_position("MonsterSpawn%d" % index, get_player_spawn())


func _marker_position(marker_name: String, fallback: Vector2) -> Vector2:
	var node := _world.get_node_or_null(NodePath(marker_name))
	if node is Node2D:
		return (node as Node2D).position
	return fallback


## ¿Esta habitación contiene todos los objetos que la anomalía necesita?
## Es lo que permite reutilizar una misma anomalía en varias habitaciones:
## solo se ofrece en las que tienen los objetos implicados.
func can_apply(anomaly: AnomalyData) -> bool:
	if anomaly == null:
		return false
	for modification in anomaly.modifications:
		if modification is AnomalyModification:
			var target: String = (modification as AnomalyModification).target_node
			if _world.get_node_or_null(NodePath(target)) == null:
				return false
	return true


func get_monster() -> Monster:
	return _monster if is_instance_valid(_monster) else null

# ---------------------------------------------------------------------------
# Puerta y amenazas
# ---------------------------------------------------------------------------

## La referencia empieza con la puerta abierta; las rondas de decisión, cerrada.
func configure_door(is_reference: bool) -> void:
	if is_reference:
		unlock_door(REFERENCE_DOOR_MESSAGE)
	else:
		lock_door()


func lock_door() -> void:
	_set_door("Examinar", LOCKED_DOOR_MESSAGE, "", "")
	for light in _door_lights:
		light.visible = false


func unlock_door(message: String = OPEN_DOOR_MESSAGE) -> void:
	_set_door("Cruzar", message, DOOR_ACTION, CROSS_BUTTON_TEXT)
	for light in _door_lights:
		_fade_in(light)


## Deja disponible un recuerdo en su objeto (brillo y punto de interacción).
func offer_memory(memory: ObjectMemory, verb: String) -> void:
	take_memory()
	_memory_spot = MemorySpot.new()
	_memory_spot.setup(_world, memory, verb)


func has_memory_offer() -> bool:
	return _memory_spot != null


## El recuerdo que guarda `interactable`, o null.
func memory_for(interactable: Interactable) -> ObjectMemory:
	if _memory_spot == null or interactable == null or interactable != _memory_spot.interactable:
		return null
	return _memory_spot.memory


func memory_spot() -> MemorySpot:
	return _memory_spot


## Retira el recuerdo disponible (leído o no) y devuelve el objeto a su estado normal.
func take_memory() -> ObjectMemory:
	if _memory_spot == null:
		return null
	var memory := _memory_spot.memory
	_memory_spot.release()
	_memory_spot = null
	return memory


func stop_ambience() -> void:
	_ambience.stop()


func set_ambience_paused(paused: bool) -> void:
	_ambience.set_paused(paused)


func ambience() -> EntityAmbience:
	return _ambience


func is_door_unlocked() -> bool:
	return _door_interactable.action_id == DOOR_ACTION


func is_locked_door(interactable: Interactable) -> bool:
	return interactable == _door_interactable and not is_door_unlocked()


## Las entidades dejan de amenazar y se desvanecen en `fade_time` segundos.
func retire_threats(fade_time: float) -> void:
	_ambience.stop()
	if get_monster() != null:
		_monster.retire(fade_time)
	for node in _world.find_children("*", "CanvasItem", true, false):
		if node.is_in_group(ENTITY_GROUP) and (node as CanvasItem).visible:
			_fade_out(node as CanvasItem, fade_time)


func _set_door(verb: String, message: String, action_id: String, button_text: String) -> void:
	_door_interactable.display_name = DOOR_NAME
	_door_interactable.prompt_verb = verb
	_door_interactable.message = message
	_door_interactable.action_id = action_id
	_door_interactable.action_button_text = button_text


func _fade_in(item: CanvasItem) -> void:
	if item.visible:
		return
	var target_alpha := item.modulate.a
	item.modulate.a = 0.0
	item.visible = true
	create_tween().tween_property(item, "modulate:a", target_alpha, DOOR_LIGHT_FADE)


func _fade_out(item: CanvasItem, fade_time: float) -> void:
	if fade_time <= 0.0:
		item.visible = false
		return
	var tween := create_tween()
	tween.tween_property(item, "modulate:a", 0.0, fade_time)
	tween.tween_callback(item.hide)