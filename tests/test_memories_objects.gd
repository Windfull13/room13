extends RefCounted

## Bloque B1, B4 y B5: recuerdos de objeto (datos, cuándo se ofrecen, lectura
## única, panel con E, puerta usable sin leer), voces opcionales y registro.

const Reporter := preload("res://tests/reporter.gd")
const GameDriver := preload("res://tests/game_driver.gd")
const MEMORY_COUNT := 20
const MAX_TEXT := 220
const TEMP_VOICES := "user://zz_voces_prueba/"
const TEST_VOICE := "voz_de_prueba"
const DUCK_DB := 8.0
const SENTENCE_STARTS := [".", "!", "?", "«", ":"]

var _report: Reporter
var _tree: SceneTree
var _catalog: ObjectMemoryCatalog
var _session: Node


func run(report: Reporter, tree: SceneTree) -> void:
	report.start("Recuerdos de objeto, voces y registro")
	_report = report
	_tree = tree
	_catalog = ObjectMemoryCatalog.default()
	_session = tree.root.get_node("Session")
	_check_data()
	await _check_offer_rules()
	await _check_reading_flow()
	await _check_every_memory_is_reachable()
	await _check_voices()
	_check_record_fields()

# ---------------------------------------------------------------------------
# Datos
# ---------------------------------------------------------------------------

func _check_data() -> void:
	_report.check(_catalog != null and _catalog.count() == MEMORY_COUNT, "hay %d recuerdos de objeto (%d)" % [MEMORY_COUNT, _catalog.count() if _catalog else -1])
	_report.check(_catalog.panel_title == "RECUERDO" and _catalog.notice_text == "Hay un recuerdo en este objeto.", "título del panel y aviso como se pidieron")
	var ids := {}
	var room := (load("res://scenes/rooms/room_base.tscn") as PackedScene).instantiate()
	for memory in _catalog.entries:
		ids[memory.anomaly_id] = true
		var path := "res://resources/anomalies/%s.tres" % memory.anomaly_id
		var anomaly := load(path) as AnomalyData if ResourceLoader.exists(path) else null
		_report.check(anomaly != null and not anomaly.is_dangerous, "%s: la anomalía existe y no es peligrosa" % memory.anomaly_id)
		_report.check(room.get_node_or_null("World/" + memory.object_node) != null, "%s: el objeto %s existe en la habitación" % [memory.anomaly_id, memory.object_node])
		_report.check(memory.text.length() <= MAX_TEXT and not memory.text.is_empty(), "%s: texto de %d caracteres (≤ %d)" % [memory.anomaly_id, memory.text.length(), MAX_TEXT])
		var names := _proper_names(memory.text)
		_report.check(names.is_empty(), "%s: sin nombres propios %s" % [memory.anomaly_id, str(names)])
	room.free()
	_report.check(ids.size() == MEMORY_COUNT, "cada recuerdo es de una anomalía distinta")
	_report.check(_catalog.for_anomaly("telefono_sonando").voice_id == "voice_phone_msg", "el mensaje del teléfono tiene su voz opcional voice_phone_msg")


## Palabras en mayúscula que no empiezan frase ni cita (posibles nombres propios).
func _proper_names(text: String) -> Array[String]:
	var found: Array[String] = []
	var words := text.split(" ", false)
	for i in range(1, words.size()):
		var word := words[i].lstrip("«¿¡")
		var previous := words[i - 1]
		var starts_sentence := SENTENCE_STARTS.any(func(mark: String) -> bool: return previous.ends_with(mark)) or words[i].begins_with("«") or words[i].begins_with("¿")
		if not word.is_empty() and word[0] == word[0].to_upper() and word[0] != word[0].to_lower() and not starts_sentence:
			found.append(word)
	return found

# ---------------------------------------------------------------------------
# Cuándo se ofrece
# ---------------------------------------------------------------------------

func _check_offer_rules() -> void:
	_session.begin_new()
	var driver := GameDriver.new(_tree)
	await driver.boot()
	await driver.enter_decision_room()
	await driver.force_anomaly(GameDriver.load_anomaly("reloj_detenido"))
	_report.check(not driver.room().has_memory_offer(), "antes de responder no hay recuerdo")
	driver.manager.pacing = 0.1
	driver.answer(AnswerEvaluator.Answer.ANOMALY)
	_report.check(driver.room().has_memory_offer(), "tras ACERTAR una anomalía con recuerdo, el objeto lo ofrece")
	var spot := driver.room().memory_spot()
	_report.check(spot.find_child("Brillo", true, false) != null, "el objeto brilla mientras el recuerdo está disponible")
	var hud := driver.manager._hud
	_report.check(hud._notice_label.text != _catalog.notice_text, "primero se ve el aviso de la puerta abierta")
	await _tree.create_timer(0.4).timeout
	_report.check(hud.is_notice_visible() and hud._notice_label.text == _catalog.notice_text, "después aparece el aviso «Hay un recuerdo en este objeto.»")
	driver.manager.pacing = 0.0
	await driver.restart()
	await driver.enter_decision_room()
	await driver.force_anomaly(GameDriver.load_anomaly("foto_cambiada"))
	driver.answer(AnswerEvaluator.Answer.NO_ANOMALY)
	await driver.await_state(GameManager.State.REFERENCIA)
	await driver.await_idle()
	_report.check(not driver.room().has_memory_offer(), "tras FALLAR no se ofrece ningún recuerdo")
	await driver.enter_decision_room()
	await driver.force_anomaly(null)
	driver.answer(AnswerEvaluator.Answer.NO_ANOMALY)
	await driver.await_idle()
	_report.check(driver.manager.state == GameManager.State.PUERTA_ABIERTA and not driver.room().has_memory_offer(), "en una ronda normal acertada no hay recuerdo")
	driver.cross_door()
	await driver.await_state(GameManager.State.EXPLORACION)
	await driver.await_idle()
	await driver.force_anomaly(GameDriver.load_anomaly("testigo_cuarto"))
	driver.answer(AnswerEvaluator.Answer.ANOMALY)
	await driver.await_idle()
	_report.check(not driver.room().has_memory_offer(), "con una anomalía peligrosa acertada no hay recuerdo")
	await driver.shutdown()

# ---------------------------------------------------------------------------
# Lectura
# ---------------------------------------------------------------------------

func _press_interact() -> void:
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	Input.parse_input_event(event)
	await _tree.process_frame
	await _tree.process_frame
	var release := InputEventAction.new()
	release.action = "interact"
	release.pressed = false
	Input.parse_input_event(release)
	await _tree.process_frame


func _check_reading_flow() -> void:
	_session.begin_new()
	var driver := GameDriver.new(_tree)
	await driver.boot()
	await driver.enter_decision_room()
	var memory := _catalog.for_anomaly("caja_de_musica")
	await driver.force_anomaly(GameDriver.load_anomaly("caja_de_musica"))
	driver.answer(AnswerEvaluator.Answer.ANOMALY)
	await driver.await_idle()
	var interactable := driver.room().memory_spot().interactable
	_report.check(interactable != driver.room().get_node_or_null("World/MusicBox/Interactable") and interactable.get_parent() == driver.room().memory_spot(), "un objeto sin Interactable recibe uno temporal mientras dura el recuerdo")
	await driver.teleport_player(interactable.global_position)
	_report.check(driver.player().get_interactable() == interactable, "junto al objeto, el recuerdo es lo que se examina")
	_report.check(driver.manager._hud._prompt_label.text.contains(_catalog.prompt_verb), "la indicación dice «%s»: %s" % [_catalog.prompt_verb, driver.manager._hud._prompt_label.text])
	driver.manager.pacing = 1.0
	await _press_interact()
	var hud := driver.manager._hud
	_report.check(driver.manager.state == GameManager.State.MENSAJE and hud._message_name.text == "RECUERDO", "E abre el panel de recuerdo con el título RECUERDO")
	_report.check(hud._message_text.text == memory.text, "el panel muestra el texto del recuerdo")
	await _tree.create_timer(0.3).timeout
	_report.check(hud.is_revealing() and hud.message_text_ratio() > 0.0 and hud.message_text_ratio() < 1.0, "el texto se escribe poco a poco (%.0f %%)" % (hud.message_text_ratio() * 100.0))
	await _press_interact()
	_report.check(hud.message_text_ratio() == 1.0 and driver.manager.state == GameManager.State.MENSAJE, "la primera E completa el texto sin cerrar")
	await _press_interact()
	driver.manager.pacing = 0.0
	_report.check(driver.manager.state == GameManager.State.PUERTA_ABIERTA and not hud._message_panel.visible, "la segunda E cierra el panel")
	_report.check(_session.has_memory("caja_de_musica") and _session.memories_found.size() == 1, "el recuerdo queda registrado en Session")
	_report.check(not driver.room().has_memory_offer(), "el objeto vuelve a su estado normal (sin brillo ni punto temporal)")
	await _tree.process_frame
	_report.check(not is_instance_valid(interactable) or not interactable.is_inside_tree(), "el Interactable temporal desaparece")
	await driver.restart()
	await driver.enter_decision_room()
	await driver.force_anomaly(GameDriver.load_anomaly("caja_de_musica"))
	driver.answer(AnswerEvaluator.Answer.ANOMALY)
	await driver.await_idle()
	_report.check(not driver.room().has_memory_offer(), "un recuerdo ya leído no se vuelve a ofrecer en la misma sesión")
	await _check_reused_object_and_door(driver)
	await driver.shutdown()


func _check_reused_object_and_door(driver: GameDriver) -> void:
	driver.cross_door()
	await driver.await_state(GameManager.State.EXPLORACION)
	await driver.await_idle()
	await driver.force_anomaly(GameDriver.load_anomaly("reloj_detenido"))
	driver.answer(AnswerEvaluator.Answer.ANOMALY)
	await driver.await_idle()
	var clock := driver.room().get_node("World/Clock/Interactable") as Interactable
	_report.check(driver.room().memory_spot().interactable == clock and clock.prompt_verb == _catalog.prompt_verb, "un objeto con Interactable propio lo reutiliza mientras dura el recuerdo")
	var original_verb: String = driver.room().memory_spot()._saved_verb
	driver.room().take_memory()
	_report.check(clock.prompt_verb == original_verb and clock.pick_priority == 0, "al retirar el recuerdo, el objeto recupera su verbo y su prioridad")
	await driver.force_anomaly(GameDriver.load_anomaly("reloj_detenido"))
	driver.manager._set_state(GameManager.State.EXPLORACION)
	driver.answer(AnswerEvaluator.Answer.ANOMALY)
	await driver.await_idle()
	var index: int = driver.manager._run.index
	driver.cross_door()
	await driver.await_idle()
	_report.check(driver.manager._run.index == index + 1, "la puerta funciona sin leer el recuerdo (es opcional)")
	_report.check(not _session.has_memory("reloj_detenido"), "cruzar sin leer no cuenta como recuerdo encontrado")
	await driver.force_anomaly(GameDriver.load_anomaly("golpes_en_la_puerta"))
	driver.answer(AnswerEvaluator.Answer.ANOMALY)
	await driver.await_idle()
	var door := driver.room().get_node("World/Door/Interactable") as Interactable
	_report.check(driver.room().memory_spot().interactable == door, "golpes_en_la_puerta guarda su recuerdo en la puerta")
	await driver.teleport_player(door.global_position)
	driver.manager._try_interact()
	_report.check(driver.manager._hud._message_name.text == "RECUERDO" and driver.manager._hud._action_button.visible, "el recuerdo de la puerta sigue ofreciendo CRUZAR LA PUERTA")
	index = driver.manager._run.index
	driver.manager._hud._action_button.pressed.emit()
	await driver.await_idle()
	_report.check(driver.manager._run.index == index + 1 and _session.has_memory("golpes_en_la_puerta"), "desde el recuerdo de la puerta se puede cruzar, y queda leído")


## Cada uno de los 20 se ofrece y se puede abrir desde su punto de interacción.
func _check_every_memory_is_reachable() -> void:
	_session.begin_new()
	var driver := GameDriver.new(_tree)
	await driver.boot()
	await driver.enter_decision_room()
	var reachable := 0
	var failures: Array[String] = []
	for memory in _catalog.entries:
		await driver.force_anomaly(GameDriver.load_anomaly(memory.anomaly_id))
		driver.manager._set_state(GameManager.State.EXPLORACION)
		driver.answer(AnswerEvaluator.Answer.ANOMALY)
		await driver.await_idle()
		var spot := driver.room().memory_spot()
		if spot == null:
			failures.append(memory.anomaly_id + " (sin oferta)")
			continue
		await driver.teleport_player(spot.interactable.global_position)
		if driver.player().get_interactable() != spot.interactable:
			failures.append(memory.anomaly_id + " (no se elige)")
			continue
		driver.manager._try_interact()
		if driver.manager._hud._message_text.text == memory.text:
			reachable += 1
		else:
			failures.append(memory.anomaly_id + " (texto)")
		driver.manager._hud.close_message()
		driver.room().lock_door()
	_report.check(reachable == MEMORY_COUNT, "los 20 recuerdos se ofrecen y se abren junto a su objeto (%d) %s" % [reachable, str(failures)])
	_report.check(_session.memories_found.size() == MEMORY_COUNT, "se registran los 20 (%d)" % _session.memories_found.size())
	await driver.shutdown()

# ---------------------------------------------------------------------------
# Voces
# ---------------------------------------------------------------------------

func _check_voices() -> void:
	var audio: Node = _tree.root.get_node("AudioManager")
	var music_bus := AudioServer.get_bus_index("Music")
	var before := AudioServer.get_bus_volume_db(music_bus)
	_report.check(not audio.play_voice("voice_phone_msg") and not audio.is_voice_playing(), "sin archivo, play_voice devuelve false (las voces aún no están grabadas)")
	_report.check(is_equal_approx(AudioServer.get_bus_volume_db(music_bus), before), "sin archivo la música no cambia")
	var original_dir: String = audio.voice_dir
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMP_VOICES))
	_write_test_voice(TEMP_VOICES + TEST_VOICE + ".wav", 0.6)
	audio.voice_dir = TEMP_VOICES
	_report.check(audio.play_voice(TEST_VOICE) and audio.is_voice_playing(), "con un archivo de prueba, play_voice devuelve true y suena")
	_report.check(is_equal_approx(AudioServer.get_bus_volume_db(music_bus), before - DUCK_DB), "mientras suena la voz la música baja 8 dB")
	var deadline := Time.get_ticks_msec() + 3000
	while audio.is_voice_playing() and Time.get_ticks_msec() < deadline:
		await _tree.process_frame
	await _tree.process_frame
	_report.check(is_equal_approx(AudioServer.get_bus_volume_db(music_bus), before), "al terminar la voz la música se restaura")
	audio.play_voice(TEST_VOICE)
	audio.stop_voice()
	_report.check(not audio.is_voice_playing() and is_equal_approx(AudioServer.get_bus_volume_db(music_bus), before), "al saltar (stop_voice) la música también se restaura")
	audio.voice_dir = original_dir
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_VOICES + TEST_VOICE + ".wav"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_VOICES))


func _write_test_voice(path: String, seconds: float) -> void:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var frames := int(seconds * wav.mix_rate)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		data.encode_s16(i * 2, int(sin(i * 0.05) * 3000.0))
	wav.data = data
	wav.save_to_wav(ProjectSettings.globalize_path(path))

# ---------------------------------------------------------------------------
# Registro
# ---------------------------------------------------------------------------

func _check_record_fields() -> void:
	_session.begin_new()
	_session.record_memory("caja_de_musica")
	_session.record_memory("caja_de_musica")
	_session.record_cinematic(true)
	var record: Dictionary = _session.build_record()
	_report.check(record.has("memories_found") and record["memories_found"] == ["caja_de_musica"], "el JSON incluye memories_found (sin repetidos)")
	_report.check(record.get("cinematic_skipped") == true, "el JSON incluye cinematic_skipped")
	_session.begin_new()
	_report.check(_session.build_record()["memories_found"].is_empty() and _session.build_record()["cinematic_skipped"] == null, "una sesión nueva empieza sin recuerdos y sin cinemática")
