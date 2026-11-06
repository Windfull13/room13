extends RefCounted

## Bloque B3: cinemática «La última puerta». Llega al final con tiempo escalado,
## muestra el aviso, se salta manteniendo E un segundo (entrada simulada),
## Session registra cinematic_skipped y el flujo sigue en el epílogo.

const Reporter := preload("res://tests/reporter.gd")
const CINEMATIC := "res://scenes/cinematic/last_door.tscn"
const POST_GAME := "res://scenes/learning/post_game.tscn"
const FAST_PACING := 0.05
const FRAME_BUDGET := 2400
const HOLD_SECONDS := 1.25

var _report: Reporter
var _tree: SceneTree
var _session: Node
var _texts: MemoryTexts


func run(report: Reporter, tree: SceneTree) -> void:
	report.start("Cinemática final «La última puerta»")
	_report = report
	_tree = tree
	_session = tree.root.get_node("Session")
	_texts = MemoryTexts.default()
	_check_texts()
	await _check_full_playback()
	await _check_skip()
	await _check_continues_to_epilogue()


func _new_cinematic(pacing: float) -> LastDoorCinematic:
	var cinematic := (load(CINEMATIC) as PackedScene).instantiate() as LastDoorCinematic
	cinematic.pacing = pacing
	cinematic.navigates = false
	_tree.root.add_child(cinematic)
	return cinematic


func _await_done(cinematic: LastDoorCinematic) -> bool:
	for i in range(FRAME_BUDGET):
		if cinematic.phase == LastDoorCinematic.Phase.DONE:
			return true
		await _tree.process_frame
	return false


func _labels(cinematic: Control) -> String:
	var parts: PackedStringArray = []
	for node in cinematic.find_children("*", "Label", true, false):
		if (node as Label).visible:
			parts.append((node as Label).text)
	return "\n".join(parts)


func _check_texts() -> void:
	_report.check(_texts.cinematic_warning == "La siguiente escena es emotiva. Mantén E para saltarla.", "el aviso inicial es el texto definitivo")
	_report.check(_texts.cinematic_fragment_lines == PackedStringArray(["Aprendiste a hacerte pequeño.", "Hubo una casa llena de color.", "Una noche, la lluvia.", "Y después, el silencio."]), "las cuatro líneas de los fragmentos son las definitivas")
	_report.check(_texts.cinematic_final_lines == PackedStringArray(["Sentir culpa no significa haber tenido la culpa.", "Recordar duele. También es una forma de quedarse con ellas."]), "las dos líneas finales son las definitivas")
	_report.check(_texts.cinematic_wife_voice == "voice_cinematic_wife" and _texts.cinematic_girl_voice == "voice_cinematic_girl", "las voces previstas son voice_cinematic_wife y voice_cinematic_girl")
	var total := 0.0
	for seconds in LastDoorCinematic.DURATIONS:
		total += seconds
	_report.check(total >= 45.0 and total <= 50.0, "a velocidad normal dura unos 45-48 s (%.0f s)" % total)


func _check_full_playback() -> void:
	_session.begin_new()
	var cinematic := _new_cinematic(FAST_PACING)
	await _tree.process_frame
	_report.check(cinematic.warning_shown and _labels(cinematic).contains(_texts.cinematic_warning), "al empezar aparece el aviso inicial")
	var phases_seen := {}
	var fragment_lines := {}
	var subtitles := {}
	for i in range(FRAME_BUDGET):
		phases_seen[cinematic.phase] = true
		var text := _labels(cinematic)
		for line in _texts.cinematic_fragment_lines:
			if text.contains(line):
				fragment_lines[line] = true
		for line in [_texts.cinematic_wife_line, _texts.cinematic_girl_line]:
			if text.contains(line):
				subtitles[line] = true
		if cinematic.phase == LastDoorCinematic.Phase.DONE:
			break
		await _tree.process_frame
	_report.check(cinematic.phase == LastDoorCinematic.Phase.DONE, "con tiempo escalado llega sola al final")
	_report.check(phases_seen.size() == LastDoorCinematic.Phase.size(), "pasa por todas las fases (%d de %d)" % [phases_seen.size(), LastDoorCinematic.Phase.size()])
	_report.check(fragment_lines.size() == 4, "los cuatro fragmentos muestran su línea (%d)" % fragment_lines.size())
	_report.check(subtitles.size() == 2, "las frases de las voces se leen aunque no haya archivo (%d)" % subtitles.size())
	_report.check(_labels(cinematic).contains(_texts.cinematic_final_lines[0]), "termina con las dos líneas finales")
	_report.check(_session.cinematic_skipped == false, "sin saltar, Session registra cinematic_skipped = false")
	_report.check(not AudioManager.is_voice_playing(), "al terminar no queda ninguna voz sonando")
	cinematic.queue_free()
	await _tree.process_frame


func _check_skip() -> void:
	_session.begin_new()
	var cinematic := _new_cinematic(1.0)
	await _tree.create_timer(0.4).timeout
	Input.action_press("interact")
	await _tree.create_timer(0.5).timeout
	_report.check(cinematic.hold_progress() > 0.2 and cinematic.hold_progress() < 1.0 and cinematic.phase < LastDoorCinematic.Phase.FINAL, "mantener E llena el anillo de progreso (%.0f %%)" % (cinematic.hold_progress() * 100.0))
	Input.action_release("interact")
	await _tree.process_frame
	await _tree.process_frame
	_report.check(cinematic.hold_progress() == 0.0 and not cinematic.skipped, "soltar E antes de 1 s no salta")
	Input.action_press("interact")
	await _tree.create_timer(HOLD_SECONDS).timeout
	Input.action_release("interact")
	await _tree.process_frame
	_report.check(cinematic.skipped and cinematic.phase == LastDoorCinematic.Phase.FINAL, "mantener E 1 s salta directamente a las líneas finales")
	_report.check(_labels(cinematic).contains(_texts.cinematic_final_lines[1]), "tras saltar se ven las dos líneas finales")
	_report.check(_session.cinematic_skipped == true, "Session registra cinematic_skipped = true")
	cinematic.pacing = FAST_PACING
	_report.check(await _await_done(cinematic), "tras las líneas finales termina")
	cinematic.queue_free()
	await _tree.process_frame


func _check_continues_to_epilogue() -> void:
	_session.begin_new()
	_tree.change_scene_to_file(CINEMATIC)
	var cinematic: LastDoorCinematic = null
	for i in range(FRAME_BUDGET):
		cinematic = _tree.current_scene as LastDoorCinematic
		if cinematic != null:
			break
		await _tree.process_frame
	cinematic.pacing = 0.0
	var flow: LearningFlow = null
	for i in range(FRAME_BUDGET):
		flow = _tree.current_scene as LearningFlow
		if flow != null and flow.scene_file_path == POST_GAME:
			break
		await _tree.process_frame
	_report.check(flow != null and flow.scene_file_path == POST_GAME, "al terminar, la cinemática pasa al post-juego")
	await _tree.process_frame
	await _tree.process_frame
	_report.check(flow != null and flow.current_view() is PageView and (flow.current_view() as PageView).page_index() == 0, "y el post-juego empieza por el epílogo")
	if flow != null:
		flow.navigates = false
		flow.queue_free()
	await _tree.process_frame
