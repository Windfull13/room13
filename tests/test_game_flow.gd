extends RefCounted

## Flujo de partida: un fallo y una muerte con susto devuelven a la ronda 0 con
## estado limpio, y completar las habitaciones lleva a la pantalla final.

const Reporter := preload("res://tests/reporter.gd")
const GameDriver := preload("res://tests/game_driver.gd")
const DANGEROUS := "figura_cama"


func run(report: Reporter, tree: SceneTree) -> void:
	report.start("Flujo de partida")
	var driver := GameDriver.new(tree)
	report.check(await driver.boot(), "la partida arranca en la habitación de referencia")
	report.check(not driver.manager._hud._decision_bar.visible, "la referencia no muestra los botones de decisión")
	await _check_failure_restarts(report, driver)
	await _check_jumpscare_death(report, driver)
	await _check_end_screen(report, driver)
	await driver.shutdown()


func _check_failure_restarts(report: Reporter, driver: GameDriver) -> void:
	await driver.enter_decision_room()
	report.check(driver.manager._hud._decision_bar.visible, "la habitación de decisión sí muestra los botones")
	await driver.force_anomaly(null)
	driver.answer(AnswerEvaluator.Answer.ANOMALY)
	report.check(await driver.await_state(GameManager.State.REFERENCIA), "un fallo devuelve a la habitación de referencia")
	report.check(_is_clean(driver.manager), "el reinicio deja el estado limpio")
	report.check(not driver.manager._hud._result_container.visible, "no queda ningún panel de error en pantalla")


func _check_jumpscare_death(report: Reporter, driver: GameDriver) -> void:
	await driver.enter_decision_room()
	var manager := driver.manager
	manager.pacing = 1.0
	var anomaly := GameDriver.load_anomaly(DANGEROUS)
	await driver.force_anomaly(anomaly)
	manager._jumpscares.last_played_path = ""
	driver.answer(AnswerEvaluator.Answer.NO_ANOMALY)
	report.check(manager.state == GameManager.State.MUERTE, "negar una anomalía peligrosa mata")
	report.check(await driver.await_state(GameManager.State.REFERENCIA), "tras el susto vuelve la habitación de referencia")
	report.check(manager._jumpscares.last_played_path == anomaly.jumpscare_scene.resource_path, "se reproduce el susto propio de la entidad")
	report.check(_is_clean(manager), "tras el susto el estado queda limpio")
	manager.pacing = 0.0


func _check_end_screen(report: Reporter, driver: GameDriver) -> void:
	var finished := [false]
	driver.manager.finished.connect(func() -> void: finished[0] = true)
	driver.manager._finish()
	await driver.tree.process_frame
	await driver.tree.process_frame
	report.check(driver.manager.state == GameManager.State.FINAL and finished[0], "al terminar, la partida queda en FINAL y avisa con la señal finished")
	report.check(not driver.manager._hud._end_panel.visible, "la pantalla «FIN DE LA PARTIDA» ya no existe: el final lo cuenta el post-juego")


func _is_clean(manager: GameManager) -> bool:
	if manager._run.index != 0 or manager._run.correct != 0 or not manager._run.previous_anomaly_id.is_empty():
		return false
	var room: Room = manager._room
	if room == null or not is_instance_valid(room):
		return false
	if not room.is_door_unlocked():
		return false
	var players := 0
	var monsters := 0
	for child in room.get_node("World").get_children():
		if child is Player:
			players += 1
		elif child is Monster:
			monsters += 1
	return players == 1 and monsters == 0