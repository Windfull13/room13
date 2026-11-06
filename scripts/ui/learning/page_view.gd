class_name PageView
extends Control

## Páginas de texto con fundido, una detrás de otra. Avanza con E, Enter (o
## Espacio) o clic. Al terminar la última emite `finished`.

signal finished

const TEXT_WIDTH := 880.0
const PAGE_TEXT_SIZE := 32
const FADE_OUT_TIME := 0.3
const FADE_IN_TIME := 0.6
const ADVANCE_ACTIONS: Array[StringName] = [&"interact", &"ui_accept"]

var _pages: PackedStringArray = []
var _index: int = -1
var _label: Label
var _hint: Label
var _changing: bool = false
var _done: bool = false


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)


func show_pages(pages: PackedStringArray, hint_text: String) -> void:
	_pages = pages
	var column := LearningUi.centered_column(self, 36)
	_label = LearningUi.body("", TEXT_WIDTH, PAGE_TEXT_SIZE)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.custom_minimum_size.y = 190.0
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.modulate.a = 0.0
	column.add_child(_label)
	_hint = LearningUi.hint(hint_text)
	column.add_child(_hint)
	if _pages.is_empty():
		push_warning("PageView: no hay páginas que mostrar; se continúa sin ellas.")
		_finish_without_pages.call_deferred()
		return
	_show_page(0)


func page_index() -> int:
	return _index


func is_done() -> bool:
	return _done


func advance() -> void:
	if _changing or _done:
		return
	if _index + 1 >= _pages.size():
		_finish()
	else:
		_show_page(_index + 1)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or not event.is_pressed():
		return
	if _is_click(event) or _is_advance_action(event):
		advance()
		get_viewport().set_input_as_handled()


func _is_click(event: InputEvent) -> bool:
	return event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT


func _is_advance_action(event: InputEvent) -> bool:
	for action in ADVANCE_ACTIONS:
		if event.is_action_pressed(action):
			return true
	return false


func _show_page(index: int) -> void:
	_changing = true
	if _index >= 0:
		var out := create_tween()
		out.tween_property(_label, "modulate:a", 0.0, FADE_OUT_TIME)
		await out.finished
	_index = index
	_label.text = _pages[index]
	var into := create_tween()
	into.tween_property(_label, "modulate:a", 1.0, FADE_IN_TIME)
	await into.finished
	_changing = false


func _finish_without_pages() -> void:
	_done = true
	finished.emit()


func _finish() -> void:
	_changing = true
	var out := create_tween()
	out.tween_property(_label, "modulate:a", 0.0, FADE_OUT_TIME)
	await out.finished
	_done = true
	finished.emit()
