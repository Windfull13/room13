extends Node

## Pantalla completa (autoload «DisplayManager»): F11 la alterna en cualquier
## escena, la casilla de OPCIONES también, y el estado se guarda en
## user://settings.cfg para recuperarlo al arrancar.

signal fullscreen_changed(enabled: bool)

const SETTINGS_SECTION := "pantalla"
const SETTINGS_KEY := "pantalla_completa"
const TOGGLE_ACTION := &"toggle_fullscreen"

var _fullscreen: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_fullscreen(bool(UserSettings.load_value(SETTINGS_SECTION, SETTINGS_KEY, false)), false)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(TOGGLE_ACTION) and not event.is_echo():
		set_fullscreen(not _fullscreen)
		get_viewport().set_input_as_handled()


func is_fullscreen() -> bool:
	return _fullscreen


## Cambia el modo de la ventana. Con `save` lo guarda (si se puede).
func set_fullscreen(enabled: bool, save: bool = true) -> void:
	_fullscreen = enabled
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)
	if save:
		UserSettings.save_value(SETTINGS_SECTION, SETTINGS_KEY, enabled)
	fullscreen_changed.emit(enabled)
