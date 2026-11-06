extends RefCounted

## Pantalla principal: es la escena de inicio, tiene sus cuatro botones, el
## aviso de contenido, créditos y opciones; INICIAR PARTIDA lleva a la
## habitación de referencia y volver desde la pausa deja el audio limpio.

const Reporter := preload("res://tests/reporter.gd")
const GameDriver := preload("res://tests/game_driver.gd")
const MENU_SCENE := "res://scenes/main_menu.tscn"
const MENU_MUSIC := "music_menu"
const BUTTON_TEXTS: Array[String] = ["INICIAR PARTIDA", "CÓMO JUGAR", "OPCIONES", "CRÉDITOS", "SALIR"]
const CONTENT_WARNING := "Este juego trata temas de duelo, acoso y salud mental."
const CREDITS_MUST_MENTION: Array[String] = ["Autoría", "Kenney", "CC0", "jumpscare_cama.wav"]
const FRAME_BUDGET := 1200
const WARNING_OFFSET := Vector2(0, -110)

var _report: Reporter
var _tree: SceneTree
var _audio: Node


func run(report: Reporter, tree: SceneTree) -> void:
	report.start("Menú principal")
	_report = report
	_tree = tree
	_audio = tree.root.get_node("AudioManager")
	_report.check(ProjectSettings.get_setting("application/run/main_scene") == MENU_SCENE, "el proyecto arranca en el menú (%s)" % ProjectSettings.get_setting("application/run/main_scene"))
	var menu := await _change_scene(MENU_SCENE)
	_report.check(menu != null, "el menú se carga como escena actual")
	if menu == null:
		return
	_check_main_screen(menu)
	await _check_credits(menu)
	await _check_options(menu)
	var game := await _start_game(menu)
	if game != null:
		await _check_back_to_menu(game)
	await _unload_current_scene()

# ---------------------------------------------------------------------------
# Pantalla principal
# ---------------------------------------------------------------------------

func _check_main_screen(menu: Node) -> void:
	for text in BUTTON_TEXTS:
		var button := _button(menu, text)
		_report.check(button != null and button.is_visible_in_tree(), "existe el botón %s" % text)
	_report.check(_label_with(menu, CONTENT_WARNING) != null, "se muestra el aviso de contenido")
	_report.check(_audio.current_music() == MENU_MUSIC, "suena la música del menú (%s)" % _audio.current_music())
	_report.check(menu.get_viewport().gui_get_focus_owner() == _button(menu, "INICIAR PARTIDA"), "el foco empieza en INICIAR PARTIDA")


func _check_credits(menu: Node) -> void:
	_button(menu, "CRÉDITOS").pressed.emit()
	var screen := menu.get_node("CreditsScreen") as Control
	var text := (menu.get_node("CreditsScreen/Panel/Box/Scroll/Text") as RichTextLabel).get_parsed_text()
	_report.check(screen.visible and not (menu.get_node("MainScreen") as Control).visible, "CRÉDITOS abre su panel en lugar de la pantalla principal")
	for fragment in CREDITS_MUST_MENTION:
		_report.check(text.contains(fragment), "los créditos muestran «%s» (desde CREDITS.md)" % fragment)
	_report.check(not text.contains("](") and not text.contains("|---"), "los créditos no muestran marcas de Markdown")
	await _press_back(menu, screen)


func _check_options(menu: Node) -> void:
	_button(menu, "OPCIONES").pressed.emit()
	var screen := menu.get_node("OptionsScreen") as Control
	var slider := screen.find_children("*", "HSlider", true, false)
	_report.check(screen.visible and slider.size() == 1, "OPCIONES abre el panel con el slider de volumen")
	if slider.size() == 1:
		var original: float = _audio.get_master_volume()
		(slider[0] as HSlider).value = 0.5
		_report.check(is_equal_approx(_audio.get_master_volume(), 0.5), "el slider de OPCIONES cambia el volumen general")
		(slider[0] as HSlider).value = original
	await _press_back(menu, screen)


func _press_back(menu: Node, screen: Control) -> void:
	(screen.find_child("BackButton") as Button).pressed.emit()
	await _tree.process_frame
	_report.check(not screen.visible and (menu.get_node("MainScreen") as Control).visible, "VOLVER regresa a la pantalla principal desde %s" % screen.name)

# ---------------------------------------------------------------------------
# Ida y vuelta a la partida
# ---------------------------------------------------------------------------

func _start_game(menu: Node) -> GameManager:
	_button(menu, "INICIAR PARTIDA").pressed.emit()
	var pre_game := await _await_current_scene("res://scenes/learning/pre_game.tscn")
	_report.check(pre_game is LearningFlow, "INICIAR PARTIDA abre el pre-juego, no la partida directamente")
	var game := await _change_scene(GameDriver.PARTIDA) as GameManager
	_report.check(game != null, "la partida carga tras el pre-juego")
	if game == null:
		return null
	var driver := _driver_for(game)
	_report.check(await driver.await_state(GameManager.State.REFERENCIA), "la partida empieza en la habitación de referencia")
	_report.check(game._run.index == 0 and game._rooms[0].is_reference, "es la ronda 0, la de referencia")
	_report.check(not game._hud._decision_bar.visible, "sin botones de decisión en la referencia")
	return game


func _check_back_to_menu(game: GameManager) -> void:
	var driver := _driver_for(game)
	game.pacing = 0.0
	await driver.await_idle()
	await driver.enter_decision_room()
	await driver.force_anomaly(GameDriver.load_anomaly("testigo_cuarto"))
	await driver.teleport_player(driver.room().get_monster().global_position + WARNING_OFFSET)
	var before: Array[String] = _audio.active_sounds()
	_report.check(before.has("ambient_room") and before.has("danger_heartbeat") and _audio.current_music() == "music_tense", "antes de salir suenan ambiente, latido y música tensa: %s" % str(before))
	game._toggle_pause()
	(game.get_node("HUD/Root/PausePanel/Center/Box/MenuButton") as Button).pressed.emit()
	var menu := await _await_current_scene(MENU_SCENE)
	await _tree.process_frame
	_report.check(menu != null, "MENÚ PRINCIPAL desde la pausa vuelve al menú")
	_report.check(_audio.active_sounds().is_empty(), "al volver no queda ningún sonido de la partida: %s" % str(_audio.active_sounds()))
	_report.check(_audio.playing_music() == [MENU_MUSIC], "al volver solo suena la música del menú: %s" % str(_audio.playing_music()))

# ---------------------------------------------------------------------------
# Ayudantes
# ---------------------------------------------------------------------------

func _driver_for(game: GameManager) -> GameDriver:
	var driver := GameDriver.new(_tree)
	driver.manager = game
	return driver


func _change_scene(path: String) -> Node:
	_tree.change_scene_to_file(path)
	return await _await_current_scene(path)


func _await_current_scene(path: String) -> Node:
	for i in range(FRAME_BUDGET):
		var scene := _tree.current_scene
		if scene != null and scene.scene_file_path == path and scene.is_node_ready():
			return scene
		await _tree.process_frame
	return null


func _unload_current_scene() -> void:
	if _tree.current_scene != null:
		_tree.current_scene.queue_free()
	_audio.stop_all()
	_audio.stop_music(0.0)
	await _tree.process_frame


func _button(root: Node, text: String) -> Button:
	for node in root.find_children("*", "Button", true, false):
		if (node as Button).text == text:
			return node as Button
	return null


func _label_with(root: Node, text: String) -> Label:
	for node in root.find_children("*", "Label", true, false):
		if (node as Label).text == text and (node as Label).is_visible_in_tree():
			return node as Label
	return null