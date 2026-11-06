extends RefCounted

## Bloque E2: 50 partidas completas con el flujo real y cambios de escena:
## menú → pre-juego → partida (decisiones perfectas o aleatorias, con recuerdos
## leídos o no) → cinemática (saltada en la mitad) → post-juego → menú.
## Sin nodos huérfanos, con los reproductores de audio estables y con el JSON
## de cada participante coherente.

const Reporter := preload("res://tests/reporter.gd")
const MENU := "res://scenes/main_menu.tscn"
const PRE_GAME := "res://scenes/learning/pre_game.tscn"
const GAME := "res://scenes/partida.tscn"
const CINEMATIC := "res://scenes/cinematic/last_door.tscn"
const POST_GAME := "res://scenes/learning/post_game.tscn"
const TEMP_RESULTS := "user://zz_estabilidad/"
const DEFAULT_RUNS := 50
const UI_TIME_SCALE := 25.0
const FRAME_BUDGET := 6000
const WRONG_CHANCE := 0.3
const READ_MEMORY_CHANCE := 0.6
const QUESTION_COUNT := 8

var _report: Reporter
var _tree: SceneTree
var _session: Node
var _audio: Node
var _rng := RandomNumberGenerator.new()
var _runs: int = DEFAULT_RUNS


func run(report: Reporter, tree: SceneTree) -> void:
	report.start("Estabilidad: %d partidas completas con el flujo real" % _runs_from_env())
	_report = report
	_tree = tree
	_session = tree.root.get_node("Session")
	_audio = tree.root.get_node("AudioManager")
	_rng.seed = 13
	var original_store: ResultsStore = _session.store
	_session.store = ResultsStore.new(TEMP_RESULTS)
	var players_before: int = _audio.get_child_count()
	var completed := 0
	var coherent := 0
	var skipped_seen := {}
	var memories_read := 0
	var failures_seen := 0
	for i in range(_runs):
		var outcome := await _play_session(i)
		completed += 1 if outcome["completed"] else 0
		coherent += 1 if outcome["coherent"] else 0
		skipped_seen[outcome["skipped"]] = true
		memories_read += outcome["memories"]
		failures_seen += outcome["failures"]
	Engine.time_scale = 1.0
	_report.check(completed == _runs, "las %d partidas llegan del menú al menú pasando por todo el flujo (%d)" % [_runs, completed])
	_report.check(coherent == _runs, "el JSON de cada participante con consentimiento es coherente (%d de %d)" % [coherent, _runs])
	_report.check(skipped_seen.has(true) and skipped_seen.has(false), "hubo cinemáticas saltadas y sin saltar")
	_report.check(memories_read > 0 and failures_seen > 0, "hubo recuerdos leídos (%d) y fallos con reinicio (%d)" % [memories_read, failures_seen])
	_tree.current_scene.queue_free()
	await _tree.process_frame
	await _tree.process_frame
	var orphans: int = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	_report.check(orphans == 0, "sin nodos huérfanos tras las %d partidas (%d)" % [_runs, orphans])
	if orphans > 0:
		Node.print_orphan_nodes()
	_report.check(_audio.get_child_count() == players_before, "los reproductores de audio no se acumulan (%d → %d)" % [players_before, _audio.get_child_count()])
	_report.check(not _audio.is_voice_playing() and _audio.active_sounds().is_empty(), "al terminar no queda ningún sonido ni voz: %s" % str(_audio.active_sounds()))
	_session.store = original_store
	_clean_results()


func _runs_from_env() -> int:
	var configured := OS.get_environment("ZIVA_STABILITY_RUNS").to_int()
	_runs = configured if configured > 0 else DEFAULT_RUNS
	return _runs

# ---------------------------------------------------------------------------
# Una sesión completa
# ---------------------------------------------------------------------------

func _play_session(index: int) -> Dictionary:
	var outcome := {"completed": false, "coherent": false, "skipped": false, "memories": 0, "failures": 0}
	Engine.time_scale = UI_TIME_SCALE
	_tree.change_scene_to_file(MENU)
	var menu := await _await_scene(MENU)
	if menu == null:
		return outcome
	_button(menu, "INICIAR PARTIDA").pressed.emit()
	var pre := await _await_scene(PRE_GAME) as LearningFlow
	if pre == null:
		return outcome
	var consent := index % 4 != 3
	var participant: String = _session.participant_id
	await _run_pre_game(pre, consent)
	var game := await _await_scene(GAME) as GameManager
	if game == null:
		return outcome
	Engine.time_scale = 1.0
	game.pacing = 0.0
	var played := await _play_game(game, index % 2 == 1)
	outcome["memories"] = played["memories"]
	outcome["failures"] = played["failures"]
	var cinematic := await _await_scene(CINEMATIC) as LastDoorCinematic
	if cinematic == null:
		return outcome
	outcome["skipped"] = index % 2 == 0
	if outcome["skipped"]:
		cinematic.skip()
	cinematic.pacing = 0.0
	Engine.time_scale = UI_TIME_SCALE
	var post := await _await_scene(POST_GAME) as LearningFlow
	if post == null:
		return outcome
	await _run_post_game(post)
	var back := await _await_scene(MENU)
	outcome["completed"] = back != null and _session.participant_id != participant
	outcome["coherent"] = _record_is_coherent(participant, consent, outcome)
	return outcome


func _run_pre_game(flow: LearningFlow, consent: bool) -> void:
	var consent_view := await _await_view(flow, InfoView) as InfoView
	consent_view.buttons()[0 if consent else 1].pressed.emit()
	await _answer_trivia(await _await_view(flow, TriviaView) as TriviaView)
	(await _await_view(flow, HowToView) as HowToView).close_button().pressed.emit()
	await _read_pages(flow)


func _run_post_game(flow: LearningFlow) -> void:
	await _read_pages(flow)
	await _answer_trivia(await _await_view(flow, TriviaView) as TriviaView)
	_button(await _await_view(flow, ResultsView), "CONTINUAR").pressed.emit()
	var survey := await _await_view(flow, SurveyView) as SurveyView
	for item in range(7):
		survey.select(item, _rng.randi_range(1, 5))
	survey.submit_button().pressed.emit()
	(await _await_view(flow, InfoView) as InfoView).buttons()[0].pressed.emit()


func _answer_trivia(view: TriviaView) -> void:
	_button(view, "EMPEZAR").pressed.emit()
	for i in range(QUESTION_COUNT):
		view.choose(_rng.randi_range(0, 4))
	await _tree.process_frame


func _read_pages(flow: LearningFlow) -> void:
	for i in range(FRAME_BUDGET):
		if not is_instance_valid(flow) or not flow.current_view() is PageView:
			return
		(flow.current_view() as PageView).advance()
		await _tree.process_frame

# ---------------------------------------------------------------------------
# La partida
# ---------------------------------------------------------------------------

## Perfecta o con decisiones al azar (el primer fallo reinicia; después, perfecta).
func _play_game(game: GameManager, random: bool) -> Dictionary:
	var result := {"memories": 0, "failures": 0}
	var failed := false
	var handled := Vector2i(-1, -1)
	for i in range(FRAME_BUDGET):
		if not is_instance_valid(game) or _tree.current_scene != game:
			return result
		await _tree.process_frame
		if not is_instance_valid(game) or game._busy:
			continue
		var step := Vector2i(game._run.index, game.state)
		if step == handled:
			continue
		match game.state:
			GameManager.State.EXPLORACION:
				handled = step
				var wrong := random and not failed and _rng.randf() < WRONG_CHANCE
				if wrong:
					failed = true
					result["failures"] += 1
				game._hud.press_decision(_answer(game, wrong))
			GameManager.State.REFERENCIA, GameManager.State.PUERTA_ABIERTA:
				handled = step
				if game._room.has_memory_offer() and _rng.randf() < READ_MEMORY_CHANCE:
					result["memories"] += await _read_memory(game)
				game._on_message_action(Room.DOOR_ACTION)
	return result


func _answer(game: GameManager, wrong: bool) -> AnswerEvaluator.Answer:
	var has_anomaly := game._current_anomaly != null
	return AnswerEvaluator.Answer.ANOMALY if has_anomaly != wrong else AnswerEvaluator.Answer.NO_ANOMALY


func _read_memory(game: GameManager) -> int:
	var spot := game._room.memory_spot()
	game._player.global_position = spot.interactable.global_position
	for i in range(4):
		await _tree.physics_frame
	if game._player.get_interactable() != spot.interactable:
		return 0
	game._try_interact()
	game._hud.reveal_all()
	game._hud.close_message()
	await _tree.process_frame
	return 1

# ---------------------------------------------------------------------------
# Ayudantes
# ---------------------------------------------------------------------------

func _record_is_coherent(participant: String, consent: bool, outcome: Dictionary) -> bool:
	var path := TEMP_RESULTS + participant + ".json"
	if not consent:
		return not FileAccess.file_exists(path)
	var record: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not record is Dictionary:
		return false
	var data := record as Dictionary
	return data.get("completed") == true \
		and data.get("cinematic_skipped") == outcome["skipped"] \
		and (data.get("memories_found") as Array).size() == outcome["memories"] \
		and int(data.get("attempts")) == 1 + int(outcome["failures"]) \
		and int(data.get("gain")) == int(data["post"]["score"]) - int(data["pre"]["score"])


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


func _button(root: Node, text: String) -> Button:
	for node in root.find_children("*", "Button", true, false):
		if (node as Button).text == text:
			return node as Button
	return null


func _clean_results() -> void:
	var global := ProjectSettings.globalize_path(TEMP_RESULTS)
	if DirAccess.dir_exists_absolute(global):
		for file_name in DirAccess.get_files_at(global):
			DirAccess.remove_absolute(global + file_name)
		DirAccess.remove_absolute(global)
