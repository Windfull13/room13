class_name ResultsView
extends Control

## Resultados tras la trivia final: puntuaciones, mejora, una fila por pregunta
## (con la respuesta correcta y su explicación cuando no se acertó al final) y
## una línea de análisis. Solo muestra: los números los calcula TriviaScorer.

signal continued

const LIST_WIDTH := 900.0
const LIST_HEIGHT := 330.0
const SCROLL_STEP := 70
const COLOR_RIGHT := Color(0.55, 0.85, 0.55)
const COLOR_WRONG := Color(0.9, 0.5, 0.45)
const COLOR_UNKNOWN := Color(0.8, 0.75, 0.5)

var _scroll: ScrollContainer
var _continue_button: Button
var _summary: Label
var _memories: Label = null


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)


## `memories_line` es la línea de recuerdos ya redactada (vacía: no se muestra).
func setup(questions: Array[TriviaQuestion], pre: Dictionary, post: Dictionary, memories_line: String = "") -> void:
	var initial := TriviaScorer.score(questions, pre)
	var final := TriviaScorer.score(questions, post)
	var column := LearningUi.centered_column(self, 14)
	column.add_child(LearningUi.title("Tus resultados", 46))
	column.add_child(_summary_label(initial, final, questions.size()))
	column.add_child(_build_list(questions, pre, post))
	column.add_child(LearningUi.body(TriviaScorer.analysis_line(questions, pre, post), LIST_WIDTH, LearningUi.SMALL_TEXT_SIZE))
	if not memories_line.is_empty():
		_memories = LearningUi.body(memories_line, LIST_WIDTH, LearningUi.SMALL_TEXT_SIZE)
		column.add_child(_memories)
	_continue_button = LearningUi.button("CONTINUAR", 340.0)
	_continue_button.pressed.connect(continued.emit)
	column.add_child(LearningUi.button_row([_continue_button]))
	LearningUi.fade_in(self)
	_continue_button.grab_focus.call_deferred()


func summary_text() -> String:
	return _summary.text


func memories_text() -> String:
	return _memories.text if _memories != null else ""


func scroll_container() -> ScrollContainer:
	return _scroll


func _summary_label(initial: int, final: int, total: int) -> Label:
	var gain := TriviaScorer.gain(initial, final)
	_summary = LearningUi.body("Trivia inicial %d/%d · Trivia final %d/%d · Mejora %s%d" % [initial, total, final, total, "+" if gain >= 0 else "", gain], LIST_WIDTH)
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return _summary


func _build_list(questions: Array[TriviaQuestion], pre: Dictionary, post: Dictionary) -> ScrollContainer:
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(LIST_WIDTH + 20.0, LIST_HEIGHT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	_scroll.add_child(list)
	for i in range(questions.size()):
		_add_question_rows(list, i, questions[i], pre, post)
	return _scroll


func _add_question_rows(list: VBoxContainer, number: int, question: TriviaQuestion, pre: Dictionary, post: Dictionary) -> void:
	var pre_mark := TriviaScorer.mark_for(question, TriviaScorer.answer_of(pre, question))
	var post_mark := TriviaScorer.mark_for(question, TriviaScorer.answer_of(post, question))
	var row := LearningUi.body("%d. %s — Inicial %s · Final %s" % [number + 1, question.topic.capitalize(), pre_mark, post_mark], LIST_WIDTH, LearningUi.SMALL_TEXT_SIZE)
	row.add_theme_color_override("font_color", _color_for(post_mark))
	list.add_child(row)
	if post_mark != TriviaScorer.MARK_RIGHT:
		list.add_child(LearningUi.body("Correcta: %s\n%s" % [question.correct_option(), question.explanation], LIST_WIDTH - 30.0, LearningUi.SMALL_TEXT_SIZE))


func _color_for(mark: String) -> Color:
	match mark:
		TriviaScorer.MARK_RIGHT:
			return COLOR_RIGHT
		TriviaScorer.MARK_WRONG:
			return COLOR_WRONG
	return COLOR_UNKNOWN


## Flechas arriba y abajo desplazan la lista aunque el foco esté en CONTINUAR.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_down") and _scroll != null:
		_scroll.scroll_vertical += SCROLL_STEP
	elif event.is_action_pressed("ui_up") and _scroll != null:
		_scroll.scroll_vertical -= SCROLL_STEP
