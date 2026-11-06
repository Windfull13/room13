class_name InfoView
extends Control

## Pantalla con título, texto y uno o más botones. Sirve para el propósito y el
## consentimiento, la ayuda y cualquier aviso. Emite el botón elegido.

signal chosen(index: int)

var _buttons: Array[Button] = []


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)


func setup(title_text: String, paragraphs: Array[String], button_labels: Array[String]) -> void:
	var column := LearningUi.centered_column(self)
	column.add_child(LearningUi.title(title_text))
	for paragraph in paragraphs:
		column.add_child(LearningUi.body(paragraph))
	for i in range(button_labels.size()):
		var button := LearningUi.button(button_labels[i], 420.0)
		button.pressed.connect(chosen.emit.bind(i))
		_buttons.append(button)
	var row_buttons := _buttons.duplicate()
	column.add_child(LearningUi.button_row(row_buttons))
	LearningUi.fade_in(self)
	focus_first.call_deferred()


func focus_first() -> void:
	if not _buttons.is_empty():
		_buttons[0].grab_focus()


func buttons() -> Array[Button]:
	return _buttons
