extends RefCounted

## Maneja una partida real desde las pruebas: espera estados, responde, cruza
## la puerta, fuerza anomalías y mueve al jugador por la física del motor.

const PARTIDA := "res://scenes/partida.tscn"
const FRAME_BUDGET := 1200
const PHYSICS_SETTLE_FRAMES := 4

var tree: SceneTree
var manager: GameManager


func _init(scene_tree: SceneTree) -> void:
	tree = scene_tree


## Arranca partida.tscn con las esperas a cero y aguarda la referencia.
func boot() -> bool:
	manager = (load(PARTIDA) as PackedScene).instantiate() as GameManager
	manager.pacing = 0.0
	manager.ending_scene = ""
	manager.early_finish_scene = ""
	tree.root.add_child(manager)
	await tree.process_frame
	return await await_state(GameManager.State.REFERENCIA)


func shutdown() -> void:
	manager.queue_free()
	await tree.process_frame


func restart() -> void:
	manager.start_campaign()
	await await_state(GameManager.State.REFERENCIA)
	await await_idle()


func await_state(wanted: GameManager.State) -> bool:
	for i in range(FRAME_BUDGET):
		if manager.state == wanted:
			return true
		await tree.process_frame
	return false


func await_idle() -> void:
	for i in range(FRAME_BUDGET):
		if not manager._busy:
			return
		await tree.process_frame


func settle_physics() -> void:
	for i in range(PHYSICS_SETTLE_FRAMES):
		await tree.physics_frame


## Desde la referencia, cruza la puerta y espera a poder jugar la ronda 2.
func enter_decision_room() -> void:
	await await_idle()
	cross_door()
	await await_state(GameManager.State.EXPLORACION)
	await await_idle()


func cross_door() -> void:
	manager._on_message_action(Room.DOOR_ACTION)


func answer(value: AnswerEvaluator.Answer) -> void:
	manager._hud.decision_made.emit(value)


func correct_answer() -> AnswerEvaluator.Answer:
	return AnswerEvaluator.Answer.ANOMALY if manager._current_anomaly != null else AnswerEvaluator.Answer.NO_ANOMALY


func wrong_answer() -> AnswerEvaluator.Answer:
	return AnswerEvaluator.Answer.NO_ANOMALY if manager._current_anomaly != null else AnswerEvaluator.Answer.ANOMALY


## Sustituye la anomalía de la ronda actual por `anomaly` (null = sala normal).
func force_anomaly(anomaly: AnomalyData) -> void:
	manager._room.reset()
	manager._current_anomaly = anomaly
	if anomaly != null:
		manager._room.apply_anomaly(anomaly)
	await tree.process_frame
	await settle_physics()


func player() -> Player:
	return manager._player


func room() -> Room:
	return manager._room


func teleport_player(position: Vector2) -> void:
	player().global_position = position
	player().velocity = Vector2.ZERO
	await settle_physics()


static func load_anomaly(id: String) -> AnomalyData:
	return load("res://resources/anomalies/%s.tres" % id) as AnomalyData