extends RefCounted

## Entidades y sustos: cada anomalía peligrosa tiene su entidad y su susto,
## ninguno se repite, las entidades escondidas caben dentro del mueble que las
## oculta, y el susto solo sale al responder NO HAY ANOMALÍA ante una peligrosa.

const Reporter := preload("res://tests/reporter.gd")
const GameDriver := preload("res://tests/game_driver.gd")
const ANOMALY_DIR := "res://resources/anomalies/"
const ROOM_SCENE := "res://scenes/rooms/room_base.tscn"
const WITNESS_TEXTURE := "px_monster_witness.png"
const WITNESS_OWNER := "testigo_cuarto"
const EXPECTED_DANGEROUS := 9
const MIN_DURATION := 1.0
const MAX_DURATION := 2.0
## Instantes del susto, como fracción de su duración.
const SAMPLE_FRACTIONS: Array[float] = [0.1, 0.35, 0.6, 0.85, 0.99]
## Entre qué fracciones de su alto puede verse la mano que asoma bajo la cama.
const HAND_VISIBLE_MIN := 0.25
const HAND_VISIBLE_MAX := 0.7
const GLASS_MARGIN := 4.0

var _report: Reporter
var _tree: SceneTree
var _dangerous: Array[AnomalyData] = []
var _harmless: Array[AnomalyData] = []


func run(report: Reporter, tree: SceneTree) -> void:
	report.start("Entidades y sustos: identidad, ocultamiento y condición de activación")
	_report = report
	_tree = tree
	for anomaly: AnomalyData in CatalogLoader.load_all(ANOMALY_DIR, AnomalyData):
		if anomaly.is_dangerous:
			_dangerous.append(anomaly)
		else:
			_harmless.append(anomaly)
	_report.check(_dangerous.size() == EXPECTED_DANGEROUS and _harmless.size() == 27, "hay %d peligrosas y %d inofensivas (36 en total)" % [_dangerous.size(), _harmless.size()])
	_check_jumpscare_identity()
	await _check_jumpscare_animation_differs()
	await _check_entity_textures_differ()
	await _check_hiding_containment()
	await _check_trigger_condition()

# ---------------------------------------------------------------------------
# Identidad de los sustos
# ---------------------------------------------------------------------------

func _check_jumpscare_identity() -> void:
	var scenes: Array[String] = []
	var scripts: Array[String] = []
	var sounds: Array[String] = []
	var texture_sets: Array[String] = []
	for anomaly in _dangerous:
		_report.check(anomaly.jumpscare_scene != null, "%s tiene susto asignado" % anomaly.id)
		if anomaly.jumpscare_scene == null:
			continue
		var probe := anomaly.jumpscare_scene.instantiate() as JumpscareBase
		scenes.append(anomaly.jumpscare_scene.resource_path)
		scripts.append((probe.get_script() as Script).resource_path)
		sounds.append(probe.sound_name)
		var textures := _texture_files(probe)
		texture_sets.append(",".join(textures))
		_report.check(probe.duration >= MIN_DURATION and probe.duration <= MAX_DURATION, "%s: su susto dura %.1f s" % [anomaly.id, probe.duration])
		_report.check(anomaly.jumpscare_scene.resource_path.contains(anomaly.id.replace("figura_en_el_", "").replace("figura_", "")) or anomaly.id == "figura_en_el_espejo", "%s: su susto se llama como ella (%s)" % [anomaly.id, anomaly.jumpscare_scene.resource_path.get_file()])
		probe.free()
	_report.check(_all_unique(scenes), "ningún susto se comparte entre anomalías")
	_report.check(_all_unique(scripts), "cada susto tiene su propio script de coreografía")
	_report.check(_all_unique(sounds), "cada susto tiene su propio sonido")
	_report.check(_all_unique(texture_sets), "cada susto está hecho con un conjunto de dibujos distinto")
	var witness_users := 0
	for set in texture_sets:
		if set.contains(WITNESS_TEXTURE):
			witness_users += 1
	_report.check(witness_users == 1, "el sprite del Testigo solo lo usa un susto (%d)" % witness_users)


## Cada susto se anima de forma distinta: se ejecuta su coreografía a varios
## instantes y se compara el estado de todos sus dibujos. (Sin ventana no hay
## capturas: lo que se prueba es que ninguna coreografía es copia de otra y que
## ninguna falla al ejecutarse.)
func _check_jumpscare_animation_differs() -> void:
	var signatures: Array[String] = []
	for anomaly in _dangerous:
		if anomaly.jumpscare_scene == null:
			continue
		var jumpscare := anomaly.jumpscare_scene.instantiate() as JumpscareBase
		_tree.root.add_child(jumpscare)
		await _tree.process_frame
		jumpscare._time_scale = 1.0
		jumpscare._on_start()
		var frames: Array[String] = []
		for fraction in SAMPLE_FRACTIONS:
			jumpscare._on_update(fraction * jumpscare.duration)
			frames.append(_pose(jumpscare))
		_report.check(frames[0] != frames[-1], "%s: su susto se mueve de principio a fin" % anomaly.id)
		signatures.append("|".join(frames))
		jumpscare.queue_free()
		await _tree.process_frame
	_report.check(_all_unique(signatures), "las nueve coreografías producen poses distintas en cada instante")


func _pose(jumpscare: Node) -> String:
	var parts: Array[String] = []
	for sprite: Sprite2D in jumpscare.find_children("*", "Sprite2D", true, false):
		parts.append("%s@%d,%d x%.1f,%.1f a%.1f" % [sprite.name, sprite.position.x, sprite.position.y, sprite.scale.x, sprite.scale.y, sprite.modulate.a])
	return ";".join(parts)


func _texture_files(root: Node) -> Array[String]:
	var files: Array[String] = []
	for sprite: Sprite2D in root.find_children("*", "Sprite2D", true, false):
		var path := sprite.texture.resource_path if sprite.texture != null else ""
		if sprite.texture is AtlasTexture:
			path = (sprite.texture as AtlasTexture).atlas.resource_path
		var file := path.get_file()
		if file != "px_white.png" and not files.has(file):
			files.append(file)
	files.sort()
	return files

# ---------------------------------------------------------------------------
# Entidades de la habitación
# ---------------------------------------------------------------------------

## El dibujo de cada entidad en la habitación es suyo: no hay clones del Testigo.
func _check_entity_textures_differ() -> void:
	var owners := {}
	for anomaly in _dangerous:
		var room := await _room_with(anomaly)
		for sprite in _visible_entities(room):
			var file := sprite.texture.resource_path.get_file()
			owners[file] = owners.get(file, []) + [anomaly.id]
		room.queue_free()
		await _tree.process_frame
	var shared := owners.keys().filter(func(file: String) -> bool: return (owners[file] as Array).size() > 1)
	_report.check(shared.is_empty(), "ningún dibujo de entidad se comparte entre anomalías: %s" % str(shared.map(func(f: String) -> String: return "%s: %s" % [f, owners[f]])))
	_report.check(owners.keys().size() >= 7, "hay al menos 7 dibujos de entidad distintos (%d): %s" % [owners.keys().size(), str(owners.keys())])
	_report.check((owners.get(WITNESS_TEXTURE, []) as Array) == [WITNESS_OWNER], "px_monster_witness solo es del Testigo del escritorio: %s" % str(owners.get(WITNESS_TEXTURE, [])))
	var old_nodes := 0
	var room := (load(ROOM_SCENE) as PackedScene).instantiate()
	for old_name in ["WindowFigure", "WardrobeFigure", "UnderBedFigure", "Figure2"]:
		old_nodes += 1 if room.get_node("World").get_node_or_null(old_name) != null else 0
	room.free()
	_report.check(old_nodes == 0, "no queda ninguna de las cuatro figuras clonadas (%d)" % old_nodes)


## Ocultamiento: cada entidad cabe dentro del mueble o espacio que la esconde.
func _check_hiding_containment() -> void:
	var room := (load(ROOM_SCENE) as PackedScene).instantiate() as Room
	_tree.root.add_child(room)
	await _tree.process_frame
	var world := room.get_node("World")
	_check_hand_under_bed(world)
	_check_crack_in_wardrobe(world)
	_check_face_behind_glass(world)
	_check_reflection_inside_mirror(world)
	room.queue_free()
	await _tree.process_frame


func _check_hand_under_bed(world: Node) -> void:
	var hand := world.get_node("UnderBedHand") as Sprite2D
	var bed := world.get_node("Bed") as Node2D
	var bed_rect := _world_rect(bed.get_node("Sprite"))
	var hand_rect := _world_rect(hand)
	var below := (hand_rect.end.y - bed_rect.end.y) / hand_rect.size.y
	_report.check(hand.position.y < bed.position.y, "la mano se dibuja detrás de la cama (y %.0f < %.0f)" % [hand.position.y, bed.position.y])
	_report.check(hand_rect.position.x >= bed_rect.position.x and hand_rect.end.x <= bed_rect.end.x, "la mano no sobresale de los lados de la cama")
	_report.check(below >= HAND_VISIBLE_MIN and below <= HAND_VISIBLE_MAX, "de la mano solo asoma el %d %% (el resto queda bajo la cama)" % roundi(below * 100.0))
	_report.check(hand_rect.position.y < bed_rect.end.y, "el arranque del brazo queda oculto tras el somier")


func _check_crack_in_wardrobe(world: Node) -> void:
	var wardrobe := world.get_node("Wardrobe") as Node2D
	var crack := wardrobe.get_node("Crack") as Sprite2D
	var wardrobe_rect := _used_world_rect(wardrobe.get_node("Sprite"))
	_report.check(crack.get_parent() == wardrobe, "la rendija es parte del armario (se ordena y vibra con él)")
	_report.check(wardrobe_rect.encloses(_world_rect(crack)), "la rendija está dentro del cuerpo del armario %s" % _world_rect(crack))


func _check_face_behind_glass(world: Node) -> void:
	var window := world.get_node("Window") as Node2D
	var face := window.get_node("Face") as Sprite2D
	var glass := _used_world_rect(window.get_node("Sprite"))
	_report.check(glass.grow(-GLASS_MARGIN).encloses(_world_rect(face)), "el rostro cabe dentro del cristal, con el marco alrededor %s" % _world_rect(face))
	_report.check(face.get_index() > window.get_node("Sprite").get_index(), "el rostro se dibuja sobre el cristal")


func _check_reflection_inside_mirror(world: Node) -> void:
	var mirror := world.get_node("Mirror") as Sprite2D
	var reflection := mirror.get_node("Reflection") as Sprite2D
	var glass := _used_world_rect(mirror).grow(-GLASS_MARGIN)
	_report.check(reflection.get_parent() == mirror, "el reflejo es hijo del espejo")
	_report.check(glass.encloses(_world_rect(reflection)), "el reflejo no sale de la luna del espejo %s" % _world_rect(reflection))

# ---------------------------------------------------------------------------
# Condición de activación
# ---------------------------------------------------------------------------

func _check_trigger_condition() -> void:
	var driver := GameDriver.new(_tree)
	await driver.boot()
	for anomaly in _dangerous:
		await _check_dangerous_round(driver, anomaly)
	for anomaly in _harmless:
		await _check_harmless_round(driver, anomaly)
	await driver.shutdown()


func _check_dangerous_round(driver: GameDriver, anomaly: AnomalyData) -> void:
	await _enter_with(driver, anomaly)
	if anomaly.ambience == "trafico_lejano":
		_report.check(AudioManager.is_playing("ambient_traffic"), "%s: suena el tráfico lejano mientras se explora" % anomaly.id)
	driver.manager._jumpscares.last_played_path = ""
	driver.answer(AnswerEvaluator.Answer.ANOMALY)
	_report.check(driver.manager._jumpscares.last_played_path == "" and driver.manager.state == GameManager.State.PUERTA_ABIERTA, "%s: HAY ANOMALÍA acierta y no activa ningún susto" % anomaly.id)
	_report.check(not AudioManager.is_active("ambient_traffic"), "%s: al acertar se corta el sonido de su efecto" % anomaly.id)
	await _enter_with(driver, anomaly)
	driver.manager._jumpscares.last_played_path = ""
	driver.answer(AnswerEvaluator.Answer.NO_ANOMALY)
	var played := driver.manager._jumpscares.last_played_path
	_report.check(played == anomaly.jumpscare_scene.resource_path, "%s: NO HAY ANOMALÍA activa su propio susto (%s)" % [anomaly.id, played.get_file()])
	_report.check(await driver.await_state(GameManager.State.REFERENCIA), "%s: tras el susto vuelve la referencia" % anomaly.id)
	await driver.await_idle()
	await _tree.process_frame
	_report.check(AudioManager.active_sounds() == ["ambient_room"] and driver.manager._jumpscares.get_child_count() == 0, "%s: al reiniciar no queda nada de ese susto sonando ni dibujado: %s" % [anomaly.id, str(AudioManager.active_sounds())])


func _check_harmless_round(driver: GameDriver, anomaly: AnomalyData) -> void:
	await _enter_with(driver, anomaly)
	driver.manager._jumpscares.last_played_path = ""
	driver.answer(AnswerEvaluator.Answer.NO_ANOMALY)
	_report.check(driver.manager._jumpscares.last_played_path == "", "%s (inofensiva): fallar no activa ningún susto" % anomaly.id)
	await driver.await_state(GameManager.State.REFERENCIA)
	await driver.await_idle()


func _enter_with(driver: GameDriver, anomaly: AnomalyData) -> void:
	await driver.restart()
	await driver.enter_decision_room()
	await driver.force_anomaly(anomaly)

# ---------------------------------------------------------------------------
# Ayudantes
# ---------------------------------------------------------------------------

func _room_with(anomaly: AnomalyData) -> Room:
	var room := (load(ROOM_SCENE) as PackedScene).instantiate() as Room
	_tree.root.add_child(room)
	await _tree.process_frame
	room.apply_anomaly(anomaly)
	return room


func _visible_entities(room: Room) -> Array[Sprite2D]:
	var sprites: Array[Sprite2D] = []
	for node: Sprite2D in room.get_node("World").find_children("*", "Sprite2D", true, false):
		if node.is_in_group(Room.ENTITY_GROUP) and node.visible:
			sprites.append(node)
	var monster := room.get_monster()
	if monster != null:
		sprites.append(monster.get_node("Sprite2D") as Sprite2D)
	return sprites


func _world_rect(sprite: Node) -> Rect2:
	var item := sprite as Sprite2D
	return item.get_global_transform() * item.get_rect()


## Lo realmente dibujado del sprite (sin los márgenes transparentes del archivo).
func _used_world_rect(sprite: Node) -> Rect2:
	var item := sprite as Sprite2D
	var image := item.texture.get_image()
	var used := image.get_used_rect()
	var local := Rect2(Vector2(used.position) - Vector2(image.get_size()) / 2.0 + item.offset, Vector2(used.size))
	return item.get_global_transform() * local


func _all_unique(values: Array[String]) -> bool:
	var seen := {}
	for value in values:
		if seen.has(value):
			return false
		seen[value] = true
	return true