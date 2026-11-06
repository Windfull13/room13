class_name LastDoorCinematic
extends Control

## Cinemática «La última puerta» (~48 s), entre el pasillo de cierre y el
## epílogo. Aviso inicial → la puerta se abre → cuatro fragmentos de recuerdo →
## la luz y las dos siluetas → dos líneas finales sobre negro. Mantener E un
## segundo la salta y lleva directamente a las líneas finales.

signal finished

enum Phase { WARNING, DOOR, FRAGMENTS, LIGHT, FINAL, DONE }

const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const POST_GAME_SCENE := "res://scenes/learning/post_game.tscn"
## Duración de cada fase en segundos (a pacing 1).
const DURATIONS: Array[float] = [3.0, 6.0, 17.0, 14.0, 8.0]
const SKIP_ACTION := &"interact"
const SKIP_HOLD_SECONDS := 1.0
const STAGE_SIZE := Vector2(960, 540)
const FRAGMENT_SIZE := Vector2(576, 324)
const FRAGMENT_SCENES: Array[String] = [
	"res://scenes/memories/vignette_childhood.tscn",
	"res://scenes/memories/vignette_family.tscn",
	"res://scenes/memories/vignette_night.tscn",
	"res://scenes/memories/vignette_after.tscn",
]
const TEXT_SIZE := 34
const HINT_SIZE := 22
const TEXT_COLOR := Color(0.94, 0.9, 0.82)
const RING_RADIUS := 16.0
## El aviso para saltar y su anillo, arriba a la derecha (lejos de los subtítulos).
const HINT_RECT := Rect2(900, 16, 300, 34)
const RING_CENTER := Vector2(1236, 33)
const RING_COLOR := Color(0.94, 0.9, 0.82)
const LEAVE_FADE_TIME := 0.8
const RAIN_SOUND := "memory_rain"
const MUSIC := "music_end"
## Momentos (0-1 dentro de la fase de luz) de cada voz y su subtítulo.
const WIFE_AT := Vector2(0.32, 0.56)
const GIRL_AT := Vector2(0.58, 0.8)

## Multiplicador de los tiempos: las pruebas lo bajan para terminar enseguida.
@export var pacing: float = 1.0
@export var next_scene: String = POST_GAME_SCENE
## Las pruebas lo desactivan para observar el final sin cambiar de escena.
@export var navigates: bool = true

var phase: Phase = Phase.WARNING
var warning_shown: bool = false
var skipped: bool = false

var _texts: MemoryTexts
var _elapsed: float = 0.0
var _hold: float = 0.0
var _stage: LastDoorStage
var _fragments: Array[MemoryVignette] = []
var _warning: Label
var _line: Label
var _subtitle: Label
var _final: Label
var _hint: Label
var _ring: Control
var _voices_started: Dictionary = {}
var _leaving: bool = false


func _ready() -> void:
	theme = UiTheme.build()
	_texts = MemoryTexts.default()
	Session.set_playing(false)
	_build()
	AudioManager.stop_all()
	AudioManager.stop_music(0.5)
	AudioManager.play(RAIN_SOUND)
	_enter(Phase.WARNING)


func _process(delta: float) -> void:
	if phase == Phase.DONE:
		return
	_track_skip(delta)
	_elapsed += delta
	while phase != Phase.DONE and _elapsed >= _duration(phase):
		_elapsed -= _duration(phase)
		_enter((phase + 1) as Phase)
	if phase != Phase.DONE:
		_update(phase, _elapsed / _duration(phase) if _duration(phase) > 0.0 else 1.0)


func hold_progress() -> float:
	return clampf(_hold / SKIP_HOLD_SECONDS, 0.0, 1.0)


func _duration(which: Phase) -> float:
	return DURATIONS[which] * pacing if which < DURATIONS.size() else 0.0

# ---------------------------------------------------------------------------
# Saltar
# ---------------------------------------------------------------------------

func _track_skip(delta: float) -> void:
	if phase >= Phase.FINAL:
		_hold = 0.0
	elif Input.is_action_pressed(SKIP_ACTION):
		_hold += delta
		if _hold >= SKIP_HOLD_SECONDS:
			skip()
	else:
		_hold = 0.0
	_ring.queue_redraw()


## Salta directamente a las dos líneas finales.
func skip() -> void:
	if phase >= Phase.FINAL:
		return
	skipped = true
	_hold = 0.0
	AudioManager.stop_voice()
	_elapsed = 0.0
	_enter(Phase.FINAL)

# ---------------------------------------------------------------------------
# Fases
# ---------------------------------------------------------------------------

func _enter(next: Phase) -> void:
	phase = next
	match next:
		Phase.WARNING:
			warning_shown = true
			_warning.visible = true
		Phase.DOOR:
			_warning.visible = false
			AudioManager.stop(RAIN_SOUND)
			AudioManager.play_music(MUSIC)
		Phase.FRAGMENTS:
			_stage.visible = false
		Phase.LIGHT:
			_hide_fragments()
			_stage.visible = true
		Phase.FINAL:
			_show_final()
		Phase.DONE:
			_leave()


func _update(current: Phase, t: float) -> void:
	_stage.time += get_process_delta_time()
	match current:
		Phase.WARNING:
			_warning.modulate.a = MemoryVignette.span(t, 0.0, 0.2) * (1.0 - MemoryVignette.span(t, 0.85, 1.0))
		Phase.DOOR:
			_stage.door_open = MemoryVignette.ease_in_out(t)
			_stage.rain = 1.0 - t
			_stage.set_progress(t)
		Phase.FRAGMENTS:
			_update_fragments(t)
		Phase.LIGHT:
			_update_light(t)
		Phase.FINAL:
			_final.modulate.a = MemoryVignette.span(t, 0.0, 0.25)


## Cuatro recuerdos que se funden uno tras otro, cada uno con su línea.
func _update_fragments(t: float) -> void:
	var count := _fragments.size()
	var index := mini(int(t * count), count - 1)
	var local := t * count - index
	var alpha := MemoryVignette.span(local, 0.0, 0.2) * (1.0 - MemoryVignette.span(local, 0.8, 1.0))
	for i in range(count):
		_fragments[i].visible = i == index
	_fragments[index].modulate.a = alpha
	_fragments[index].set_progress(local)
	_line.text = _texts.cinematic_fragment_lines[index]
	_line.modulate.a = alpha


func _update_light(t: float) -> void:
	_stage.rain = 0.0
	_stage.door_open = 1.0
	_stage.light = MemoryVignette.ease_in_out(t)
	_stage.stand = MemoryVignette.span(t, 0.08, 0.3)
	_stage.family = MemoryVignette.span(t, 0.25, 0.42) * (1.0 - MemoryVignette.span(t, 0.82, 1.0))
	_stage.set_progress(t)
	_line.modulate.a = 0.0
	_subtitle.text = ""
	_say(t, WIFE_AT, _texts.cinematic_wife_voice, _texts.cinematic_wife_line)
	_say(t, GIRL_AT, _texts.cinematic_girl_voice, _texts.cinematic_girl_line)


## Voz opcional y su subtítulo (que se muestra siempre, haya archivo o no).
func _say(t: float, window: Vector2, voice_id: String, line: String) -> void:
	if t < window.x or t > window.y:
		return
	_subtitle.text = line
	if not _voices_started.has(voice_id):
		_voices_started[voice_id] = true
		AudioManager.play_voice(voice_id)


func _hide_fragments() -> void:
	for fragment in _fragments:
		fragment.visible = false
	_line.modulate.a = 0.0


func _show_final() -> void:
	Session.record_cinematic(skipped)
	_warning.visible = false
	_stage.visible = false
	_hide_fragments()
	_subtitle.text = ""
	_hint.visible = false
	_final.visible = true
	_final.modulate.a = 0.0


func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	AudioManager.stop_voice()
	finished.emit()
	if not navigates:
		return
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, LEAVE_FADE_TIME * pacing)
	await fade.finished
	get_tree().change_scene_to_file(next_scene)

# ---------------------------------------------------------------------------
# Construcción
# ---------------------------------------------------------------------------

func _build() -> void:
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(black)
	_stage = LastDoorStage.new()
	_stage.display_size = STAGE_SIZE
	_center(_stage, STAGE_SIZE)
	add_child(_stage)
	for path in FRAGMENT_SCENES:
		var fragment := (load(path) as PackedScene).instantiate() as MemoryVignette
		fragment.display_size = FRAGMENT_SIZE
		fragment.sound_name = ""
		_center(fragment, FRAGMENT_SIZE)
		fragment.visible = false
		add_child(fragment)
		_fragments.append(fragment)
	_warning = _label(_texts.cinematic_warning, TEXT_SIZE, Rect2(140, 300, 1000, 120))
	_line = _label("", TEXT_SIZE, Rect2(140, 560, 1000, 60))
	_subtitle = _label("", TEXT_SIZE, Rect2(140, 620, 1000, 60))
	_final = _label("\n".join(_texts.cinematic_final_lines), TEXT_SIZE, Rect2(140, 280, 1000, 160))
	_final.visible = false
	_hint = _label(_texts.cinematic_skip_hint, HINT_SIZE, HINT_RECT)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ring = Control.new()
	_ring.position = RING_CENTER
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.draw.connect(_draw_ring)
	add_child(_ring)


func _center(control: Control, control_size: Vector2) -> void:
	control.position = (Vector2(1280, 720) - control_size) / 2.0


func _label(text: String, font_size: int, rect: Rect2) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", TEXT_COLOR)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	add_child(label)
	return label


## Anillo que se completa mientras se mantiene E.
func _draw_ring() -> void:
	if _hint == null or not _hint.visible:
		return
	_ring.draw_arc(Vector2.ZERO, RING_RADIUS, 0.0, TAU, 32, Color(RING_COLOR, 0.25), 2.0)
	if hold_progress() > 0.0:
		_ring.draw_arc(Vector2.ZERO, RING_RADIUS, -PI / 2.0, -PI / 2.0 + TAU * hold_progress(), 32, RING_COLOR, 3.0)
