extends RefCounted

## Simulaciones headless largas: 200 partidas perfectas, 200 con un fallo, las
## 36 anomalías aplicadas y revertidas, y la muerte con cada una de las nueve
## entidades que tienen susto.

const Reporter := preload("res://tests/reporter.gd")
const PARTIDA := "res://scenes/partida.tscn"
const ROOM_BASE := "res://scenes/rooms/room_base.tscn"
const PLAYTHROUGHS := 200
const FRAME_BUDGET := 600
const EXPECTED_ENTITIES := 9

## Cuántas partidas simular en cada tanda (la variable de entorno
## ZIVA_PLAYTHROUGHS permite acortarlo para una comprobación rápida).
var _playthroughs := PLAYTHROUGHS
var _audio_players_at_start := 0


func run(report: Reporter, tree: SceneTree) -> void:
	report.start("Simulaciones: partidas, anomalías y muertes")
	var configured := OS.get_environment("ZIVA_PLAYTHROUGHS").to_int()
	if configured > 0:
		_playthroughs = configured
	_audio_players_at_start = tree.root.get_node("AudioManager").get_child_count()
	var manager := (load(PARTIDA) as PackedScene).instantiate() as GameManager
	manager.pacing = 0.0
	manager.ending_scene = ""
	tree.root.add_child(manager)
	await tree.process_frame
	await _await_state(tree, manager, GameManager.State.REFERENCIA)
	await _perfect_runs(report, tree, manager)
	await _failing_runs(report, tree, manager)
	await _anomaly_round_trip(report, tree)
	await _entity_deaths(report, tree, manager)
	await _orphan_check(report, tree, manager)
	manager.queue_free()
	await tree.process_frame


func _perfect_runs(report: Reporter, tree: SceneTree, manager: GameManager) -> void:
	var finishes := 0
	var clean := 0
	for i in range(_playthroughs):
		manager.pacing = 0.0
		if await _play_until_end(tree, manager, -1) == "final":
			finishes += 1
		manager.pacing = 0.0
		manager.start_campaign()
		if await _await_state(tree, manager, GameManager.State.REFERENCIA) and _is_clean(manager):
			clean += 1
	report.check(finishes == _playthroughs, "%d partidas perfectas llegan al final (llegaron %d)" % [_playthroughs, finishes])
	report.check(clean == _playthroughs, "el estado queda limpio tras las %d partidas (limpias %d)" % [_playthroughs, clean])


func _failing_runs(report: Reporter, tree: SceneTree, manager: GameManager) -> void:
	var failures := 0
	var clean := 0
	for i in range(_playthroughs):
		manager.pacing = 0.0
		var outcome := await _play_until_end(tree, manager, 1 + (i % 10))
		if outcome == "fallo":
			failures += 1
			if await _await_state(tree, manager, GameManager.State.REFERENCIA) and _is_clean(manager):
				clean += 1
		manager.pacing = 0.0
		manager.start_campaign()
		await _await_state(tree, manager, GameManager.State.REFERENCIA)
	report.check(failures == _playthroughs, "las %d partidas con fallo fallan (fallaron %d)" % [_playthroughs, failures])
	report.check(clean == _playthroughs, "el fallo reinicia con estado limpio en las %d (limpias %d)" % [_playthroughs, clean])


func _anomaly_round_trip(report: Reporter, tree: SceneTree) -> void:
	var room := (load(ROOM_BASE) as PackedScene).instantiate() as Room
	tree.root.add_child(room)
	await tree.process_frame
	await tree.process_frame
	var catalog: Array[AnomalyData] = []
	catalog.assign(CatalogLoader.load_all("res://resources/anomalies/", AnomalyData))
	var before := _snapshot(room.get_node("World"))
	var children_before := room.get_node("World").get_child_count()
	var broken: Array[String] = []
	for anomaly in catalog:
		room.apply_anomaly(anomaly)
		room.reset()
		await tree.process_frame
		if _snapshot(room.get_node("World")) != before:
			broken.append(anomaly.id)
		if room.get_node("World").get_child_count() != children_before:
			broken.append(anomaly.id + " (deja nodos)")
	report.check(broken.is_empty(), "las %d anomalías se aplican y se revierten sin dejar rastro: %s" % [catalog.size(), str(broken)])
	room.free()
	await tree.process_frame


func _entity_deaths(report: Reporter, tree: SceneTree, manager: GameManager) -> void:
	var catalog: Array[AnomalyData] = []
	catalog.assign(CatalogLoader.load_all("res://resources/anomalies/", AnomalyData))
	var checked := 0
	var own_jumpscare := 0
	for anomaly in catalog:
		if anomaly.jumpscare_scene == null:
			continue
		checked += 1
		manager.pacing = 0.0
		await _enter_decision_room(tree, manager)
		manager.pacing = 1.0
		manager._current_anomaly = anomaly
		manager._jumpscares.last_played_path = ""
		manager._hud.decision_made.emit(AnswerEvaluator.Answer.NO_ANOMALY)
		await tree.process_frame
		await tree.process_frame
		if manager._jumpscares.last_played_path == anomaly.jumpscare_scene.resource_path:
			own_jumpscare += 1
		var back := await _await_state(tree, manager, GameManager.State.REFERENCIA)
		report.check(back and _is_clean(manager), "tras el susto de %s vuelve la referencia limpia" % anomaly.id)
		manager.pacing = 0.0
		manager.start_campaign()
		await _await_state(tree, manager, GameManager.State.REFERENCIA)
	report.check(checked == EXPECTED_ENTITIES, "se prueban las %d entidades con susto (%d)" % [EXPECTED_ENTITIES, checked])
	report.check(own_jumpscare == checked, "cada entidad reproduce su propio susto (%d de %d)" % [own_jumpscare, checked])


func _orphan_check(report: Reporter, tree: SceneTree, manager: GameManager) -> void:
	manager.pacing = 0.0
	manager.start_campaign()
	await tree.process_frame
	await tree.process_frame
	var orphans: int = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	report.check(orphans == 0, "sin nodos huérfanos tras las simulaciones (%d)" % orphans)
	if orphans > 0:
		Node.print_orphan_nodes()
	var audio := tree.root.get_node("AudioManager")
	report.check(audio.get_child_count() == _audio_players_at_start, "los reproductores de audio no se acumulan (%d al empezar, %d al acabar)" % [_audio_players_at_start, audio.get_child_count()])
	report.check(audio.active_sounds() == ["ambient_room"], "tras las simulaciones solo suena el ambiente de la partida nueva: %s" % str(audio.active_sounds()))


## Juega una partida: responde en cada ronda de decisión y cruza la puerta
## cuando está abierta. `fail_at_room` es la ronda en la que responde mal.
func _play_until_end(tree: SceneTree, manager: GameManager, fail_at_room: int) -> String:
	var last_action := Vector2i(-1, -1)
	var highest_index := -1
	for i in range(FRAME_BUDGET):
		await tree.process_frame
		if manager.state == GameManager.State.FINAL:
			return "final"
		var index: int = manager._run.index
		# Un fallo puede resolverse dentro del mismo fotograma, así que se
		# detecta por el retroceso del índice al reiniciarse la partida.
		if index < highest_index:
			return "fallo"
		highest_index = maxi(highest_index, index)
		var action := Vector2i(index, manager.state)
		if manager._busy or action == last_action:
			continue
		match manager.state:
			GameManager.State.REFERENCIA, GameManager.State.PUERTA_ABIERTA:
				last_action = action
				manager._on_message_action(Room.DOOR_ACTION)
			GameManager.State.EXPLORACION:
				last_action = action
				manager._hud.decision_made.emit(_answer(manager._current_anomaly != null, index == fail_at_room))
	print("    aviso: partida estancada en estado %d, ronda %d, anomalía %s, susto=%s, reproductor ocupado=%s hijos=%d" % [
			manager.state,
			manager._run.index,
			manager._current_anomaly.id if manager._current_anomaly != null else "ninguna",
			manager._jumpscares.last_played_path,
			str(manager._jumpscares._running),
			manager._jumpscares.get_child_count(),
		])
	return "timeout"


func _answer(has_anomaly: bool, wrong: bool) -> int:
	var claims_anomaly := has_anomaly != wrong
	return AnswerEvaluator.Answer.ANOMALY if claims_anomaly else AnswerEvaluator.Answer.NO_ANOMALY


func _enter_decision_room(tree: SceneTree, manager: GameManager) -> void:
	manager._on_message_action(Room.DOOR_ACTION)
	await _await_state(tree, manager, GameManager.State.EXPLORACION)
	for i in range(FRAME_BUDGET):
		if not manager._busy:
			return
		await tree.process_frame


func _await_state(tree: SceneTree, manager: GameManager, wanted: int) -> bool:
	for i in range(FRAME_BUDGET):
		if manager.state == wanted:
			return true
		await tree.process_frame
	return false


func _is_clean(manager: GameManager) -> bool:
	if manager._run.index != 0 or manager._run.correct != 0 or not manager._run.previous_anomaly_id.is_empty():
		return false
	var room: Room = manager._room
	if room == null or not is_instance_valid(room):
		return false
	var players := 0
	var monsters := 0
	for child in room.get_node("World").get_children():
		if child is Player:
			players += 1
		elif child is Monster:
			monsters += 1
	return players == 1 and monsters == 0


func _snapshot(world: Node) -> Dictionary:
	var snapshot: Dictionary = {}
	_collect(world, snapshot)
	return snapshot


func _collect(node: Node, snapshot: Dictionary) -> void:
	for child in node.get_children():
		if child is Player or child is Monster:
			continue
		var entry: Dictionary = {}
		if child is Node2D:
			var node_2d := child as Node2D
			entry["posicion"] = node_2d.position
			entry["giro"] = node_2d.rotation
			entry["escala"] = node_2d.scale
			entry["visible"] = node_2d.visible
		if child is CanvasItem:
			entry["color"] = (child as CanvasItem).modulate
		if child is Sprite2D:
			entry["textura"] = (child as Sprite2D).texture
			entry["volteo"] = (child as Sprite2D).flip_h
		if child is CollisionShape2D:
			entry["colision_off"] = (child as CollisionShape2D).disabled
		snapshot[str(child.get_path())] = entry
		_collect(child, snapshot)
