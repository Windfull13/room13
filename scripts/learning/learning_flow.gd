class_name LearningFlow
extends Control

## Conduce las pantallas de antes y después de la partida (una escena por etapa):
##
##   PRE : propósito y consentimiento → trivia inicial → cómo jugar → historia → partida
##   POST: epílogo → trivia final → resultados → encuesta → ayuda → menú
##
## Esc abre la pausa sin perder el punto en el que se estaba. La lógica de
## puntuación y de guardado vive en TriviaScorer, ResultsStore y Session.

enum Stage { PRE, POST }

signal leaving(scene_path: String)
## Pantalla de agradecimiento sin actividad durante FAIR_IDLE_RETURN_SECONDS (modo feria).
signal idle_expired

const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const GAME_SCENE := "res://scenes/partida.tscn"
const MENU_SCENE := "res://scenes/main_menu.tscn"
const MENU_MUSIC := "music_menu"
const BACKDROP_COLOR := Color(0.025, 0.022, 0.03)
const LEAVE_FADE_TIME := 0.5
const CONTINUE_LABEL := "CONTINUAR"
const CONSENT_FIRST := 0

@export var stage: Stage = Stage.PRE
## Las pruebas lo desactivan para observar la salida sin cambiar de escena.
@export var navigates: bool = true
## Multiplicador del tiempo de inactividad: las pruebas lo bajan para no esperar 30 s.
@export var idle_scale: float = 1.0

var content: LearningContent
var questions: Array[TriviaQuestion] = []

var _views: Control
var _pause: LearningPause
var _current: Control = null
var _paused: bool = false
var _focus_before_pause: Control = null
var _leaving: bool = false
var _rng := RandomNumberGenerator.new()
var _idle_elapsed: float = 0.0
var _watching_idle: bool = false


## Une «el participante pulsó el botón» y «pasó el tiempo» en una sola espera.
class _HelpDone:
	extends RefCounted
	signal done

	func finish() -> void:
		done.emit()


func _ready() -> void:
	theme = UiTheme.build()
	content = LearningContent.default()
	questions = LearningContent.questions()
	_rng.randomize()
	_build_layers()
	AudioManager.play_music(MENU_MUSIC)
	Session.set_playing(false)
	if stage == Stage.PRE:
		_run_pre()
	else:
		_run_post()


func current_view() -> Control:
	return _current


func is_paused() -> bool:
	return _paused


func pause_overlay() -> LearningPause:
	return _pause


func _process(delta: float) -> void:
	if not _watching_idle or _leaving:
		return
	_idle_elapsed += delta
	if _idle_elapsed >= FairMode.FAIR_IDLE_RETURN_SECONDS * idle_scale:
		_watching_idle = false
		idle_expired.emit()


## Cualquier tecla, clic o movimiento del ratón cuenta como actividad.
func _input(_event: InputEvent) -> void:
	_idle_elapsed = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not _leaving:
		_toggle_pause()
		get_viewport().set_input_as_handled()


func _build_layers() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = BACKDROP_COLOR
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	_views = Control.new()
	_views.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_views)
	_pause = LearningPause.new()
	_pause.name = "Pause"
	add_child(_pause)
	_pause.setup(content)
	_pause.resume_requested.connect(_toggle_pause)
	_pause.menu_requested.connect(return_to_menu)

# ---------------------------------------------------------------------------
# Etapas
# ---------------------------------------------------------------------------

func _run_pre() -> void:
	var consent_view := InfoView.new()
	var paragraphs: Array[String] = []
	paragraphs.assign(content.purpose_pages)
	paragraphs.append(content.consent_text)
	_present(consent_view)
	consent_view.setup(content.purpose_title, paragraphs, [content.consent_save_button, content.consent_skip_button])
	var choice: int = await consent_view.chosen
	Session.record_consent(choice == CONSENT_FIRST)
	Session.record_pre(await _ask_trivia(content.trivia_title_initial, content.trivia_intro_initial))
	Session.save()
	await _show_howto()
	await _show_pages(content.intro_pages)
	_leave_to(GAME_SCENE)


func _run_post() -> void:
	await _show_pages(PackedStringArray([content.early_finish_page]) if Session.ended_early else content.epilogue_pages)
	Session.record_post(await _ask_trivia(content.trivia_title_final, content.trivia_intro_final))
	Session.save()
	await _show_results()
	await _show_survey()
	await _show_help()
	return_to_menu()


func _show_pages(pages: PackedStringArray) -> void:
	var view := PageView.new()
	_present(view)
	view.show_pages(pages, content.page_hint)
	await view.finished


func _ask_trivia(intro_title: String, intro_text: String) -> Dictionary:
	var view := TriviaView.new()
	_present(view)
	view.start(questions, content, intro_title, intro_text, _rng)
	return await view.finished


func _show_howto() -> void:
	var view := HowToView.new()
	view.closes_on_pause = false
	_present(view)
	view.setup(content, CONTINUE_LABEL)
	await view.closed


func _show_results() -> void:
	var view := ResultsView.new()
	_present(view)
	var memories := content.results_memories_line % [Session.memories_found.size(), ObjectMemoryCatalog.default().count()]
	view.setup(questions, Session.pre_answers, Session.post_answers, memories)
	await view.continued


func _show_survey() -> void:
	var view := SurveyView.new()
	_present(view)
	view.setup(content)
	var result: Array = await view.submitted
	Session.record_survey(result[0], result[1])
	Session.save()


func _show_help() -> void:
	var view := InfoView.new()
	_present(view)
	view.setup(content.help_title, _help_paragraphs(), [content.help_button])
	_idle_elapsed = 0.0
	_watching_idle = FairMode.enabled
	var done := _HelpDone.new()
	view.chosen.connect(done.finish.unbind(1))
	idle_expired.connect(done.finish, CONNECT_ONE_SHOT)
	await done.done
	_watching_idle = false
	if idle_expired.is_connected(done.finish):
		idle_expired.disconnect(done.finish)


## Texto de ayuda, las líneas locales (solo si hay) y el agradecimiento.
func _help_paragraphs() -> Array[String]:
	var paragraphs: Array[String] = [content.help_text]
	var lines: Array[String] = []
	for line in content.help_lines:
		if not line.strip_edges().is_empty():
			lines.append(line)
	if not lines.is_empty():
		paragraphs.append("\n".join(lines))
	paragraphs.append(content.thanks_text)
	return paragraphs

# ---------------------------------------------------------------------------
# Presentación, pausa y salida
# ---------------------------------------------------------------------------

func _present(view: Control) -> void:
	if _current != null and is_instance_valid(_current):
		_current.queue_free()
	_current = view
	_views.add_child(view)


func _toggle_pause() -> void:
	_paused = not _paused
	_views.process_mode = Node.PROCESS_MODE_DISABLED if _paused else Node.PROCESS_MODE_INHERIT
	if _paused:
		_focus_before_pause = get_viewport().gui_get_focus_owner()
		_pause.open()
	else:
		_pause.close()
		_restore_focus()


func _restore_focus() -> void:
	if _focus_before_pause != null and is_instance_valid(_focus_before_pause):
		_focus_before_pause.grab_focus()
	_focus_before_pause = null


## Cierra la sesión (el siguiente participante tendrá otro identificador).
func return_to_menu() -> void:
	Session.begin_new()
	_leave_to(MENU_SCENE)


func _leave_to(scene_path: String) -> void:
	if _leaving:
		return
	_leaving = true
	leaving.emit(scene_path)
	if not navigates:
		return
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, LEAVE_FADE_TIME)
	await fade.finished
	get_tree().change_scene_to_file(scene_path)
