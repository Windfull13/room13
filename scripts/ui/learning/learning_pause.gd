class_name LearningPause
extends Control

## Pausa de las pantallas de pre y post-juego: volumen, reanudar, cómo jugar y
## volver al menú. Misma estética que la pausa de la partida.

signal resume_requested
signal menu_requested

const VOLUME_CONTROL := preload("res://scenes/ui/volume_control.tscn")
const DIM_COLOR := Color(0.02, 0.02, 0.03, 0.88)

var _content: LearningContent
var _howto: HowToView
var _resume_button: Button
var _howto_button: Button
var _menu_button: Button


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false


func setup(content: LearningContent) -> void:
	_content = content
	var dim := ColorRect.new()
	dim.color = DIM_COLOR
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var column := LearningUi.centered_column(self, 22)
	column.add_child(LearningUi.title("Pausa", 72))
	column.add_child(VOLUME_CONTROL.instantiate())
	_resume_button = _add_button(column, "REANUDAR", resume_requested.emit)
	_howto_button = _add_button(column, "CÓMO JUGAR", _open_howto)
	_menu_button = _add_button(column, "MENÚ PRINCIPAL", menu_requested.emit)


func open() -> void:
	visible = true
	_resume_button.grab_focus()


func close() -> void:
	visible = false


func is_howto_open() -> bool:
	return _howto != null and is_instance_valid(_howto)


func howto_button() -> Button:
	return _howto_button


func menu_button() -> Button:
	return _menu_button


func _add_button(column: VBoxContainer, text: String, action: Callable) -> Button:
	var button := LearningUi.button(text, 380.0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(action)
	column.add_child(button)
	return button


func _open_howto() -> void:
	_howto = HowToView.new()
	add_child(_howto)
	_howto.setup(_content, "VOLVER")
	_howto.closed.connect(_close_howto)


func _close_howto() -> void:
	_howto.queue_free()
	_howto = null
	_howto_button.grab_focus()
