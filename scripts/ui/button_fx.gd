class_name ButtonFx
extends RefCounted

## Movimiento y sonido de un botón del menú: al pasar el ratón (o recibir el
## foco con el teclado) se ilumina, se adelanta unos píxeles y suena; al
## pulsarlo se hunde un instante. No toca el foco ni la navegación: solo anima.

const HOVER_SOUND := "ui_hover"
const NAVIGATION_ACTIONS: Array[StringName] = [&"ui_up", &"ui_down", &"ui_left", &"ui_right", &"ui_focus_next", &"ui_focus_prev"]
const HOVER_SHIFT := 12.0
const HOVER_SCALE := 1.03
const PRESS_SCALE := 0.96
const HOVER_TINT := Color(1.14, 1.08, 1.0)
const HOVER_TIME := 0.12
const PRESS_TIME := 0.07
const ENTER_TIME := 0.45
const ENTER_SLIDE := 46.0
const ENTER_STAGGER := 0.09

const REST_META := &"fx_rest_x"
const TWEEN_META := &"fx_tween"


## Añade el comportamiento a `button`. Un botón dentro de un contenedor no puede
## desplazarse (el contenedor manda), así que solo cambia de brillo y de tamaño.
static func attach(button: Button) -> void:
	button.set_meta(REST_META, button.position.x)
	button.pivot_offset = button.size / 2.0
	button.resized.connect(func() -> void: button.pivot_offset = button.size / 2.0)
	button.mouse_entered.connect(_highlight.bind(button, true, true))
	button.focus_entered.connect(func() -> void: _highlight(button, true, _is_keyboard_navigation()))
	button.mouse_exited.connect(_highlight.bind(button, false, false))
	button.focus_exited.connect(_highlight.bind(button, false, false))
	button.button_down.connect(_press.bind(button, true))
	button.button_up.connect(_press.bind(button, false))


## Entrada escalonada: cada botón aparece un poco después que el anterior.
static func slide_in(buttons: Array[Button]) -> void:
	for i in range(buttons.size()):
		var button := buttons[i]
		var rest_x := _rest_x(button)
		button.modulate.a = 0.0
		if _can_shift(button):
			button.position.x = rest_x - ENTER_SLIDE
		var tween := button.create_tween().set_parallel(true)
		tween.tween_property(button, "modulate:a", 1.0, ENTER_TIME).set_delay(i * ENTER_STAGGER)
		if _can_shift(button):
			tween.tween_property(button, "position:x", rest_x, ENTER_TIME).set_delay(i * ENTER_STAGGER).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## El foco que da el código al abrir un menú no suena: solo el ratón y las
## teclas de navegación.
static func _is_keyboard_navigation() -> bool:
	for action in NAVIGATION_ACTIONS:
		if Input.is_action_just_pressed(action):
			return true
	return false


static func _highlight(button: Button, active: bool, with_sound: bool) -> void:
	if active and with_sound and not button.disabled:
		AudioManager.play(HOVER_SOUND)
	var tween := _restart_tween(button).set_parallel(true)
	tween.tween_property(button, "modulate", HOVER_TINT if active else Color.WHITE, HOVER_TIME)
	tween.tween_property(button, "scale", Vector2.ONE * (HOVER_SCALE if active else 1.0), HOVER_TIME)
	if _can_shift(button):
		tween.tween_property(button, "position:x", _rest_x(button) + (HOVER_SHIFT if active else 0.0), HOVER_TIME)


static func _press(button: Button, down: bool) -> void:
	var scale_to := PRESS_SCALE if down else HOVER_SCALE
	_restart_tween(button).tween_property(button, "scale", Vector2.ONE * scale_to, PRESS_TIME)


static func _restart_tween(button: Button) -> Tween:
	if button.has_meta(TWEEN_META):
		var running: Tween = button.get_meta(TWEEN_META)
		if running != null and running.is_valid():
			running.kill()
	var tween := button.create_tween()
	button.set_meta(TWEEN_META, tween)
	return tween


static func _can_shift(button: Button) -> bool:
	return not (button.get_parent() is Container)


static func _rest_x(button: Button) -> float:
	return button.get_meta(REST_META) if button.has_meta(REST_META) else button.position.x