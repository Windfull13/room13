extends RefCounted

## Bloque C y flujo completo: tarjetas de aprendizaje en los pasillos, pre y
## post-juego de principio a fin, pausa con Esc, y el recorrido real
## menú → pre-juego → partida (con un fallo) → post-juego → menú.

const Reporter := preload("res://tests/reporter.gd")
const GameDriver := preload("res://tests/game_driver.gd")
const MENU_SCENE := "res://scenes/main_menu.tscn"
const PRE_GAME := "res://scenes/learning/pre_game.tscn"
const POST_GAME := "res://scenes/learning/post_game.tscn"
const GAME := "res://scenes/partida.tscn"
const CINEMATIC := "res://scenes/cinematic/last_door.tscn"
const TEMP_RESULTS := "user://zz_flow_results/"
const FAST_TIME := 6.0
const CORRIDOR_PACING := 0.1
const FRAME_BUDGET := 2400
const QUESTION_COUNT := 8
const PRE_CORRECT := 3
const POST_CORRECT := 7

var _report: Reporter
var _tree: SceneTree
var _content: LearningContent
var _questions: Array[TriviaQuestion]
var _session: Node
var _default_store: ResultsStore


func run(report: Reporter, tree: SceneTree) -> void:
	report.start("Aprendizaje C: tarjetas, pre-juego, post-juego y flujo completo")
	_report = report
	_tree = tree
	_content = LearningContent.default()
	_questions = LearningContent.questions()
	_session = tree.root.get_node("Session")
	_default_store = _session.store
	_session.store = ResultsStore.new(TEMP_RESULTS)
	_check_corridor_durations()
	await _check_cards_in_corridors()
	await _check_pre_game_stage()
	await _check_post_game_stage()
	await _check_full_flow()
	_session.store = _default_store
	_clean_results()

# ---------------------------------------------------------------------------
# Ayudantes
# ---------------------------------------------------------------------------

func _clean_results() -> void:
	var global := ProjectSettings.globalize_path(TEMP_RESULTS)
	if DirAccess.dir_exists_absolute(global):
		for file_name in DirAccess.get_files_at(global):
			DirAccess.remove_absolute(global + file_name)
		DirAccess.remove_absolute(global)


func _settle(frames: int = 6) -> void:
	for i in range(frames):
		await _tree.process_frame


func _send_action(action: String) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	await _tree.process_frame
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)
	await _tree.process_frame


func _await_scene(path: String) -> Node:
	for i in range(FRAME_BUDGET):
		var scene := _tree.current_scene
		if scene != null and scene.scene_file_path == path and scene.is_node_ready():
			return scene
		await _tree.process_frame
	return null


func _await_view(flow: LearningFlow, view_class: Variant) -> Control:
	for i in range(FRAME_BUDGET):
		if is_instance_of(flow.current_view(), view_class):
			return flow.current_view()
		await _tree.process_frame
	return null


func _button_with(view: Node, text: String) -> Button:
	for node in view.find_children("*", "Button", true, false):
		if (node as Button).text == text:
			return node as Button
	return null


## Contesta las 8 preguntas acertando las primeras `correct_count`.
func _answer_trivia(view: TriviaView, correct_count: int) -> void:
	_button_with(view, "EMPEZAR").pressed.emit()
	for i in range(QUESTION_COUNT):
		if i < correct_count:
			view.choose(view._order.find(_questions[i].correct_index))
		else:
			view.choose(view.options_on_screen().size() - 1)


func _read_pages(flow: LearningFlow) -> void:
	for i in range(FRAME_BUDGET):
		if not is_instance_valid(flow):
			return
		var view := flow.current_view() as PageView
		if view == null:
			return
		view.advance()
		await _tree.process_frame


func _fill_survey(view: SurveyView, comment: String) -> void:
	for item in range(7):
		view.select(item, 4)
	view.comment_field().text = comment
	view.submit_button().pressed.emit()


func _watch_leaving(flow: LearningFlow) -> Array:
	var destination: Array = []
	flow.leaving.connect(func(path: String) -> void: destination.append(path))
	return destination

# ---------------------------------------------------------------------------
# Tarjetas en los pasillos
# ---------------------------------------------------------------------------

func _check_corridor_durations() -> void:
	var all_ok := true
	for card in _content.corridor_cards + PackedStringArray([_content.closing_card]):
		var expected := minf(maxf(3.4, 2.2 + 0.045 * card.length()), 7.0)
		all_ok = all_ok and is_equal_approx(GameManager.corridor_time_for(card), expected)
	_report.check(all_ok, "la duración del pasillo con tarjeta es max(3,4; 2,2 + 0,045 × caracteres) con tope de 7 s (11 tarjetas)")
	_report.check(GameManager.corridor_time_for("") == 3.4, "sin tarjeta el pasillo dura 3,4 s")
	_report.check(GameManager.corridor_time_for("x".repeat(40)) == 4.0 and GameManager.corridor_time_for("x".repeat(200)) == 7.0, "tarjeta corta: 2,2 + 0,045×40 = 4,0 s; tarjeta larguísima: tope 7 s")
	var shortest := 999.0
	for card in _content.corridor_cards:
		shortest = minf(shortest, GameManager.corridor_time_for(card))
	_report.check(shortest >= 3.4, "ningún pasillo con tarjeta es más corto que el normal (%.2f s)" % shortest)


func _check_cards_in_corridors() -> void:
	var driver := GameDriver.new(_tree)
	await driver.boot()
	var manager := driver.manager
	var shown_ok := 0
	var timing_ok := 0
	var rounds := manager._rooms.size()
	for next_index in range(1, rounds + 1):
		if next_index > 1:
			driver.answer(driver.correct_answer())
		manager.pacing = CORRIDOR_PACING
		driver.cross_door()
		var observed := await _watch_corridor(manager)
		manager.pacing = 0.0
		var expected: String = _content.closing_card if next_index == rounds else _content.corridor_cards[next_index - 1]
		shown_ok += 1 if observed["card"] == expected else 0
		var memory := MemoryTexts.default().corridor_memory_for(next_index) if next_index < rounds else null
		var walk: float = GameManager.corridor_time_for(expected, memory.caption() if memory != null else "") * CORRIDOR_PACING
		timing_ok += 1 if observed["seconds"] >= walk * 0.9 and observed["seconds"] <= walk + 0.7 + 1.5 else 0
		if next_index < rounds:
			await driver.await_idle()
			await driver.await_state(GameManager.State.EXPLORACION)
		else:
			await driver.await_state(GameManager.State.FINAL)
	_report.check(shown_ok == rounds, "cada pasillo muestra su tarjeta: 10 de aprendizaje + la de cierre (%d de %d)" % [shown_ok, rounds])
	_report.check(timing_ok == rounds, "la duración real de cada pasillo respeta la fórmula con tiempo escalado (%d de %d)" % [timing_ok, rounds])
	_report.check(manager.state == GameManager.State.FINAL, "tras el pasillo de cierre la partida queda en FINAL")
	await driver.shutdown()


## Espera a que aparezca el pasillo y a que desaparezca; devuelve su tarjeta y lo que duró.
func _watch_corridor(manager: GameManager) -> Dictionary:
	var corridor: Corridor = null
	for i in range(FRAME_BUDGET):
		for child in manager.get_children():
			if child is Corridor:
				corridor = child
		if corridor != null:
			break
		await _tree.process_frame
	if corridor == null:
		return {"card": "(no hubo pasillo)", "seconds": 0.0}
	var started := Time.get_ticks_msec()
	for i in range(FRAME_BUDGET):
		if not corridor.card_text().is_empty():
			break
		await _tree.process_frame
	var card := corridor.card_text()
	while is_instance_valid(corridor) and not corridor.is_queued_for_deletion():
		await _tree.process_frame
	return {"card": card, "seconds": (Time.get_ticks_msec() - started) / 1000.0}

# ---------------------------------------------------------------------------
# Pre-juego
# ---------------------------------------------------------------------------

func _check_pre_game_stage() -> void:
	_session.begin_new()
	_tree.change_scene_to_file(PRE_GAME)
	await _settle(10)
	var flow := _tree.current_scene as LearningFlow
	flow.navigates = false
	Engine.time_scale = FAST_TIME
	var destination := _watch_leaving(flow)
	var consent := await _await_view(flow, InfoView) as InfoView
	_report.check(consent != null, "el pre-juego empieza por propósito y consentimiento")
	consent.buttons()[0].pressed.emit()
	var trivia := await _await_view(flow, TriviaView) as TriviaView
	_report.check(trivia != null and _session.consent == true, "PARTICIPAR Y GUARDAR registra el consentimiento y pasa a la trivia inicial")
	# Esc en mitad de la trivia: pausa sin perder la pregunta ni la vista.
	_button_with(trivia, "EMPEZAR").pressed.emit()
	trivia.choose(0)
	trivia.choose(0)
	await _send_action("pause")
	_report.check(flow.is_paused() and flow.current_view() == trivia and trivia.question_index() == 2, "Esc abre la pausa sin cambiar de pregunta (pregunta %d)" % (trivia.question_index() + 1))
	await _send_action("pause")
	_report.check(not flow.is_paused() and flow.current_view() == trivia and trivia.question_index() == 2, "Esc otra vez reanuda en la misma pregunta")
	for i in range(2, QUESTION_COUNT):
		trivia.choose(trivia._order.find(_questions[i].correct_index) if i < PRE_CORRECT + 2 else trivia.options_on_screen().size() - 1)
	var howto := await _await_view(flow, HowToView) as HowToView
	_report.check(howto != null, "tras la trivia inicial viene «Cómo jugar»")
	var record: Dictionary = _session.store.load_record(_session.participant_id)
	_report.check(record.get("consent") == true and record["pre"]["answers"].size() == QUESTION_COUNT and record["pre"]["score"] != null, "la trivia inicial queda guardada en el JSON antes de jugar")
	_report.check(record["post"]["score"] == null and record["completed"] == false, "el JSON aún no tiene trivia final ni está completado")
	howto.close_button().pressed.emit()
	var pages := await _await_view(flow, PageView) as PageView
	_report.check(pages != null, "después viene la historia de entrada")
	var shown: PackedStringArray = []
	for i in range(_content.intro_pages.size()):
		shown.append((pages.find_children("*", "Label", true, false)[0] as Label).text)
		for frame in range(FRAME_BUDGET):
			pages.advance()
			if pages.page_index() > i or pages.is_done():
				break
			await _tree.process_frame
	_report.check(shown == _content.intro_pages, "las 4 páginas de la historia salen en orden y tal cual los datos")
	for i in range(FRAME_BUDGET):
		if not destination.is_empty():
			break
		await _tree.process_frame
	_report.check(destination == [GAME], "al terminar la historia se pasa a la partida (%s)" % str(destination))
	Engine.time_scale = 1.0
	flow.queue_free()
	await _tree.process_frame

# ---------------------------------------------------------------------------
# Post-juego
# ---------------------------------------------------------------------------

func _check_post_game_stage() -> void:
	_session.begin_new()
	_session.record_consent(true)
	var pre_answers := {}
	for q in _questions:
		pre_answers[q.id] = -1
	_session.record_pre(pre_answers)
	_session.save()
	_tree.change_scene_to_file(POST_GAME)
	await _settle(10)
	var flow := _tree.current_scene as LearningFlow
	flow.navigates = false
	Engine.time_scale = FAST_TIME
	var destination := _watch_leaving(flow)
	var pages := await _await_view(flow, PageView) as PageView
	_report.check(pages != null, "el post-juego empieza por el epílogo")
	await _read_pages(flow)
	var trivia := await _await_view(flow, TriviaView) as TriviaView
	_report.check(trivia != null and (trivia.find_children("*", "Label", true, false).any(func(l: Label) -> bool: return l.text == _content.trivia_intro_final)), "el epílogo da paso a la trivia final con su introducción")
	_answer_trivia(trivia, POST_CORRECT)
	var results := await _await_view(flow, ResultsView) as ResultsView
	_report.check(results != null and results.summary_text() == "Trivia inicial 0/8 · Trivia final 7/8 · Mejora +7", "los resultados muestran la mejora: %s" % (results.summary_text() if results != null else "(sin vista)"))
	_report.check(results != null and results.memories_text() == "Recuerdos de objeto encontrados: 0 de 20.", "los resultados dicen cuántos recuerdos de objeto se encontraron: %s" % (results.memories_text() if results != null else ""))
	var saved: Dictionary = _session.store.load_record(_session.participant_id)
	_report.check(saved["post"]["score"] == 7 and saved["gain"] == 7 and is_equal_approx(saved["normalized_gain"], 7.0 / 8.0), "la trivia final queda guardada con ganancia 7 y normalizada 7/8")
	await _send_action("pause")
	_report.check(flow.is_paused() and flow.current_view() == results, "Esc abre la pausa en los resultados sin romper el flujo")
	await _send_action("pause")
	_button_with(results, "CONTINUAR").pressed.emit()
	var survey := await _await_view(flow, SurveyView) as SurveyView
	_report.check(survey != null, "tras los resultados viene la encuesta")
	_fill_survey(survey, "Me hizo pensar")
	var help := await _await_view(flow, InfoView) as InfoView
	var final_record: Dictionary = _session.store.load_record(_session.participant_id)
	_report.check(final_record["completed"] == true and final_record["survey"]["comment"] == "Me hizo pensar" and final_record["survey"]["u1"] == 4, "la encuesta se guarda en el JSON y marca completed")
	_report.check(help != null and help.buttons().size() == 1, "la última pantalla es la de ayuda y agradecimiento")
	var finished_id: String = _session.participant_id
	help.buttons()[0].pressed.emit()
	for i in range(FRAME_BUDGET):
		if not destination.is_empty():
			break
		await _tree.process_frame
	_report.check(destination == [MENU_SCENE] and _session.participant_id != finished_id, "VOLVER AL MENÚ cierra la sesión (otro identificador)")
	Engine.time_scale = 1.0
	flow.queue_free()
	await _tree.process_frame

# ---------------------------------------------------------------------------
# Recorrido completo con cambios de escena reales
# ---------------------------------------------------------------------------

func _check_full_flow() -> void:
	_tree.change_scene_to_file(MENU_SCENE)
	var menu := await _await_scene(MENU_SCENE) as Control
	await _settle(10)
	var first_id: String = _session.participant_id
	_button_with(menu, "INICIAR PARTIDA").pressed.emit()
	var flow := await _await_scene(PRE_GAME) as LearningFlow
	_report.check(flow != null and _session.participant_id != first_id, "menú → INICIAR PARTIDA abre el pre-juego con identificador nuevo")
	Engine.time_scale = FAST_TIME
	var consent := await _await_view(flow, InfoView) as InfoView
	consent.buttons()[0].pressed.emit()
	var trivia := await _await_view(flow, TriviaView) as TriviaView
	_answer_trivia(trivia, PRE_CORRECT)
	var howto := await _await_view(flow, HowToView) as HowToView
	howto.close_button().pressed.emit()
	await _read_pages(flow)
	var game := await _await_scene(GAME) as GameManager
	Engine.time_scale = 1.0
	_report.check(game != null, "completado el pre-juego se abre la partida")
	if game == null:
		return
	game.pacing = 0.0
	var driver := GameDriver.new(_tree)
	driver.manager = game
	await driver.await_state(GameManager.State.REFERENCIA)
	await driver.await_idle()
	_report.check(game._run.index == 0 and game._rooms[0].is_reference, "la partida empieza en la habitación de referencia")
	var id: String = _session.participant_id
	var pre_score: int = _session.pre_score()
	var attempts_before: int = _session.attempts
	await driver.enter_decision_room()
	driver.answer(driver.wrong_answer())
	await driver.await_state(GameManager.State.REFERENCIA)
	await driver.await_idle()
	_report.check(_tree.current_scene == game and _tree.root.find_children("*", "LearningFlow", true, false).is_empty(), "un fallo vuelve a la referencia SIN repetir el pre-juego")
	_report.check(_session.participant_id == id and _session.pre_score() == pre_score and _session.consent == true, "tras el fallo la sesión conserva identificador, consentimiento y trivia inicial")
	_report.check(_session.attempts == attempts_before + 1, "el fallo cuenta un intento más (%d → %d)" % [attempts_before, _session.attempts])
	await driver.enter_decision_room()
	var last_index: int = game._rooms.size() - 1
	while game._run.index < last_index:
		driver.answer(driver.correct_answer())
		driver.cross_door()
		await driver.await_idle()
	driver.answer(driver.correct_answer())
	driver.cross_door()
	var cinematic := await _await_scene(CINEMATIC) as LastDoorCinematic
	_report.check(cinematic != null, "completar la ronda 10 abre la cinemática final")
	if cinematic != null:
		cinematic.pacing = 0.0
	var post_flow := await _await_scene(POST_GAME) as LearningFlow
	_report.check(post_flow != null, "tras la cinemática se abre el post-juego")
	if post_flow == null:
		return
	Engine.time_scale = FAST_TIME
	await _read_pages(post_flow)
	var final_trivia := await _await_view(post_flow, TriviaView) as TriviaView
	_answer_trivia(final_trivia, POST_CORRECT)
	var results := await _await_view(post_flow, ResultsView) as ResultsView
	_button_with(results, "CONTINUAR").pressed.emit()
	var survey := await _await_view(post_flow, SurveyView) as SurveyView
	_fill_survey(survey, "")
	var help := await _await_view(post_flow, InfoView) as InfoView
	help.buttons()[0].pressed.emit()
	var back := await _await_scene(MENU_SCENE)
	Engine.time_scale = 1.0
	_report.check(back != null and _session.participant_id != id and _session.attempts == 0, "volver al menú reinicia la sesión (identificador nuevo, 0 intentos)")
	var record: Dictionary = _session.store.load_record(id)
	_report.check(record.get("completed") == true and record["attempts"] == attempts_before + 1 and record["pre"]["score"] == PRE_CORRECT and record["post"]["score"] == POST_CORRECT, "el JSON del participante refleja el recorrido (intentos %s, pre %s, post %s)" % [str(record.get("attempts")), str(record["pre"]["score"]), str(record["post"]["score"])])
	_report.check(record["gain"] == POST_CORRECT - PRE_CORRECT and float(record["play_seconds"]) > 0.0, "ganancia %d y segundos de juego > 0 (%.1f)" % [POST_CORRECT - PRE_CORRECT, float(record["play_seconds"])])
	_tree.current_scene.queue_free()
	await _tree.process_frame
