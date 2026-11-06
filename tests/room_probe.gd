extends RefCounted

## Mide la habitación con las formas de colisión reales: qué suelo alcanza el
## jugador, a qué distancia queda su cuerpo de un círculo de peligro y qué
## objeto inspeccionaría desde un punto. Lo usan las pruebas de los Testigos.

const GRID_STEP := 8
const WORLD_SIZE := Vector2i(1280, 768)

var _space: PhysicsDirectSpaceState2D
var _body_shape: Shape2D
var _body_offset: Vector2
var _body_mask: int
var _reach_radius: float
var _reach_offset: Vector2
var _interactables: Array[Interactable] = []
var _reachable: Dictionary = {}


## `player` es una instancia de player.tscn (puede estar fuera del árbol).
func _init(room: Room, player: Player) -> void:
	_space = room.get_world_2d().direct_space_state
	var body := player.get_node("CollisionShape2D") as CollisionShape2D
	_body_shape = body.shape
	_body_offset = body.position
	_body_mask = player.collision_mask
	var reach := player.get_node("InteractionArea/CollisionShape2D") as CollisionShape2D
	_reach_radius = (reach.shape as CircleShape2D).radius
	_reach_offset = reach.position
	for node in room.find_children("*", "Interactable", true, false):
		if (node as Interactable).is_active():
			_interactables.append(node as Interactable)


## ¿Cabe el cuerpo del jugador en esa posición sin chocar con nada?
func is_free(position: Vector2) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _body_shape
	query.transform = Transform2D(0.0, position + _body_offset)
	query.collision_mask = _body_mask
	return _space.intersect_shape(query, 1).is_empty()


## Rellena el suelo alcanzable caminando desde `start`.
func flood_from(start: Vector2) -> void:
	_reachable.clear()
	var origin := Vector2i(start / GRID_STEP)
	var pending: Array[Vector2i] = [origin]
	_reachable[origin] = true
	while not pending.is_empty():
		var cell: Vector2i = pending.pop_back()
		for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + step
			if _reachable.has(next) or not _inside_world(next):
				continue
			if is_free(Vector2(next * GRID_STEP)):
				_reachable[next] = true
				pending.append(next)


func is_reachable(position: Vector2) -> bool:
	return _reachable.has(Vector2i(position / GRID_STEP))


func reachable_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for cell in _reachable.keys():
		positions.append(Vector2(cell * GRID_STEP))
	return positions


## Distancia desde `point` al rectángulo del cuerpo del jugador en `position`.
func body_distance(point: Vector2, position: Vector2) -> float:
	var rect := _body_rect(position)
	var closest := Vector2(clampf(point.x, rect.position.x, rect.end.x), clampf(point.y, rect.position.y, rect.end.y))
	return point.distance_to(closest)


## Objeto que el jugador inspeccionaría desde `position` (mismo criterio que Player).
func interactable_at(position: Vector2) -> Interactable:
	var best: Interactable = null
	var best_distance := INF
	var reach_center := position + _reach_offset
	for interactable in _interactables:
		if reach_center.distance_to(interactable.global_position) > _reach_radius + _zone_radius(interactable):
			continue
		var distance := position.distance_to(interactable.global_position)
		if distance < best_distance:
			best_distance = distance
			best = interactable
	return best


func zone_radius(interactable: Interactable) -> float:
	return _zone_radius(interactable)


func _zone_radius(interactable: Interactable) -> float:
	var shape := interactable.get_node("CollisionShape2D") as CollisionShape2D
	return (shape.shape as CircleShape2D).radius


func _body_rect(position: Vector2) -> Rect2:
	var size := (_body_shape as RectangleShape2D).size
	return Rect2(position + _body_offset - size / 2.0, size)


func _inside_world(cell: Vector2i) -> bool:
	var point := cell * GRID_STEP
	return point.x >= 0 and point.y >= 0 and point.x < WORLD_SIZE.x and point.y < WORLD_SIZE.y