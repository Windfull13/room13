extends RefCounted

## Bloques A (vistas) y B: trivia, resultados, encuesta, ayuda, «Cómo jugar»,
## consentimiento, menú de 5 botones y carpeta de resultados.

const Reporter := preload("res://tests/reporter.gd")
const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const MENU_SCENE := "res://scenes/main_menu.tscn"
const PRE_GAME := "res://scenes/learning/pre_game.tscn"
const MIN_FONT_SIZE := 22
const QUESTION_COUNT := 8
const FOCUS_SLACK := 8.0
const FRAMES_TO_SETTLE := 6
## Lo que tardan en entrar los botones del menú.
const MENU_ENTRY_SECONDS := 1.3

var _report: Reporter
var _tree: SceneTree
var _content: LearningContent
var _questions: Array[TriviaQuestion]
var _viewport_rect: Rect2


func run(report: Reporter, tree: SceneTree) -> void:
	report.start("Aprendizaje B: vistas, trivia, encuesta, ayuda, cómo jugar y menú")
	_report = report
	_tree = tree
	_content = LearningContent.default()
	_questions = LearningContent.questions()
	_viewport_rect = Rect2(Vector2.ZERO, tree.root.get_visible_rect().size)
	await _check_trivia_view()
	await _check_results_view()
	await _check_survey_view()
	await _check_howto_text_and_view()
	await _check_help_lines()
	await _check_consent_view()
	await _check_menu()
	await _check_howto_from_pause_screens()

# ---------------------------------------------------------------------------
# Ayudantes
# ---------------------------------------------------------------------------

func _mount(view: Control) -> void:
	view.theme = UiTheme.build()
	_tree.root.add_child(view)


func _unmount(view: Control) -> void:
	view.queue_free()
	await _tree.process_frame


func _settle(frames: int = FRAMES_TO_SETTLE) -> void:
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


func _send_key(keycode: Key) -> void:
	var press := InputEventKey.new()
	press.keycode = keycode
	press.physical_keycode = keycode
	press.pressed = true
	Input.parse_input_event(press)
	await _tree.process_frame
	var release := InputEventKey.new()
	release.keycode = keycode
	release.physical_keycode = keycode
	release.pressed = false
	Input.parse_input_event(release)
	await _tree.process_frame


func _fits_screen(view: Control) -> bool:
	var panels := view.find_children("*", "PanelContainer", true, false)
	return not panels.is_empty() and _viewport_rect.encloses((panels[0] as Control).get_global_rect())


func _smallest_font(view: Control) -> int:
	var smallest := 999
	for node in view.find_children("*", "Label", true, false):
		var label := node as Label
		if not label.text.is_empty():
			smallest = mini(smallest, label.get_theme_font_size("font_size"))
	return smallest


func _labels_text(view: Control) -> String:
	var parts: PackedStringArray = []
	for node in view.find_children("*", "Label", true, false):
		parts.append((node as Label).text)
	return "\n".join(parts)


func _button_with(view: Node, text: String) -> Button:
	for node in view.find_children("*", "Button", true, false):
		if (node as Button).text == text:
			return node as Button
	return null

# ---------------------------------------------------------------------------
# TriviaView
# ---------------------------------------------------------------------------

func _check_trivia_view() -> void:
	var view := TriviaView.new()
	_mount(view)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var results: Array = []
	view.finished.connect(func(answers: Dictionary) -> void: results.append(answers))
	view.start(_questions, _content, _content.trivia_title_initial, _content.trivia_intro_initial, rng)
	await _settle()
	_report.check(_labels_text(view).contains(_content.trivia_intro_initial), "la trivia inicial abre con su texto de introducción")
	_report.check(_fits_screen(view), "la introducción de la trivia cabe en 1280×720")
	_button_with(view, "EMPEZAR").pressed.emit()
	await _settle()
	_report.check(_labels_text(view).contains("PREGUNTA 1/8") and view.question_index() == 0, "la primera pantalla dice «PREGUNTA 1/8»")
	var options := view.options_on_screen()
	_report.check(options.size() == 5 and options[4].text.contains("No lo sé"), "cada pregunta muestra 4 opciones y «No lo sé» como quinta")
	_report.check(_fits_screen(view) and _smallest_font(view) >= MIN_FONT_SIZE, "la pregunta cabe en pantalla y su texto es ≥ %d (%d)" % [MIN_FONT_SIZE, _smallest_font(view)])
	var text := _labels_text(view).to_lower() + " ".repeat(1)
	_report.check(not text.contains("correcto") and not text.contains("incorrecto"), "no hay ninguna pista de acierto durante la trivia")
	# Tecla 2: guarda el índice ORIGINAL de la opción mostrada en 2.ª posición.
	var shown_second: int = view._order[1]
	await _send_key(KEY_2)
	_report.check(view.question_index() == 1, "la tecla 2 contesta y pasa a la pregunta 2")
	_report.check(results.is_empty(), "no termina antes de contestar las 8")
	# Flechas + Enter: el foco empieza en la 1.ª opción; abajo → 2.ª; Enter la elige.
	var second_question_order: Array[int] = view._order.duplicate()
	await _settle(3)
	await _send_action("ui_down")
	await _send_action("ui_accept")
	_report.check(view.question_index() == 2, "flecha abajo + Enter eligen la 2.ª opción con el teclado")
	# Tecla 5 = «No lo sé»; clic con ratón en la 1.ª opción.
	await _send_key(KEY_5)
	_report.check(view.question_index() == 3, "la tecla 5 elige «No lo sé»")
	view.options_on_screen()[0].pressed.emit()
	for i in range(QUESTION_COUNT - 4):
		view.choose(0)
	await _settle()
	_report.check(results.size() == 1, "tras la octava respuesta emite sus respuestas")
	var answers: Dictionary = results[0] if not results.is_empty() else {}
	_report.check(answers.size() == QUESTION_COUNT, "guarda una respuesta por pregunta (%d)" % answers.size())
	_report.check(answers.get(_questions[0].id) == shown_second, "la respuesta se guarda por el índice ORIGINAL de la opción (%s)" % str(answers.get(_questions[0].id)))
	_report.check(answers.get(_questions[1].id) == second_question_order[1], "con flechas+Enter también se guarda el índice original")
	_report.check(answers.get(_questions[2].id) == -1, "«No lo sé» se guarda como -1")
	await _unmount(view)

# ---------------------------------------------------------------------------
# ResultsView
# ---------------------------------------------------------------------------

func _check_results_view() -> void:
	var pre := {}
	var post := {}
	for i in range(_questions.size()):
		pre[_questions[i].id] = _questions[i].correct_index if i < 2 else (-1 if i == 7 else 1)
		post[_questions[i].id] = _questions[i].correct_index if i != 3 and i != 7 else 2
	var view := ResultsView.new()
	_mount(view)
	var continued := [false]
	view.continued.connect(func() -> void: continued[0] = true)
	view.setup(_questions, pre, post)
	await _settle()
	_report.check(view.summary_text() == "Trivia inicial 2/8 · Trivia final 6/8 · Mejora +4", "resumen: «%s»" % view.summary_text())
	var text := _labels_text(view)
	_report.check(text.contains("Inicial ✓ · Final ✓") and text.contains("Inicial ✗ · Final ✗") and text.contains("Inicial ? · Final ✗"), "cada pregunta muestra ✓, ✗ o ? en inicial y final")
	_report.check(text.contains(_questions[3].correct_option()) and text.contains(_questions[3].explanation), "en las falladas al final se muestra la respuesta correcta y la explicación")
	_report.check(not text.contains(_questions[0].explanation), "en las acertadas al final no se repite la explicación")
	_report.check(text.contains("Aprendiste más sobre:") and text.contains("Para repasar:"), "hay una línea de análisis generada por código")
	_report.check(_fits_screen(view), "los resultados caben en 1280×720 (con scroll interno)")
	_report.check(_smallest_font(view) >= MIN_FONT_SIZE, "texto de resultados ≥ %d (%d)" % [MIN_FONT_SIZE, _smallest_font(view)])
	var scroll := view.scroll_container()
	_report.check(scroll.get_v_scroll_bar().max_value > scroll.size.y, "la lista tiene scroll cuando no cabe")
	var before := scroll.scroll_vertical
	await _send_action("ui_down")
	_report.check(scroll.scroll_vertical > before, "la flecha abajo desplaza la lista con el teclado")
	var focus := view.get_viewport().gui_get_focus_owner() as Button
	_report.check(focus != null and focus.text == "CONTINUAR", "el foco está en CONTINUAR")
	focus.pressed.emit()
	_report.check(continued[0], "CONTINUAR avanza")
	await _unmount(view)

# ---------------------------------------------------------------------------
# SurveyView
# ---------------------------------------------------------------------------

func _check_survey_view() -> void:
	var view := SurveyView.new()
	_mount(view)
	var received: Array = []
	view.submitted.connect(func(values: Dictionary, comment: String) -> void: received.append([values, comment]))
	view.setup(_content)
	await _settle()
	_report.check(view.submit_button().disabled, "ENVIAR está desactivado al empezar")
	_report.check(_labels_text(view).contains(_content.survey_texts[0]) and view.comment_field().placeholder_text == _content.survey_comment_prompt, "se muestran los ítems y el comentario opcional")
	_report.check(_fits_screen(view) and _smallest_font(view) >= MIN_FONT_SIZE, "la encuesta cabe en 1280×720 con texto ≥ %d (%d, panel %s)" % [MIN_FONT_SIZE, _smallest_font(view), (view.find_children("*", "PanelContainer", true, false)[0] as Control).get_global_rect()])
	for item in range(6):
		view.select(item, 3 + item % 3)
	_report.check(view.submit_button().disabled and not view.is_complete(), "con 6 de 7 ítems contestados no se puede continuar")
	view.submit_button().pressed.emit()
	_report.check(received.is_empty(), "pulsar ENVIAR incompleta no envía nada")
	view.row_buttons(6)[0].grab_focus()
	await _send_key(KEY_4)
	_report.check(view.is_complete() and not view.submit_button().disabled, "la tecla 4 con el foco en el ítem 7 lo contesta y habilita ENVIAR")
	_report.check(view.comment_field().max_length == 200, "el comentario admite hasta 200 caracteres")
	view.submit_button().pressed.emit()
	_report.check(received.size() == 1 and received[0][0].size() == 7 and received[0][1] == "", "con el comentario vacío se puede enviar (es opcional)")
	_report.check(received[0][0]["r1"] == 4 and received[0][0]["u1"] == 3, "se envían los valores 1-5 por identificador (u1…r1)")
	await _unmount(view)

# ---------------------------------------------------------------------------
# Cómo jugar
# ---------------------------------------------------------------------------

func _check_howto_text_and_view() -> void:
	var text := HowToText.build(_content)
	for key in ["W, A, S, D o las flechas", "pulsa E", "Esc"]:
		_report.check(text.contains(key), "«Cómo jugar» menciona «%s» (del InputMap)" % key)
	_report.check(text.contains("HAY ANOMALÍA") and text.contains("NO HAY ANOMALÍA"), "explica la decisión HAY / NO HAY ANOMALÍA")
	_report.check(text.contains("Si fallas, vuelves a empezar"), "incluye la regla «si fallas, vuelves a empezar»")
	_report.check(not text.contains("{"), "no quedan marcadores sin sustituir")
	var original := InputMap.action_get_events("interact").duplicate()
	InputMap.action_erase_events("interact")
	var remapped := InputEventKey.new()
	remapped.physical_keycode = KEY_Q
	InputMap.action_add_event("interact", remapped)
	_report.check(HowToText.build(_content).contains("pulsa Q") and not HowToText.build(_content).contains("pulsa E"), "si se reasigna la acción, el texto cambia (lee el InputMap real)")
	InputMap.action_erase_events("interact")
	for event in original:
		InputMap.action_add_event("interact", event)
	var view := HowToView.new()
	_mount(view)
	var closed := [0]
	view.closed.connect(func() -> void: closed[0] += 1)
	view.setup(_content, "VOLVER")
	await _settle()
	_report.check(_fits_screen(view) and _smallest_font(view) >= MIN_FONT_SIZE, "«Cómo jugar» cabe en 1280×720 con texto ≥ %d (%d)" % [MIN_FONT_SIZE, _smallest_font(view)])
	await _send_action("pause")
	_report.check(closed[0] == 1, "Esc cierra «Cómo jugar» cuando es una superposición")
	await _unmount(view)

# ---------------------------------------------------------------------------
# Ayuda y agradecimiento
# ---------------------------------------------------------------------------

func _check_help_lines() -> void:
	var flow := LearningFlow.new()
	flow.content = _content.duplicate()
	var paragraphs := flow._help_paragraphs()
	_report.check(paragraphs.size() == 2 and paragraphs[0] == _content.help_text and paragraphs[1] == "Gracias por participar.", "con help_lines vacía solo hay ayuda y agradecimiento")
	_report.check(not paragraphs.has(""), "no aparece ninguna línea vacía")
	flow.content.help_lines = PackedStringArray(["Línea de ayuda: 000 000", "  ", "Web: ejemplo.org"])
	paragraphs = flow._help_paragraphs()
	_report.check(paragraphs.size() == 3 and paragraphs[1] == "Línea de ayuda: 000 000\nWeb: ejemplo.org", "con valores, las muestra (y descarta las vacías)")
	_report.check(paragraphs[2] == "Gracias por participar.", "«Gracias por participar.» es lo último")
	flow.free()
	var view := InfoView.new()
	_mount(view)
	view.setup(_content.help_title, flow_paragraphs_for_view(), [_content.help_button])
	await _settle()
	_report.check(_fits_screen(view) and _smallest_font(view) >= MIN_FONT_SIZE, "la pantalla de ayuda cabe en 1280×720 con texto ≥ %d" % MIN_FONT_SIZE)
	_report.check(_labels_text(view).contains("emergencias") and _labels_text(view).contains("Gracias por participar."), "la ayuda recuerda llamar a emergencias y agradece")
	await _unmount(view)


func flow_paragraphs_for_view() -> Array[String]:
	return [_content.help_text, _content.thanks_text]

# ---------------------------------------------------------------------------
# Consentimiento
# ---------------------------------------------------------------------------

func _check_consent_view() -> void:
	_tree.change_scene_to_file(PRE_GAME)
	await _settle(10)
	var flow := _tree.current_scene as LearningFlow
	flow.navigates = false
	var view := flow.current_view() as InfoView
	_report.check(view != null, "el pre-juego empieza por la pantalla de propósito y consentimiento")
	var text := _labels_text(view)
	_report.check(text.contains("Antes de entrar") and text.contains(_content.purpose_pages[0]) and text.contains(_content.consent_text), "muestra el propósito y el consentimiento tal como están en los datos")
	_report.check(view.buttons().size() == 2 and view.buttons()[0].text == "PARTICIPAR Y GUARDAR" and view.buttons()[1].text == "JUGAR SIN GUARDAR", "ofrece PARTICIPAR Y GUARDAR y JUGAR SIN GUARDAR")
	_report.check(_fits_screen(view) and _smallest_font(view) >= MIN_FONT_SIZE, "la pantalla cabe en 1280×720 con texto ≥ %d" % MIN_FONT_SIZE)
	_report.check(view.get_viewport().gui_get_focus_owner() == view.buttons()[0], "el teclado empieza en PARTICIPAR Y GUARDAR")
	view.buttons()[1].pressed.emit()
	await _settle()
	var session: Node = _tree.root.get_node("Session")
	_report.check(session.consent == false, "JUGAR SIN GUARDAR deja consent = false")
	_tree.current_scene.queue_free()
	await _tree.process_frame

# ---------------------------------------------------------------------------
# Menú
# ---------------------------------------------------------------------------

func _check_menu() -> void:
	_tree.change_scene_to_file(MENU_SCENE)
	await _tree.create_timer(MENU_ENTRY_SECONDS).timeout
	var menu := _tree.current_scene as Control
	var column := menu.get_node("MainScreen/MenuColumn")
	var buttons: Array[Button] = []
	for child in column.get_children():
		buttons.append(child as Button)
	var texts: Array[String] = []
	for button in buttons:
		texts.append(button.text)
	_report.check(texts == ["INICIAR PARTIDA", "CÓMO JUGAR", "OPCIONES", "CRÉDITOS", "SALIR"], "el menú tiene 5 botones en orden: %s" % str(texts))
	# El botón con foco crece un 3 % y se adelanta unos píxeles: se tolera esa holgura.
	var column_box := Rect2(Vector2.ZERO, column.size)
	var inside := true
	var overlaps := false
	for i in range(buttons.size()):
		inside = inside and column_box.grow(FOCUS_SLACK).encloses(buttons[i].get_rect())
		if i > 0:
			overlaps = overlaps or buttons[i - 1].get_rect().intersects(buttons[i].get_rect())
	var warning := menu.get_node("MainScreen/ContentWarning") as Label
	var last_bottom: float = column.global_position.y + buttons[4].get_rect().end.y
	_report.check(not overlaps and inside and last_bottom <= warning.get_global_rect().position.y, "los 5 botones caben sin solaparse y sobre el aviso de contenido (fin %.0f, aviso %.0f)" % [last_bottom, warning.get_global_rect().position.y])
	_report.check(menu.get_viewport().gui_get_focus_owner() == buttons[0], "el foco empieza en INICIAR PARTIDA")
	for i in range(1, buttons.size()):
		await _send_action("ui_down")
		_report.check(menu.get_viewport().gui_get_focus_owner() == buttons[i], "flecha abajo → %s" % buttons[i].text)
	await _check_folder_button(menu)
	await _check_menu_howto(menu, buttons[1])
	await _check_start_opens_pre_game(menu, buttons[0])


func _check_folder_button(menu: Control) -> void:
	var opened_paths: Array[String] = []
	menu.folder_opener = func(path: String) -> int:
		opened_paths.append(path)
		return OK
	menu.get_node("MainScreen/MenuColumn/OptionsButton").pressed.emit()
	await _settle()
	var folder_button := menu.get_node("OptionsScreen/Panel/Box/ResultsFolderButton") as Button
	var notice := menu.get_node("OptionsScreen/Panel/Box/FolderNotice") as Label
	_report.check(folder_button.text == "ABRIR CARPETA DE RESULTADOS" and folder_button.is_visible_in_tree(), "OPCIONES ofrece ABRIR CARPETA DE RESULTADOS")
	folder_button.pressed.emit()
	_report.check(opened_paths.size() == 1 and opened_paths[0] == ProjectSettings.globalize_path("user://resultados/") and notice.text.is_empty(), "abre la ruta global de user://resultados (%s)" % str(opened_paths))
	menu.folder_opener = func(_path: String) -> int: return ERR_CANT_OPEN
	folder_button.pressed.emit()
	_report.check(notice.text == "No se pudo abrir la carpeta de resultados." and menu.is_inside_tree(), "si el sistema falla, muestra un aviso breve y no da error")
	await _send_action("pause")
	_report.check((menu.get_node("MainScreen") as Control).visible, "Esc vuelve del panel de opciones")


func _check_menu_howto(menu: Control, howto_button: Button) -> void:
	howto_button.pressed.emit()
	await _settle()
	var overlay := menu._howto as HowToView
	_report.check(overlay != null and overlay.text_shown().contains("Si fallas, vuelves a empezar"), "CÓMO JUGAR del menú abre las instrucciones")
	_report.check(menu.get_viewport().gui_get_focus_owner() == overlay.close_button(), "al abrir, el foco está en VOLVER")
	await _send_action("pause")
	await _settle()
	_report.check(menu._howto == null and menu.get_viewport().gui_get_focus_owner() == howto_button, "Esc cierra las instrucciones y devuelve el foco al botón")


func _check_start_opens_pre_game(menu: Control, start: Button) -> void:
	var session: Node = _tree.root.get_node("Session")
	var before: String = session.participant_id
	start.pressed.emit()
	for i in range(40):
		await _tree.process_frame
	_report.check(_tree.current_scene is LearningFlow and session.participant_id != before, "INICIAR PARTIDA abre el pre-juego con una sesión nueva (otro identificador)")
	(_tree.current_scene as LearningFlow).navigates = false
	_tree.current_scene.queue_free()
	await _tree.process_frame

# ---------------------------------------------------------------------------
# Cómo jugar desde la pausa (pre-juego y partida)
# ---------------------------------------------------------------------------

func _check_howto_from_pause_screens() -> void:
	_tree.change_scene_to_file(PRE_GAME)
	await _settle(10)
	var flow := _tree.current_scene as LearningFlow
	flow.navigates = false
	await _send_action("pause")
	_report.check(flow.is_paused() and flow.pause_overlay().visible, "Esc en el pre-juego abre la pausa")
	flow.pause_overlay().howto_button().pressed.emit()
	await _settle()
	_report.check(flow.pause_overlay().is_howto_open(), "la pausa del pre-juego ofrece CÓMO JUGAR")
	await _send_action("pause")
	await _settle()
	_report.check(not flow.pause_overlay().is_howto_open() and flow.is_paused(), "Esc cierra CÓMO JUGAR y deja la pausa abierta")
	await _send_action("pause")
	_report.check(not flow.is_paused() and not flow.pause_overlay().visible, "otro Esc reanuda el pre-juego")
	flow.queue_free()
	await _tree.process_frame
	var driver := GameDriver.new(_tree)
	await driver.boot()
	driver.manager._toggle_pause()
	await _settle()
	var hud := driver.manager._hud
	var howto_button := driver.manager.get_node("HUD/Root/PausePanel/Center/Box/HowToButton") as Button
	_report.check(howto_button.visible and howto_button.text == "CÓMO JUGAR", "la pausa de la partida tiene el botón CÓMO JUGAR")
	howto_button.pressed.emit()
	await _settle()
	var views := hud.get_node("Root").find_children("*", "HowToView", true, false)
	_report.check(views.size() == 1 and (views[0] as HowToView).text_shown().contains("Si fallas"), "CÓMO JUGAR desde la pausa de la partida muestra las instrucciones")
	await _send_action("pause")
	await _settle()
	_report.check(hud.get_node("Root").find_children("*", "HowToView", true, false).is_empty() and driver.manager._paused, "Esc cierra las instrucciones sin reanudar la partida")
	await driver.shutdown()


const GameDriver := preload("res://tests/game_driver.gd")
