class_name MemorySpot
extends Node2D

## Lo que la habitación necesita mientras un recuerdo de objeto está disponible:
## un brillo suave que late sobre el objeto y un punto de interacción (el del
## propio objeto o uno temporal si no tiene). Al liberarlo todo queda como estaba.

const GLOW_COLOR := Color(1.0, 0.9, 0.68, 0.55)
const GLOW_RADIUS := 34.0
const GLOW_MIN_ALPHA := 0.25
const GLOW_PULSE_TIME := 1.1
const OWN_RADIUS := 52.0
const INTERACTABLE_LAYER := 4
const PRIORITY := 1

var memory: ObjectMemory
var interactable: Interactable
var _reused: bool = false
var _saved_verb: String = ""
var _saved_priority: int = 0


func setup(world: Node2D, offered: ObjectMemory, verb: String) -> void:
	memory = offered
	name = "Recuerdo"
	world.add_child(self)
	var target := world.get_node_or_null(offered.object_node) as Node2D
	var existing := target.get_node_or_null("Interactable") as Interactable if target != null else null
	if existing != null and existing.is_active():
		_reuse(existing, verb)
	else:
		_create_own(verb)
	_add_glow(_glow_position(target))


func release() -> void:
	if _reused and is_instance_valid(interactable):
		interactable.prompt_verb = _saved_verb
		interactable.pick_priority = _saved_priority
	elif is_instance_valid(interactable):
		interactable.visible = false
	visible = false
	if get_parent() != null:
		get_parent().remove_child(self)
	queue_free()


func _reuse(existing: Interactable, verb: String) -> void:
	_reused = true
	interactable = existing
	_saved_verb = existing.prompt_verb
	_saved_priority = existing.pick_priority
	existing.prompt_verb = verb
	existing.pick_priority = PRIORITY


func _create_own(verb: String) -> void:
	interactable = Interactable.new()
	interactable.display_name = memory.object_name
	interactable.prompt_verb = verb
	interactable.pick_priority = PRIORITY
	interactable.collision_layer = INTERACTABLE_LAYER
	interactable.collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = OWN_RADIUS
	shape.shape = circle
	interactable.add_child(shape)
	add_child(interactable)
	interactable.global_position = memory.interact_position


## Sobre el objeto si se ve; si no (la silla que falta), donde estaba.
func _glow_position(target: Node2D) -> Vector2:
	if target != null and target.is_visible_in_tree():
		return target.global_position
	return memory.interact_position


func _add_glow(at: Vector2) -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, GLOW_COLOR)
	gradient.set_color(1, Color(GLOW_COLOR, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = int(GLOW_RADIUS * 2.0)
	texture.height = int(GLOW_RADIUS * 2.0)
	var glow := Sprite2D.new()
	glow.name = "Brillo"
	glow.texture = texture
	glow.z_index = 4
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = additive
	add_child(glow)
	glow.global_position = at
	var pulse := glow.create_tween().set_loops()
	pulse.tween_property(glow, "modulate:a", GLOW_MIN_ALPHA, GLOW_PULSE_TIME).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(glow, "modulate:a", 1.0, GLOW_PULSE_TIME).set_trans(Tween.TRANS_SINE)
