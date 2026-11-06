class_name LearningContent
extends Resource

## Todo el texto de aprendizaje del juego: propósito, consentimiento, historia de
## entrada, epílogo, tarjetas del pasillo, encuesta y ayuda. Vive en
## resources/learning/learning_content.tres para poder editarlo sin tocar código.

const CONTENT_PATH := "res://resources/learning/learning_content.tres"
const QUESTIONS_DIR := "res://resources/learning/questions/"
const CORRIDOR_ROUNDS := 10

@export_group("Propósito y consentimiento")
@export var purpose_title: String = ""
@export var purpose_pages: PackedStringArray = []
@export_multiline var consent_text: String = ""
@export var consent_save_button: String = ""
@export var consent_skip_button: String = ""

@export_group("Trivia")
@export var trivia_title_initial: String = ""
@export var trivia_title_final: String = ""
@export_multiline var trivia_intro_initial: String = ""
@export_multiline var trivia_intro_final: String = ""
@export var trivia_dont_know: String = ""

@export_group("Narrativa")
@export var page_hint: String = ""
@export var intro_pages: PackedStringArray = []
@export var epilogue_pages: PackedStringArray = []

@export_group("Tarjetas del pasillo")
## Una por cada ronda de decisión (la k-ésima se ve en el pasillo que lleva a ella).
@export var corridor_cards: PackedStringArray = []
@export var closing_card: String = ""

## «%d de %d»: recuerdos de objeto encontrados y total.
@export var results_memories_line: String = ""

@export_group("Modo feria")
@export var fair_pause_hint: String = ""
@export var fair_finish_button: String = ""
@export var fair_finish_confirm: String = ""
@export var fair_menu_confirm: String = ""
@export var fair_menu_accept: String = ""
@export var fair_keep_playing: String = ""
## Primera página del post-juego cuando se termina antes de tiempo.
@export var early_finish_page: String = ""

@export_group("Encuesta")
@export var survey_title: String = ""
@export var survey_ids: PackedStringArray = []
@export var survey_texts: PackedStringArray = []
@export var survey_scale_hint: String = ""
@export var survey_comment_prompt: String = ""

@export_group("Ayuda")
@export var help_title: String = ""
@export var help_button: String = ""
@export_multiline var help_text: String = ""
## Líneas de ayuda locales (teléfonos, webs). Vacía por defecto: se rellena a mano.
@export var help_lines: PackedStringArray = []
@export var thanks_text: String = ""

@export_group("Cómo jugar")
@export var howto_title: String = ""
@export_multiline var howto_goal: String = ""
## Una línea por control. Los marcadores {accion} se sustituyen por las teclas reales del InputMap.
@export var howto_controls: PackedStringArray = []
@export_multiline var howto_rule: String = ""


## El contenido por defecto (ResourceLoader ya lo cachea mientras alguien lo use).
static func default() -> LearningContent:
	return load(CONTENT_PATH) as LearningContent


## Las preguntas de la trivia, en orden de id.
static func questions() -> Array[TriviaQuestion]:
	var result: Array[TriviaQuestion] = []
	result.assign(CatalogLoader.load_all(QUESTIONS_DIR, TriviaQuestion))
	return result


## Tarjeta del pasillo que lleva a la ronda `next_index` (1-10); la de cierre si no hay más rondas.
func card_for_round(next_index: int, total_rounds: int) -> String:
	if next_index >= total_rounds:
		return closing_card
	var position := next_index - 1
	return corridor_cards[position] if position >= 0 and position < corridor_cards.size() else ""
