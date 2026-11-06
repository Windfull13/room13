class_name SurveyView
extends Control

## Encuesta de valoración: siete ítems obligatorios en escala 1-5 y un comentario
## opcional de hasta 200 caracteres. «ENVIAR» no se activa hasta contestar todos.

signal submitted(values: Dictionary, comment: String)

const SCALE_MIN := 1
const SCALE_MAX := 5
const LABEL_WIDTH := 760.0
const ROW_GAP := 6
const HINT_WIDTH := 1040.0
const SCALE_BUTTON_SIZE := Vector2(62, 42)
const COMMENT_MAX := 200
const KEY_FIRST := KEY_1

var _ids: PackedStringArray = []
var _values: Dictionary = {}
var _rows: Array[Array] = []
var _comment: LineEdit
var _submit: Button


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)


func setup(content: LearningContent) -> void:
	_ids = content.survey_ids
	var column := LearningUi.centered_column(self, ROW_GAP)
	column.add_child(LearningUi.title(content.survey_title, 40))
	column.add_child(_scale_hint(content.survey_scale_hint))
	for i in range(_ids.size()):
		column.add_child(_build_row(i, content.survey_texts[i]))
	_comment = LineEdit.new()
	_comment.max_length = COMMENT_MAX
	_comment.placeholder_text = content.survey_comment_prompt
	_comment.custom_minimum_size = Vector2(940, 44)
	_comment.add_theme_font_size_override("font_size", LearningUi.SMALL_TEXT_SIZE)
	column.add_child(_comment)
	_submit = LearningUi.button("ENVIAR", 340.0)
	_submit.disabled = true
	_submit.pressed.connect(_on_submit)
	column.add_child(LearningUi.button_row([_submit]))
	LearningUi.fade_in(self)
	_rows[0][0].grab_focus.call_deferred()


func _scale_hint(text: String) -> Label:
	var label := LearningUi.body(text, HINT_WIDTH, LearningUi.SMALL_TEXT_SIZE)
	label.add_theme_color_override("font_color", LearningUi.DIM_TEXT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func is_complete() -> bool:
	return _values.size() == _ids.size()


func submit_button() -> Button:
	return _submit


func comment_field() -> LineEdit:
	return _comment


func row_buttons(item_index: int) -> Array:
	return _rows[item_index]


## Marca el valor 1-5 del ítem `item_index`.
func select(item_index: int, value: int) -> void:
	_values[_ids[item_index]] = value
	(_rows[item_index][value - SCALE_MIN] as Button).button_pressed = true
	_submit.disabled = not is_complete()


func _build_row(item_index: int, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", ROW_GAP)
	row.add_child(LearningUi.body("%d. %s" % [item_index + 1, text], LABEL_WIDTH, LearningUi.SMALL_TEXT_SIZE))
	var group := ButtonGroup.new()
	var buttons: Array[Button] = []
	for value in range(SCALE_MIN, SCALE_MAX + 1):
		var button := Button.new()
		button.text = str(value)
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = SCALE_BUTTON_SIZE
		button.add_theme_font_size_override("font_size", LearningUi.TEXT_SIZE)
		button.pressed.connect(select.bind(item_index, value))
		ButtonFx.attach(button)
		row.add_child(button)
		buttons.append(button)
	_rows.append(buttons)
	return row


## Con el foco en una fila, las teclas 1-5 contestan ese ítem.
func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var value := key.keycode - KEY_FIRST + SCALE_MIN
	var item := _focused_item()
	if item >= 0 and value >= SCALE_MIN and value <= SCALE_MAX:
		select(item, value)
		get_viewport().set_input_as_handled()


func _focused_item() -> int:
	var focused := get_viewport().gui_get_focus_owner()
	for i in range(_rows.size()):
		if _rows[i].has(focused):
			return i
	return -1


func _on_submit() -> void:
	if is_complete():
		submitted.emit(_values.duplicate(), _comment.text)
