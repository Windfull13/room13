class_name TriviaScorer
extends RefCounted

## Puntuación de la trivia, sin nodos ni interfaz. Una respuesta es el índice
## ORIGINAL de la opción elegida; «No lo sé» se guarda como -1 y vale 0.

const DONT_KNOW := -1
const MARK_RIGHT := "✓"
const MARK_WRONG := "✗"
const MARK_UNKNOWN := "?"
const IMPROVED_LINE := "Aprendiste más sobre: %s."
const REVIEW_LINE := "Para repasar: %s."
const NO_IMPROVEMENT_LINE := "Aún no se nota mejora en ningún tema."
const NOTHING_TO_REVIEW_LINE := "No te queda ningún tema por repasar."


static func answer_of(answers: Dictionary, question: TriviaQuestion) -> int:
	return int(answers.get(question.id, DONT_KNOW))


static func is_correct(question: TriviaQuestion, answer: int) -> bool:
	return answer != DONT_KNOW and answer == question.correct_index


static func score(questions: Array[TriviaQuestion], answers: Dictionary) -> int:
	var total := 0
	for question in questions:
		total += 1 if is_correct(question, answer_of(answers, question)) else 0
	return total


static func gain(initial: int, final: int) -> int:
	return final - initial


## (final − inicial) / (total − inicial); 0 si ya se acertó todo al principio.
static func normalized_gain(initial: int, final: int, total: int) -> float:
	if initial >= total:
		return 0.0
	return float(final - initial) / float(total - initial)


## ✓, ✗ o ? (no lo sé / sin respuesta) para una respuesta.
static func mark_for(question: TriviaQuestion, answer: int) -> String:
	if answer == DONT_KNOW:
		return MARK_UNKNOWN
	return MARK_RIGHT if is_correct(question, answer) else MARK_WRONG


## Orden en que se muestran las opciones: una permutación de sus índices originales.
static func shuffled_order(option_count: int, rng: RandomNumberGenerator) -> Array[int]:
	var order: Array[int] = []
	for i in range(option_count):
		order.append(i)
	for i in range(option_count - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := order[i]
		order[i] = order[j]
		order[j] = swap
	return order


## Respuesta guardada al pulsar la posición `position` de la lista mostrada.
## La última posición (después de las opciones) es «No lo sé».
static func answer_for_position(order: Array[int], position: int) -> int:
	return order[position] if position >= 0 and position < order.size() else DONT_KNOW


static func topics_in_order(questions: Array[TriviaQuestion]) -> Array[String]:
	var topics: Array[String] = []
	for question in questions:
		if not topics.has(question.topic):
			topics.append(question.topic)
	return topics


static func correct_in_topic(questions: Array[TriviaQuestion], answers: Dictionary, topic: String) -> int:
	var total := 0
	for question in questions:
		if question.topic == topic and is_correct(question, answer_of(answers, question)):
			total += 1
	return total


static func questions_in_topic(questions: Array[TriviaQuestion], topic: String) -> int:
	return questions.filter(func(question: TriviaQuestion) -> bool: return question.topic == topic).size()


## Temas en los que se acierta más al final que al principio.
static func topics_improved(questions: Array[TriviaQuestion], pre: Dictionary, post: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for topic in topics_in_order(questions):
		if correct_in_topic(questions, post, topic) > correct_in_topic(questions, pre, topic):
			result.append(topic)
	return result


## Temas en los que al final queda alguna pregunta sin acertar.
static func topics_to_review(questions: Array[TriviaQuestion], post: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for topic in topics_in_order(questions):
		if correct_in_topic(questions, post, topic) < questions_in_topic(questions, topic):
			result.append(topic)
	return result


## Una línea de análisis para la pantalla de resultados.
static func analysis_line(questions: Array[TriviaQuestion], pre: Dictionary, post: Dictionary) -> String:
	var improved := topics_improved(questions, pre, post)
	var review := topics_to_review(questions, post)
	var first := IMPROVED_LINE % ", ".join(improved) if not improved.is_empty() else NO_IMPROVEMENT_LINE
	var second := REVIEW_LINE % ", ".join(review) if not review.is_empty() else NOTHING_TO_REVIEW_LINE
	return "%s %s" % [first, second]
