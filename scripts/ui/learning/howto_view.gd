class_name HowToView
extends Control

## Pantalla de «Cómo jugar», reutilizable desde el menú, el pre-juego y la
## pausa. Con `closes_on_pause` el Esc la cierra (como superposición); en el
## pre-juego, Esc abre la pausa, así que lo gestiona el flujo.

signal closed

const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const DIM_COLOR := Color(0.02, 0.02, 0.03, 0.94)
const TEXT_WIDTH := 900.0

var closes_on_pause: bool = true
var _close_button: Button
var _text: Label


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)


func setup(content: LearningContent, close_label: String) -> void:
	theme = UiTheme.build()
	var dim := ColorRect.new()
	dim.color = DIM_COLOR
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var column := LearningUi.centered_column(self, 18)
	column.add_child(LearningUi.title(content.howto_title, 50))
	_text = LearningUi.body(HowToText.build(content), TEXT_WIDTH, LearningUi.TEXT_SIZE)
	column.add_child(_text)
	_close_button = LearningUi.button(close_label, 340.0)
	_close_button.pressed.connect(closed.emit)
	column.add_child(LearningUi.button_row([_close_button]))
	_keep_focus_on(_close_button)
	LearningUi.fade_in(self, 0.25)
	_close_button.grab_focus.call_deferred()


## El teclado no puede escaparse a los botones que quedan debajo de la superposición.
func _keep_focus_on(button: Button) -> void:
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		button.set_focus_neighbor(side, button.get_path())
	button.focus_next = button.get_path()
	button.focus_previous = button.get_path()


func text_shown() -> String:
	return _text.text


func close_button() -> Button:
	return _close_button


func _unhandled_input(event: InputEvent) -> void:
	if closes_on_pause and event.is_action_pressed("pause"):
		closed.emit()
		get_viewport().set_input_as_handled()
