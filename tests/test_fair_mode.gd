extends RefCounted

## Modo feria: TERMINAR Y EVALUAR en la pausa de la partida, confirmaciones,
## finalización anticipada (sin cinemática ni epílogo), datos de la sesión,
## regreso automático desde la pantalla de agradecimiento y análisis agregado.
## Con FairMode.enabled = false nada de esto aparece.

const Reporter := preload("res://tests/reporter.gd")
const ScreenCatalog := preload("res://dev/screen_catalog.gd")
const GameDriver := preload("res://tests/game_driver.gd")
const MENU := "res://scenes/main_menu.tscn"
const PRE_GAME := "res://scenes/learning/pre_game.tscn"
const GAME := "res://scenes/partida.tscn"
const POST_GAME := "res://scenes/learning/post_game.tscn"
const TEMP_RESULTS := "user://zz_feria/"
const SAMPLE_DIR := "res://dev/out/ejemplo_resultados"
const ANALYZER := "res://dev/analyze_results.py"
const ANALYSIS_OUT := "user://zz_feria_analisis/"
const ENOUGH_SECONDS := 300.0
const FRAME_BUDGET := 6000
const UI_TIME_SCALE := 25.0
const IDLE_SCALE := 0.02
const QUESTION_COUNT := 8
const DEFAULT_EARLY_RUNS := 30

var _report: Reporter
var _tree: SceneTree
var _session: Node
var _audio: Node
var _content: LearningContent
var _rng := RandomNumberGenerator.new()


func run(report: Reporter, tree: SceneTree) -> void:
	report.start("Modo feria: terminar y evaluar, confirmaciones, datos y análisis")
	_report = report
	_tree = tree
	_session = tree.root.get_node("Session")
	_audio = tree.root.get_node("AudioManager")
	_content = LearningContent.default()
	_rng.seed = 21
	var original_store: ResultsStore = _session.store
	_session.store = ResultsStore.new(TEMP_RESULTS)
	FairMode.enabled = FairMode.FAIR_MODE
	_check_constants_and_texts()
	await _check_button_visibility()
	await _check_other_pauses_have_no_button()
	await _check_confirmation_and_keyboard()
	await _check_early_flow_and_record()
	await _check_menu_confirmation()
	await _check_idle_return()
	await _check_fair_mode_off()
	_check_old_json_and_analyzer()
	await _check_early_finishes_stability()
	FairMode.enabled = FairMode.FAIR_MODE
	_session.store = original_store
	_clean(TEMP_RESULTS)
	_clean(ANALYSIS_OUT)

# ---------------------------------------------------------------------------
# Ayudantes
# ---------------------------------------------------------------------------

func _clean(directory: String) -> void:
	var global := ProjectSettings.globalize_path(directory)
	if DirAccess.dir_exists_absolute(global):
		for file_name in DirAccess.get_files_at(global):
			DirAccess.remove_absolute(global + file_name)
		DirAccess.remove_absolute(global)


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


func _prepare_session(has_initial: bool, seconds: float, consent: bool = true) -> void:
	_session.begin_new()
	_session.record_consent(consent)
	if has_initial:
		_session.record_pre(_answers(3))
	_session.play_seconds = seconds


func _answers(correct: int) -> Dictionary:
	var answers := {}
	var questions := LearningContent.questions()
	for i in range(questions.size()):
		answers[questions[i].id] = questions[i].correct_index if i < correct else -1
	return answers


func _boot_game_paused() -> GameDriver:
	var driver := GameDriver.new(_tree)
	await driver.boot()
	await driver.enter_decision_room()
	driver.manager._toggle_pause()
	await _tree.process_frame
	return driver


func _find_button(root: Node, text: String) -> Button:
	for node in root.find_children("*", "Button", true, false):
		if (node as Button).text == text:
			return node as Button
	return null


func _await_scene(path: String) -> Node:
	for i in range(FRAME_BUDGET):
		var scene := _tree.current_scene
		if scene != null and scene.scene_file_path == path and scene.is_node_ready():
			return scene
		await _tree.process_frame
	return null


func _await_view(flow: LearningFlow, view_class: Variant) -> Control:
	for i in range(FRAME_BUDGET):
		if is_instance_valid(flow) and is_instance_of(flow.current_view(), view_class):
			return flow.current_view()
		await _tree.process_frame
	return null


func _labels(root: Node) -> String:
	var parts: PackedStringArray = []
	for node in root.find_children("*", "Label", true, false):
		parts.append((node as Label).text)
	return "\n".join(parts)


func _free_current_scene() -> void:
	if _tree.current_scene != null:
		if _tree.current_scene is LearningFlow:
			(_tree.current_scene as LearningFlow).navigates = false
		_tree.current_scene.queue_free()
	await _tree.process_frame

# ---------------------------------------------------------------------------
# Constantes y textos
# ---------------------------------------------------------------------------

func _check_constants_and_texts() -> void:
	_report.check(FairMode.FAIR_MODE == true and FairMode.FAIR_MIN_PLAY_SECONDS == 240 and FairMode.FAIR_IDLE_RETURN_SECONDS == 30, "las constantes del modo feria están en un solo archivo: true, 240 s y 30 s")
	_report.check(_content.fair_pause_hint == "Si ya has jugado un rato, puedes terminar y responder la trivia final.", "texto de la pausa tal cual")
	_report.check(_content.fair_finish_confirm == "¿Terminar la partida y responder la trivia final? No podrás volver a la habitación." and _content.fair_finish_button == "TERMINAR Y EVALUAR" and _content.fair_keep_playing == "SEGUIR JUGANDO", "confirmación de terminar y botones tal cual")
	_report.check(_content.fair_menu_confirm == "Si sales ahora, no responderás la trivia final y tu sesión se cerrará." and _content.fair_menu_accept == "SALIR AL MENÚ", "confirmación de salir al menú tal cual")
	_report.check(_content.early_finish_page == "Has decidido terminar aquí. Antes de salir, responde las mismas preguntas del principio con lo que recuerdes.", "página de finalización anticipada tal cual (en learning_content.tres)")
	_report.check(FairMode.can_offer_finish(true, 240) and not FairMode.can_offer_finish(true, 239.9) and not FairMode.can_offer_finish(false, 999), "can_offer_finish: trivia inicial y ≥ 240 s")
	_report.check(FairMode.menu_needs_confirmation(true, false) and not FairMode.menu_needs_confirmation(true, true) and not FairMode.menu_needs_confirmation(false, false), "menu_needs_confirmation: solo con trivia inicial y sin final")

# ---------------------------------------------------------------------------
# Visibilidad del botón
# ---------------------------------------------------------------------------

func _check_button_visibility() -> void:
	_prepare_session(true, ENOUGH_SECONDS)
	var driver := await _boot_game_paused()
	var hud := driver.manager._hud
	_report.check(hud.is_evaluate_visible(), "con modo feria, trivia inicial y ≥ 240 s, la pausa muestra TERMINAR Y EVALUAR")
	_report.check(hud.evaluate_hint_text() == _content.fair_pause_hint and hud._evaluate_hint.visible, "y el aviso «Si ya has jugado un rato…»")
	_report.check(hud._evaluate_button.get_theme_font_size("font_size") > 0 and hud._evaluate_button.text == "TERMINAR Y EVALUAR", "el botón usa el tema del juego")
	await _tree.create_timer(0.4).timeout
	var pause_problems := ScreenCatalog.layout_problems(hud.get_node("Root/PausePanel"))
	_report.check(pause_problems.is_empty(), "la pausa con el botón y el aviso cabe en 1280×720 sin solapes %s" % str(pause_problems))
	await driver.shutdown()
	for case in [[false, ENOUGH_SECONDS, "sin trivia inicial"], [true, 239.0, "con menos de 240 s"]]:
		_prepare_session(case[0], case[1])
		var other := await _boot_game_paused()
		_report.check(not other.manager._hud.is_evaluate_visible() and not other.manager._hud._evaluate_hint.visible, "%s: ni botón ni aviso" % case[2])
		await other.shutdown()
	_prepare_session(true, ENOUGH_SECONDS)
	var closed := await _boot_game_paused()
	closed.manager._toggle_pause()
	await _tree.process_frame
	closed.manager._toggle_pause()
	await _tree.process_frame
	_report.check(closed.manager._hud.is_evaluate_visible(), "al reabrir la pausa sigue disponible")
	_session.play_seconds = 10.0
	closed.manager._toggle_pause()
	await _tree.create_timer(0.4).timeout
	closed.manager._toggle_pause()
	await _tree.process_frame
	_report.check(not closed.manager._hud.is_evaluate_visible(), "se decide cada vez que se abre la pausa")
	await closed.shutdown()


func _check_other_pauses_have_no_button() -> void:
	_prepare_session(true, ENOUGH_SECONDS)
	for scene_path in [PRE_GAME, POST_GAME]:
		_tree.change_scene_to_file(scene_path)
		var flow := await _await_scene(scene_path) as LearningFlow
		flow.navigates = false
		await _send_action("pause")
		_report.check(flow.is_paused() and _find_button(flow.pause_overlay(), "TERMINAR Y EVALUAR") == null, "la pausa de %s no tiene TERMINAR Y EVALUAR" % scene_path.get_file())
		await _free_current_scene()

# ---------------------------------------------------------------------------
# Confirmación (ratón y teclado)
# ---------------------------------------------------------------------------

func _check_confirmation_and_keyboard() -> void:
	_prepare_session(true, ENOUGH_SECONDS)
	var driver := await _boot_game_paused()
	var manager := driver.manager
	var hud := manager._hud
	hud._evaluate_button.pressed.emit()
	await _tree.process_frame
	var buttons := hud.confirm_buttons()
	_report.check(hud.is_confirm_visible() and hud._confirm_text.text == _content.fair_finish_confirm, "TERMINAR Y EVALUAR pide confirmación con el texto pedido")
	var confirm_problems := ScreenCatalog.layout_problems(hud._confirm_panel)
	_report.check(confirm_problems.is_empty(), "el cuadro de confirmación cabe sin solapes %s" % str(confirm_problems))
	_report.check(buttons[0].text == "TERMINAR Y EVALUAR" and buttons[1].text == "SEGUIR JUGANDO", "con los botones TERMINAR Y EVALUAR y SEGUIR JUGANDO")
	_report.check(hud.get_viewport().gui_get_focus_owner() == buttons[1], "el teclado empieza en SEGUIR JUGANDO (la opción segura)")
	await _send_action("ui_down")
	_report.check(hud.get_viewport().gui_get_focus_owner() == buttons[1], "la flecha abajo no se sale del cuadro")
	await _send_action("ui_up")
	_report.check(hud.get_viewport().gui_get_focus_owner() == buttons[0], "la flecha arriba pasa a TERMINAR Y EVALUAR")
	await _send_action("ui_up")
	_report.check(hud.get_viewport().gui_get_focus_owner() == buttons[0], "y tampoco se sale por arriba")
	buttons[1].pressed.emit()
	await _tree.process_frame
	_report.check(not hud.is_confirm_visible() and manager._paused and manager.state == GameManager.State.EXPLORACION and not _session.ended_early, "SEGUIR JUGANDO cierra el cuadro y no cambia nada")
	_report.check(hud.get_viewport().gui_get_focus_owner() == hud._resume_button, "el foco vuelve a la pausa")
	hud._evaluate_button.pressed.emit()
	await _send_action("pause")
	_report.check(not hud.is_confirm_visible() and manager._paused and not _session.ended_early, "Esc cierra la confirmación sin reanudar ni terminar")
	hud._evaluate_button.pressed.emit()
	await _send_action("ui_up")
	var finished := [false]
	manager.finished_early.connect(func() -> void: finished[0] = true)
	await _send_action("ui_accept")
	for i in range(30):
		await _tree.process_frame
	_report.check(finished[0] and _session.ended_early and manager.state == GameManager.State.FINAL, "con el teclado (flecha arriba + Enter) se confirma y la partida termina")
	await driver.shutdown()

# ---------------------------------------------------------------------------
# Flujo completo de finalización anticipada y datos guardados
# ---------------------------------------------------------------------------

func _check_early_flow_and_record() -> void:
	_prepare_session(true, ENOUGH_SECONDS)
	var id: String = _session.participant_id
	var driver := GameDriver.new(_tree)
	await driver.boot()
	driver.manager.early_finish_scene = POST_GAME
	await driver.enter_decision_room()
	driver.answer(driver.correct_answer())
	driver.cross_door()
	await driver.await_state(GameManager.State.EXPLORACION)
	await driver.await_idle()
	var reached: int = driver.manager._run.index
	driver.manager._toggle_pause()
	await _tree.process_frame
	driver.manager._hud._evaluate_button.pressed.emit()
	driver.manager._hud.confirm_buttons()[0].pressed.emit()
	var flow := await _await_scene(POST_GAME) as LearningFlow
	_report.check(flow != null, "confirmar lleva directamente al post-juego")
	flow.navigates = false
	flow.idle_scale = IDLE_SCALE
	Engine.time_scale = UI_TIME_SCALE
	var pages := await _await_view(flow, PageView) as PageView
	_report.check(pages != null and _labels(pages).contains(_content.early_finish_page), "lo primero es la página de finalización anticipada")
	_report.check(not _labels(pages).contains(_content.epilogue_pages[0]) and _tree.root.find_children("*", "LastDoorCinematic", true, false).is_empty(), "sin epílogo ni cinemática")
	_report.check(_session.cinematic_skipped == null, "la cinemática no cuenta como vista ni como saltada")
	await _read_pages(flow)
	var trivia := await _await_view(flow, TriviaView) as TriviaView
	_report.check(trivia != null and _labels(trivia).contains(_content.trivia_intro_final), "después, la trivia final")
	await _answer_trivia(trivia)
	var results := await _await_view(flow, ResultsView) as ResultsView
	_report.check(results != null, "después, los resultados")
	_find_button(results, "CONTINUAR").pressed.emit()
	var survey := await _await_view(flow, SurveyView) as SurveyView
	_report.check(survey != null, "después, la encuesta")
	for item in range(7):
		survey.select(item, 4)
	survey.submit_button().pressed.emit()
	var record: Dictionary = _session.store.load_record(id)
	_report.check(record.get("finish_type") == "anticipado" and record.get("ended_early") == true, "el JSON guarda finish_type = anticipado y ended_early = true")
	_report.check(int(record.get("max_round_reached", -1)) == reached and reached >= 1, "max_round_reached = %s (la ronda alcanzada)" % str(record.get("max_round_reached")))
	_report.check(int(record.get("attempts", 0)) == 1 and float(record.get("play_seconds", 0.0)) >= ENOUGH_SECONDS, "guarda attempts (%s) y play_seconds (%s)" % [str(record.get("attempts")), str(record.get("play_seconds"))])
	_report.check(record.get("completed") == true and record["post"]["score"] != null, "y la sesión consta como completada con trivia final")
	var help := await _await_view(flow, InfoView) as InfoView
	_report.check(help != null, "por último, la ayuda y el agradecimiento")
	Engine.time_scale = 1.0
	await _free_current_scene()
	if is_instance_valid(driver.manager):
		driver.manager.queue_free()
	await _tree.process_frame

# ---------------------------------------------------------------------------
# MENÚ PRINCIPAL desde la pausa
# ---------------------------------------------------------------------------

func _check_menu_confirmation() -> void:
	_prepare_session(true, 10.0)
	var driver := await _boot_game_paused()
	var hud := driver.manager._hud
	var id: String = _session.participant_id
	hud._pause_menu.pressed.emit()
	await _tree.process_frame
	_report.check(hud.is_confirm_visible() and hud._confirm_text.text == _content.fair_menu_confirm, "con trivia inicial y sin final, MENÚ PRINCIPAL pide confirmación")
	_report.check(hud.confirm_buttons()[0].text == "SALIR AL MENÚ" and hud.confirm_buttons()[1].text == "SEGUIR JUGANDO", "con SALIR AL MENÚ y SEGUIR JUGANDO")
	hud.confirm_buttons()[1].pressed.emit()
	await _tree.process_frame
	_report.check(not hud.is_confirm_visible() and _session.participant_id == id and driver.manager._paused, "SEGUIR JUGANDO no cierra la sesión")
	hud._pause_menu.pressed.emit()
	hud.confirm_buttons()[0].pressed.emit()
	await _tree.process_frame
	_report.check(_session.participant_id != id, "SALIR AL MENÚ cierra la sesión (identificador nuevo)")
	await _go_back_to_menu(driver)
	await _menu_goes_straight("sin trivia inicial", false, false, true)
	await _menu_goes_straight("con la trivia final ya hecha", true, true, true)
	await _menu_goes_straight("con el modo feria apagado", true, false, false)


## Casos sin confirmación: el menú se abre de inmediato y no sale ningún cuadro.
func _menu_goes_straight(label: String, initial: bool, final: bool, fair: bool) -> void:
	_prepare_session(initial, 10.0)
	if final:
		_session.record_post(_answers(5))
	FairMode.enabled = fair
	var driver := await _boot_game_paused()
	var id: String = _session.participant_id
	driver.manager._hud._pause_menu.pressed.emit()
	await _tree.process_frame
	_report.check(not driver.manager._hud.is_confirm_visible() and _session.participant_id != id, "MENÚ PRINCIPAL %s: sin confirmación, como hoy" % label)
	FairMode.enabled = FairMode.FAIR_MODE
	await _go_back_to_menu(driver)


func _go_back_to_menu(driver: GameDriver) -> void:
	await _await_scene(MENU)
	await _free_current_scene()
	await driver.shutdown()

# ---------------------------------------------------------------------------
# Regreso automático desde la pantalla de agradecimiento
# ---------------------------------------------------------------------------

func _drive_post_to_help(flow: LearningFlow) -> InfoView:
	Engine.time_scale = UI_TIME_SCALE
	await _await_view(flow, PageView)
	await _read_pages(flow)
	await _answer_trivia(await _await_view(flow, TriviaView) as TriviaView)
	_find_button(await _await_view(flow, ResultsView), "CONTINUAR").pressed.emit()
	var survey := await _await_view(flow, SurveyView) as SurveyView
	for item in range(7):
		survey.select(item, 3)
	survey.submit_button().pressed.emit()
	return await _await_view(flow, InfoView) as InfoView


func _read_pages(flow: LearningFlow) -> void:
	for i in range(FRAME_BUDGET):
		if not is_instance_valid(flow) or not flow.current_view() is PageView:
			return
		(flow.current_view() as PageView).advance()
		await _tree.process_frame


func _answer_trivia(view: TriviaView) -> void:
	_find_button(view, "EMPEZAR").pressed.emit()
	for i in range(QUESTION_COUNT):
		view.choose(_rng.randi_range(0, 4))
	await _tree.process_frame


func _open_post_game() -> LearningFlow:
	_tree.change_scene_to_file(POST_GAME)
	var flow := await _await_scene(POST_GAME) as LearningFlow
	flow.idle_scale = IDLE_SCALE
	return flow


func _check_idle_return() -> void:
	_prepare_session(true, ENOUGH_SECONDS)
	var id: String = _session.participant_id
	var flow := await _open_post_game()
	flow.navigates = false
	var destination: Array = []
	flow.leaving.connect(func(path: String) -> void: destination.append(path))
	var help := await _drive_post_to_help(flow)
	Engine.time_scale = 1.0
	_report.check(help != null and destination.is_empty(), "en la pantalla de agradecimiento todavía no ha vuelto")
	var waited := 0.0
	while destination.is_empty() and waited < 3.0:
		await _tree.process_frame
		waited += _tree.root.get_process_delta_time()
	_report.check(destination == [MENU], "sin actividad, a los 30 s (escalados) vuelve al menú: %s tras %.2f s" % [str(destination), waited])
	_report.check(_session.participant_id != id, "y la sesión queda cerrada con otro identificador")
	await _free_current_scene()

	_prepare_session(true, ENOUGH_SECONDS)
	flow = await _open_post_game()
	flow.navigates = false
	flow.idle_scale = 0.5
	destination.clear()
	flow.leaving.connect(func(path: String) -> void: destination.append(path))
	await _drive_post_to_help(flow)
	Engine.time_scale = 1.0
	for i in range(4):
		await _tree.create_timer(flow.idle_scale * FairMode.FAIR_IDLE_RETURN_SECONDS * 0.4).timeout
		var wiggle := InputEventMouseMotion.new()
		wiggle.position = Vector2(100 + i, 100)
		Input.parse_input_event(wiggle)
		await _tree.process_frame
	_report.check(destination.is_empty(), "la actividad (ratón o teclado) reinicia la cuenta atrás")
	await _free_current_scene()

# ---------------------------------------------------------------------------
# Modo feria apagado
# ---------------------------------------------------------------------------

func _check_fair_mode_off() -> void:
	FairMode.enabled = false
	_prepare_session(true, ENOUGH_SECONDS)
	var driver := await _boot_game_paused()
	var hud := driver.manager._hud
	_report.check(not hud.is_evaluate_visible() and not hud._evaluate_hint.visible, "con FAIR_MODE = false la pausa no ofrece TERMINAR Y EVALUAR")
	hud._evaluate_button.pressed.emit()
	await _tree.process_frame
	_report.check(not hud.is_confirm_visible() and not _session.ended_early, "y aunque se forzara, no hace nada")
	_report.check(not FairMode.can_offer_finish(true, 9999) and not FairMode.menu_needs_confirmation(true, false), "las funciones de decisión devuelven false")
	await driver.shutdown()
	_prepare_session(true, ENOUGH_SECONDS)
	var flow := await _open_post_game()
	flow.navigates = false
	var destination: Array = []
	flow.leaving.connect(func(path: String) -> void: destination.append(path))
	await _drive_post_to_help(flow)
	Engine.time_scale = 1.0
	await _tree.create_timer(IDLE_SCALE * FairMode.FAIR_IDLE_RETURN_SECONDS * 3.0).timeout
	_report.check(destination.is_empty(), "sin modo feria, la pantalla de agradecimiento no vuelve sola al menú")
	await _free_current_scene()
	FairMode.enabled = FairMode.FAIR_MODE

# ---------------------------------------------------------------------------
# JSON antiguo y análisis agregado
# ---------------------------------------------------------------------------

func _run_analyzer(arguments: Array[String]) -> String:
	var output: Array = []
	var args: Array[String] = [ProjectSettings.globalize_path(ANALYZER)]
	args.append_array(arguments)
	OS.execute("python", PackedStringArray(args), output, true)
	return "".join(output)


func _check_old_json_and_analyzer() -> void:
	var sample := ProjectSettings.globalize_path(SAMPLE_DIR)
	var old_dir := ProjectSettings.globalize_path(ANALYSIS_OUT + "antiguo/")
	DirAccess.make_dir_recursive_absolute(old_dir)
	var first: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAMPLE_DIR + "/" + DirAccess.get_files_at(sample)[0]))
	for key in ["finish_type", "max_round_reached", "ended_early", "simulated"]:
		first.erase(key)
	first["participant_id"] = "0ldc0de1"
	var file := FileAccess.open(old_dir + "0ldc0de1.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(first))
	file.close()
	var store := ResultsStore.new(ANALYSIS_OUT + "antiguo/")
	var loaded := store.load_record("0ldc0de1")
	_report.check(not loaded.is_empty() and not loaded.has("finish_type"), "un JSON antiguo (sin los campos nuevos) se lee sin errores")
	var text := _run_analyzer([old_dir, "--salida", old_dir + "out"])
	var report_text := FileAccess.get_file_as_string(ANALYSIS_OUT + "antiguo/out/analisis_resultados.md")
	_report.check(text.contains("1 participantes") and report_text.contains("Terminaron la historia (**completo**): 1") and report_text.contains("(**anticipado**): 0"), "el análisis trata el JSON antiguo como «completo»")
	var out := ProjectSettings.globalize_path(ANALYSIS_OUT + "simulados")
	_run_analyzer([sample, "--include-simulated", "--salida", out])
	var simulated := FileAccess.get_file_as_string(ANALYSIS_OUT + "simulados/analisis_resultados.md")
	# A mano: completos (9) inicial 30/9 = 3,33, final 49/9 = 5,44, ganancia +2,11, normalizada 0,530, 77,8 % mejoran;
	# anticipados (3) inicial 12/3 = 4,00, final 19/3 = 6,33, ganancia +2,33, normalizada 0,667, 100 %; rondas 4, 7 y 9 → 6,67.
	for expected in [
		"(**completo**): 9", "(**anticipado**): 3", "**6.67**",
		"| Inicial | 3.50 | 1.45 |", "**+2.17**", "**0.564**", "**83.3 %**",
		"| completo | 9 | 3.33 | 5.44 | +2.11 | 0.530 | 77.8 % |",
		"| anticipado | 3 | 4.00 | 6.33 | +2.33 | 0.667 | 100.0 % |",
	]:
		_report.check(simulated.contains(expected), "cifra esperada calculada a mano: %s" % expected)
	var csv_head := FileAccess.get_file_as_string(ANALYSIS_OUT + "simulados/resultados_consolidados.csv").split("\n")[0]
	_report.check(csv_head.contains("finish_type") and csv_head.contains("max_round_reached") and csv_head.contains("ended_early"), "el CSV incluye finish_type, max_round_reached y ended_early")
	var plain := _run_analyzer([sample, "--salida", ProjectSettings.globalize_path(ANALYSIS_OUT + "sin")])
	_report.check(plain.contains("0 participantes analizados (12 simulados ignorados)"), "sin --include-simulated, los simulados se ignoran")

# ---------------------------------------------------------------------------
# Estabilidad: finalizaciones anticipadas
# ---------------------------------------------------------------------------

func _check_early_finishes_stability() -> void:
	var runs := OS.get_environment("ZIVA_FAIR_RUNS").to_int()
	runs = runs if runs > 0 else DEFAULT_EARLY_RUNS
	var players_before: int = _audio.get_child_count()
	var coherent := 0
	var rounds_seen := {}
	for i in range(runs):
		var outcome := await _early_session(i)
		coherent += 1 if outcome["ok"] else 0
		rounds_seen[outcome["round"]] = true
	Engine.time_scale = 1.0
	_report.check(coherent == runs, "%d finalizaciones anticipadas completas (menú → pre-juego → partida → terminar → post-juego → menú) con JSON coherente (%d)" % [runs, coherent])
	_report.check(rounds_seen.size() >= mini(3, runs), "terminaron en rondas distintas (%s)" % str(rounds_seen.keys()))
	await _free_current_scene()
	await _tree.process_frame
	var orphans: int = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	_report.check(orphans == 0, "sin nodos huérfanos (%d)" % orphans)
	_report.check(_audio.get_child_count() == players_before, "los reproductores de audio no se acumulan (%d → %d)" % [players_before, _audio.get_child_count()])
	_report.check(_audio.active_sounds().is_empty() and not _audio.is_voice_playing(), "no queda ningún sonido: %s" % str(_audio.active_sounds()))


func _early_session(index: int) -> Dictionary:
	var outcome := {"ok": false, "round": -1}
	Engine.time_scale = UI_TIME_SCALE
	_tree.change_scene_to_file(MENU)
	var menu := await _await_scene(MENU)
	_find_button(menu, "INICIAR PARTIDA").pressed.emit()
	var pre := await _await_scene(PRE_GAME) as LearningFlow
	var id: String = _session.participant_id
	(await _await_view(pre, InfoView) as InfoView).buttons()[0].pressed.emit()
	await _answer_trivia(await _await_view(pre, TriviaView) as TriviaView)
	(await _await_view(pre, HowToView) as HowToView).close_button().pressed.emit()
	await _read_pages(pre)
	var game := await _await_scene(GAME) as GameManager
	Engine.time_scale = 1.0
	game.pacing = 0.0
	var target := 1 + index % 10
	outcome["round"] = await _play_until(game, target)
	_session.play_seconds = ENOUGH_SECONDS
	game._toggle_pause()
	game._hud._evaluate_button.pressed.emit()
	game._hud.confirm_buttons()[0].pressed.emit()
	Engine.time_scale = UI_TIME_SCALE
	var post := await _await_scene(POST_GAME) as LearningFlow
	post.idle_scale = IDLE_SCALE
	await _drive_post_to_help(post)
	await _await_scene(MENU)
	var record: Dictionary = _session.store.load_record(id)
	outcome["ok"] = _session.participant_id != id \
		and record.get("finish_type") == "anticipado" and record.get("ended_early") == true \
		and int(record.get("max_round_reached", -1)) == outcome["round"] \
		and int(record.get("attempts", 0)) == 1 and record.get("completed") == true
	return outcome


## Juega perfecto hasta quedar en la ronda `target` (sin responder) y devuelve su índice.
func _play_until(game: GameManager, target: int) -> int:
	var handled := Vector2i(-1, -1)
	for i in range(FRAME_BUDGET):
		await _tree.process_frame
		if game._busy:
			continue
		var step := Vector2i(game._run.index, game.state)
		if game.state == GameManager.State.EXPLORACION and game._run.index >= target:
			return game._run.index
		if step == handled:
			continue
		match game.state:
			GameManager.State.EXPLORACION:
				handled = step
				game._hud.press_decision(AnswerEvaluator.Answer.ANOMALY if game._current_anomaly != null else AnswerEvaluator.Answer.NO_ANOMALY)
			GameManager.State.REFERENCIA, GameManager.State.PUERTA_ABIERTA:
				handled = step
				game._on_message_action(Room.DOOR_ACTION)
	return -1
