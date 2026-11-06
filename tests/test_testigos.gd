extends RefCounted

## Los Testigos son justos y las entidades se ven:
## - la muerte llega caminando hasta el Testigo, por su Area2D letal;
## - el escritorio y la cama se inspeccionan desde un punto alcanzable, fuera
##   del radio letal y dentro del de aviso;
## - cada entidad queda dentro de la pantalla, sin taparse con la HUD y con
##   alfa mayor que 0,5.

const Reporter := preload("res://tests/reporter.gd")
const GameDriver := preload("res://tests/game_driver.gd")
const Probe := preload("res://tests/room_probe.gd")
const TESTIGOS := ["testigo_cuarto", "testigo_esquina"]
## Peligrosas cuya amenaza no es un sprite de entidad (oscuridad, objetos).
const WITHOUT_ENTITY_SPRITE: Array[String] = ["oscuridad_total", "tres_senales"]
## Un velo (la oscuridad) más claro que esto no cuenta como mueble que tapa.
const OCCLUDER_MIN_ALPHA := 0.5
## Mueble junto al que espera cada Testigo: ahí el aviso debe saltar al inspeccionar.
const GUARDED := {"testigo_cuarto": "Escritorio", "testigo_esquina": "Cama"}
## Desde dónde se acerca el jugador al Testigo: el primer punto alcanzable.
const APPROACH_OFFSETS: Array[Vector2] = [Vector2(0, 110), Vector2(0, -110), Vector2(-110, 0), Vector2(110, 0)]
const WALK_FRAMES := 240
## Lo que la cámara enseña: 1280×720 con el borde superior en y = -16 (la
## habitación mide 640 de alto y queda centrada).
const VIEW_RECT := Rect2(0, -16, 1280, 720)
const MIN_ALPHA := 0.5
const MAX_HUD_COVER := 0.5
const MIN_UNCOVERED := 0.25
const PIXEL_STEP := 2

var _report: Reporter
var _driver: GameDriver


func run(report: Reporter, tree: SceneTree) -> void:
	report.start("Testigos: muerte física, inspección segura y visibilidad")
	_report = report
	_driver = GameDriver.new(tree)
	await _driver.boot()
	for id: String in TESTIGOS:
		await _check_walking_into_testigo_kills(GameDriver.load_anomaly(id))
		await _check_safe_inspection(GameDriver.load_anomaly(id))
	for anomaly: AnomalyData in CatalogLoader.load_all("res://resources/anomalies/", AnomalyData):
		if anomaly.jumpscare_scene != null and not WITHOUT_ENTITY_SPRITE.has(anomaly.id):
			await _check_entity_visibility(anomaly)
	await _driver.shutdown()


func _prepare_round(anomaly: AnomalyData) -> void:
	await _driver.restart()
	await _driver.enter_decision_room()
	await _driver.force_anomaly(anomaly)


# ---------------------------------------------------------------------------
# Muerte física
# ---------------------------------------------------------------------------

func _check_walking_into_testigo_kills(anomaly: AnomalyData) -> void:
	await _prepare_round(anomaly)
	var monster := _driver.room().get_monster()
	var hits := {"aviso": 0, "letal": 0}
	monster.player_entered_warning.connect(func() -> void: hits["aviso"] += 1)
	monster.player_entered_danger.connect(func() -> void: hits["letal"] += 1)
	_driver.manager._jumpscares.last_played_path = ""
	var offset := _approach_offset(monster)
	_report.check(offset != Vector2.INF, "%s: hay un lado por el que acercarse al Testigo" % anomaly.id)
	await _driver.teleport_player(monster.global_position + offset)
	_report.check(hits["aviso"] > 0 and hits["letal"] == 0, "%s: a %d px el aviso ya salta y aún no mata" % [anomaly.id, roundi(offset.length())])
	var direction := _direction_towards(offset)
	Input.action_press(direction)
	for i in range(WALK_FRAMES):
		await _driver.tree.physics_frame
		if hits["letal"] > 0:
			break
	Input.action_release(direction)
	_report.check(hits["letal"] > 0, "%s: caminar hasta el Testigo entra en su Area2D letal" % anomaly.id)
	_report.check(await _driver.await_state(GameManager.State.REFERENCIA), "%s: tras la muerte vuelve la referencia" % anomaly.id)
	_report.check(_driver.manager._jumpscares.last_played_path == anomaly.jumpscare_scene.resource_path, "%s: esa muerte reproduce su susto" % anomaly.id)


# ---------------------------------------------------------------------------
# Inspección segura
# ---------------------------------------------------------------------------

## Primer punto alcanzable a 110 px del Testigo, o INF si ninguno lo es.
func _approach_offset(monster: Monster) -> Vector2:
	var probe = Probe.new(_driver.room(), _driver.player())
	probe.flood_from(_driver.room().get_player_spawn())
	for offset in APPROACH_OFFSETS:
		if probe.is_reachable(monster.global_position + offset):
			return offset
	return Vector2.INF


## La acción de movimiento que lleva desde `offset` hasta el Testigo.
func _direction_towards(offset: Vector2) -> String:
	if absf(offset.y) >= absf(offset.x):
		return "move_up" if offset.y > 0.0 else "move_down"
	return "move_left" if offset.x > 0.0 else "move_right"


## Cada objeto interactuable de la habitación, con cada Testigo activo, se
## puede inspeccionar desde algún punto seguro.
func _check_safe_inspection(anomaly: AnomalyData) -> void:
	await _prepare_round(anomaly)
	for target: Interactable in _driver.room().find_children("*", "Interactable", true, false):
		if _driver.manager.state != GameManager.State.EXPLORACION:
			await _prepare_round(anomaly)
		var target_name := target.display_name
		var guarded: bool = GUARDED[anomaly.id] == target_name
		var spot := _safe_spot(target, guarded)
		var zone := "fuera del radio letal y dentro del de aviso" if guarded else "fuera del radio letal"
		_report.check(spot != Vector2.INF, "%s: hay un punto alcanzable para inspeccionar %s %s" % [anomaly.id, target_name, zone])
		if spot == Vector2.INF:
			continue
		await _driver.teleport_player(spot)
		_report.check(_driver.player().get_interactable() == target, "%s: desde %s se inspecciona %s" % [anomaly.id, spot, target_name])
		if guarded:
			_report.check(_driver.manager._hud._danger_label.visible, "%s: junto a %s salta el aviso de peligro" % [anomaly.id, target_name])
		_driver.manager._try_interact()
		var hud := _driver.manager._hud
		_report.check(_driver.manager.state == GameManager.State.MENSAJE and hud._message_name.text == target.display_name, "%s: E abre el mensaje de %s sin morir" % [anomaly.id, target_name])
		hud.close_message()
		_report.check(_driver.manager.state == GameManager.State.EXPLORACION, "%s: tras leer %s sigue la ronda" % [anomaly.id, target_name])


## Punto alcanzable dentro de la zona del objeto desde el que se inspecciona ese
## objeto con el cuerpo fuera del radio letal (y dentro del de aviso si
## `inside_warning`).
func _safe_spot(target: Interactable, inside_warning: bool) -> Vector2:
	var monster := _driver.room().get_monster()
	var danger := _circle(monster, "DangerArea")
	var warning := _circle(monster, "WarnArea")
	var probe = Probe.new(_driver.room(), _driver.player())
	probe.flood_from(_driver.room().get_player_spawn())
	var best := Vector2.INF
	var zone_radius: float = probe.zone_radius(target)
	for position: Vector2 in probe.reachable_positions():
		if position.distance_to(target.global_position) > zone_radius or probe.interactable_at(position) != target:
			continue
		var distance: float = probe.body_distance(danger.center, position)
		if distance <= danger.radius:
			continue
		if inside_warning and probe.body_distance(warning.center, position) >= warning.radius:
			continue
		if best == Vector2.INF or position.distance_to(target.global_position) < best.distance_to(target.global_position):
			best = position
	if best != Vector2.INF:
		print("    %s: punto %s, cuerpo a %.1f px del centro letal" % [target.display_name, best, probe.body_distance(danger.center, best)])
	return best


func _circle(monster: Monster, area_name: String) -> Dictionary:
	var shape := monster.get_node("%s/CollisionShape2D" % area_name) as CollisionShape2D
	return {"center": shape.global_position, "radius": (shape.shape as CircleShape2D).radius}


# ---------------------------------------------------------------------------
# Visibilidad
# ---------------------------------------------------------------------------

func _check_entity_visibility(anomaly: AnomalyData) -> void:
	await _prepare_round(anomaly)
	var sprites := _entity_sprites()
	_report.check(not sprites.is_empty(), "%s: hay una entidad visible" % anomaly.id)
	for sprite in sprites:
		var label := "%s/%s" % [anomaly.id, sprite.get_parent().name if sprite.get_parent() is Monster else sprite.name]
		var rect := sprite.get_global_transform() * sprite.get_rect()
		_report.check(VIEW_RECT.encloses(rect), "%s: entera dentro de la pantalla %s" % [label, rect])
		_report.check(_alpha(sprite) > MIN_ALPHA, "%s: alfa %.2f > %.1f" % [label, _alpha(sprite), MIN_ALPHA])
		var cover := _cover_fractions(sprite)
		print("    %s: visible %d %%, bajo la HUD %d %%" % [label, roundi(cover.visible * 100.0), roundi(cover.hud * 100.0)])
		_report.check(cover.hud <= MAX_HUD_COVER, "%s: la HUD tapa solo el %d %%" % [label, roundi(cover.hud * 100.0)])
		_report.check(cover.visible >= MIN_UNCOVERED, "%s: se ve el %d %% (escondida tras muebles, no oculta)" % [label, roundi(cover.visible * 100.0)])


func _entity_sprites() -> Array[Sprite2D]:
	var sprites: Array[Sprite2D] = []
	for node in _driver.room().get_node("World").find_children("*", "Sprite2D", true, false):
		if node.is_in_group(Room.ENTITY_GROUP) and (node as CanvasItem).visible:
			sprites.append(node as Sprite2D)
	var monster := _driver.room().get_monster()
	if monster != null:
		sprites.append(monster.get_node("Sprite2D") as Sprite2D)
	return sprites


func _alpha(sprite: Sprite2D) -> float:
	var alpha := sprite.self_modulate.a
	var node: Node = sprite
	while node is CanvasItem:
		alpha *= (node as CanvasItem).modulate.a
		node = node.get_parent()
	return alpha


## Fracción de píxeles opacos de la entidad tapados por la HUD y fracción que
## queda a la vista (sin muebles delante ni HUD encima).
func _cover_fractions(sprite: Sprite2D) -> Dictionary:
	var image := sprite.texture.get_image()
	var front := _sprites_in_front_of(sprite)
	var hud_rects := _hud_rects()
	var opaque := 0
	var under_hud := 0
	var seen := 0
	var rect := sprite.get_rect()
	for y in range(0, image.get_height(), PIXEL_STEP):
		for x in range(0, image.get_width(), PIXEL_STEP):
			if image.get_pixel(x, y).a < 0.5:
				continue
			opaque += 1
			var local := rect.position + Vector2(image.get_width() - 1 - x if sprite.flip_h else x, y) + Vector2(0.5, 0.5)
			var world := sprite.get_global_transform() * local
			var covered_by_hud := _inside_any(world - VIEW_RECT.position, hud_rects)
			if covered_by_hud:
				under_hud += 1
			if not covered_by_hud and not _covered_by(world, front):
				seen += 1
	if opaque == 0:
		return {"hud": 1.0, "visible": 0.0}
	return {"hud": float(under_hud) / opaque, "visible": float(seen) / opaque}


## Sprites de la habitación que se dibujan encima de `sprite` (orden por Y).
func _sprites_in_front_of(sprite: Sprite2D) -> Array[Sprite2D]:
	var world := _driver.room().get_node("World")
	var own_root := _world_child(sprite, world)
	var front: Array[Sprite2D] = []
	for node in world.get_children():
		if node == own_root or node is Player or not (node is Node2D) or not (node as CanvasItem).visible:
			continue
		var other := node as Node2D
		if other.z_index < own_root.z_index:
			continue
		var drawn_after := other.position.y > own_root.position.y or (other.position.y == own_root.position.y and other.get_index() > own_root.get_index())
		if not drawn_after and other.z_index == own_root.z_index:
			continue
		var candidates: Array[Node] = other.find_children("*", "Sprite2D", true, false)
		if other is Sprite2D:
			candidates.append(other)
		for candidate in candidates:
			var occluder := candidate as Sprite2D
			if occluder.is_visible_in_tree() and _opacity(occluder) >= OCCLUDER_MIN_ALPHA:
				front.append(occluder)
	return front


## Opacidad real de un sprite (la suya por la de sus padres).
func _opacity(sprite: CanvasItem) -> float:
	var alpha := 1.0
	var node: Node = sprite
	while node is CanvasItem:
		alpha *= (node as CanvasItem).modulate.a * (node as CanvasItem).self_modulate.a
		node = node.get_parent()
	return alpha


func _world_child(node: Node, world: Node) -> Node2D:
	while node.get_parent() != world:
		node = node.get_parent()
	return node as Node2D


func _covered_by(world_point: Vector2, front: Array[Sprite2D]) -> bool:
	for other in front:
		var local := other.get_global_transform().affine_inverse() * world_point
		var rect := other.get_rect()
		if not rect.has_point(local):
			continue
		var image := other.texture.get_image()
		var pixel := Vector2i((local - rect.position) * Vector2(image.get_size()) / rect.size)
		if other.flip_h:
			pixel.x = image.get_width() - 1 - pixel.x
		pixel = pixel.clamp(Vector2i.ZERO, image.get_size() - Vector2i.ONE)
		if image.get_pixelv(pixel).a >= 0.5:
			return true
	return false


## Rectángulos de la HUD que están en pantalla durante la exploración, más el
## aviso de peligro (que aparece cerca de los Testigos).
func _hud_rects() -> Array[Rect2]:
	var hud := _driver.manager._hud
	var rects: Array[Rect2] = []
	for control: Control in [hud._round_label, hud._danger_label, hud._decision_bar.get_child(0)]:
		rects.append(control.get_global_rect())
	return rects


func _inside_any(point: Vector2, rects: Array[Rect2]) -> bool:
	for rect in rects:
		if rect.has_point(point):
			return true
	return false