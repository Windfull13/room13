extends RefCounted

## Audio: los archivos existen y suenan de verdad (picos en su bus), cada
## sonido se detiene, los bucles hacen bucle, los sustos tienen sonido propio,
## y la partida enciende y apaga lo que toca sin dejar nada sonando.
## No juzga cómo suena: solo que se reproduce y se detiene.

const Reporter := preload("res://tests/reporter.gd")
const GameDriver := preload("res://tests/game_driver.gd")
const SoundCatalog := preload("res://scripts/audio/sound_catalog.gd")
const JUMPSCARE_DIR := "res://scenes/jumpscares/"
const SESSION_SCRIPT := "res://tests/project_session.gd"
const SESSION_STEPS: Array[String] = ["SESION menu", "SESION pre_juego", "SESION vuelta_al_menu"]
const AUDIBLE_DB := -60.0
const LISTEN_SECONDS := 0.6
const LOOP_PROBE := "danger_heartbeat"
const RESTARTS := 10
const WALK_FRAMES := 40
const SETTLE_FRAMES := 30
const WARNING_OFFSET := Vector2(0, -110)
const TEST_VOLUME := 0.37

var _report: Reporter
var _driver: GameDriver
var _audio: Node
var _tree: SceneTree


func run(report: Reporter, tree: SceneTree) -> void:
	report.start("Audio: archivos, reproducción, parada y salida limpia")
	_report = report
	_tree = tree
	_audio = tree.root.get_node("AudioManager")
	_check_buses()
	_check_files()
	await _check_each_sound_plays_and_stops()
	await _check_loops()
	_check_jumpscare_sounds()
	_check_missing_sound_is_harmless()
	_check_master_volume()
	_driver = GameDriver.new(tree)
	await _driver.boot()
	await _check_round_music_and_ambient()
	await _check_footsteps()
	await _check_danger_warning()
	await _check_pause()
	await _check_restarts_leave_nothing()
	await _check_jumpscare_silences_music()
	await _check_end_music()
	_check_volume_slider()
	await _driver.shutdown()
	_report.check(_audio._warned.size() == 1, "el juego solo pidió sonidos que existen (avisos: %s)" % str(_audio._warned.keys()))
	_check_clean_session()

# ---------------------------------------------------------------------------
# Datos y archivos
# ---------------------------------------------------------------------------

func _check_buses() -> void:
	for bus in SoundCatalog.BUSES:
		_report.check(AudioServer.get_bus_index(bus) > 0, "existe el bus %s (default_bus_layout.tres)" % bus)


func _check_files() -> void:
	for sound_name: String in SoundCatalog.SOUNDS:
		var path: String = SoundCatalog.entry(sound_name)["file"]
		var stream: AudioStream = _audio.stream_for(sound_name)
		var length := stream.get_length() if stream != null else 0.0
		_report.check(ResourceLoader.exists(path) and stream != null and length > 0.0, "%s: %s existe, carga y dura %.2f s" % [sound_name, path.get_file(), length])

# ---------------------------------------------------------------------------
# Reproducción real
# ---------------------------------------------------------------------------

## Cada sonido, solo, produce señal en su bus (no es silencio) y se detiene.
## Se graba la salida mezclada del bus: así cuenta cada muestra, también la de
## un clic de pocos milisegundos.
func _check_each_sound_plays_and_stops() -> void:
	for sound_name: String in SoundCatalog.SOUNDS:
		var bus: String = SoundCatalog.entry(sound_name)["bus"]
		var recorder := _attach_recorder(bus)
		_start(sound_name)
		await _tree.create_timer(LISTEN_SECONDS).timeout
		var peak := _peak_db(recorder.get_recording())
		print("    %-26s pico grabado en %-7s %6.1f dB" % [sound_name, bus, peak])
		_detach_recorder(bus, recorder)
		_stop(sound_name)
		await _tree.process_frame
		var stopped: bool = not _audio.is_active(sound_name) and _audio.current_music() != sound_name
		_report.check(peak > AUDIBLE_DB and stopped, "%s se oye en %s (pico %.1f dB) y se detiene" % [sound_name, bus, peak])


func _check_loops() -> void:
	for sound_name: String in SoundCatalog.SOUNDS:
		if SoundCatalog.entry(sound_name).get("loop", false):
			var stream: AudioStream = _audio.stream_for(sound_name)
			var looping: bool = stream.loop if stream is AudioStreamOggVorbis else false
			_report.check(looping, "%s está en bucle" % sound_name)
	var length: float = _audio.stream_for(LOOP_PROBE).get_length()
	_audio.play(LOOP_PROBE)
	await _tree.create_timer(length + 0.6).timeout
	_report.check(_audio.is_playing(LOOP_PROBE), "%s (%.1f s) sigue sonando pasado su final: el bucle funciona" % [LOOP_PROBE, length])
	_audio.stop(LOOP_PROBE)


func _check_jumpscare_sounds() -> void:
	var used: Array[String] = []
	for file_name in DirAccess.get_files_at(JUMPSCARE_DIR):
		if not file_name.ends_with(".tscn") or file_name == "jumpscare_base.tscn":
			continue
		var jumpscare := (load(JUMPSCARE_DIR + file_name) as PackedScene).instantiate() as JumpscareBase
		var sound_name := jumpscare.sound_name
		_report.check(SoundCatalog.has(sound_name), "%s tiene sonido propio: %s" % [file_name, sound_name])
		_report.check(not used.has(sound_name), "%s no comparte sonido con otro susto" % file_name)
		used.append(sound_name)
		_tree.root.add_child(jumpscare)
		var flash := jumpscare.get_node("Flash") as ColorRect
		jumpscare.play(0.0)
		_report.check(_audio.is_playing(sound_name) and flash.color.a == 1.0, "%s: el sonido arranca con el destello" % file_name)
		_audio.stop(sound_name)
	_report.check(used.size() == 9, "hay 9 sustos con sonido (%d)" % used.size())


func _check_missing_sound_is_harmless() -> void:
	var active_before: int = _audio.active_sounds().size()
	_audio.play("sonido_que_no_existe")
	_audio.play("sonido_que_no_existe")
	_report.check(_audio._warned.size() == 1 and _audio.active_sounds().size() == active_before, "un sonido desconocido avisa una sola vez y no rompe nada")


func _check_master_volume() -> void:
	var original: float = _audio.get_master_volume()
	_audio.set_master_volume(TEST_VOLUME)
	var config := ConfigFile.new()
	config.load(UserSettings.path)
	var saved: float = config.get_value(_audio.SETTINGS_SECTION, _audio.SETTINGS_KEY, -1.0)
	_report.check(is_equal_approx(saved, TEST_VOLUME), "el volumen general se guarda en user://settings.cfg (%.2f)" % saved)
	_report.check(is_equal_approx(AudioServer.get_bus_volume_db(0), linear_to_db(TEST_VOLUME)), "el volumen general ajusta el bus Master")
	_audio.set_master_volume(0.0)
	_report.check(AudioServer.is_bus_mute(0), "volumen 0 silencia el bus Master")
	_audio.set_master_volume(original)

# ---------------------------------------------------------------------------
# Partida
# ---------------------------------------------------------------------------

func _check_round_music_and_ambient() -> void:
	_report.check(_audio.current_music() == "music_calm", "la referencia usa la música tranquila (%s)" % _audio.current_music())
	_report.check(_audio.is_playing("ambient_room"), "durante la partida suena el ambiente")
	await _driver.enter_decision_room()
	_report.check(_audio.current_music() == "music_tense", "las rondas de decisión pasan a la música tensa (%s)" % _audio.current_music())
	await _driver.restart()


func _check_footsteps() -> void:
	var steps := [0]
	_driver.player().footstep.connect(func() -> void: steps[0] += 1)
	Input.action_press("move_down")
	var heard := false
	for i in range(WALK_FRAMES):
		await _tree.physics_frame
		heard = heard or _audio.is_playing("footstep")
	Input.action_release("move_down")
	_report.check(steps[0] > 0 and heard, "al caminar suenan pasos (%d pasos)" % steps[0])
	for i in range(SETTLE_FRAMES):
		await _tree.physics_frame
	var after_stop: int = steps[0]
	for i in range(SETTLE_FRAMES):
		await _tree.physics_frame
	_report.check(steps[0] == after_stop, "al parar ya no suenan pasos")


func _check_danger_warning() -> void:
	await _driver.enter_decision_room()
	await _driver.force_anomaly(GameDriver.load_anomaly("testigo_cuarto"))
	var monster_position := _driver.room().get_monster().global_position
	await _driver.teleport_player(monster_position + WARNING_OFFSET)
	_report.check(_audio.is_playing("danger_heartbeat"), "entrar en el radio de aviso inicia el latido")
	await _driver.teleport_player(_driver.room().get_player_spawn())
	_report.check(not _audio.is_active("danger_heartbeat"), "salir del radio de aviso lo detiene")
	await _driver.teleport_player(monster_position + WARNING_OFFSET)
	_driver.answer(AnswerEvaluator.Answer.ANOMALY)
	await _tree.process_frame
	_report.check(not _audio.is_active("danger_heartbeat"), "acertar detiene el latido")
	await _driver.restart()


func _check_pause() -> void:
	_driver.manager._toggle_pause()
	_report.check(_audio.is_paused("ambient_room") and not _audio.is_playing("ambient_room"), "la pausa detiene el ambiente")
	_driver.manager._toggle_pause()
	_report.check(_audio.is_playing("ambient_room"), "quitar la pausa reanuda el ambiente")


## Tras un fallo con susto (y con el latido sonando) o sin susto, la partida
## nueva solo tiene su ambiente y no aparecen reproductores nuevos.
func _check_restarts_leave_nothing() -> void:
	var players: int = _audio.player_count()
	var children: int = _audio.get_child_count()
	var leftovers: Array[String] = []
	for i in range(RESTARTS):
		await _driver.enter_decision_room()
		if i % 2 == 0:
			await _driver.force_anomaly(GameDriver.load_anomaly("testigo_esquina"))
			await _driver.teleport_player(_driver.room().get_monster().global_position + WARNING_OFFSET)
			_driver.answer(AnswerEvaluator.Answer.NO_ANOMALY)
		else:
			await _driver.force_anomaly(null)
			_driver.answer(AnswerEvaluator.Answer.ANOMALY)
		await _driver.await_state(GameManager.State.REFERENCIA)
		await _driver.await_idle()
		if _audio.active_sounds() != ["ambient_room"]:
			leftovers.append(str(_audio.active_sounds()))
	_report.check(leftovers.is_empty(), "tras %d reinicios solo suena el ambiente nuevo: %s" % [RESTARTS, str(leftovers)])
	_report.check(_audio.player_count() == players and _audio.get_child_count() == children, "el número de reproductores no crece (%d)" % _audio.get_child_count())


func _check_jumpscare_silences_music() -> void:
	await _driver.enter_decision_room()
	await _driver.force_anomaly(GameDriver.load_anomaly("figura_cama"))
	_driver.manager.pacing = 1.0
	_driver.answer(AnswerEvaluator.Answer.NO_ANOMALY)
	await _tree.process_frame
	_report.check(_audio.current_music() == "" and _audio.is_playing("jumpscare_cama"), "durante el susto la música calla y suena el susto")
	_report.check(not _audio.is_active("ambient_room"), "durante el susto el ambiente calla")
	await _driver.await_state(GameManager.State.REFERENCIA)
	_driver.manager.pacing = 0.0
	await _driver.await_idle()
	_report.check(_audio.current_music() == "music_calm", "tras el susto vuelve la música tranquila")


func _check_end_music() -> void:
	await _driver.enter_decision_room()
	var last_index: int = _driver.manager._rooms.size() - 1
	while _driver.manager._run.index < last_index:
		_driver.answer(_driver.correct_answer())
		_driver.cross_door()
		await _driver.await_idle()
	_driver.answer(_driver.correct_answer())
	_driver.cross_door()
	await _driver.await_state(GameManager.State.FINAL)
	_report.check(_audio.active_sounds().is_empty(), "al terminar no queda ningún efecto ni ambiente: %s" % str(_audio.active_sounds()))


func _check_volume_slider() -> void:
	var slider := _driver.manager.get_node("HUD/Root/PausePanel/Center/Box/VolumeControl/Slider") as HSlider
	var original: float = _audio.get_master_volume()
	_report.check(is_equal_approx(slider.value, original), "el slider de la pausa muestra el volumen guardado")
	slider.value = TEST_VOLUME
	_report.check(is_equal_approx(_audio.get_master_volume(), TEST_VOLUME), "mover el slider cambia el volumen general")
	slider.value = original

# ---------------------------------------------------------------------------
# Sesión real en otro proceso
# ---------------------------------------------------------------------------

func _check_clean_session() -> void:
	var output: Array = []
	var args := ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--max-fps", "60", "--script", SESSION_SCRIPT]
	var exit_code := OS.execute(OS.get_executable_path(), args, output, true)
	var lines := Array("\n".join(output).split("\n"))
	var errors: Array[String] = []
	for line: String in lines:
		if line.contains("ERROR"):
			errors.append(line.strip_edges())
	var steps_seen := SESSION_STEPS.filter(func(step: String) -> bool: return lines.any(func(line: String) -> bool: return line.begins_with(step)))
	_report.check(exit_code == 0 and steps_seen.size() == SESSION_STEPS.size(), "sesión real menú → pre-juego → menú → SALIR completa (código %d, pasos %d)" % [exit_code, steps_seen.size()])
	_report.check(errors.is_empty(), "la sesión real no imprime errores del motor ni de los scripts: %s" % str(errors))

# ---------------------------------------------------------------------------
# Ayudantes
# ---------------------------------------------------------------------------

func _start(sound_name: String) -> void:
	if SoundCatalog.is_music(sound_name):
		_audio.play_music(sound_name, 0.0)
	else:
		_audio.play(sound_name)


func _stop(sound_name: String) -> void:
	if SoundCatalog.is_music(sound_name):
		_audio.stop_music(0.0)
	else:
		_audio.stop(sound_name)


func _attach_recorder(bus: String) -> AudioEffectRecord:
	var recorder := AudioEffectRecord.new()
	recorder.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(AudioServer.get_bus_index(bus), recorder)
	recorder.set_recording_active(true)
	return recorder


func _detach_recorder(bus: String, recorder: AudioEffectRecord) -> void:
	recorder.set_recording_active(false)
	var index := AudioServer.get_bus_index(bus)
	AudioServer.remove_bus_effect(index, AudioServer.get_bus_effect_count(index) - 1)


## Pico (dBFS) de una grabación de 16 bits.
func _peak_db(recording: AudioStreamWAV) -> float:
	if recording == null:
		return -200.0
	var data := recording.data
	var peak := 0
	for offset in range(0, data.size() - 1, 2):
		peak = maxi(peak, absi(data.decode_s16(offset)))
	return linear_to_db(maxf(peak / 32768.0, 0.00001))