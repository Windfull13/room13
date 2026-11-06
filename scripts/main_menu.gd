extends Control

## Pantalla principal: a la izquierda el título y las cuatro opciones (partida,
## opciones, créditos y salir); a la derecha, una imagen viva que anuncia de qué
## va el juego. Cada submenú es una «pantalla» y solo hay una visible a la vez;
## Esc vuelve a la principal. Todo se maneja con ratón o teclado.

const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const CreditsText := preload("res://scripts/ui/credits_text.gd")
const PRE_GAME_SCENE := "res://scenes/learning/pre_game.tscn"
const CREDITS_PATH := "res://CREDITS.md"
const CREDITS_MISSING := "No se encontró CREDITS.md."
const MENU_MUSIC := "music_menu"
const CLICK_SOUND := "ui_click"
const FOLDER_FAILED := "No se pudo abrir la carpeta de resultados."
const FOLDER_NOTICE_TIME := 3.0
const HOWTO_CLOSE_LABEL := "VOLVER"
const SCREEN_FADE_TIME := 0.25
const TITLE_BREATH_TIME := 3.6
const TITLE_DIM_ALPHA := 0.82
const TITLE_DRIFT := 3.0
const TITLE_FLICKER: Array[Vector2] = [Vector2(0.55, 0.05), Vector2(1.0, 0.06), Vector2(0.78, 0.07), Vector2(1.0, 0.1)]
const TITLE_FLICKER_EVERY := 9.0
const PANEL_ENTER_SCALE := 0.95

@onready var _main_screen: Control = $MainScreen
@onready var _options_screen: Control = $OptionsScreen
@onready var _credits_screen: Control = $CreditsScreen
@onready var _title: Label = $MainScreen/Title
@onready var _subtitle: Label = $MainScreen/Subtitle
@onready var _start_button: Button = $MainScreen/MenuColumn/StartButton
@onready var _fullscreen_check: CheckBox = $OptionsScreen/Panel/Box/FullscreenCheck
@onready var _folder_notice: Label = $OptionsScreen/Panel/Box/FolderNotice
@onready var _credits_text: RichTextLabel = $CreditsScreen/Panel/Box/Scroll/Text
@onready var _menu_buttons: Array[Button] = [
	$MainScreen/MenuColumn/StartButton,
	$MainScreen/MenuColumn/HowToButton,
	$MainScreen/MenuColumn/OptionsButton,
	$MainScreen/MenuColumn/CreditsButton,
	$MainScreen/MenuColumn/QuitButton,
]


## Cómo se abre una carpeta del sistema. Las pruebas lo sustituyen para no abrir ventanas.
var folder_opener: Callable = OS.shell_open
var _howto: HowToView = null


func _ready() -> void:
	Session.begin_new()
	theme = UiTheme.build()
	_fill_credits()
	_connect_buttons()
	AudioManager.play_music(MENU_MUSIC)
	_show_screen(_main_screen)
	_animate_title()
	ButtonFx.slide_in(_menu_buttons)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not _main_screen.visible:
		_on_back_pressed()
		get_viewport().set_input_as_handled()


func _fill_credits() -> void:
	var markdown := FileAccess.get_file_as_string(CREDITS_PATH)
	_credits_text.text = CreditsText.from_markdown(markdown) if not markdown.is_empty() else CREDITS_MISSING


func _connect_buttons() -> void:
	for button in _menu_buttons + _sub_screen_buttons():
		ButtonFx.attach(button)
	_start_button.pressed.connect(_on_start_pressed)
	$MainScreen/MenuColumn/HowToButton.pressed.connect(_open_howto)
	$MainScreen/MenuColumn/OptionsButton.pressed.connect(_open.bind(_options_screen))
	$MainScreen/MenuColumn/CreditsButton.pressed.connect(_open.bind(_credits_screen))
	$MainScreen/MenuColumn/QuitButton.pressed.connect(AudioManager.quit_cleanly)
	$OptionsScreen/Panel/Box/ResultsFolderButton.pressed.connect(open_results_folder)
	_fullscreen_check.set_pressed_no_signal(DisplayManager.is_fullscreen())
	_fullscreen_check.toggled.connect(DisplayManager.set_fullscreen.bind(true))
	DisplayManager.fullscreen_changed.connect(_fullscreen_check.set_pressed_no_signal)
	$OptionsScreen/Panel/Box/BackButton.pressed.connect(_on_back_pressed)
	$CreditsScreen/Panel/Box/BackButton.pressed.connect(_on_back_pressed)


func _sub_screen_buttons() -> Array[Button]:
	return [$OptionsScreen/Panel/Box/ResultsFolderButton, $OptionsScreen/Panel/Box/BackButton, $CreditsScreen/Panel/Box/BackButton]


func _on_start_pressed() -> void:
	AudioManager.play(CLICK_SOUND)
	Session.begin_new()
	get_tree().change_scene_to_file(PRE_GAME_SCENE)


## «Cómo jugar» como superposición; al cerrarla el foco vuelve a su botón.
func _open_howto() -> void:
	AudioManager.play(CLICK_SOUND)
	_howto = HowToView.new()
	add_child(_howto)
	_howto.setup(LearningContent.default(), HOWTO_CLOSE_LABEL)
	_howto.closed.connect(_close_howto)


func _close_howto() -> void:
	_howto.queue_free()
	_howto = null
	$MainScreen/MenuColumn/HowToButton.grab_focus()


## Abre la carpeta de resultados; si no se puede, avisa sin dar error.
func open_results_folder() -> void:
	var store := Session.store
	var opened := store.ensure_directory() and int(folder_opener.call(store.global_directory())) == OK
	_folder_notice.text = "" if opened else FOLDER_FAILED
	if not opened:
		get_tree().create_timer(FOLDER_NOTICE_TIME).timeout.connect(_folder_notice.set_text.bind(""))


func _open(screen: Control) -> void:
	AudioManager.play(CLICK_SOUND)
	_show_screen(screen)


func _on_back_pressed() -> void:
	AudioManager.play(CLICK_SOUND)
	_show_screen(_main_screen)


## Muestra una pantalla (con un fundido corto) y deja el foco en su botón.
func _show_screen(screen: Control) -> void:
	for candidate: Control in [_main_screen, _options_screen, _credits_screen]:
		candidate.visible = candidate == screen
	screen.modulate.a = 0.0
	create_tween().tween_property(screen, "modulate:a", 1.0, SCREEN_FADE_TIME)
	var focus := _start_button if screen == _main_screen else screen.find_child("BackButton") as Button
	focus.grab_focus()


## El título respira y se desplaza unos píxeles; de vez en cuando la luz le falla.
func _animate_title() -> void:
	var home := _title.position.y
	var breath := create_tween().set_loops().set_parallel(false)
	breath.tween_property(_title, "modulate:a", TITLE_DIM_ALPHA, TITLE_BREATH_TIME).set_trans(Tween.TRANS_SINE)
	breath.tween_property(_title, "modulate:a", 1.0, TITLE_BREATH_TIME).set_trans(Tween.TRANS_SINE)
	var drift := create_tween().set_loops()
	drift.tween_property(_title, "position:y", home + TITLE_DRIFT, TITLE_BREATH_TIME * 1.4).set_trans(Tween.TRANS_SINE)
	drift.tween_property(_title, "position:y", home, TITLE_BREATH_TIME * 1.4).set_trans(Tween.TRANS_SINE)
	var flicker := create_tween().set_loops()
	flicker.tween_interval(TITLE_FLICKER_EVERY)
	for step in TITLE_FLICKER:
		flicker.tween_property(_subtitle, "modulate:a", step.x, step.y)