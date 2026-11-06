class_name TriviaView
extends Control

## Una pregunta por pantalla, sin ninguna pista de acierto. Se contesta con las
## flechas y Enter, con las teclas 1-5 o con el ratón. La última opción es
## siempre «No lo sé». Emite las respuestas por el índice ORIGINAL de la opción.

signal finished(answers: Dictionary)

const KEY_FIRST_OPTION := KEY_1
const OPTION_WIDTH := 880.0
const TOPIC_COLOR := Color(0.86, 0.66, 0.38)

var _questions: Array[TriviaQuestion] = []
var _content: LearningContent
var _rng: RandomNumberGenerator
var _answers: Dictionary = {}
var _position: int = -1
var _order: Array[int] = []
var _column: VBoxContainer
var _option_buttons: Array[Button] = []
var _locked: bool = false


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)


func start(questions: Array[TriviaQuestion], content: LearningContent, intro_title: String, intro_text: String, rng: RandomNumberGenerator) -> void:
	_questions = questions
	_content = content
	_rng = rng
	_show_intro(intro_title, intro_text)


func question_index() -> int:
	return _position


func options_on_screen() -> Array[Button]:
	return _option_buttons


## Contesta con la posición mostrada (0-3 opciones, 4 = «No lo sé»).
func choose(shown_position: int) -> void:
	if _locked or _position < 0 or shown_position < 0 or shown_position > _order.size():
		return
	_locked = true
	AudioManager.play(LearningUi.CLICK_SOUND)
	_answers[_questions[_position].id] = TriviaScorer.answer_for_position(_order, shown_position)
	_next_question()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or _option_buttons.is_empty():
		return
	var shown := key.keycode - KEY_FIRST_OPTION
	if shown >= 0 and shown <= _order.size():
		choose(shown)
		get_viewport().set_input_as_handled()


func _reset_column() -> void:
	if _column != null:
		_column.get_parent().get_parent().queue_free()
	_column = LearningUi.centered_column(self, 18)
	_option_buttons.clear()


func _show_intro(intro_title: String, intro_text: String) -> void:
	_reset_column()
	_column.add_child(LearningUi.title(intro_title))
	_column.add_child(LearningUi.body(intro_text))
	var start_button := LearningUi.button("EMPEZAR", 340.0)
	start_button.pressed.connect(_next_question)
	_column.add_child(LearningUi.button_row([start_button]))
	LearningUi.fade_in(self)
	start_button.grab_focus.call_deferred()


func _next_question() -> void:
	_position += 1
	if _position >= _questions.size():
		finished.emit(_answers)
		return
	_show_question(_questions[_position])


func _show_question(question: TriviaQuestion) -> void:
	_reset_column()
	_order = TriviaScorer.shuffled_order(question.options.size(), _rng)
	var header := LearningUi.body("PREGUNTA %d/%d · %s" % [_position + 1, _questions.size(), question.topic.to_upper()], OPTION_WIDTH, LearningUi.SMALL_TEXT_SIZE)
	header.add_theme_color_override("font_color", TOPIC_COLOR)
	_column.add_child(header)
	_column.add_child(LearningUi.body(question.text, OPTION_WIDTH))
	for shown in range(_order.size()):
		_add_option("%d. %s" % [shown + 1, question.options[_order[shown]]], shown)
	_add_option("%d. %s" % [_order.size() + 1, _content.trivia_dont_know], _order.size())
	_wire_focus()
	LearningUi.fade_in(self, 0.25)
	_locked = false
	_option_buttons[0].grab_focus.call_deferred()


func _add_option(text: String, shown_position: int) -> void:
	var button := LearningUi.button(text, OPTION_WIDTH)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", LearningUi.TEXT_SIZE)
	button.pressed.connect(choose.bind(shown_position))
	_column.add_child(button)
	_option_buttons.append(button)


## Las flechas recorren las opciones sin salirse de la lista.
func _wire_focus() -> void:
	var first := _option_buttons[0]
	var last := _option_buttons[_option_buttons.size() - 1]
	first.focus_neighbor_top = first.get_path_to(last)
	last.focus_neighbor_bottom = last.get_path_to(first)
