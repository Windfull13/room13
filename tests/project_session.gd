extends SceneTree

## Sesión real del juego, pulsando sus botones: menú → partida → menú → SALIR.
## test_audio.gd la lanza en un proceso aparte y revisa que la salida no tenga
## ninguna línea de error. Cada paso deja una marca «SESION» para comprobarlo.

const STEP_SECONDS := 1.5
const QUIT_TIMEOUT := 3.0


func _init() -> void:
	await process_frame
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await _wait(STEP_SECONDS)
	_mark("menu")
	_press("MainScreen/MenuColumn/StartButton")
	await _wait(STEP_SECONDS)
	_mark("pre_juego")
	current_scene.get_node("Pause").menu_button().pressed.emit()
	await _wait(STEP_SECONDS)
	_mark("vuelta_al_menu")
	_press("MainScreen/MenuColumn/QuitButton")
	await _wait(QUIT_TIMEOUT)
	print("SESION no_salio")
	quit(1)


func _press(path: String) -> void:
	(current_scene.get_node(path) as Button).pressed.emit()


func _mark(step: String) -> void:
	var audio := root.get_node("AudioManager")
	print("SESION %s escena=%s musica=%s sonidos=%s" % [step, current_scene.scene_file_path.get_file(), audio.current_music(), audio.active_sounds()])


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout