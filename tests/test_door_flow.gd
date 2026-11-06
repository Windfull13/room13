extends RefCounted

## La puerta como salida de cada ronda: acertar la abre sin avanzar solo, se
## cruza con E, fallar reinicia, la última puerta lleva al final y, tras
## acertar, las amenazas ya no matan.

const Reporter := preload("res://tests/reporter.gd")
const GameDriver := preload("res://tests/game_driver.gd")
const IDLE_FRAMES := 120
const DOOR_APPROACH := Vector2(605, 262)
const INPUT_FRAMES := 6

var _report: Reporter
var _driver: GameDriver


func run(report: Reporter, tree: SceneTree) -> void:
	report.start("Puerta: desbloqueo, cruce y final")
	_report = report
	_driver = GameDriver.new(tree)
	report.check(await _driver.boot(), "la partida arranca en la referencia")
	await _check_correct_answer_opens_door()
	await _check_door_crossed_with_e()
	await _check_failure_restarts()
	await _check_threats_retire()
	await _check_last_door_finishes()
	await _driver.shutdown()


func _check_correct_answer_opens_door() -> void:
	await _driver.enter_decision_room()
	var index: int = _driver.manager._run.index
	_report.check(not _driver.room().is_door_unlocked(), "en una ronda de decisión la puerta empieza cerrada")
	_driver.answer(_driver.correct_answer())
	_report.check(_driver.manager.state == GameManager.State.PUERTA_ABIERTA, "acertar pasa a PUERTA_ABIERTA")
	_report.check(_driver.room().is_door_unlocked(), "acertar desbloquea la puerta")
	_report.check(_driver.room().get_node("World/Door/LightSlit").visible, "la puerta abierta muestra la rendija de luz")
	_report.check(_driver.manager._hud.is_notice_visible(), "la HUD avisa de que la puerta se ha abierto")
	_report.check(not _driver.manager._hud._decision_bar.visible, "los botones de decisión desaparecen")
	_report.check(_driver.player().can_move, "el jugador sigue pudiendo caminar")
	for i in range(IDLE_FRAMES):
		await _driver.tree.process_frame
	_report.check(_driver.manager._run.index == index and _driver.manager.state == GameManager.State.PUERTA_ABIERTA, "tras acertar no avanza solo")
	_driver.answer(_driver.wrong_answer())
	await _driver.tree.process_frame
	_report.check(_driver.manager.state == GameManager.State.PUERTA_ABIERTA and _driver.manager._run.correct == 1, "no se puede responder dos veces")
	_driver.manager._toggle_pause()
	_report.check(_driver.manager._paused and not _driver.player().can_move, "la pausa funciona con la puerta abierta")
	_driver.manager._toggle_pause()
	_report.check(not _driver.manager._paused and _driver.player().can_move, "la pausa se quita con la puerta abierta")


## Camino real: el jugador junto a la puerta, la tecla E y el botón de cruzar.
func _check_door_crossed_with_e() -> void:
	var index: int = _driver.manager._run.index
	await _driver.teleport_player(DOOR_APPROACH)
	var door := _driver.room().get_node("World/Door/Interactable") as Interactable
	_report.check(_driver.player().get_interactable() == door, "junto a la puerta, la puerta es el objeto a inspeccionar")
	await _press_interact()
	var hud := _driver.manager._hud
	_report.check(_driver.manager.state == GameManager.State.MENSAJE and hud._action_button.visible, "E en la puerta abierta ofrece cruzarla")
	hud._action_button.pressed.emit()
	await _driver.await_idle()
	_report.check(_driver.manager._run.index == index + 1, "cruzar la puerta lleva a la ronda siguiente (%d -> %d)" % [index, _driver.manager._run.index])
	_report.check(_driver.manager.state == GameManager.State.EXPLORACION, "la ronda nueva empieza en exploración")


func _check_failure_restarts() -> void:
	var games_before := Session.attempts
	_driver.answer(_driver.wrong_answer())
	_report.check(await _driver.await_state(GameManager.State.REFERENCIA), "fallar devuelve a la referencia")
	_report.check(_driver.manager._run.index == 0 and _driver.manager._run.correct == 0, "fallar reinicia el marcador")
	_report.check(Session.attempts == games_before + 1, "fallar cuenta un intento más (%d -> %d)" % [games_before, Session.attempts])


func _check_threats_retire() -> void:
	await _driver.await_idle()
	await _driver.enter_decision_room()
	await _driver.force_anomaly(GameDriver.load_anomaly("testigo_cuarto"))
	var monster := _driver.room().get_monster()
	_driver.answer(AnswerEvaluator.Answer.ANOMALY)
	await _driver.settle_physics()
	await _driver.teleport_player(monster.global_position)
	_report.check(monster.is_retired(), "al acertar, el Testigo se retira")
	_report.check(_driver.manager.state == GameManager.State.PUERTA_ABIERTA, "tras acertar, ponerse sobre el Testigo no mata")
	_report.check(not _driver.manager._hud._danger_label.visible, "tras acertar no queda aviso de peligro")
	await _check_entities_fade_and_harmless_stays()


func _check_entities_fade_and_harmless_stays() -> void:
	await _driver.restart()
	await _driver.enter_decision_room()
	await _driver.force_anomaly(GameDriver.load_anomaly("figura_cama"))
	_driver.answer(AnswerEvaluator.Answer.ANOMALY)
	await _driver.tree.process_frame
	_report.check(not _driver.room().get_node("World/UnderBedHand").visible, "al acertar, la mano bajo la cama se desvanece")
	var harmless := _harmless_anomaly_that_shows()
	await _driver.restart()
	await _driver.enter_decision_room()
	await _driver.force_anomaly(harmless.anomaly)
	_driver.answer(AnswerEvaluator.Answer.ANOMALY)
	await _driver.tree.process_frame
	_report.check(_driver.room().get_node("World/" + harmless.node).visible, "una anomalía inofensiva (%s) sigue visible tras acertar" % harmless.anomaly.id)


func _check_last_door_finishes() -> void:
	await _driver.restart()
	await _driver.enter_decision_room()
	var last_index: int = _driver.manager._rooms.size() - 1
	while _driver.manager._run.index < last_index:
		_driver.answer(_driver.correct_answer())
		_driver.cross_door()
		await _driver.await_idle()
	_driver.answer(_driver.correct_answer())
	_report.check(_driver.manager.state == GameManager.State.PUERTA_ABIERTA, "en la ronda 11, acertar abre la puerta sin terminar")
	_driver.cross_door()
	_report.check(await _driver.await_state(GameManager.State.FINAL), "cruzar la última puerta lleva a la pantalla final")
	_report.check(Session.attempts >= 1, "la sesión lleva la cuenta de intentos (%d)" % Session.attempts)


func _press_interact() -> void:
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	Input.parse_input_event(event)
	for i in range(INPUT_FRAMES):
		await _driver.tree.process_frame
	var release := InputEventAction.new()
	release.action = "interact"
	release.pressed = false
	Input.parse_input_event(release)
	await _driver.tree.process_frame


## Primera anomalía inofensiva del catálogo que muestra un nodo.
func _harmless_anomaly_that_shows() -> Dictionary:
	for anomaly: AnomalyData in CatalogLoader.load_all("res://resources/anomalies/", AnomalyData):
		if anomaly.is_dangerous:
			continue
		for modification in anomaly.modifications:
			if modification is AnomalyModification and modification.mode == AnomalyModification.Mode.SHOW:
				return {"anomaly": anomaly, "node": modification.target_node}
	return {}