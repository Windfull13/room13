class_name GameManager
extends Node2D

## Coordinador de la partida.
##
## Conecta las piezas ya resueltas: datos (RoomData/AnomalyData), mundo (Room),
## jugador (Player), interfaz (HUD), fundidos (SceneTransition) y sustos
## (JumpscarePlayer). No decide reglas: la selección de anomalías vive en
## AnomalySelector, el marcador en RunState y la evaluación en AnswerEvaluator.
##
## Clave del diseño: las anomalías NO crean habitaciones nuevas. Las once rondas
## reutilizan una habitación de una sola pantalla y el catálogo común se aplica
## sobre ella como una modificación del escenario existente.

enum State {
	TRANSICION,
	REFERENCIA,
	EXPLORACION,
	PUERTA_ABIERTA,
	MENSAJE,
	MUERTE,
	FINAL,
}

const ROOMS_DIR := "res://resources/rooms/"
const CATALOG_DIR := "res://resources/anomalies/"
const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
## Tras el pasillo de cierre: la cinemática final, que lleva al post-juego.
const ENDING_SCENE := "res://scenes/cinematic/last_door.tscn"
## Terminar antes de tiempo desde la pausa (modo feria): va directo al post-juego.
const EARLY_FINISH_SCENE := "res://scenes/learning/post_game.tscn"
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const CORRIDOR_SCENE := preload("res://scenes/corridor.tscn")
## Lo que dura el paseo por el pasillo entre dos habitaciones.
const CORRIDOR_TIME := 3.4
## Con tarjeta de aprendizaje el pasillo dura lo que pide leerla (con tope).
const CARD_BASE_TIME := 2.2
const CARD_TIME_PER_CHARACTER := 0.045
const CORRIDOR_MAX_TIME := 7.0
const CORRIDOR_MEMORY_MAX_TIME := 12.0
const END_CORRIDOR_TEXT := "Salida"
## Teclas de decisión (las mismas respuestas que los botones de la HUD).
const DECISION_ACTIONS := {"decide_anomaly": AnswerEvaluator.Answer.ANOMALY, "decide_no_anomaly": AnswerEvaluator.Answer.NO_ANOMALY}
const NO_DECISION_KEY := -1
## Estados en los que el jugador camina e interactúa.
const PLAYABLE_STATES: Array[State] = [State.REFERENCIA, State.EXPLORACION, State.PUERTA_ABIERTA]
const FEEDBACK_TIME := 1.8
const DOOR_NOTICE_TIME := 3.0
const DOOR_OPEN_NOTICE := "La puerta se ha abierto"
## Velocidad a la que se escribe el texto de un recuerdo.
const MEMORY_CHARS_PER_SECOND := 40.0
const THREAT_FADE_TIME := 0.6
const BARE_DEATH_PAUSE := 0.9
const MUSIC_REFERENCE := "music_calm"
const MUSIC_DECISION := "music_tense"
## La música se calla casi de golpe al morir: el susto suena solo.
const MUSIC_CUT_FADE := 0.15
const SOUND_AMBIENT := "ambient_room"
const SOUND_DANGER := "danger_heartbeat"
const SOUND_FOOTSTEP := "footstep"
const SOUND_MESSAGE_OPEN := "message_open"
const SOUND_MESSAGE_CLOSE := "message_close"
const SOUND_DOOR_LOCKED := "door_locked"
const SOUND_DOOR_UNLOCK := "door_unlock"
const SOUND_DOOR_CROSS := "door_cross"
const SOUND_SUCCESS := "success"
const SOUND_FAIL := "fail"
const SOUND_FADE := "fade"
## Lo que calla la pausa (la música sigue, más baja que el resto).
const PAUSABLE_SOUNDS: Array[String] = [SOUND_AMBIENT, SOUND_DANGER]

## Se emite al cruzar la última puerta, tras el pasillo de cierre.
signal finished
## Se terminó antes de tiempo desde la pausa y la sesión pasa al post-juego.
signal finished_early

## Qué está confirmando el jugador en el cuadro de la pausa.
enum Confirm { NONE, FINISH_EARLY, EXIT_TO_MENU }

## Multiplicador de todas las esperas. Las pruebas lo bajan a 0 para jugar
## partidas completas sin esperar fundidos ni avisos.
@export var pacing: float = 1.0
## Escena que se abre al terminar la partida. Vacía: la partida solo queda en FINAL.
@export var ending_scene: String = ENDING_SCENE
@export var early_finish_scene: String = EARLY_FINISH_SCENE

@onready var _hud: HUD = $HUD
@onready var _transition: SceneTransition = $Transition
@onready var _jumpscares: JumpscarePlayer = $Jumpscares

var state: State = State.TRANSICION

var _content: LearningContent = LearningContent.default()
var _memories: ObjectMemoryCatalog
var _memory_texts: MemoryTexts
## Recuerdo abierto en el panel ahora mismo (null si es un mensaje normal).
var _reading_memory: ObjectMemory = null
var _pending_confirm: Confirm = Confirm.NONE
var _rooms: Array[RoomData] = []
var _catalog: Array[AnomalyData] = []
var _run := RunState.new()
var _selector: AnomalySelector
var _room: Room = null
var _player: Player = null
## Anomalía realmente aplicada en la visita actual (null si la sala está normal).
var _current_anomaly: AnomalyData = null
## Estado al que se vuelve al cerrar un mensaje.
var _state_before_message: State = State.REFERENCIA
## Hay un fundido o una carga en curso: no se acepta entrada de juego.
var _busy: bool = false
## La pausa se superpone a cualquier estado jugable sin sustituirlo.
var _paused: bool = false


func _ready() -> void:
	_memories = ObjectMemoryCatalog.default()
	_memory_texts = MemoryTexts.default()
	_connect_hud()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_selector = AnomalySelector.new(rng)
	_rooms.assign(CatalogLoader.load_all(ROOMS_DIR, RoomData))
	_catalog.assign(CatalogLoader.load_all(CATALOG_DIR, AnomalyData))
	start_campaign()


## Al salir de la partida (menú, reinicio de escena, fin de una prueba) no
## queda ningún sonido suyo sonando. La música la decide la escena siguiente.
func _exit_tree() -> void:
	Session.set_playing(false)
	AudioManager.stop_all()


func _connect_hud() -> void:
	_hud.decision_made.connect(_on_decision_made)
	_hud.message_closed.connect(_return_from_message)
	_hud.message_action.connect(_on_message_action)
	_hud.menu_pressed.connect(_on_menu_requested)
	_hud.evaluate_pressed.connect(_on_evaluate_requested)
	_hud.confirm_answered.connect(_on_confirm_answered)
	_hud.resume_pressed.connect(_toggle_pause)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if _hud.is_confirm_visible():
			_hud.cancel_confirm()
			get_viewport().set_input_as_handled()
		elif _can_toggle_pause():
			_toggle_pause()
			get_viewport().set_input_as_handled()
	elif _decision_key(event) != NO_DECISION_KEY:
		if _can_decide():
			_hud.press_decision(_decision_key(event))
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		if state == State.MENSAJE:
			_advance_message()
			get_viewport().set_input_as_handled()
		elif _is_playable():
			_try_interact()
			get_viewport().set_input_as_handled()


## La respuesta asociada a una tecla de decisión, o NO_DECISION_KEY.
func _decision_key(event: InputEvent) -> int:
	if event.is_echo():
		return NO_DECISION_KEY
	for action: String in DECISION_ACTIONS:
		if event.is_action_pressed(action):
			return DECISION_ACTIONS[action]
	return NO_DECISION_KEY


## Solo se decide una vez, en una ronda de decisión, sin pausa ni fundidos.
func _can_decide() -> bool:
	return state == State.EXPLORACION and not _busy and not _paused


func _is_playable() -> bool:
	return state in PLAYABLE_STATES

# ---------------------------------------------------------------------------
# Flujo de partida
# ---------------------------------------------------------------------------

func start_campaign() -> void:
	Session.add_attempt()
	state = State.TRANSICION
	_run.restart()
	_busy = true
	_paused = false
	_current_anomaly = null
	_hud.clear()
	_jumpscares.clear()
	AudioManager.stop_all()
	AudioManager.play(SOUND_AMBIENT)
	if _rooms.is_empty():
		push_error("No hay rondas cargadas.")
		_hud.show_end("SIN CONTENIDO", "No se encontraron rondas para jugar.")
		await _transition.fade_in(_scaled(SceneTransition.FADE_TIME))
		return
	_load_room(0)
	await _transition.fade_in(_scaled(SceneTransition.FADE_TIME))
	_busy = false
	_refresh_control()


## Carga una ronda: instancia su habitación, coloca al jugador y decide el estado.
func _load_room(index: int) -> void:
	_run.index = index
	Session.note_round(index)
	var data: RoomData = _rooms[index]
	_teardown_round()
	_spawn_room(data)
	_spawn_player()
	_current_anomaly = null if data.is_reference else _pick_anomaly(_room)
	if _current_anomaly != null:
		_room.apply_anomaly(_current_anomaly)
	_hud.set_round_text(_round_text(index))
	_hud.hide_result()
	_hud.set_prompt("")
	_set_danger_warning(false)
	AudioManager.play_music(MUSIC_REFERENCE if data.is_reference else MUSIC_DECISION)
	_set_state(State.REFERENCIA if data.is_reference else State.EXPLORACION)


func _spawn_room(data: RoomData) -> void:
	_room = (load(data.scene_path) as PackedScene).instantiate() as Room
	_room.name = "Room"
	add_child(_room)
	_room.configure_door(data.is_reference)
	# Diferida: la muerte reinicia la partida, y eso no puede ocurrir mientras
	# la física está notificando la entrada en el área.
	_room.monster_entered_danger.connect(_die_by_presence, CONNECT_DEFERRED)
	_room.monster_entered_warning.connect(_set_danger_warning.bind(true))
	_room.monster_warning_cleared.connect(_set_danger_warning.bind(false))


func _spawn_player() -> void:
	_player = PLAYER_SCENE.instantiate() as Player
	_room.get_node("World").add_child(_player)
	_player.global_position = _room.get_player_spawn()
	_player.reset_state()
	_player.can_move = false
	_player.interactable_changed.connect(_on_interactable_changed)
	_player.footstep.connect(AudioManager.play.bind(SOUND_FOOTSTEP))


## Aviso de peligro del Testigo: el texto de la HUD y el latido van juntos.
func _set_danger_warning(active: bool) -> void:
	_hud.set_danger_warning(active)
	AudioManager.set_tension(active)
	if active:
		AudioManager.play(SOUND_DANGER)
	else:
		AudioManager.stop(SOUND_DANGER)


## Cambia de estado y ajusta lo que depende de él: barra de decisión y control.
func _set_state(new_state: State) -> void:
	state = new_state
	_sync_play_time()
	_hud.set_decision_bar_visible(state == State.EXPLORACION)
	_refresh_control()


## Libera la habitación de la ronda anterior (con su jugador).
func _teardown_round() -> void:
	_player = null
	_reading_memory = null
	AudioManager.stop_voice()
	if _room != null and is_instance_valid(_room):
		remove_child(_room)
		_room.free()
	_room = null


## Elige el estado de la habitación: normal o una anomalía compatible al azar.
func _pick_anomaly(room: Room) -> AnomalyData:
	var chosen := _selector.pick(_catalog, room.can_apply, _run.index, _run)
	_run.record(chosen)
	return chosen


## Texto del indicador ("Habitación de referencia" o "Habitación N / M").
## Los totales se cuentan desde los datos, sin números fijos en el código.
func _round_text(index: int) -> String:
	if _rooms[index].is_reference:
		return "Habitación de referencia"
	return "Habitación %d / %d" % [_decision_rooms_through(index), _decision_room_count()]


## Habitaciones de decisión desde la primera hasta `index`, incluida.
func _decision_rooms_through(index: int) -> int:
	var total := 0
	for i in range(index + 1):
		if not _rooms[i].is_reference:
			total += 1
	return total


func _decision_room_count() -> int:
	return _decision_rooms_through(_rooms.size() - 1)


## Los segundos de juego solo corren con la partida en marcha y sin pausa.
func _sync_play_time() -> void:
	Session.set_playing(state != State.FINAL and not _paused)


func _refresh_control() -> void:
	if _player != null and is_instance_valid(_player):
		_player.can_move = _is_playable() and not _busy and not _paused

# ---------------------------------------------------------------------------
# Interacción
# ---------------------------------------------------------------------------

func _on_interactable_changed(interactable: Interactable) -> void:
	if not _is_playable():
		return
	if interactable == null or _paused:
		_hud.set_prompt("")
	else:
		_hud.set_prompt("E — %s %s" % [interactable.prompt_verb, interactable.display_name])


func _try_interact() -> void:
	if _busy or _paused or _player == null:
		return
	var interactable := _player.get_interactable()
	if interactable == null:
		return
	_player.face_towards(interactable.global_position)
	var memory := _room.memory_for(interactable)
	if memory != null:
		_open_memory(memory, interactable)
		return
	AudioManager.play(SOUND_DOOR_LOCKED if _room.is_locked_door(interactable) else SOUND_MESSAGE_OPEN)
	_show_message(interactable.get_data())


func _show_message(data: Dictionary) -> void:
	_state_before_message = state
	_hud.set_prompt("")
	_hud.show_message(data)
	_set_state(State.MENSAJE)


## E en un mensaje: si un recuerdo aún se está escribiendo, lo completa; si no, cierra.
func _advance_message() -> void:
	if _hud.is_revealing():
		_hud.reveal_all()
	else:
		_hud.close_message()


func _return_from_message() -> void:
	_finish_memory()
	if state == State.MENSAJE:
		AudioManager.play(SOUND_MESSAGE_CLOSE)
		_set_state(_state_before_message)


func _on_message_action(action_id: String) -> void:
	_finish_memory()
	if action_id == Room.DOOR_ACTION and _door_is_open():
		_advance_to_next()
	else:
		_return_from_message()


## La puerta se cruza en la referencia y en una ronda ya acertada.
func _door_is_open() -> bool:
	var current := _state_before_message if state == State.MENSAJE else state
	return current == State.REFERENCIA or current == State.PUERTA_ABIERTA

# ---------------------------------------------------------------------------
# Decisión y consecuencias
# ---------------------------------------------------------------------------

## Solo se responde una vez por ronda: después la ronda pasa a PUERTA_ABIERTA
## o se reinicia, y en ninguno de los dos estados se aceptan respuestas.
func _on_decision_made(answer: int) -> void:
	if state != State.EXPLORACION or _busy or _paused:
		return
	if _evaluate(answer) == AnswerEvaluator.Verdict.CORRECT:
		_open_door()
	else:
		_fail()


func _evaluate(answer: int) -> AnswerEvaluator.Verdict:
	var has_anomaly := _current_anomaly != null
	var is_dangerous := has_anomaly and _current_anomaly.is_dangerous
	return AnswerEvaluator.evaluate(has_anomaly, is_dangerous, answer as AnswerEvaluator.Answer)


## Acierto: las amenazas se retiran y la puerta se abre. El jugador sigue
## caminando y avanza cuando cruza la puerta.
func _open_door() -> void:
	_run.correct += 1
	_set_state(State.PUERTA_ABIERTA)
	_room.retire_threats(_scaled(THREAT_FADE_TIME))
	_room.unlock_door()
	_set_danger_warning(false)
	AudioManager.play(SOUND_SUCCESS)
	AudioManager.play(SOUND_DOOR_UNLOCK)
	_hud.show_success(_success_detail(), _scaled(FEEDBACK_TIME), _success_meaning())
	_hud.show_notice(DOOR_OPEN_NOTICE, _scaled(DOOR_NOTICE_TIME))
	_offer_memory()
	_on_interactable_changed(_player.get_interactable())


## Tras acertar una anomalía no peligrosa, su objeto puede guardar un recuerdo
## (si aún no se leyó en esta sesión).
func _offer_memory() -> void:
	if _current_anomaly == null or _current_anomaly.is_dangerous:
		return
	var memory := _memories.for_anomaly(_current_anomaly.id)
	if memory == null or Session.has_memory(memory.anomaly_id):
		return
	_room.offer_memory(memory, _memories.prompt_verb)
	_announce_memory(_room)


## El aviso del recuerdo llega después del de la puerta abierta.
func _announce_memory(room: Room) -> void:
	await _wait(DOOR_NOTICE_TIME)
	if room == _room and is_instance_valid(room) and room.has_memory_offer():
		_hud.show_notice(_memories.notice_text, _scaled(DOOR_NOTICE_TIME))


func _open_memory(memory: ObjectMemory, interactable: Interactable) -> void:
	AudioManager.play(SOUND_MESSAGE_OPEN)
	var data := interactable.get_data()
	data["name"] = _memories.panel_title
	data["message"] = memory.text
	_reading_memory = memory
	_state_before_message = state
	_hud.set_prompt("")
	_hud.show_memory(data, _scaled(memory.text.length() / MEMORY_CHARS_PER_SECOND))
	if not memory.voice_id.is_empty():
		AudioManager.play_voice(memory.voice_id)
	_set_state(State.MENSAJE)


## Al cerrar el panel el recuerdo queda leído: se registra y el objeto vuelve a su mensaje.
func _finish_memory() -> void:
	if _reading_memory == null:
		return
	Session.record_memory(_reading_memory.anomaly_id)
	_reading_memory = null
	AudioManager.stop_voice()
	if _room != null:
		_room.take_memory()


## Segunda línea del acierto: el significado de la anomalía (vacío si no hubo).
func _success_meaning() -> String:
	return _current_anomaly.meaning if _current_anomaly != null else ""


## Texto breve del acierto.
func _success_detail() -> String:
	if _current_anomaly != null:
		return "Detectaste la anomalía: %s." % _current_anomaly.display_name
	return "La habitación estaba en su estado normal."


## Fallo (respuesta equivocada o presencia que alcanza al jugador): susto de la
## entidad si lo tiene, fundido a negro y partida reiniciada desde la referencia.
func _fail() -> void:
	if state == State.MUERTE:
		return
	_busy = true
	_set_state(State.MUERTE)
	_set_danger_warning(false)
	_hud.set_prompt("")
	_hud.hide_result()
	_silence_round()
	if _current_anomaly != null and _current_anomaly.jumpscare_scene != null:
		# El aviso se conecta antes de lanzar el susto: aunque termine al
		# instante, el reinicio no se pierde.
		_jumpscares.finished.connect(_on_jumpscare_finished, CONNECT_ONE_SHOT)
		_jumpscares.play(_current_anomaly.jumpscare_scene, pacing)
	else:
		AudioManager.play(SOUND_FAIL)
		_bare_failure()


## Antes del susto (o del fallo sobrio) se apaga todo lo de la ronda.
func _silence_round() -> void:
	_room.stop_ambience()
	AudioManager.stop_music(_scaled(MUSIC_CUT_FADE))
	AudioManager.stop(SOUND_AMBIENT)
	AudioManager.stop(SOUND_FOOTSTEP)


func _on_jumpscare_finished() -> void:
	_restart_after_failure()


## Muerte sin susto: una pausa sobria y a empezar de nuevo.
func _bare_failure() -> void:
	await _wait(BARE_DEATH_PAUSE)
	_restart_after_failure()


func _restart_after_failure() -> void:
	AudioManager.play(SOUND_FADE)
	await _transition.fade_out(_scaled(SceneTransition.FADE_TIME))
	start_campaign()


## Espera propia del coordinador, acortable en las pruebas.
func _wait(seconds: float) -> void:
	if _scaled(seconds) <= 0.0:
		await get_tree().process_frame
		return
	var wait := create_tween()
	wait.tween_interval(_scaled(seconds))
	await wait.finished


func _scaled(seconds: float) -> float:
	return seconds * pacing


## La presencia de la habitación ha alcanzado al jugador. Tras acertar ya no
## mata: la ronda está en PUERTA_ABIERTA y las amenazas se han retirado.
func _die_by_presence() -> void:
	if _paused:
		return
	if state == State.REFERENCIA or state == State.EXPLORACION:
		_fail()

# ---------------------------------------------------------------------------
# Transiciones
# ---------------------------------------------------------------------------

func _advance_to_next() -> void:
	if _busy:
		return
	_busy = true
	_set_state(State.TRANSICION)
	_hud.set_prompt("")
	AudioManager.stop(SOUND_FOOTSTEP)
	AudioManager.play(SOUND_DOOR_CROSS)
	await _transition.fade_out(_scaled(SceneTransition.FADE_TIME))
	if _is_last_round():
		_finish()
		return
	await _walk_corridor(_run.index + 1)
	_load_room(_run.index + 1)
	await _transition.fade_in(_scaled(SceneTransition.FADE_TIME))
	_busy = false
	_refresh_control()


func _is_last_round() -> bool:
	return _run.index + 1 >= _rooms.size()


## Duración del pasillo: la normal, o lo que pide leer su tarjeta y, si hay
## recuerdo, también su pie (con un tope mayor).
static func corridor_time_for(card: String, caption: String = "") -> float:
	if card.is_empty() and caption.is_empty():
		return CORRIDOR_TIME
	var characters := card.length() + caption_characters(caption)
	var reading := CARD_BASE_TIME + CARD_TIME_PER_CHARACTER * characters
	var cap := CORRIDOR_MAX_TIME if caption.is_empty() else CORRIDOR_MEMORY_MAX_TIME
	return minf(maxf(CORRIDOR_TIME, reading), cap)


## Caracteres que se leen de un pie de dos líneas (sin contar el salto de línea).
static func caption_characters(caption: String) -> int:
	return caption.replace("\n", "").length()


## Entre una habitación y la siguiente: un pasillo breve, con su propio fundido.
## No es una ronda: el marcador no se toca. `next_index` es la ronda a la que
## lleva (o el número de rondas si lleva a la salida) y decide la tarjeta.
func _walk_corridor(next_index: int) -> void:
	var card := _content.card_for_round(next_index, _rooms.size())
	var memory := _corridor_memory(next_index)
	var caption := memory.caption() if memory != null else ""
	var seconds := _scaled(corridor_time_for(card, caption))
	if seconds <= 0.0:
		return
	var corridor := CORRIDOR_SCENE.instantiate() as Corridor
	add_child(corridor)
	await _transition.fade_in(_scaled(SceneTransition.FADE_TIME))
	await corridor.play(seconds, _corridor_text(next_index), card, memory)
	await _transition.fade_out(_scaled(SceneTransition.FADE_TIME))
	corridor.queue_free()


## Recuerdo del pasillo que lleva a la ronda de decisión `next_index` (null si no hay).
func _corridor_memory(next_index: int) -> CorridorMemory:
	if next_index >= _rooms.size():
		return null
	return _memory_texts.corridor_memory_for(_decision_rooms_through(next_index))


func _corridor_text(next_index: int) -> String:
	return END_CORRIDOR_TEXT if next_index >= _rooms.size() else _round_text(next_index)


## Tras la última puerta: pasillo de cierre y, después, el post-juego.
func _finish() -> void:
	_busy = true
	_set_state(State.FINAL)
	_teardown_round()
	AudioManager.stop_all()
	_hud.clear()
	_hud.set_round_text("")
	await _walk_corridor(_rooms.size())
	finished.emit()
	if not ending_scene.is_empty():
		get_tree().change_scene_to_file(ending_scene)

# ---------------------------------------------------------------------------
# Pausa y navegación
# ---------------------------------------------------------------------------

func _can_toggle_pause() -> bool:
	if _paused:
		return true
	return not _busy and (_is_playable() or state == State.MENSAJE)


func _toggle_pause() -> void:
	if not _can_toggle_pause():
		return
	_paused = not _paused
	_sync_play_time()
	if _paused:
		_hud.show_pause(FairMode.can_offer_finish(Session.has_pre(), Session.play_seconds))
	else:
		_hud.hide_pause(true)
	_pause_round_sounds(_paused)
	_refresh_control()


func _pause_round_sounds(paused: bool) -> void:
	if _room != null:
		_room.set_ambience_paused(paused)
	AudioManager.stop(SOUND_FOOTSTEP)
	for sound_name in PAUSABLE_SOUNDS:
		AudioManager.set_paused(sound_name, paused)


## MENÚ PRINCIPAL: en modo feria, si aún falta la trivia final, pide confirmación.
func _on_menu_requested() -> void:
	if FairMode.menu_needs_confirmation(Session.has_pre(), Session.has_post()) and _paused:
		_pending_confirm = Confirm.EXIT_TO_MENU
		_hud.show_confirm(_content.fair_menu_confirm, _content.fair_menu_accept, _content.fair_keep_playing)
	else:
		_on_menu_pressed()


func _on_evaluate_requested() -> void:
	if not FairMode.can_offer_finish(Session.has_pre(), Session.play_seconds) or not _paused:
		return
	_pending_confirm = Confirm.FINISH_EARLY
	_hud.show_confirm(_content.fair_finish_confirm, _content.fair_finish_button, _content.fair_keep_playing)


func _on_confirm_answered(accepted: bool) -> void:
	var asked := _pending_confirm
	_pending_confirm = Confirm.NONE
	if not accepted:
		return
	if asked == Confirm.FINISH_EARLY:
		_finish_early()
	elif asked == Confirm.EXIT_TO_MENU:
		_on_menu_pressed()


## Termina la partida sin pasar por la cinemática ni el epílogo: la sesión se
## marca como «anticipada» y se guarda lo jugado hasta ahora.
func _finish_early() -> void:
	_busy = true
	_paused = false
	Session.end_early()
	Session.save()
	_set_state(State.FINAL)
	_hud.hide_pause()
	_hud.clear()
	_teardown_round()
	AudioManager.stop_all()
	await _transition.fade_out(_scaled(SceneTransition.FADE_TIME))
	finished_early.emit()
	if not early_finish_scene.is_empty():
		get_tree().change_scene_to_file(early_finish_scene)


## Al volver al menú no sigue sonando nada de la partida, ni siquiera la
## música apagándose por debajo de la del menú.
func _on_menu_pressed() -> void:
	Session.begin_new()
	AudioManager.stop_all()
	AudioManager.stop_music(0.0)
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
