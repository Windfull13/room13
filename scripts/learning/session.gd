extends Node

## Sesión de un participante (autoload «Session»). Sobrevive a los cambios de
## escena y guarda lo necesario para el JSON de resultados: identificador
## anónimo, consentimiento, trivia inicial y final, encuesta, intentos y tiempo
## de juego. Se reinicia al volver al menú.

const SURVEY_COMMENT_KEY := "comment"
const MAX_COMMENT_LENGTH := 200
const VERSION_SETTING := "application/config/version"
const UNKNOWN_VERSION := "0.0.0"
const FINISH_COMPLETE := "completo"
const FINISH_EARLY := "anticipado"

var participant_id: String = ""
var consent: bool = false
var pre_answers: Dictionary = {}
var post_answers: Dictionary = {}
var survey: Dictionary = {}
## Recuerdos de objeto leídos (ids de anomalía), sin repetir.
var memories_found: Array[String] = []
## null hasta ver la cinemática final; después, si se saltó.
var cinematic_skipped: Variant = null
## Ronda más lejana alcanzada en la sesión (0 = referencia, 1-10 = decisión).
var max_round_reached: int = 0
## Se terminó desde la pausa (modo feria) sin completar la historia.
var ended_early: bool = false
var attempts: int = 0
var play_seconds: float = 0.0
var started_at: String = ""
var finished_at: String = ""
var completed: bool = false
var game_version: String = UNKNOWN_VERSION
var store := ResultsStore.new()
## Si el último intento de guardar fue bien (true también cuando no hay nada que guardar).
var last_save_ok: bool = true

var _rng := RandomNumberGenerator.new()
var _playing: bool = false
var _has_pre: bool = false
var _has_post: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	begin_new()


func _process(delta: float) -> void:
	if _playing:
		play_seconds += delta


## Abre una sesión nueva: otro identificador y todo a cero.
func begin_new() -> void:
	participant_id = ResultsStore.new_id(_rng)
	game_version = String(ProjectSettings.get_setting(VERSION_SETTING, UNKNOWN_VERSION))
	consent = false
	pre_answers = {}
	post_answers = {}
	survey = {}
	memories_found = []
	cinematic_skipped = null
	max_round_reached = 0
	ended_early = false
	attempts = 0
	play_seconds = 0.0
	started_at = Time.get_datetime_string_from_system(true)
	finished_at = ""
	completed = false
	last_save_ok = true
	_playing = false
	_has_pre = false
	_has_post = false


func add_attempt() -> void:
	attempts += 1


## Mientras es true se cuentan los segundos de juego (no en la pausa ni en las pantallas de texto).
func set_playing(playing: bool) -> void:
	_playing = playing


func is_playing() -> bool:
	return _playing


func record_memory(anomaly_id: String) -> void:
	if not memories_found.has(anomaly_id):
		memories_found.append(anomaly_id)


func has_memory(anomaly_id: String) -> bool:
	return memories_found.has(anomaly_id)


func note_round(round_index: int) -> void:
	max_round_reached = maxi(max_round_reached, round_index)


## Marca la sesión como terminada antes de tiempo (finish_type «anticipado»).
func end_early() -> void:
	ended_early = true


func finish_type() -> String:
	return FINISH_EARLY if ended_early else FINISH_COMPLETE


func has_pre() -> bool:
	return _has_pre


func has_post() -> bool:
	return _has_post


func record_cinematic(skipped: bool) -> void:
	cinematic_skipped = skipped


func record_consent(accepted: bool) -> void:
	consent = accepted


func record_pre(answers: Dictionary) -> void:
	pre_answers = answers.duplicate()
	_has_pre = true


func record_post(answers: Dictionary) -> void:
	post_answers = answers.duplicate()
	_has_post = true


## `values` son los siete ítems (id → 1-5); el comentario se recorta a 200 caracteres.
func record_survey(values: Dictionary, comment: String) -> void:
	survey = values.duplicate()
	survey[SURVEY_COMMENT_KEY] = comment.substr(0, MAX_COMMENT_LENGTH)
	finished_at = Time.get_datetime_string_from_system(true)
	completed = true


func pre_score() -> int:
	return TriviaScorer.score(LearningContent.questions(), pre_answers)


func post_score() -> int:
	return TriviaScorer.score(LearningContent.questions(), post_answers)


## El registro completo tal como se guarda. Lo que aún no ha ocurrido va a null.
func build_record() -> Dictionary:
	var total := LearningContent.questions().size()
	var gain: Variant = null
	var normalized: Variant = null
	if _has_pre and _has_post:
		gain = TriviaScorer.gain(pre_score(), post_score())
		normalized = TriviaScorer.normalized_gain(pre_score(), post_score(), total)
	var pre_value: Variant = null
	var post_value: Variant = null
	if _has_pre:
		pre_value = pre_score()
	if _has_post:
		post_value = post_score()
	return {
		"participant_id": participant_id,
		"version": game_version,
		"consent": consent,
		"started_at": started_at,
		"finished_at": finished_at,
		"completed": completed,
		"attempts": attempts,
		"play_seconds": snappedf(play_seconds, 0.1),
		"pre": {"answers": pre_answers, "score": pre_value},
		"post": {"answers": post_answers, "score": post_value},
		"gain": gain,
		"normalized_gain": normalized,
		"survey": survey,
		"memories_found": memories_found.duplicate(),
		"cinematic_skipped": cinematic_skipped,
		"finish_type": finish_type(),
		"max_round_reached": max_round_reached,
		"ended_early": ended_early,
	}


## Escribe el JSON solo si el participante dio su consentimiento.
func save() -> bool:
	if not consent:
		return false
	last_save_ok = store.save(build_record())
	return last_save_ok
