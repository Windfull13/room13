extends SceneTree

## Aplica la composición de la habitación base sobre scenes/rooms/room_base.tscn.
##
##   godot --headless --path . --script res://dev/build_room_layout.gd
##
## La habitación es una sola pantalla compacta: pared del fondo alta (3 filas
## de 64 px), suelo de 11×6 baldosas, paredes laterales y frontal de una fila.
## Todo lo que cuelga de una pared se coloca sobre ella; los muebles apoyan su
## base (el origen del nodo) en el suelo. Los tamaños salen de lo que dibuja
## cada sprite (los PNG tienen márgenes transparentes), no del tamaño del
## archivo. Los números de abajo son la única fuente de verdad de la
## distribución.

const SCENE_PATH := "res://scenes/rooms/room_base.tscn"
const WHITE := preload("res://assets/generated/px_white.png")
const SPRITES := "res://assets/generated/"
const WALL_ORIGIN := Vector2(224, 24)
const FLOOR_ORIGIN := Vector2(288, 216)
const FLOOR_CELLS := Vector2i(11, 6)
const WALL_CELLS := Vector2i(13, 10)
const BACK_WALL_ROWS := 3
const FURNITURE_SCALE := 1.3
const CHAIR_SCALE := 1.25
## Un armario frontal no enseña su tapa: sus pies quedan casi pegados a la pared.
const WARDROBE_BASE_Y := 262.0
const WINDOW_SCALE := 1.7
const ENTITY_GROUP := &"entidades"
const NOTE_SCALE := 0.45
const OLD_ENTITIES: Array[String] = ["WindowFigure", "WardrobeFigure", "UnderBedFigure", "Figure2"]
const MEMORIES := {
	"Photograph": "Una fotografía enmarcada: los tres sonreís bajo el sol, antes de uno de aquellos viajes largos. Ella te agarra del brazo; la niña le saca la lengua a la cámara.",
	"Book": "Un cuento infantil con la esquina doblada. Lo leías en voz alta cada noche; ella se dormía antes del final y tú lo terminabas igual.",
	"Phone": "El teléfono de casa. Hay mensajes guardados que no te atreves a escuchar, y uno que no borrarías por nada del mundo.",
	"Window": "Fuera llueve sin ruido. A lo lejos, los faros de la carretera dibujan líneas en el cristal.",
	"Desk": "El escritorio donde solías escribir. En un cajón siguen los dibujos de colores que te dejaban encima del teclado para que no trabajaras tanto.",
}
const SHADING_NODES: Array[String] = ["WallBase", "WallBaseLight", "WallShadowNear", "WallShadowFar", "SideShadowLeft", "SideShadowRight", "FrontShadow"]

var _room: Node2D
var _world: Node2D


func _init() -> void:
	await process_frame
	_room = (load(SCENE_PATH) as PackedScene).instantiate()
	root.add_child(_room)
	_world = _room.get_node("World")
	_build_shell()
	_place_furniture()
	_place_wall_items()
	_place_small_items()
	_place_anomaly_objects()
	_place_hidden_things()
	_write_memories()
	_place_markers()
	_save()
	quit()

# ---------------------------------------------------------------------------
# Estructura: suelo, paredes y sombras
# ---------------------------------------------------------------------------

func _build_shell() -> void:
	var floor_layer := _world.get_node("Floor") as TileMapLayer
	var wall_layer := _world.get_node("Walls") as TileMapLayer
	floor_layer.position = FLOOR_ORIGIN
	wall_layer.position = WALL_ORIGIN
	floor_layer.clear()
	wall_layer.clear()
	for x in range(FLOOR_CELLS.x):
		for y in range(FLOOR_CELLS.y):
			floor_layer.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
	for x in range(WALL_CELLS.x):
		for y in range(WALL_CELLS.y):
			if _is_wall_cell(x, y):
				wall_layer.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
	_add_shading()


func _is_wall_cell(x: int, y: int) -> bool:
	var is_back := y < BACK_WALL_ROWS
	var is_front := y == WALL_CELLS.y - 1
	var is_side := x == 0 or x == WALL_CELLS.x - 1
	return is_back or is_front or is_side


func _add_shading() -> void:
	for node_name in SHADING_NODES:
		_remove_child(_world, node_name)
	var floor_rect := Rect2(FLOOR_ORIGIN, Vector2(FLOOR_CELLS) * 64.0)
	_strip("WallBase", Rect2(floor_rect.position.x, 198, floor_rect.size.x, 18), Color(0.17, 0.11, 0.09, 1.0), -15)
	_strip("WallBaseLight", Rect2(floor_rect.position.x, 198, floor_rect.size.x, 3), Color(0.30, 0.21, 0.16, 1.0), -15)
	_strip("WallShadowNear", Rect2(floor_rect.position.x, 216, floor_rect.size.x, 14), Color(0, 0, 0, 0.34), -14)
	_strip("WallShadowFar", Rect2(floor_rect.position.x, 230, floor_rect.size.x, 12), Color(0, 0, 0, 0.14), -14)
	_strip("SideShadowLeft", Rect2(floor_rect.position.x, 216, 12, floor_rect.size.y), Color(0, 0, 0, 0.22), -14)
	_strip("SideShadowRight", Rect2(floor_rect.end.x - 12, 216, 12, floor_rect.size.y), Color(0, 0, 0, 0.22), -14)
	_strip("FrontShadow", Rect2(floor_rect.position.x, floor_rect.end.y - 16, floor_rect.size.x, 16), Color(0, 0, 0, 0.26), -14)


func _strip(node_name: String, rect: Rect2, color: Color, z: int) -> void:
	var strip := _make_strip(node_name, rect, color)
	strip.z_index = z
	_world.add_child(strip)
	_adopt(strip)


func _make_strip(node_name: String, rect: Rect2, color: Color) -> Sprite2D:
	var strip := Sprite2D.new()
	strip.name = node_name
	strip.texture = WHITE
	strip.position = rect.get_center()
	strip.scale = rect.size / Vector2(WHITE.get_size())
	strip.modulate = color
	return strip

# ---------------------------------------------------------------------------
# Muebles: apoyados en el suelo y contra la pared del fondo
# ---------------------------------------------------------------------------

func _place_furniture() -> void:
	_body("Bed", Vector2(348, 322), FURNITURE_SCALE, Vector2(112, 92), "")
	_body("Wardrobe", Vector2(472, WARDROBE_BASE_Y), FURNITURE_SCALE, Vector2(58, 46), "")
	_body("Desk", Vector2(805, 316), FURNITURE_SCALE, Vector2(132, 90), "px_desk_clear.png")
	_body("Chair", Vector2(805, 392), CHAIR_SCALE, Vector2(36, 24), "px_chair_back.png")
	_body("Door", Vector2(605, 224), FURNITURE_SCALE, Vector2(80, 16), "px_door_wall.png")
	_zone("Bed/Interactable", Vector2(348, 309), 62)
	_zone("Wardrobe/Interactable", Vector2(472, WARDROBE_BASE_Y + 22), 56)
	_zone("Desk/Interactable", Vector2(738, 340), 34)
	_zone("Chair/Interactable", Vector2(805, 379), 44)
	_zone("Door/Interactable", Vector2(605, 237), 80)
	_place_door_light()
	_place_rug()
	_place_plant()
	_place_mirror()
	_place_toy()


## Un mueble: su origen es el punto de apoyo en el suelo, el sprite crece hacia
## arriba y la colisión cubre solo la huella (la profundidad contra la pared).
func _body(node_name: String, origin: Vector2, sprite_scale: float, footprint: Vector2, texture_file: String) -> void:
	var body := _world.get_node(node_name) as Node2D
	body.position = origin
	var sprite := body.get_node("Sprite") as Sprite2D
	if not texture_file.is_empty():
		sprite.texture = load(SPRITES + texture_file)
	sprite.scale = Vector2.ONE * sprite_scale
	sprite.position = Vector2(0, -sprite.texture.get_height() * sprite_scale / 2.0)
	var collision := body.get_node("CollisionShape2D") as CollisionShape2D
	(collision.shape as RectangleShape2D).size = footprint
	collision.position = Vector2(0, -footprint.y / 2.0)


func _place_door_light() -> void:
	var door := _world.get_node("Door")
	var slit := door.get_node("LightSlit") as Sprite2D
	slit.position = Vector2(24, -66)
	slit.scale = Vector2(0.5, 14.5)
	var spill := door.get_node("LightSpill") as Sprite2D
	spill.position = Vector2(0, 12)
	spill.scale = Vector2(10, 2.2)


func _place_rug() -> void:
	var rug := _world.get_node("Rug") as Node2D
	rug.position = Vector2(640, 455)
	rug.z_index = -10
	var sprite := rug.get_node("Sprite") as Sprite2D
	sprite.scale = Vector2.ONE * 1.6
	sprite.position = Vector2.ZERO


func _place_plant() -> void:
	var plant := _world.get_node("Plant") as Sprite2D
	plant.position = Vector2(950, 552)
	plant.scale = Vector2.ONE * 1.2
	_attach_collider(plant, Vector2(0, 26), Vector2(26, 10))


func _place_mirror() -> void:
	var mirror := _world.get_node("Mirror") as Sprite2D
	mirror.position = Vector2(324, 490)
	mirror.scale = Vector2.ONE * 1.2
	_attach_collider(mirror, Vector2(0, 30), Vector2(36, 10))
	_zone("Mirror/Interactable", Vector2(388, 512), 52)


func _place_toy() -> void:
	var toy := _world.get_node("Toy") as Node2D
	toy.position = Vector2(448, 440)
	var sprite := toy.get_node("Sprite") as Sprite2D
	sprite.scale = Vector2.ONE * 0.75
	sprite.position = Vector2(0, -24)
	_zone("Toy/Interactable", Vector2(448, 428), 46)


## Colisión de base para un objeto de suelo que no la tenía. Cuelga del sprite:
## si una anomalía lo gira, la colisión gira con él.
func _attach_collider(sprite: Sprite2D, local_position: Vector2, world_size: Vector2) -> void:
	_remove_child(sprite, "Collider")
	var body := StaticBody2D.new()
	body.name = "Collider"
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var rect := RectangleShape2D.new()
	rect.size = world_size / sprite.scale.x
	shape.shape = rect
	shape.position = local_position
	body.add_child(shape)
	sprite.add_child(body)
	_adopt(body)

# ---------------------------------------------------------------------------
# Objetos colgados de la pared
# ---------------------------------------------------------------------------

func _place_wall_items() -> void:
	_place_window()
	var clock := _world.get_node("Clock") as Node2D
	clock.position = Vector2(692, 138)
	var clock_sprite := clock.get_node("Sprite") as Sprite2D
	clock_sprite.scale = Vector2.ONE * 1.1
	clock_sprite.position = Vector2(0, -26.4)
	_zone("Clock/Interactable", Vector2(692, 208), 46)
	_put("Drawing", Vector2(472, 100), 1.2)
	_put("WifePhoto", Vector2(348, 112), 1.2)
	_put("Handprint", Vector2(620, 172), 1.0)


func _place_window() -> void:
	var window := _world.get_node("Window") as Node2D
	window.position = Vector2(931, 152)
	var sprite := window.get_node("Sprite") as Sprite2D
	sprite.scale = Vector2.ONE * WINDOW_SCALE
	sprite.position = Vector2(0, -32.0 * WINDOW_SCALE)
	_remove_child(window, "CollisionShape2D")
	_remove_child(window, "Frame")
	_remove_child(window, "Sill")
	var frame := _make_strip("Frame", Rect2(-64, -115, 128, 119), Color(0.10, 0.07, 0.06, 1.0))
	window.add_child(frame)
	window.move_child(frame, 0)
	_adopt(frame)
	var sill := _make_strip("Sill", Rect2(-72, -1, 144, 9), Color(0.32, 0.25, 0.20, 1.0))
	window.add_child(sill)
	_adopt(sill)
	_zone("Window/Interactable", Vector2(931, 198), 56)

# ---------------------------------------------------------------------------
# Objetos pequeños: sobre el escritorio o en el suelo
# ---------------------------------------------------------------------------

func _place_small_items() -> void:
	_on_desk("Photograph", Vector2(762, 218), 0.55, -13.2, Vector2(766, 340))
	_on_desk("Book", Vector2(790, 224), 0.5, -12.0, Vector2(794, 340))
	_on_desk("Phone", Vector2(822, 214), 0.6, 0.0, Vector2(822, 340))
	var lamp := _world.get_node("Lamp") as Sprite2D
	lamp.position = Vector2(850, 187)
	lamp.scale = Vector2.ONE * 0.7
	lamp.z_index = 1
	_put("Letter", Vector2(800, 204), 0.7, 1)
	_put("Keys", Vector2(590, 505), 0.8)
	_put("Spider", Vector2(540, 540), 1.0)
	_put("Doll", Vector2(540, 430), 1.0)
	_put("Crow", Vector2(985, 146), 1.0, 1)


## Objetos que solo aparecen con una anomalía. Empiezan ocultos y cada uno está
## apoyado en el mueble que lo sostiene (o en el suelo, junto a la puerta).
func _place_anomaly_objects() -> void:
	_hidden_item(_world, "DeskGlass", "px_glass_c.png", Vector2(752, 230), 1.0, 0.0, 1)
	_hidden_item(_world, "DeskPlate", "px_plate.png", Vector2(777, 231), 1.0, 0.0, 1)
	_hidden_item(_world, "MusicBox", "px_musicbox.png", Vector2(853, 221), 1.0, 0.0, 1)
	_hidden_item(_world, "DoorNote1", "px_note.png", Vector2(545, 246), NOTE_SCALE, -12.0, 0)
	_hidden_item(_world, "DoorNote2", "px_note.png", Vector2(568, 258), NOTE_SCALE, 8.0, 0)
	_hidden_item(_world, "DoorNote3", "px_note.png", Vector2(648, 250), NOTE_SCALE, -6.0, 0)
	_hidden_item(_world.get_node("Mirror"), "Cover", "px_note.png", Vector2(4, -12), NOTE_SCALE * 1.2, 6.0, 1)
	_hidden_item(_world.get_node("Plant"), "Flower", "px_flower.png", Vector2(5, -20), 0.85, 0.0, 1)


func _hidden_item(parent: Node, node_name: String, texture_file: String, position: Vector2, sprite_scale: float, degrees: float, z: int) -> void:
	_remove_child(parent, node_name)
	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.texture = load(SPRITES + texture_file)
	sprite.position = position
	sprite.scale = Vector2.ONE * sprite_scale
	sprite.rotation_degrees = degrees
	sprite.z_index = z
	sprite.visible = false
	parent.add_child(sprite)
	_adopt(sprite)


## Objeto sobre el escritorio. Su zona de interacción está en el borde delantero
## del mueble, justo debajo del objeto: el jugador elige uno según dónde se pare.
func _on_desk(node_name: String, origin: Vector2, sprite_scale: float, sprite_y: float, zone_center: Vector2) -> void:
	var item := _world.get_node(node_name) as Node2D
	item.position = origin
	item.z_index = 1
	var sprite := item.get_node_or_null("Sprite") as Sprite2D
	if sprite != null:
		sprite.scale = Vector2.ONE * sprite_scale
		sprite.position = Vector2(0, sprite_y)
	else:
		item.scale = Vector2.ONE * sprite_scale
	_zone("%s/Interactable" % node_name, zone_center, 26)


func _put(node_name: String, center: Vector2, sprite_scale: float, z: int = 0) -> void:
	var item := _world.get_node(node_name) as Node2D
	item.position = center
	item.scale = Vector2.ONE * sprite_scale
	item.z_index = z

# ---------------------------------------------------------------------------
# Entidades escondidas y puntos de aparición
# ---------------------------------------------------------------------------

## Entidades escondidas. Cada una vive DENTRO del mueble que la oculta y solo
## enseña la parte que ese mueble permite; ninguna es el cuerpo completo de otra.
func _place_hidden_things() -> void:
	for old_name in OLD_ENTITIES:
		_remove_child(_world, old_name)
	_add_under_bed_hand()
	_add_wardrobe_crack()
	_add_window_face()
	_add_mirror_reflection()
	_world.get_node("Crow").add_to_group(ENTITY_GROUP, true)


## Mano bajo la cama: nace detrás de la cama (un y menor se dibuja antes) y solo
## asoma lo que cae por delante del somier.
func _add_under_bed_hand() -> void:
	var hand := _entity_sprite("UnderBedHand", "px_hand_under_bed.png", _world)
	hand.position = Vector2(348, 321)
	hand.offset = Vector2(0, 6)


## Rendija del armario: cuelga del propio armario, así que se ordena y vibra con él.
func _add_wardrobe_crack() -> void:
	var crack := _entity_sprite("Crack", "px_wardrobe_crack.png", _world.get_node("Wardrobe"))
	crack.scale = Vector2.ONE * FURNITURE_SCALE
	crack.position = Vector2(0, -80)


## Rostro tras el cristal: dentro del vidrio, con un velo encima y el marco alrededor.
func _add_window_face() -> void:
	var face := _entity_sprite("Face", "px_face_window.png", _world.get_node("Window"))
	face.position = Vector2(0, -62)
	face.scale = Vector2.ONE * 1.1
	face.modulate = Color(0.82, 0.9, 1.0, 0.9)
	var glass := _make_strip("Glass", Rect2(-26, -30, 52, 60), Color(0.7, 0.8, 1.0, 0.16))
	face.add_child(glass)
	_adopt(glass)


## Reflejo: hijo del espejo, más pequeño que su luna, así que no puede sobresalir.
func _add_mirror_reflection() -> void:
	var reflection := _entity_sprite("Reflection", "px_mirror_reflection.png", _world.get_node("Mirror"))
	reflection.position = Vector2(0, 4)
	reflection.scale = Vector2.ONE * 0.75
	reflection.modulate = Color(0.75, 0.82, 1.0, 0.8)


func _entity_sprite(node_name: String, texture_file: String, parent: Node) -> Sprite2D:
	_remove_child(parent, node_name)
	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.texture = load(SPRITES + texture_file)
	sprite.visible = false
	sprite.add_to_group(ENTITY_GROUP, true)
	parent.add_child(sprite)
	_adopt(sprite)
	return sprite


## Recuerdos que se leen en los objetos: cariño primero, y solo pistas sueltas
## de lo que pasó (la lluvia, la carretera). Nada confirma cómo ocurrió.
func _write_memories() -> void:
	for object_name: String in MEMORIES:
		var interactable := _world.get_node("%s/Interactable" % object_name)
		interactable.set("message", MEMORIES[object_name])


func _place_markers() -> void:
	(_world.get_node("PlayerSpawn") as Node2D).position = Vector2(640, 520)
	(_world.get_node("MonsterSpawn1") as Node2D).position = Vector2(870, 306)
	(_world.get_node("MonsterSpawn2") as Node2D).position = Vector2(406, 300)

# ---------------------------------------------------------------------------
# Ayudantes
# ---------------------------------------------------------------------------

## Zona de interacción: centro y radio en coordenadas del mundo, da igual la
## escala del padre.
func _zone(path: String, world_center: Vector2, world_radius: float) -> void:
	var interactable := _world.get_node(path) as Node2D
	interactable.global_position = world_center
	var shape := interactable.get_node("CollisionShape2D") as CollisionShape2D
	shape.position = Vector2.ZERO
	(shape.shape as CircleShape2D).radius = world_radius / interactable.global_transform.get_scale().x


func _remove_child(parent: Node, child_name: String) -> void:
	var child := parent.get_node_or_null(child_name)
	if child != null:
		parent.remove_child(child)
		child.free()


func _adopt(node: Node) -> void:
	node.owner = _room
	for child in node.get_children():
		_adopt(child)


func _save() -> void:
	root.remove_child(_room)
	var packed := PackedScene.new()
	assert(packed.pack(_room) == OK)
	print("room_base.tscn guardada: ", ResourceSaver.save(packed, SCENE_PATH) == OK)
	_room.free()