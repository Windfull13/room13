extends RefCounted

## Presentación: la habitación está compuesta como un lugar real (muebles contra
## la pared, objetos pequeños sobre el escritorio, alfombra y ventana
## integradas, espacio para caminar), las entidades afectan al entorno, el
## pasillo conecta las habitaciones sin ser una ronda, y el menú y la pausa
## comparten estética y se manejan con teclado.

const Reporter := preload("res://tests/reporter.gd")
const GameDriver := preload("res://tests/game_driver.gd")
const Probe := preload("res://tests/room_probe.gd")
const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const ROOM_SCENE := "res://scenes/rooms/room_base.tscn"
const MENU_SCENE := "res://scenes/main_menu.tscn"
const CORRIDOR_SCENE := "res://scenes/corridor.tscn"
const TABLEAU_SCRIPT := "res://scripts/ui/menu_tableau.gd"

## Suelo de la habitación en coordenadas del mundo y la altura donde acaba la pared del fondo.
const FLOOR_RECT := Rect2(288, 216, 704, 384)
const WALL_BOTTOM := 216.0
const MAX_WALL_GAP := 24.0
const PLAYER_SCALE := 1.3
const MAX_FURNITURE_SCALE := 1.3
const MAX_DESK_ITEM_SCALE := 0.75
const MIN_WALKABLE_SHARE := 0.55
const FRAME_BUDGET := 900
const EXPECTED_ROOMS := 11
const EXPECTED_DECISIONS := 10
const MOVE_TOLERANCE := 6.0
## Tiempo real que se espera a que un efecto continuo (el más lento vibra cada 2,4 s) se note.
const CONTINUOUS_EFFECT_WAIT_MS := 5000

var _report: Reporter
var _tree: SceneTree
var _audio: Node


func run(report: Reporter, tree: SceneTree) -> void:
	report.start("Presentación: habitación, entidades, pasillo, menú y pausa")
	_report = report
	_tree = tree
	_audio = tree.root.get_node("AudioManager")
	await _check_room_layout()
	await _check_walkable_space()
	await _check_anomaly_targets_in_room()
	await _check_entities_affect_environment()
	await _check_corridor_scene()
	await _check_corridor_in_game_flow()
	await _check_menu_composition()
	await _check_menu_motion_and_keyboard()
	await _check_pause_menu()

# ---------------------------------------------------------------------------
# Habitación
# ---------------------------------------------------------------------------

func _check_room_layout() -> void:
	var room := (load(ROOM_SCENE) as PackedScene).instantiate() as Room
	_tree.root.add_child(room)
	await _tree.process_frame
	var world := room.get_node("World")
	for furniture in ["Bed", "Wardrobe", "Desk"]:
		var gap := _footprint_top(world.get_node(furniture)) - WALL_BOTTOM
		_report.check(gap >= -2.0 and gap <= MAX_WALL_GAP, "%s: apoyado contra la pared del fondo (separación %.0f px)" % [furniture, gap])
	var door := world.get_node("Door") as Node2D
	_report.check(door.position.y >= WALL_BOTTOM and door.position.y <= WALL_BOTTOM + 16.0 and FLOOR_RECT.has_point(Vector2(door.position.x, WALL_BOTTOM + 1.0)), "la puerta está empotrada en la pared del fondo, dentro de su tramo (base en y = %.0f)" % door.position.y)
	_report.check(_texture_file(door.get_node("Sprite")) == "px_door_wall.png", "la puerta usa el sprite frontal con marco")
	_report.check(_world_rect(world.get_node("Window/Sprite")).end.y <= WALL_BOTTOM + 2.0, "la ventana cuelga de la pared (su borde inferior en y = %.0f)" % _world_rect(world.get_node("Window/Sprite")).end.y)
	_report.check(world.get_node("Window/Frame") != null and world.get_node("Window/Sill") != null, "la ventana tiene marco y alféizar")
	_report.check(world.get_node("Window/Sprite").scale.x > MAX_FURNITURE_SCALE, "la ventana es mayor que antes (escala %.1f)" % world.get_node("Window/Sprite").scale.x)
	_report.check(_world_rect(world.get_node("Clock/Sprite")).end.y <= WALL_BOTTOM, "el reloj está en la pared, por encima del suelo (borde inferior y = %.0f)" % _world_rect(world.get_node("Clock/Sprite")).end.y)
	_report.check(_world_rect(world.get_node("Clock/Sprite")).position.y > 24.0, "el reloj está a una altura razonable")
	_check_rug(world)
	_check_desk_and_chair(world)
	_check_proportions(world)
	_check_inside_floor(world)
	room.queue_free()
	await _tree.process_frame


func _check_rug(world: Node) -> void:
	var rug := _world_rect(world.get_node("Rug/Sprite"))
	_report.check(FLOOR_RECT.encloses(rug), "la alfombra está entera sobre el suelo %s" % rug)
	_report.check(rug.size.x > 192.0 * PLAYER_SCALE, "la alfombra es más grande que antes (%.0f px de ancho)" % rug.size.x)
	_report.check(world.get_node("Rug").z_index < world.get_node("Bed").z_index + 1 and world.get_node("Rug").z_index <= -10, "la alfombra se dibuja bajo los muebles")
	for furniture in ["Bed", "Wardrobe", "Desk", "Door"]:
		var footprint := _footprint_rect(world.get_node(furniture))
		_report.check(not footprint.intersects(rug), "la alfombra no atraviesa la huella de %s" % furniture)


func _check_desk_and_chair(world: Node) -> void:
	var desk := world.get_node("Desk") as Node2D
	var chair := world.get_node("Chair") as Node2D
	var desk_sprite := _world_rect(desk.get_node("Sprite"))
	_report.check(absf(chair.position.x - desk.position.x) <= 12.0 and chair.position.y > desk.position.y, "la silla está delante del escritorio, centrada")
	_report.check(_texture_file(chair.get_node("Sprite")) == "px_chair_back.png", "la silla se ve de espaldas, orientada al escritorio")
	_report.check(not _footprint_rect(chair).intersects(_footprint_rect(desk)), "la silla no se solapa con el escritorio")
	for item in ["Photograph", "Book", "Phone", "Lamp", "Letter"]:
		var node := world.get_node(item) as Node2D
		var sprite := node if node is Sprite2D else node.get_node("Sprite")
		_report.check(desk_sprite.has_point(node.global_position) or desk_sprite.grow(4.0).has_point(node.global_position), "%s está sobre el escritorio" % item)
		_report.check(absf(sprite.global_transform.get_scale().x) <= MAX_DESK_ITEM_SCALE, "%s es proporcional al escritorio (escala %.2f)" % [item, absf(sprite.global_transform.get_scale().x)])


func _check_proportions(world: Node) -> void:
	for furniture in ["Bed", "Wardrobe", "Desk"]:
		var scale_factor: float = world.get_node(furniture).get_node("Sprite").scale.x
		_report.check(scale_factor <= MAX_FURNITURE_SCALE, "%s no ha crecido (escala %.2f)" % [furniture, scale_factor])
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate()
	var player_height: float = (player.get_node("AnimatedSprite2D") as AnimatedSprite2D).sprite_frames.get_frame_texture("idle_down", 0).get_height() * PLAYER_SCALE
	player.free()
	for furniture in ["Bed", "Wardrobe", "Desk"]:
		_report.check(_world_rect(world.get_node(furniture).get_node("Sprite")).size.y > player_height * 0.9, "%s es claramente mayor que el personaje" % furniture)
	for small in ["Toy", "Mirror", "Plant"]:
		var node := world.get_node(small)
		var sprite := node if node is Sprite2D else node.get_node("Sprite")
		_report.check(_world_rect(sprite).size.y < _world_rect(world.get_node("Wardrobe/Sprite")).size.y, "%s es menor que un mueble" % small)


func _check_inside_floor(world: Node) -> void:
	for node_name in ["Bed", "Wardrobe", "Desk", "Chair", "Plant", "Mirror", "Toy", "PlayerSpawn", "MonsterSpawn1", "MonsterSpawn2"]:
		var position: Vector2 = world.get_node(node_name).position
		_report.check(FLOOR_RECT.grow(2.0).has_point(position), "%s está dentro de la habitación (%s)" % [node_name, position])


## Espacio para caminar: el suelo alcanzable sin atravesar muebles ni paredes.
func _check_walkable_space() -> void:
	var driver := GameDriver.new(_tree)
	await driver.boot()
	var probe = Probe.new(driver.room(), driver.player())
	probe.flood_from(driver.room().get_player_spawn())
	var reachable: Array[Vector2] = probe.reachable_positions()
	var floor_cells := (FLOOR_RECT.size.x / Probe.GRID_STEP) * (FLOOR_RECT.size.y / Probe.GRID_STEP)
	var share := reachable.size() / floor_cells
	_report.check(share >= MIN_WALKABLE_SHARE and share < 0.95, "se puede caminar por el %d %% del suelo (ni vacío ni saturado)" % roundi(share * 100.0))
	var outside := 0
	for position in reachable:
		if not FLOOR_RECT.grow(MOVE_TOLERANCE * 2.0).has_point(position):
			outside += 1
	_report.check(outside == 0, "el jugador no puede atravesar las paredes (%d celdas fuera)" % outside)
	for interactable: Interactable in driver.room().find_children("*", "Interactable", true, false):
		var reachable_spot := false
		for position in reachable:
			if probe.interactable_at(position) == interactable:
				reachable_spot = true
				break
		_report.check(reachable_spot, "se puede llegar a inspeccionar «%s»" % interactable.display_name)
	for furniture in ["Bed", "Wardrobe", "Desk", "Chair", "Plant", "Mirror"]:
		var footprint := _footprint_rect(driver.room().get_node("World/" + furniture))
		var inside := reachable.filter(func(p: Vector2) -> bool: return footprint.has_point(p + Vector2(0, -9)))
		_report.check(inside.is_empty(), "el jugador no atraviesa «%s»" % furniture)
	var door_spot := Vector2(605, 262)
	_report.check(probe.is_reachable(door_spot), "se llega a la puerta desde el centro de la habitación")
	await driver.shutdown()


func _check_anomaly_targets_in_room() -> void:
	var room := (load(ROOM_SCENE) as PackedScene).instantiate() as Room
	_tree.root.add_child(room)
	await _tree.process_frame
	var broken: Array[String] = []
	var checked := 0
	for anomaly: AnomalyData in CatalogLoader.load_all("res://resources/anomalies/", AnomalyData):
		for modification in anomaly.modifications:
			checked += 1
			var target := room.get_node("World").get_node_or_null(NodePath((modification as AnomalyModification).target_node))
			if target == null:
				broken.append("%s → %s (no existe)" % [anomaly.id, modification.target_node])
			elif modification.mode == AnomalyModification.Mode.SET_POSITION and not FLOOR_RECT.grow(8.0).has_point(modification.position):
				broken.append("%s → %s en %s (fuera del suelo)" % [anomaly.id, modification.target_node, modification.position])
	_report.check(broken.is_empty() and checked > 0, "las anomalías apuntan a objetos que existen y a posiciones dentro de la habitación (%d modificaciones): %s" % [checked, str(broken)])
	room.queue_free()
	await _tree.process_frame

# ---------------------------------------------------------------------------
# Entidades que afectan al entorno
# ---------------------------------------------------------------------------

func _check_entities_affect_environment() -> void:
	var driver := GameDriver.new(_tree)
	await driver.boot()
	await _check_ambience_catalog()
	await _check_lamp_and_gaze(driver)
	await _check_continuous_effect(driver, "figura_ventana", "Window/Sprite")
	await _check_continuous_effect(driver, "figura_armario", "Wardrobe")
	await _check_effects_stop_on_retire(driver)
	await driver.shutdown()


func _check_ambience_catalog() -> void:
	var with_effect := 0
	for anomaly: AnomalyData in CatalogLoader.load_all("res://resources/anomalies/", AnomalyData):
		if anomaly.ambience.is_empty():
			_report.check(not anomaly.is_dangerous, "%s: toda peligrosa tiene efecto de entorno" % anomaly.id)
			continue
		_report.check(EntityAmbience.EFFECTS.has(anomaly.ambience), "%s: su efecto «%s» existe" % [anomaly.id, anomaly.ambience])
		with_effect += anomaly.is_dangerous as int
	_report.check(with_effect == 9, "las 9 amenazas peligrosas afectan al entorno (%d)" % with_effect)
	await _tree.process_frame


func _check_lamp_and_gaze(driver: GameDriver) -> void:
	await driver.restart()
	await driver.enter_decision_room()
	await driver.force_anomaly(GameDriver.load_anomaly("testigo_cuarto"))
	var room := driver.room()
	var lamp := room.get_node("World/Lamp") as Sprite2D
	var monster := room.get_monster()
	var calm := lamp.modulate
	await _tree.create_timer(0.3).timeout
	_report.check(lamp.modulate == calm, "mientras el jugador está lejos la lámpara no cambia")
	var eye_home: float = monster.get_node("Sprite2D/OjoIzq").position.x
	await driver.teleport_player(monster.global_position + Vector2(-100, 70))
	var dimmed := false
	var eyes_shifted := false
	for i in range(80):
		await _tree.process_frame
		dimmed = dimmed or lamp.modulate.r < calm.r - 0.05
		eyes_shifted = eyes_shifted or absf(monster.get_node("Sprite2D/OjoIzq").position.x - eye_home) > 0.1
	_report.check(dimmed, "al acercarse al Testigo la lámpara del escritorio parpadea")
	_report.check(eyes_shifted and monster.get_node("Sprite2D").rotation < 0.0, "el Testigo se inclina hacia el jugador, que está a su izquierda (rotación %.3f)" % monster.get_node("Sprite2D").rotation)
	await driver.teleport_player(room.get_player_spawn())
	await _tree.create_timer(0.35).timeout
	_report.check(not room._ambience.is_running() and lamp.modulate == calm, "al alejarse, la lámpara vuelve a su estado normal")
	var tension_before := AudioManager.is_tense()
	await driver.teleport_player(monster.global_position + Vector2(-100, 70))
	await _tree.create_timer(0.7).timeout
	_report.check(AudioManager.is_tense() and not tension_before, "cerca de la entidad el ambiente sonoro baja")
	await driver.teleport_player(room.get_player_spawn())
	await _tree.create_timer(0.7).timeout
	_report.check(not AudioManager.is_tense(), "al alejarse el ambiente sonoro se recupera")


func _check_continuous_effect(driver: GameDriver, anomaly_id: String, target_path: String) -> void:
	await driver.restart()
	await driver.enter_decision_room()
	await driver.force_anomaly(null)
	var room := driver.room()
	var target := room.get_node("World/" + target_path) as Node2D
	var before_color := target.modulate
	var before_position := target.position
	await driver.force_anomaly(GameDriver.load_anomaly(anomaly_id))
	var changed := false
	var deadline := Time.get_ticks_msec() + CONTINUOUS_EFFECT_WAIT_MS
	while not changed and Time.get_ticks_msec() < deadline:
		await _tree.process_frame
		changed = target.modulate != before_color or target.position != before_position
	_report.check(changed, "%s: «%s» reacciona sola, sin que el jugador se acerque" % [anomaly_id, target_path])
	room.reset()
	_report.check(target.modulate == before_color and target.position == before_position, "%s: al revertir la anomalía, «%s» queda como estaba" % [anomaly_id, target_path])


func _check_effects_stop_on_retire(driver: GameDriver) -> void:
	await driver.restart()
	await driver.enter_decision_room()
	await driver.force_anomaly(GameDriver.load_anomaly("figura_ventana"))
	driver.answer(AnswerEvaluator.Answer.ANOMALY)
	await _tree.process_frame
	_report.check(not driver.room()._ambience.is_running(), "al acertar, el entorno deja de reaccionar")

# ---------------------------------------------------------------------------
# Pasillo
# ---------------------------------------------------------------------------

func _check_corridor_scene() -> void:
	var corridor := (load(CORRIDOR_SCENE) as PackedScene).instantiate() as Corridor
	_tree.root.add_child(corridor)
	await _tree.process_frame
	var start_x := corridor.walker_x()
	_report.check(not corridor.is_destination_lit(), "al entrar en el pasillo la puerta de destino está apagada")
	await corridor.play(0.5, "Habitación 2 / 10")
	_report.check(corridor.walker_x() > start_x + 500.0, "el protagonista cruza el pasillo (de x = %.0f a %.0f)" % [start_x, corridor.walker_x()])
	_report.check(corridor.is_destination_lit(), "al llegar se enciende la luz de la puerta de destino")
	_report.check((corridor.get_node("Stage/DestinationLabel") as Label).text == "Habitación 2 / 10", "el pasillo anuncia la habitación de destino")
	corridor.queue_free()
	await _tree.process_frame


## Cruzar una puerta pasa por el pasillo, no cuenta como ronda y se libera.
func _check_corridor_in_game_flow() -> void:
	var driver := GameDriver.new(_tree)
	await driver.boot()
	driver.manager.pacing = 0.05
	var seen := {"pasillo": false, "indices": []}
	driver.cross_door()
	for i in range(FRAME_BUDGET):
		await _tree.process_frame
		seen["pasillo"] = seen["pasillo"] or driver.manager.get_node_or_null("Corridor") != null
		if driver.manager.state == GameManager.State.EXPLORACION and not driver.manager._busy:
			break
	_report.check(seen["pasillo"], "al cruzar la puerta se pasa por el pasillo")
	_report.check(driver.manager._run.index == 1, "el pasillo no es una ronda: del 0 se pasa al 1 (índice %d)" % driver.manager._run.index)
	_report.check(driver.manager.get_node_or_null("Corridor") == null, "al llegar el pasillo se libera")
	driver.manager.pacing = 0.0
	var rooms: Array[RoomData] = []
	rooms.assign(CatalogLoader.load_all("res://resources/rooms/", RoomData))
	var decisions := rooms.filter(func(room: RoomData) -> bool: return not room.is_reference).size()
	_report.check(rooms.size() == EXPECTED_ROOMS and decisions == EXPECTED_DECISIONS, "siguen siendo %d rondas (1 referencia + %d de decisión)" % [rooms.size(), decisions])
	await driver.shutdown()

# ---------------------------------------------------------------------------
# Menú principal
# ---------------------------------------------------------------------------

func _check_menu_composition() -> void:
	var menu := await _load_menu()
	var title := menu.get_node("MainScreen/Title") as Label
	var buttons := menu.find_children("*", "Button", true, false).filter(func(b: Node) -> bool: return b.is_visible_in_tree())
	var tableau_view := menu.get_node("MainScreen/TableauView") as Control
	var all_left := buttons.all(func(b: Button) -> bool: return b.get_global_rect().end.x < tableau_view.get_global_rect().position.x)
	_report.check(title.get_global_rect().end.x < tableau_view.get_global_rect().position.x and all_left, "el título y los 5 botones están a la izquierda y la imagen a la derecha")
	_report.check(buttons.size() == 5, "hay exactamente 5 botones en la pantalla principal (%d)" % buttons.size())
	_report.check(tableau_view.get_global_rect().size.y > 500.0 and tableau_view.get_global_rect().position.x > 600.0, "la imagen de la derecha ocupa media pantalla")
	_report.check(title.get_theme_font("font").resource_path.get_file() == "UnifrakturCook-Bold.ttf", "el título usa tipografía gótica (UnifrakturCook)")
	_report.check(buttons[0].get_theme_font("font").resource_path.get_file() == "PirataOne-Regular.ttf", "los botones usan la gótica legible (Pirata One)")
	_report.check(title.text.contains("13"), "el título dice «La Habitación 13»")
	var tableau := menu.get_node("MainScreen/TableauView/Viewport/Tableau") as MenuTableau
	var photo_before := tableau.is_photo_altered()
	tableau._blackout(true)
	await _tree.create_timer(0.7).timeout
	var altered := tableau.is_photo_altered()
	tableau._blackout(false)
	await _tree.create_timer(0.7).timeout
	_report.check(not photo_before and altered and not tableau.is_photo_altered(), "la fotografía de la familia cambia con el apagón y vuelve a la normalidad")
	await _unload_menu(menu)


func _check_menu_motion_and_keyboard() -> void:
	var menu := await _load_menu()
	var start := menu.get_node("MainScreen/MenuColumn/StartButton") as Button
	var options := menu.get_node("MainScreen/MenuColumn/HowToButton") as Button
	await _tree.create_timer(1.0).timeout
	_report.check(menu.get_viewport().gui_get_focus_owner() == start, "el foco empieza en INICIAR PARTIDA")
	_press_action("ui_down")
	await _tree.create_timer(0.3).timeout
	_report.check(menu.get_viewport().gui_get_focus_owner() == options, "la flecha abajo mueve el foco a CÓMO JUGAR (teclado)")
	_report.check(options.scale.x > 1.0 and options.modulate.r > 1.0, "el botón con foco se ilumina y crece")
	_report.check(not start.scale.x > 1.0, "el botón que pierde el foco vuelve a su tamaño")
	options.button_down.emit()
	await _tree.create_timer(0.15).timeout
	_report.check(options.scale.x < 1.0, "al pulsar el botón se hunde")
	options.button_up.emit()
	var recorder := AudioEffectRecord.new()
	recorder.format = AudioStreamWAV.FORMAT_16_BITS
	var sfx_bus := AudioServer.get_bus_index("SFX")
	AudioServer.add_bus_effect(sfx_bus, recorder)
	recorder.set_recording_active(true)
	var credits := menu.get_node("MainScreen/MenuColumn/CreditsButton") as Button
	credits.mouse_entered.emit()
	await _tree.create_timer(0.3).timeout
	var heard := _peak_db(recorder.get_recording()) > -60.0
	recorder.set_recording_active(false)
	AudioServer.remove_bus_effect(sfx_bus, AudioServer.get_bus_effect_count(sfx_bus) - 1)
	_report.check(heard, "al pasar el ratón por un botón suena el hover")
	_report.check(start.modulate.a >= 0.99 and options.modulate.a >= 0.99, "los botones terminaron su entrada suave y son visibles")
	await _unload_menu(menu)

# ---------------------------------------------------------------------------
# Pausa
# ---------------------------------------------------------------------------

func _check_pause_menu() -> void:
	var driver := GameDriver.new(_tree)
	await driver.boot()
	var hud := driver.manager._hud
	var title := driver.manager.get_node("HUD/Root/PausePanel/Center/Box/Title") as Label
	driver.manager._toggle_pause()
	_report.check(hud.is_pause_visible() and driver.manager._paused, "la pausa aparece")
	await _tree.create_timer(0.5).timeout
	var panel := driver.manager.get_node("HUD/Root/PausePanel") as Control
	_report.check(panel.modulate.a > 0.99, "la pausa aparece con un fundido (opacidad %.2f)" % panel.modulate.a)
	_report.check(title.get_theme_font("font").resource_path.get_file() == "UnifrakturCook-Bold.ttf", "el título de la pausa usa la misma gótica del menú")
	var resume := driver.manager.get_node("HUD/Root/PausePanel/Center/Box/ResumeButton") as Button
	var menu_button := driver.manager.get_node("HUD/Root/PausePanel/Center/Box/MenuButton") as Button
	_report.check(hud.get_viewport().gui_get_focus_owner() == resume, "al abrir la pausa el foco está en REANUDAR")
	_press_action("ui_down")
	await _tree.create_timer(0.3).timeout
	_press_action("ui_down")
	await _tree.create_timer(0.3).timeout
	_report.check(hud.get_viewport().gui_get_focus_owner() == menu_button and menu_button.scale.x > 1.0, "con el teclado se baja hasta MENÚ PRINCIPAL (pasando por CÓMO JUGAR) y se ilumina")
	_report.check(resume.has_meta(&"fx_rest_x"), "los botones de la pausa tienen la misma animación que los del menú")
	driver.manager._toggle_pause()
	await _tree.create_timer(0.4).timeout
	_report.check(not hud.is_pause_visible() and not driver.manager._paused, "la pausa se cierra con su transición")
	_report.check(driver.player().can_move, "al cerrar la pausa el jugador puede moverse")
	await driver.shutdown()

# ---------------------------------------------------------------------------
# Ayudantes
# ---------------------------------------------------------------------------

func _load_menu() -> Control:
	_tree.change_scene_to_file(MENU_SCENE)
	for i in range(FRAME_BUDGET):
		await _tree.process_frame
		if _tree.current_scene != null and _tree.current_scene.scene_file_path == MENU_SCENE and _tree.current_scene.is_node_ready():
			break
	await _tree.process_frame
	return _tree.current_scene as Control


func _unload_menu(menu: Control) -> void:
	menu.queue_free()
	_audio.stop_all()
	_audio.stop_music(0.0)
	await _tree.process_frame


func _press_action(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await _tree.process_frame
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)


func _peak_db(recording: AudioStreamWAV) -> float:
	if recording == null:
		return -200.0
	var peak := 0
	for offset in range(0, recording.data.size() - 1, 2):
		peak = maxi(peak, absi(recording.data.decode_s16(offset)))
	return linear_to_db(maxf(peak / 32768.0, 0.00001))


func _world_rect(sprite: Node) -> Rect2:
	var item := sprite as Sprite2D
	return item.get_global_transform() * item.get_rect()


func _texture_file(sprite: Node) -> String:
	return (sprite as Sprite2D).texture.resource_path.get_file()


## Rectángulo de la colisión de un mueble (su huella en el suelo).
func _footprint_rect(body: Node) -> Rect2:
	for node in body.find_children("*", "CollisionShape2D", true, false):
		var shape := node as CollisionShape2D
		if shape.shape is RectangleShape2D:
			var size := (shape.shape as RectangleShape2D).size
			return Rect2(shape.global_position - size / 2.0, size)
	return Rect2()


func _footprint_top(body: Node) -> float:
	return _footprint_rect(body).position.y