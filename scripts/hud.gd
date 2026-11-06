class_name HUD
extends CanvasLayer

## Interfaz de usuario del juego de exploración.
##
## Indicador de ronda, indicación contextual de interacción, aviso de peligro,
## ventana de mensaje con gestión de foco, barra de decisión (dos opciones),
## reacción de acierto, fin de partida y pausa.
## No contiene lógica de juego: solo informa y emite señales.

signal decision_made(answer: int)
signal message_closed
signal message_action(action_id: String)
signal menu_pressed
signal resume_pressed
## Se pulsó TERMINAR Y EVALUAR en la pausa (modo feria); aún falta confirmar.
signal evaluate_pressed
## Respuesta del cuadro de confirmación: true = aceptar, false = seguir jugando.
signal confirm_answered(accepted: bool)

const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const COLOR_CORRECT := Color(0.45, 0.82, 0.5)
const CLICK_SOUND := "ui_click"
const PAUSE_FADE_TIME := 0.25
const PAUSE_ENTER_SCALE := 0.94
const PAUSE_BUTTON_SIZE := Vector2(380, 68)
const PAUSE_BUTTON_FONT := 26
const HINT_FONT := 22
const HINT_WIDTH := 520.0
const CONFIRM_TEXT_WIDTH := 640.0
const CONFIRM_DIM := Color(0.02, 0.02, 0.03, 0.82)
const CONFIRM_LAYER_NAME := "ConfirmPanel"

@onready var _root: Control = $Root
@onready var _round_label: Label = $Root/RoundLabel
@onready var _prompt_label: Label = $Root/PromptLabel
@onready var _danger_label: Label = $Root/DangerLabel
@onready var _notice_label: Label = $Root/NoticeLabel
@onready var _message_panel: PanelContainer = $Root/MessageAnchor/MessagePanel
@onready var _message_name: Label = $Root/MessageAnchor/MessagePanel/Margin/Box/MessageName
@onready var _message_text: Label = $Root/MessageAnchor/MessagePanel/Margin/Box/MessageText
@onready var _action_button: Button = $Root/MessageAnchor/MessagePanel/Margin/Box/MessageButtons/ActionButton
@onready var _close_button: Button = $Root/MessageAnchor/MessagePanel/Margin/Box/MessageButtons/CloseButton
@onready var _decision_bar: Control = $Root/DecisionAnchor
@onready var _anomaly_button: Button = $Root/DecisionAnchor/DecisionBar/Margin/Box/Buttons/AnomalyButton
@onready var _no_anomaly_button: Button = $Root/DecisionAnchor/DecisionBar/Margin/Box/Buttons/NoAnomalyButton
@onready var _result_container: CenterContainer = $Root/ResultContainer
@onready var _result_title: Label = $Root/ResultContainer/ResultPanel/Margin/ResultBox/ResultTitle
@onready var _result_detail: Label = $Root/ResultContainer/ResultPanel/Margin/ResultBox/ResultDetail
@onready var _result_meaning: Label = $Root/ResultContainer/ResultPanel/Margin/ResultBox/ResultMeaning
@onready var _end_panel: Control = $Root/EndPanel
@onready var _end_title: Label = $Root/EndPanel/Center/Box/Title
@onready var _end_body: Label = $Root/EndPanel/Center/Box/Body
@onready var _end_menu: Button = $Root/EndPanel/Center/Box/MenuButton
@onready var _pause_panel: Control = $Root/PausePanel
@onready var _pause_box: Control = $Root/PausePanel/Center/Box
@onready var _resume_button: Button = $Root/PausePanel/Center/Box/ResumeButton
@onready var _howto_button: Button = $Root/PausePanel/Center/Box/HowToButton
@onready var _pause_menu: Button = $Root/PausePanel/Center/Box/MenuButton

var _pending_action_id: String = ""
var _pause_tween: Tween
## Elementos de la pausa que solo existen para el modo feria (se crean al abrirla).
var _evaluate_button: Button
var _evaluate_hint: Label
var _confirm_panel: Control
var _confirm_text: Label
var _confirm_accept: Button
var _confirm_cancel: Button
## Escritura progresiva del texto de un recuerdo.
var _reveal_tween: Tween
## Turno de ocultado de cada aviso temporal: un aviso nuevo invalida el anterior.
var _hide_turns: Dictionary = {}


func _ready() -> void:
	_root.theme = UiTheme.build()
	_anomaly_button.pressed.connect(_on_decision_pressed.bind(AnswerEvaluator.Answer.ANOMALY, "ui_decision_anomaly"))
	_no_anomaly_button.pressed.connect(_on_decision_pressed.bind(AnswerEvaluator.Answer.NO_ANOMALY, "ui_decision_no_anomaly"))
	_action_button.pressed.connect(_on_action_pressed)
	_close_button.pressed.connect(close_message)
	_connect_menu_button(_end_menu, menu_pressed)
	_connect_menu_button(_resume_button, resume_pressed)
	_connect_menu_button(_pause_menu, menu_pressed)
	_howto_button.pressed.connect(_open_howto)
	_build_fair_pause_items()
	_build_confirm_panel()
	for button: Button in [_anomaly_button, _no_anomaly_button, _action_button, _close_button, _end_menu, _resume_button, _howto_button, _pause_menu]:
		ButtonFx.attach(button)
	clear()


## La misma decisión (y el mismo sonido) que pulsar el botón; la usan las teclas 1 y 2.
func press_decision(answer: AnswerEvaluator.Answer) -> void:
	var button := _anomaly_button if answer == AnswerEvaluator.Answer.ANOMALY else _no_anomaly_button
	button.pressed.emit()


func _on_decision_pressed(answer: AnswerEvaluator.Answer, sound_name: String) -> void:
	AudioManager.play(sound_name)
	decision_made.emit(answer)


func _connect_menu_button(button: Button, relay: Signal) -> void:
	button.pressed.connect(func() -> void:
		AudioManager.play(CLICK_SOUND)
		relay.emit())


func _on_action_pressed() -> void:
	var action_id := _pending_action_id
	_message_panel.visible = false
	_close_button.release_focus()
	message_action.emit(action_id)


func close_message() -> void:
	if not _message_panel.visible:
		return
	_message_panel.visible = false
	_close_button.release_focus()
	message_closed.emit()


## Texto del indicador de ronda.
func set_round_text(text: String) -> void:
	_round_label.text = text


## Indicación contextual de interacción ("E — Examinar ..."). Vacío = ocultar.
func set_prompt(text: String) -> void:
	_prompt_label.text = text
	_prompt_label.visible = not text.is_empty()


## Aviso de peligro cercano.
func set_danger_warning(active: bool) -> void:
	_danger_label.visible = active


## Muestra u oculta la barra con las dos opciones de decisión.
func set_decision_bar_visible(shown: bool) -> void:
	_decision_bar.visible = shown


## Muestra la ventana de mensaje de un objeto interactivo, gestionando el foco.
func show_message(data: Dictionary) -> void:
	_stop_reveal()
	_message_text.visible_ratio = 1.0
	_pending_action_id = String(data.get("action_id", ""))
	_message_name.text = String(data.get("name", ""))
	_message_text.text = String(data.get("message", ""))
	var action_text := String(data.get("button_text", ""))
	if action_text.is_empty():
		_action_button.visible = false
		_close_button.text = "Continuar"
	else:
		_action_button.visible = true
		_action_button.text = action_text
		_close_button.text = "Cancelar"
	_message_panel.visible = true
	_close_button.grab_focus()


## Panel de recuerdo: el mismo estilo que un mensaje, con el texto apareciendo
## poco a poco durante `reveal_seconds` (0 = de golpe).
func show_memory(data: Dictionary, reveal_seconds: float) -> void:
	show_message(data)
	if reveal_seconds <= 0.0:
		return
	_message_text.visible_ratio = 0.0
	_reveal_tween = create_tween()
	_reveal_tween.tween_property(_message_text, "visible_ratio", 1.0, reveal_seconds)


func is_revealing() -> bool:
	return _reveal_tween != null and _reveal_tween.is_valid() and _reveal_tween.is_running()


## Muestra ya todo el texto que se estaba escribiendo.
func reveal_all() -> void:
	_stop_reveal()
	_message_text.visible_ratio = 1.0


func message_text_ratio() -> float:
	return _message_text.visible_ratio


func _stop_reveal() -> void:
	if _reveal_tween != null and _reveal_tween.is_valid():
		_reveal_tween.kill()
	_reveal_tween = null


## Aviso de acierto durante `seconds` segundos.
func show_success(detail: String, seconds: float, meaning: String = "") -> void:
	_result_title.text = "CORRECTO"
	_result_title.add_theme_color_override("font_color", COLOR_CORRECT)
	_result_detail.text = detail
	_result_meaning.text = meaning
	_result_meaning.visible = not meaning.is_empty()
	_show_briefly(_result_container, seconds)


## Aviso de una línea bajo el indicador de ronda durante `seconds` segundos.
func show_notice(text: String, seconds: float) -> void:
	_notice_label.text = text
	_show_briefly(_notice_label, seconds)


func is_notice_visible() -> bool:
	return _notice_label.visible


func hide_result() -> void:
	_hide(_result_container)


func _show_briefly(control: Control, seconds: float) -> void:
	var turn: int = _hide_turns.get(control, 0) + 1
	_hide_turns[control] = turn
	control.visible = true
	# La espera es un tween del propio HUD: si el HUD se libera antes (volver al
	# menú), el tween muere con él y no queda nada pendiente.
	var wait := create_tween()
	wait.tween_interval(maxf(seconds, 0.0))
	await wait.finished
	if _hide_turns.get(control, 0) == turn:
		control.visible = false


func _hide(control: Control) -> void:
	_hide_turns[control] = _hide_turns.get(control, 0) + 1
	control.visible = false


## Deja la interfaz como al empezar una partida.
func clear() -> void:
	if _confirm_panel != null:
		_confirm_panel.visible = false
	hide_result()
	_hide(_notice_label)
	hide_end()
	hide_pause()
	set_decision_bar_visible(false)
	set_prompt("")
	set_danger_warning(false)
	_message_panel.visible = false


## Pantalla de fin de partida.
func show_end(title: String, body: String) -> void:
	_end_title.text = title
	_end_body.text = body
	_end_panel.visible = true
	_end_menu.grab_focus()


func hide_end() -> void:
	_end_panel.visible = false


## Pantalla de pausa: aparece con un fundido y un ligero crecimiento.
func show_pause(offer_evaluation: bool = false) -> void:
	_stop_pause_animation()
	_evaluate_button.visible = offer_evaluation
	_evaluate_hint.visible = offer_evaluation
	_pause_panel.visible = true
	_pause_panel.modulate.a = 0.0
	_pause_box.pivot_offset = _pause_box.size / 2.0
	_pause_box.scale = Vector2.ONE * PAUSE_ENTER_SCALE
	_pause_tween = create_tween().set_parallel(true)
	_pause_tween.tween_property(_pause_panel, "modulate:a", 1.0, PAUSE_FADE_TIME)
	_pause_tween.tween_property(_pause_box, "scale", Vector2.ONE, PAUSE_FADE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_resume_button.grab_focus()


## Con `animated` se desvanece; sin él (reinicios, cambios de escena) se oculta ya.
func hide_pause(animated: bool = false) -> void:
	_stop_pause_animation()
	if not animated or not _pause_panel.visible:
		_pause_panel.visible = false
		return
	_pause_tween = create_tween()
	_pause_tween.tween_property(_pause_panel, "modulate:a", 0.0, PAUSE_FADE_TIME * 0.7)
	_pause_tween.tween_callback(_pause_panel.hide)


func is_evaluate_visible() -> bool:
	return _evaluate_button.visible and _pause_panel.visible


func evaluate_hint_text() -> String:
	return _evaluate_hint.text


## Cuadro de confirmación sobre la pausa; el foco empieza en la opción segura.
func show_confirm(text: String, accept_label: String, cancel_label: String) -> void:
	_confirm_text.text = text
	_confirm_accept.text = accept_label
	_confirm_cancel.text = cancel_label
	_confirm_panel.visible = true
	_confirm_cancel.grab_focus()


func is_confirm_visible() -> bool:
	return _confirm_panel.visible


## Esc o SEGUIR JUGANDO: se cierra sin hacer nada.
func cancel_confirm() -> void:
	_answer_confirm(false)


func confirm_buttons() -> Array[Button]:
	return [_confirm_accept, _confirm_cancel]


func _answer_confirm(accepted: bool) -> void:
	if not _confirm_panel.visible:
		return
	_confirm_panel.visible = false
	if _pause_panel.visible:
		_resume_button.grab_focus()
	confirm_answered.emit(accepted)


func _build_fair_pause_items() -> void:
	var content := LearningContent.default()
	var box := _pause_menu.get_parent()
	_evaluate_hint = Label.new()
	_evaluate_hint.text = content.fair_pause_hint
	_evaluate_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_evaluate_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_evaluate_hint.custom_minimum_size = Vector2(HINT_WIDTH, 0)
	_evaluate_hint.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_evaluate_hint.add_theme_font_size_override("font_size", HINT_FONT)
	_evaluate_hint.add_theme_color_override("font_color", UiTheme.INK_DIM)
	_evaluate_button = _make_button(content.fair_finish_button, PAUSE_BUTTON_SIZE, PAUSE_BUTTON_FONT)
	_connect_menu_button(_evaluate_button, evaluate_pressed)
	for item: Control in [_evaluate_hint, _evaluate_button]:
		item.visible = false
		box.add_child(item)
		box.move_child(item, _pause_menu.get_index())


func _build_confirm_panel() -> void:
	var content := LearningContent.default()
	_confirm_panel = Control.new()
	_confirm_panel.name = CONFIRM_LAYER_NAME
	_confirm_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm_panel.visible = false
	var dim := ColorRect.new()
	dim.color = CONFIRM_DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm_panel.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm_panel.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	panel.add_child(column)
	_confirm_text = Label.new()
	_confirm_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_text.custom_minimum_size = Vector2(CONFIRM_TEXT_WIDTH, 0)
	_confirm_text.add_theme_font_size_override("font_size", PAUSE_BUTTON_FONT)
	column.add_child(_confirm_text)
	_confirm_accept = _make_button(content.fair_finish_button, PAUSE_BUTTON_SIZE, PAUSE_BUTTON_FONT)
	_confirm_cancel = _make_button(content.fair_keep_playing, PAUSE_BUTTON_SIZE, PAUSE_BUTTON_FONT)
	for button in [_confirm_accept, _confirm_cancel]:
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(button)
	_keep_focus_between(_confirm_accept, _confirm_cancel)
	_confirm_accept.pressed.connect(AudioManager.play.bind(CLICK_SOUND))
	_confirm_cancel.pressed.connect(AudioManager.play.bind(CLICK_SOUND))
	_confirm_accept.pressed.connect(_answer_confirm.bind(true))
	_confirm_cancel.pressed.connect(_answer_confirm.bind(false))
	_root.add_child(_confirm_panel)


func _make_button(text: String, minimum: Vector2, font_size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = minimum
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", font_size)
	ButtonFx.attach(button)
	return button


## El teclado solo se mueve entre las dos opciones (una sobre otra), nunca a la pausa de debajo.
func _keep_focus_between(upper: Button, lower: Button) -> void:
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP]:
		upper.set_focus_neighbor(side, upper.get_path_to(upper))
		lower.set_focus_neighbor(side, lower.get_path_to(upper) if side == SIDE_TOP else lower.get_path_to(lower))
	upper.set_focus_neighbor(SIDE_BOTTOM, upper.get_path_to(lower))
	lower.set_focus_neighbor(SIDE_BOTTOM, lower.get_path_to(lower))
	upper.focus_next = upper.get_path_to(lower)
	upper.focus_previous = upper.get_path_to(lower)
	lower.focus_next = lower.get_path_to(upper)
	lower.focus_previous = lower.get_path_to(upper)


func is_pause_visible() -> bool:
	return _pause_panel.visible


## «Cómo jugar» sobre la pausa; al cerrarlo el foco vuelve a su botón.
func _open_howto() -> void:
	var view := HowToView.new()
	_root.add_child(view)
	view.setup(LearningContent.default(), "VOLVER")
	view.closed.connect(_close_howto.bind(view))


func _close_howto(view: HowToView) -> void:
	view.queue_free()
	_howto_button.grab_focus()


func _stop_pause_animation() -> void:
	if _pause_tween != null and _pause_tween.is_valid():
		_pause_tween.kill()
	_pause_tween = null