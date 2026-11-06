extends RefCounted

## Bloque A: datos de aprendizaje, puntuación, registro de resultados, sesión y
## el script de análisis (probado con los 12 participantes simulados).

const Reporter := preload("res://tests/reporter.gd")
const TEMP_DIR := "user://zz_learning_test/"
const BLOCKED_FILE := "user://zz_learning_blocked"
const SAMPLE_DIR := "res://dev/out/ejemplo_resultados"
const ANALYZER := "res://dev/analyze_results.py"
const CARD_MAX_CHARS := 140
const QUESTION_COUNT := 8
const OPTION_COUNT := 4

var _report: Reporter
var _tree: SceneTree
var _questions: Array[TriviaQuestion]
var _content: LearningContent


func run(report: Reporter, tree: SceneTree) -> void:
	report.start("Aprendizaje A: datos, puntuación, resultados y análisis")
	_report = report
	_tree = tree
	_questions = LearningContent.questions()
	_content = LearningContent.default()
	_check_content_is_valid()
	_check_questions_are_valid()
	_check_cards_cover_questions()
	_check_scorer()
	_check_shuffle_keeps_original_index()
	_check_topics_and_analysis_line()
	_check_store()
	_check_store_failure_is_silent()
	_check_session_and_record()
	await _check_session_survives_scene_change()
	_check_analyzer()

# ---------------------------------------------------------------------------
# Datos
# ---------------------------------------------------------------------------

func _check_content_is_valid() -> void:
	_report.check(_content != null, "learning_content.tres carga como LearningContent")
	_report.check(not _content.purpose_title.is_empty() and not _content.purpose_pages.is_empty() and not _content.consent_text.is_empty(), "hay páginas de propósito y texto de consentimiento")
	_report.check(_content.intro_pages.size() == 4, "la historia de entrada tiene 4 páginas (%d)" % _content.intro_pages.size())
	_report.check(_content.epilogue_pages.size() == 2, "el epílogo tiene 2 páginas (%d)" % _content.epilogue_pages.size())
	_report.check(_content.corridor_cards.size() == 10 and not _content.closing_card.is_empty(), "hay 10 tarjetas de pasillo y la de cierre (%d)" % _content.corridor_cards.size())
	var too_long: Array[String] = []
	for card in _content.corridor_cards + PackedStringArray([_content.closing_card]):
		if card.length() > CARD_MAX_CHARS:
			too_long.append(card)
	_report.check(too_long.is_empty(), "ninguna tarjeta supera %d caracteres %s" % [CARD_MAX_CHARS, str(too_long)])
	_report.check(_content.survey_ids == PackedStringArray(["u1", "u2", "u3", "u4", "l1", "l2", "r1"]) and _content.survey_texts.size() == 7, "la encuesta tiene los 7 ítems u1…r1")
	_report.check(_content.help_lines.is_empty(), "help_lines está vacía por defecto")
	_report.check(_content.thanks_text == "Gracias por participar." and not _content.help_text.is_empty(), "hay texto de ayuda y agradecimiento")
	_report.check(_content.consent_save_button == "PARTICIPAR Y GUARDAR" and _content.consent_skip_button == "JUGAR SIN GUARDAR", "los botones de consentimiento son los pedidos")


func _check_questions_are_valid() -> void:
	_report.check(_questions.size() == QUESTION_COUNT, "hay exactamente 8 preguntas (%d)" % _questions.size())
	var ids := {}
	for question in _questions:
		ids[question.id] = true
		var valid := question.options.size() == OPTION_COUNT and question.correct_index >= 0 and question.correct_index < OPTION_COUNT
		_report.check(valid and not question.explanation.is_empty() and not question.topic.is_empty() and not question.text.is_empty(), "%s: 4 opciones, índice en rango, tema y explicación" % question.id)
	_report.check(ids.size() == QUESTION_COUNT, "los identificadores de las preguntas son únicos")


func _check_cards_cover_questions() -> void:
	var covered: Array[String] = []
	for i in range(6):
		covered.append(_questions[i].id)
	_report.check(covered.size() == 6 and _questions[0].id.begins_with("q01") and _questions[5].id.begins_with("q06"), "las preguntas q01-q06 existen para las tarjetas 1-6")
	var keywords := ["acoso", "calla", "duelo", "culpa", "Aislarse", "Comer, dormir"]
	for i in range(keywords.size()):
		_report.check(_content.corridor_cards[i].contains(keywords[i]), "la tarjeta %d trata el tema de q0%d («%s»)" % [i + 1, i + 1, keywords[i]])

# ---------------------------------------------------------------------------
# TriviaScorer
# ---------------------------------------------------------------------------

func _answers_with(correct_count: int, unknown_after: int = -1) -> Dictionary:
	var answers := {}
	for i in range(_questions.size()):
		if i < correct_count:
			answers[_questions[i].id] = _questions[i].correct_index
		elif unknown_after >= 0 and i >= unknown_after:
			answers[_questions[i].id] = TriviaScorer.DONT_KNOW
		else:
			answers[_questions[i].id] = (_questions[i].correct_index + 1) % OPTION_COUNT
	return answers


func _check_scorer() -> void:
	_report.check(TriviaScorer.score(_questions, _answers_with(5)) == 5, "5 aciertos puntúan 5")
	_report.check(TriviaScorer.score(_questions, _answers_with(0)) == 0, "todo mal puntúa 0")
	_report.check(TriviaScorer.score(_questions, _answers_with(QUESTION_COUNT)) == QUESTION_COUNT, "todo bien puntúa 8")
	_report.check(TriviaScorer.score(_questions, {}) == 0, "sin respuestas puntúa 0")
	var with_unknown := _answers_with(3, 5)
	_report.check(with_unknown[_questions[7].id] == -1 and TriviaScorer.score(_questions, with_unknown) == 3, "«No lo sé» se guarda como -1 y vale 0")
	_report.check(TriviaScorer.mark_for(_questions[0], 0) == "✓" and TriviaScorer.mark_for(_questions[0], 2) == "✗" and TriviaScorer.mark_for(_questions[0], -1) == "?", "marcas ✓, ✗ y ? según la respuesta")
	_report.check(TriviaScorer.gain(3, 6) == 3 and TriviaScorer.gain(5, 4) == -1, "ganancia = final − inicial")
	_report.check(is_equal_approx(TriviaScorer.normalized_gain(3, 6, 8), 0.6), "ganancia normalizada (3→6) = 3/5 = 0,6")
	_report.check(is_equal_approx(TriviaScorer.normalized_gain(0, 8, 8), 1.0), "ganancia normalizada (0→8) = 1")
	_report.check(TriviaScorer.normalized_gain(8, 8, 8) == 0.0, "ganancia normalizada con inicial = 8 es 0 (sin dividir entre cero)")
	_report.check(is_equal_approx(TriviaScorer.normalized_gain(4, 2, 8), -0.5), "ganancia normalizada negativa si empeora (4→2 = −0,5)")


func _check_shuffle_keeps_original_index() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var all_permutations := true
	var moved := false
	for i in range(50):
		var order := TriviaScorer.shuffled_order(OPTION_COUNT, rng)
		var sorted := order.duplicate()
		sorted.sort()
		all_permutations = all_permutations and sorted == [0, 1, 2, 3]
		moved = moved or order != [0, 1, 2, 3]
	_report.check(all_permutations, "el barajado siempre es una permutación de las 4 opciones")
	_report.check(moved, "el barajado realmente cambia el orden")
	var order: Array[int] = [2, 0, 3, 1]
	_report.check(TriviaScorer.answer_for_position(order, 0) == 2 and TriviaScorer.answer_for_position(order, 3) == 1, "pulsar una posición guarda el índice ORIGINAL de la opción")
	_report.check(TriviaScorer.answer_for_position(order, 4) == TriviaScorer.DONT_KNOW, "la posición 5 (después de las 4) es «No lo sé» = -1")


func _check_topics_and_analysis_line() -> void:
	var pre := _answers_with(2)
	var post := _answers_with(QUESTION_COUNT)
	var improved := TriviaScorer.topics_improved(_questions, pre, post)
	_report.check(improved == ["duelo", "salud mental", "historia"], "temas mejorados (2→8): %s" % str(improved))
	_report.check(TriviaScorer.topics_to_review(_questions, post).is_empty(), "con todo acertado no queda nada que repasar")
	var weak_post := _answers_with(4)
	var review := TriviaScorer.topics_to_review(_questions, weak_post)
	_report.check(review == ["salud mental", "historia"], "temas a repasar con 4 aciertos: %s" % str(review))
	var line := TriviaScorer.analysis_line(_questions, pre, weak_post)
	_report.check(line.begins_with("Aprendiste más sobre: duelo.") and line.contains("Para repasar: salud mental, historia."), "línea de análisis: %s" % line)
	_report.check(TriviaScorer.analysis_line(_questions, post, post).contains("Aún no se nota mejora"), "sin mejora, la línea lo dice sin inventar temas")

# ---------------------------------------------------------------------------
# ResultsStore
# ---------------------------------------------------------------------------

func _clean_temp() -> void:
	var global := ProjectSettings.globalize_path(TEMP_DIR)
	if DirAccess.dir_exists_absolute(global):
		for file_name in DirAccess.get_files_at(global):
			DirAccess.remove_absolute(global + file_name)
		DirAccess.remove_absolute(global)


func _check_store() -> void:
	_clean_temp()
	var rng := RandomNumberGenerator.new()
	var id := ResultsStore.new_id(rng)
	_report.check(ResultsStore.is_valid_id(id) and id.length() == 8, "el identificador son 8 caracteres hexadecimales (%s)" % id)
	_report.check(not ResultsStore.is_valid_id("zzzzzzzz") and not ResultsStore.is_valid_id("abc") and not ResultsStore.is_valid_id("../etc/pw"), "identificadores inválidos rechazados (evita rutas raras)")
	var store := ResultsStore.new(TEMP_DIR)
	var session := _new_session(store)
	session.begin_new()
	session.record_consent(true)
	session.record_pre(_answers_with(3))
	_report.check(session.save(), "con consentimiento, guarda tras la trivia inicial")
	var stage_one := store.load_record(session.participant_id)
	var keys := ["participant_id", "version", "consent", "started_at", "finished_at", "completed", "attempts", "play_seconds", "pre", "post", "gain", "normalized_gain", "survey", "memories_found", "cinematic_skipped", "finish_type", "max_round_reached", "ended_early"]
	var missing: Array[String] = []
	for key in keys:
		if not stage_one.has(key):
			missing.append(key)
	_report.check(missing.is_empty(), "el JSON tiene todas las claves esperadas (faltan: %s)" % str(missing))
	_report.check(int(stage_one["pre"]["score"]) == 3 and stage_one["post"]["score"] == null and stage_one["gain"] == null, "tras la etapa 1: pre=3 y lo que no ha ocurrido va a null")
	_report.check(stage_one["version"] == ProjectSettings.get_setting("application/config/version") and stage_one["consent"] == true, "guarda la versión del juego y el consentimiento")
	session.record_post(_answers_with(7))
	session.save()
	var stage_two := store.load_record(session.participant_id)
	_report.check(int(stage_two["post"]["score"]) == 7 and int(stage_two["gain"]) == 4, "tras la trivia final: post=7 y ganancia=4")
	_report.check(is_equal_approx(float(stage_two["normalized_gain"]), 4.0 / 5.0), "ganancia normalizada guardada = 4/5")
	var values := {"u1": 5, "u2": 4, "u3": 4, "u4": 3, "l1": 5, "l2": 5, "r1": 4}
	session.record_survey(values, "Gracias")
	session.save()
	var stage_three := store.load_record(session.participant_id)
	_report.check(stage_three["completed"] == true and stage_three["survey"]["l1"] == 5 and stage_three["survey"]["comment"] == "Gracias", "tras la encuesta: completed y valores guardados")
	_report.check(not String(stage_three["finished_at"]).is_empty(), "al terminar se registra finished_at")
	_report.check(DirAccess.get_files_at(ProjectSettings.globalize_path(TEMP_DIR)).size() == 1, "hay un único JSON por participante (se actualiza, no se duplica)")
	_report.check(not FileAccess.get_file_as_string(TEMP_DIR + session.participant_id + ".json").contains("nombre"), "el JSON no contiene campos de datos personales")
	session.free()
	_clean_temp()


func _check_store_failure_is_silent() -> void:
	var no_consent := _new_session(ResultsStore.new(TEMP_DIR))
	no_consent.begin_new()
	no_consent.record_consent(false)
	no_consent.record_pre(_answers_with(2))
	_report.check(not no_consent.save() and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(TEMP_DIR)), "sin consentimiento no se escribe nada (ni se crea la carpeta)")
	no_consent.free()
	var blocked := FileAccess.open(BLOCKED_FILE, FileAccess.WRITE)
	blocked.store_string("no soy una carpeta")
	blocked.close()
	var unwritable := _new_session(ResultsStore.new(BLOCKED_FILE + "/sub/"))
	unwritable.begin_new()
	unwritable.record_consent(true)
	var saved: bool = unwritable.save()
	_report.check(not saved and not unwritable.last_save_ok, "si la carpeta no se puede escribir, save() devuelve false y el juego sigue")
	_report.check(unwritable.build_record()["participant_id"] == unwritable.participant_id, "la sesión sigue utilizable tras el fallo de escritura")
	unwritable.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(BLOCKED_FILE))

# ---------------------------------------------------------------------------
# Session
# ---------------------------------------------------------------------------

func _new_session(store: ResultsStore) -> Node:
	var session: Node = load("res://scripts/learning/session.gd").new()
	session.store = store
	return session


func _check_session_and_record() -> void:
	var session := _new_session(ResultsStore.new(TEMP_DIR))
	session.begin_new()
	var first_id: String = session.participant_id
	session.add_attempt()
	session.add_attempt()
	session.record_consent(true)
	session.record_pre(_answers_with(1))
	_report.check(session.attempts == 2 and ResultsStore.is_valid_id(first_id), "la sesión cuenta intentos y tiene identificador válido")
	session.begin_new()
	_report.check(session.participant_id != first_id and session.attempts == 0 and not session.consent and session.pre_answers.is_empty(), "begin_new() da otro identificador y deja todo a cero")
	session.set_playing(true)
	session._process(2.5)
	session.set_playing(false)
	session._process(9.0)
	_report.check(is_equal_approx(session.play_seconds, 2.5), "los segundos de juego solo cuentan mientras se juega (%.1f)" % session.play_seconds)
	session.record_survey({}, "x".repeat(300))
	_report.check(String(session.survey["comment"]).length() == 200, "el comentario se recorta a 200 caracteres")
	session.free()


func _check_session_survives_scene_change() -> void:
	var session: Node = _tree.root.get_node("Session")
	session.begin_new()
	var id: String = session.participant_id
	session.add_attempt()
	session.add_attempt()
	session.add_attempt()
	_tree.change_scene_to_file("res://scenes/learning/pre_game.tscn")
	for i in range(30):
		await _tree.process_frame
	_tree.change_scene_to_file("res://scenes/corridor.tscn")
	for i in range(30):
		await _tree.process_frame
	_report.check(session.attempts == 3 and session.participant_id == id, "los intentos y el identificador sobreviven al cambio de escena (%d)" % session.attempts)
	_tree.change_scene_to_file("res://scenes/main_menu.tscn")
	for i in range(30):
		await _tree.process_frame
	_report.check(session.participant_id != id and session.attempts == 0, "volver al menú cierra la sesión: otro identificador y 0 intentos")
	_tree.current_scene.queue_free()
	await _tree.process_frame

# ---------------------------------------------------------------------------
# dev/analyze_results.py
# ---------------------------------------------------------------------------

func _run_analyzer(arguments: Array[String]) -> Dictionary:
	var output: Array = []
	var args: Array[String] = [ProjectSettings.globalize_path(ANALYZER)]
	args.append_array(arguments)
	var code := OS.execute("python", PackedStringArray(args), output, true)
	return {"code": code, "text": "".join(output)}


func _check_analyzer() -> void:
	var sample := ProjectSettings.globalize_path(SAMPLE_DIR)
	var simulated := 0
	for file_name in DirAccess.get_files_at(sample):
		if file_name.ends_with(".json") and JSON.parse_string(FileAccess.get_file_as_string(SAMPLE_DIR + "/" + file_name)).get("simulated", false):
			simulated += 1
	_report.check(simulated == 12, "hay 12 participantes simulados marcados con simulated:true (%d)" % simulated)
	var out_dir := ProjectSettings.globalize_path(TEMP_DIR + "analisis/")
	var ignored := _run_analyzer([sample, "--salida", out_dir + "sin"])
	_report.check(ignored["code"] == 0 and String(ignored["text"]).contains("0 participantes analizados (12 simulados ignorados)"), "sin --include-simulated ignora los 12 simulados: %s" % String(ignored["text"]).strip_edges())
	var included := _run_analyzer([sample, "--include-simulated", "--salida", out_dir + "con"])
	_report.check(included["code"] == 0 and String(included["text"]).contains("12 participantes analizados"), "con --include-simulated analiza los 12")
	var report_text := FileAccess.get_file_as_string(out_dir + "con/analisis_resultados.md")
	_report.check(report_text.contains("DATOS DE EJEMPLO"), "el informe avisa de que son datos de ejemplo")
	# Cifras calculadas a mano: pre 42/12 = 3,5; post 68/12 = 5,67; ganancia 26/12 = 2,17;
	# normalizada 6,7667/12 = 0,564; 10 de 12 mejoraron = 83,3 %; desviación inicial (n−1) = √(23/11) = 1,45.
	# Recuerdos: 81/12 = 6,75 de media; 3 de los 9 que la vieron saltan la cinemática = 33,3 %; Pearson
	# entre recuerdos (5 9 4 8 6 12 7 2 11 6 10 1) y ganancia (3 3 3 2 3 2 2 0 3 2 3 0) = 0,604.
	for expected in ["| Inicial | 3.50 | 1.45 |", "| Final | 5.67 | 2.19 |", "**+2.17**", "**0.564**", "**83.3 %**", "**6.75**", "**33.3 %**", "**0.604**"]:
		_report.check(report_text.contains(expected), "cifra esperada calculada a mano en el informe: %s" % expected)
	var csv_lines := FileAccess.get_file_as_string(out_dir + "con/resultados_consolidados.csv").strip_edges().split("\n")
	_report.check(csv_lines.size() == 13, "el CSV tiene cabecera + 12 filas (%d líneas)" % csv_lines.size())
	_report.check(report_text.contains("| q01_acoso |") and report_text.contains("| u1 · "), "el informe incluye acierto por pregunta y la encuesta")
	_check_analyzer_real_record(out_dir)
	_clean_analysis(out_dir)


## Un participante real (sin simulated) sí se analiza sin la opción.
func _check_analyzer_real_record(out_dir: String) -> void:
	var real_dir := out_dir + "real/"
	DirAccess.make_dir_recursive_absolute(real_dir)
	var first: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAMPLE_DIR + "/" + DirAccess.get_files_at(ProjectSettings.globalize_path(SAMPLE_DIR))[0]))
	first.erase("simulated")
	var file := FileAccess.open(real_dir + "aaaaaaaa.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(first))
	file.close()
	var result := _run_analyzer([real_dir, "--salida", real_dir + "out"])
	_report.check(String(result["text"]).contains("1 participantes analizados"), "un participante sin el indicador simulated sí se analiza: %s" % String(result["text"]).strip_edges())
	_report.check(not FileAccess.get_file_as_string(real_dir + "out/analisis_resultados.md").contains("DATOS DE EJEMPLO"), "un análisis de datos reales no lleva el aviso de ejemplo")


func _clean_analysis(out_dir: String) -> void:
	for sub in ["sin", "con", "real/out", "real"]:
		var dir: String = out_dir + sub + "/"
		if DirAccess.dir_exists_absolute(dir):
			for file_name in DirAccess.get_files_at(dir):
				DirAccess.remove_absolute(dir + file_name)
			DirAccess.remove_absolute(dir)
	DirAccess.remove_absolute(out_dir)
	_clean_temp()
