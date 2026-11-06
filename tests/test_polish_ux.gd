extends RefCounted

## Bloque A: decisión con las teclas 1 y 2, pantalla completa (F11 y casilla),
## ajustes guardados en settings.cfg y pistas luminosas de las anomalías sonoras.

const Reporter := preload("res://tests/reporter.gd")
const GameDriver := preload("res://tests/game_driver.gd")
const MENU_SCENE := "res://scenes/main_menu.tscn"
const TEMP_SETTINGS := "user://zz_settings_test.cfg"
const BLOCKED_SETTINGS := "user://zz_carpeta_inexistente/settings.cfg"
const CONTACT_SHEET := "res://dev/contact_sheet.tscn"
const CUE_METRICS := "res://dev/out/anomaly_contact_metrics_parcial.txt"
const CUE_ANOMALIES: Array[String] = ["telefono_sonando", "golpes_en_la_puerta"]
const MIN_CUE_PIXELS := 60
const SOUND_YES := "ui_decision_anomaly"
const SOUND_NO := "ui_decision_no_anomaly"

var _report: Reporter
var _tree: SceneTree
var _audio: Node


func run(report: Reporter, tree: SceneTree) -> void:
	report.start("Pulido A: teclas 1/2, pantalla completa, ajustes y pistas luminosas")
	_report = report
	_tree = tree
	_audio = tree.root.get_node("AudioManager")
	await _check_decision_keys()
	_check_howto_mentions_keys()
	await _check_fullscreen_and_settings()
	await _check_cue_nodes()
	_check_cue_pixels_rendered()

# ---------------------------------------------------------------------------
# Ayudantes
# ---------------------------------------------------------------------------

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


var _listener: Callable


func _record_sounds() -> Array[String]:
	var heard: Array[String] = []
	_listener = func(sound_name: String) -> void: heard.append(sound_name)
	_audio.sound_started.connect(_listener)
	return heard

# ---------------------------------------------------------------------------
# Teclas 1 y 2
# ---------------------------------------------------------------------------

func _check_decision_keys() -> void:
	var driver := GameDriver.new(_tree)
	await driver.boot()
	var manager := driver.manager
	var yes_button := manager.get_node("HUD/Root/DecisionAnchor/DecisionBar/Margin/Box/Buttons/AnomalyButton") as Button
	var no_button := manager.get_node("HUD/Root/DecisionAnchor/DecisionBar/Margin/Box/Buttons/NoAnomalyButton") as Button
	_report.check(yes_button.text.begins_with("[1]") and no_button.text.begins_with("[2]"), "los botones muestran [1] y [2]: «%s» / «%s»" % [yes_button.text, no_button.text])
	var heard := _record_sounds()
	await _send_action("decide_anomaly")
	_report.check(manager.state == GameManager.State.REFERENCIA and heard.is_empty(), "en la referencia la tecla 1 no hace nada (ni suena)")
	await driver.enter_decision_room()
	await driver.force_anomaly(GameDriver.load_anomaly("reloj_detenido"))
	manager._toggle_pause()
	await _send_action("decide_anomaly")
	_report.check(manager.state == GameManager.State.EXPLORACION and not heard.has(SOUND_YES), "en pausa la tecla 1 no decide")
	manager._toggle_pause()
	await _send_action("decide_anomaly")
	_report.check(manager.state == GameManager.State.PUERTA_ABIERTA and heard.has(SOUND_YES), "la tecla 1 responde HAY ANOMALÍA con su sonido (acierto)")
	heard.clear()
	await _send_action("decide_no_anomaly")
	_report.check(manager.state == GameManager.State.PUERTA_ABIERTA and heard.is_empty(), "tras responder la tecla 2 se ignora")
	driver.cross_door()
	await driver.await_state(GameManager.State.EXPLORACION)
	await driver.await_idle()
	await driver.force_anomaly(null)
	await _send_action("decide_no_anomaly")
	_report.check(manager.state == GameManager.State.PUERTA_ABIERTA and heard.has(SOUND_NO), "la tecla 2 responde NO HAY ANOMALÍA con su sonido (habitación normal)")
	_audio.sound_started.disconnect(_listener)
	await driver.shutdown()


func _check_howto_mentions_keys() -> void:
	var text := HowToText.build(LearningContent.default())
	_report.check(text.contains("pulsa 1 para HAY ANOMALÍA o 2 para NO HAY ANOMALÍA"), "«Cómo jugar» explica las teclas 1 y 2 desde el InputMap")
	_report.check(text.contains("F11"), "«Cómo jugar» menciona F11 para la pantalla completa")
	_report.check(text.contains("Tras acertar una anomalía, examina el objeto: puede guardar un recuerdo."), "«Cómo jugar» explica los recuerdos de objeto")
	_report.check(InputMap.has_action("decide_anomaly") and InputMap.has_action("decide_no_anomaly") and InputMap.has_action("toggle_fullscreen"), "las acciones nuevas están en el InputMap")

# ---------------------------------------------------------------------------
# Pantalla completa y settings.cfg
# ---------------------------------------------------------------------------

func _check_fullscreen_and_settings() -> void:
	var display: Node = _tree.root.get_node("DisplayManager")
	var original_path := UserSettings.path
	var original_volume: float = _audio.get_master_volume()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_SETTINGS))
	UserSettings.path = TEMP_SETTINGS
	var was_fullscreen: bool = display.is_fullscreen()
	await _send_action("toggle_fullscreen")
	_report.check(display.is_fullscreen() != was_fullscreen, "F11 alterna la pantalla completa")
	_report.check(bool(UserSettings.load_value(display.SETTINGS_SECTION, display.SETTINGS_KEY, was_fullscreen)) == display.is_fullscreen(), "el cambio se guarda en settings.cfg")
	await _send_action("toggle_fullscreen")
	_report.check(display.is_fullscreen() == was_fullscreen, "otro F11 la devuelve")
	_audio.set_master_volume(0.37)
	display.set_fullscreen(true)
	var fresh: Node = load("res://scripts/settings/display_manager.gd").new()
	_tree.root.add_child(fresh)
	_report.check(fresh.is_fullscreen() and is_equal_approx(_audio._load_master_volume(), 0.37), "al arrancar se cargan pantalla completa y volumen guardados")
	fresh.free()
	await _check_menu_checkbox(display)
	UserSettings.path = BLOCKED_SETTINGS
	_report.check(not UserSettings.save_value("pantalla", "x", 1), "si no se puede escribir, save_value devuelve false (sin errores)")
	_report.check(UserSettings.load_value("pantalla", "x", 7) == 7, "si no se puede leer, devuelve el valor por defecto")
	display.set_fullscreen(false)
	_report.check(not display.is_fullscreen(), "el juego sigue funcionando con el archivo inaccesible")
	UserSettings.path = original_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_SETTINGS))
	display.set_fullscreen(was_fullscreen, false)
	_audio.set_master_volume(original_volume, false)


func _check_menu_checkbox(display: Node) -> void:
	_tree.change_scene_to_file(MENU_SCENE)
	await _tree.create_timer(0.5).timeout
	var menu := _tree.current_scene
	var check := menu.get_node("OptionsScreen/Panel/Box/FullscreenCheck") as CheckBox
	_report.check(check.button_pressed == display.is_fullscreen(), "la casilla de OPCIONES refleja el estado actual")
	check.button_pressed = false
	_report.check(not display.is_fullscreen(), "desmarcar la casilla sale de pantalla completa")
	check.button_pressed = true
	_report.check(display.is_fullscreen(), "marcar la casilla entra en pantalla completa")
	display.set_fullscreen(false)
	_report.check(not check.button_pressed, "F11 (o cualquier cambio) actualiza la casilla")
	menu.queue_free()
	await _tree.process_frame

# ---------------------------------------------------------------------------
# Pistas luminosas
# ---------------------------------------------------------------------------

func _check_cue_nodes() -> void:
	for anomaly_id in CUE_ANOMALIES:
		var driver := GameDriver.new(_tree)
		await driver.boot()
		await driver.enter_decision_room()
		await driver.force_anomaly(GameDriver.load_anomaly(anomaly_id))
		var ambience := driver.room().ambience()
		await _tree.create_timer(EntityAmbience.REPEAT_START_DELAY + 0.1).timeout
		var cue := ambience.cue_node()
		_report.check(cue != null and cue.is_inside_tree(), "%s: al sonar aparece la pista luminosa" % anomaly_id)
		var saw_lit := false
		var saw_dark := false
		for i in range(90):
			if cue == null or not is_instance_valid(cue):
				break
			saw_lit = saw_lit or cue.modulate.a > 0.99
			saw_dark = saw_dark or (saw_lit and cue.modulate.a < 0.01)
			await _tree.process_frame
		_report.check(saw_lit and saw_dark, "%s: la pista parpadea (se enciende y se apaga)" % anomaly_id)
		ambience.stop()
		await _tree.process_frame
		_report.check(ambience.cue_node() == null and driver.room().get_node("World").find_child(EntityAmbience.CUE_NODE_NAME, false, false) == null, "%s: al parar, la pista desaparece" % anomaly_id)
		await driver.shutdown()


## Render real (en otro proceso con ventana): la luz sola cambia ≥ 60 píxeles en la zona del objeto.
func _check_cue_pixels_rendered() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CUE_METRICS))
	OS.set_environment("ZIVA_ONLY", ",".join(CUE_ANOMALIES))
	var output: Array = []
	var args := PackedStringArray(["--path", ProjectSettings.globalize_path("res://"), CONTACT_SHEET])
	var code := OS.execute(OS.get_executable_path(), args, output, true)
	OS.unset_environment("ZIVA_ONLY")
	var metrics := FileAccess.get_file_as_string(CUE_METRICS)
	_report.check(code == 0 and not metrics.is_empty(), "dev/contact_sheet mide las pistas renderizando de verdad (código %d)" % code)
	for anomaly_id in CUE_ANOMALIES:
		var pixels := _cue_pixels(metrics, anomaly_id)
		_report.check(pixels >= MIN_CUE_PIXELS, "%s: la pista luminosa cambia %d píxeles (≥ %d)" % [anomaly_id, pixels, MIN_CUE_PIXELS])


func _cue_pixels(metrics: String, anomaly_id: String) -> int:
	for line in metrics.split("\n"):
		if line.begins_with(anomaly_id + " |"):
			return line.split(" | ")[4].to_int()
	return -1
