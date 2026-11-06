extends Node

## Reproductor central de sonido y música (autoload «AudioManager»).
##
## El juego pide sonidos por nombre (play, stop, play_music...) y no conoce
## archivos ni reproductores: los datos están en SoundCatalog. Los efectos usan
## un grupo fijo de AudioStreamPlayer que se reutilizan; la música tiene dos
## reproductores propios para el fundido cruzado.

## Cada vez que se pide un sonido (las pruebas lo escuchan).
signal sound_started(sound_name: String)

const SoundCatalog := preload("res://scripts/audio/sound_catalog.gd")
const POOL_SIZE := 16
const MUSIC_PLAYERS := 2
const SILENT_DB := -60.0
const DEFAULT_MUSIC_FADE := 1.5
const REPLACEMENT_EXTENSIONS: Array[String] = ["ogg", "wav", "mp3"]
const VOICE_DIR := "res://assets/audio/voices/"
const VOICE_EXTENSIONS: Array[String] = ["ogg", "wav"]
## Mientras suena una voz, la música baja estos decibelios.
const VOICE_MUSIC_DUCK_DB := 8.0
const SETTINGS_SECTION := "audio"
const SETTINGS_KEY := "master_volume"
const DEFAULT_MASTER_VOLUME := 0.8
const MASTER_BUS := 0
## Tiempo que necesita el servidor de audio para soltar lo que se acaba de
## parar. Si el juego se cierra antes, Godot informa de recursos aún en uso.
const TENSION_BUS := "Ambient"
const TENSION_DB := -9.0
const TENSION_FADE := 0.5
const RELEASE_GRACE := 0.1
const RELEASE_TIMEOUT := 1.0
## Pico por debajo del cual un bus ya no está mezclando nada.
const RELEASED_PEAK_DB := -150.0

var _pool: Array[AudioStreamPlayer] = []
var _music: Array[AudioStreamPlayer] = []
var _voice: AudioStreamPlayer
## Volumen del bus de música antes de bajarlo por una voz (null si no está bajado).
var _music_bus_before_voice: Variant = null
## Carpeta de las voces grabadas (las pruebas la cambian por una temporal).
var voice_dir: String = VOICE_DIR
var _active_music := 0
var _music_name := ""
## Reproductor → nombre del sonido que tiene cargado.
var _sound_of: Dictionary = {}
var _streams: Dictionary = {}
var _tweens: Dictionary = {}
var _warned: Dictionary = {}
var _master_volume := DEFAULT_MASTER_VOLUME
var _tension_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(POOL_SIZE):
		_pool.append(_add_player("Efecto%d" % i))
	for i in range(MUSIC_PLAYERS):
		_music.append(_add_player("Musica%d" % i))
	_voice = _add_player("Voz")
	_voice.bus = SoundCatalog.BUS_SFX
	_voice.finished.connect(_restore_music_after_voice)
	set_master_volume(_load_master_volume(), false)
	get_tree().auto_accept_quit = false
	_preload_catalog()


## Carga todo al arrancar: si un sonido se cargara la primera vez que suena,
## el tirón caería justo en ese momento (un susto, un cambio de ronda).
func _preload_catalog() -> void:
	for sound_name: String in SoundCatalog.SOUNDS:
		_stream_for(sound_name)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_cleanly()


func _add_player(player_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	add_child(player)
	return player

# ---------------------------------------------------------------------------
# Efectos, ambiente y peligro
# ---------------------------------------------------------------------------

## Reproduce un sonido. Un bucle que ya suena no se duplica.
func play(sound_name: String) -> void:
	sound_started.emit(sound_name)
	var stream := _stream_for(sound_name)
	if stream == null:
		return
	var entry := SoundCatalog.entry(sound_name)
	if entry.get("loop", false) and is_active(sound_name):
		return
	var player := _free_player()
	_prepare(player, sound_name, stream, entry)
	player.pitch_scale = 1.0 + randf_range(-1.0, 1.0) * float(entry.get("pitch_jitter", 0.0))
	player.play()


func stop(sound_name: String) -> void:
	for player in _players_of(sound_name):
		_halt(player)


## Detiene efectos, ambiente y peligro. La música se gestiona aparte.
func stop_all() -> void:
	for player in _pool:
		_halt(player)
	_apply_tension(false, 0.0)


## Mientras hay peligro cerca, el ambiente baja: el silencio también asusta.
func set_tension(active: bool) -> void:
	_apply_tension(active, TENSION_FADE)


func is_tense() -> bool:
	return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(TENSION_BUS)) < TENSION_DB / 2.0


func _apply_tension(active: bool, fade: float) -> void:
	var bus := AudioServer.get_bus_index(TENSION_BUS)
	if _tension_tween != null and _tension_tween.is_valid():
		_tension_tween.kill()
	var target := TENSION_DB if active else 0.0
	if fade <= 0.0:
		AudioServer.set_bus_volume_db(bus, target)
		return
	_tension_tween = create_tween()
	_tension_tween.tween_method(func(volume_db: float) -> void: AudioServer.set_bus_volume_db(bus, volume_db), AudioServer.get_bus_volume_db(bus), target, fade)


func set_paused(sound_name: String, paused: bool) -> void:
	for player in _players_of(sound_name):
		player.stream_paused = paused


func is_playing(sound_name: String) -> bool:
	return _players_of(sound_name).any(func(player: AudioStreamPlayer) -> bool: return player.playing)


func is_paused(sound_name: String) -> bool:
	return _players_of(sound_name).any(func(player: AudioStreamPlayer) -> bool: return player.stream_paused)


## Suena o está en pausa (sigue «vivo»).
func is_active(sound_name: String) -> bool:
	return is_playing(sound_name) or is_paused(sound_name)


## Nombres de los sonidos que suenan o están en pausa, sin la música.
func active_sounds() -> Array[String]:
	var names: Array[String] = []
	for player in _pool:
		if _is_busy(player) and not names.has(_sound_of[player]):
			names.append(_sound_of[player])
	return names


func player_count() -> int:
	return _pool.size() + _music.size() + 1

# ---------------------------------------------------------------------------
# Música
# ---------------------------------------------------------------------------

## Cambia de pieza con un fundido cruzado. Si ya suena, no hace nada.
func play_music(sound_name: String, fade: float = DEFAULT_MUSIC_FADE) -> void:
	if sound_name == _music_name:
		return
	var stream := _stream_for(sound_name)
	if stream == null:
		return
	_fade_out(_music[_active_music], fade)
	_active_music = (_active_music + 1) % _music.size()
	var player := _music[_active_music]
	var entry := SoundCatalog.entry(sound_name)
	_prepare(player, sound_name, stream, entry)
	player.volume_db = SILENT_DB
	player.play()
	_fade_to(player, float(entry.get("volume_db", 0.0)), fade)
	_music_name = sound_name


func stop_music(fade: float = DEFAULT_MUSIC_FADE) -> void:
	_fade_out(_music[_active_music], fade)
	_music_name = ""


## Pieza que suena ahora ("" si hay silencio).
func current_music() -> String:
	return _music_name


func is_music_playing() -> bool:
	return _music_name != "" and _music[_active_music].playing


## Piezas que suenan ahora mismo, incluida la que se esté apagando.
func playing_music() -> Array[String]:
	var names: Array[String] = []
	for player in _music:
		if player.playing:
			names.append(_sound_of.get(player, ""))
	return names

# ---------------------------------------------------------------------------
# Cierre
# ---------------------------------------------------------------------------

## Para todo, suelta los streams y espera a que el servidor de audio los libere:
## primero a que todos los buses queden en silencio (prueba de que ha procesado
## las paradas) y después un margen fijo.
func release_all() -> void:
	stop_voice()
	_voice.stream = null
	stop_all()
	stop_music(0.0)
	for player in _pool + _music:
		player.stream = null
	_streams.clear()
	await _await_silent_buses()
	await _await_real_time(RELEASE_GRACE)


func _await_silent_buses() -> void:
	var deadline := Time.get_ticks_msec() + int(RELEASE_TIMEOUT * 1000.0)
	while Time.get_ticks_msec() < deadline and not _all_buses_silent():
		await get_tree().process_frame


## Espera en tiempo real. Un temporizador del árbol no sirve aquí: avanza con
## el delta del fotograma, y tras un fotograma largo (una carga) vence al instante.
func _await_real_time(seconds: float) -> void:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


func _all_buses_silent() -> bool:
	for bus in range(AudioServer.bus_count):
		if AudioServer.get_bus_peak_volume_left_db(bus, 0) > RELEASED_PEAK_DB:
			return false
	return true


## Salida del juego (botón SALIR o cerrar la ventana) sin dejar audio a medias.
func quit_cleanly() -> void:
	await release_all()
	get_tree().quit()

# ---------------------------------------------------------------------------
# Voces grabadas (opcionales)
# ---------------------------------------------------------------------------

## Reproduce la voz `voice_id` si su archivo existe y baja la música mientras
## suena. Sin archivo devuelve false sin errores: el texto se muestra igual.
func play_voice(voice_id: String) -> bool:
	var stream := _voice_stream(voice_id)
	if stream == null:
		return false
	stop_voice()
	_voice.stream = stream
	_duck_music()
	_voice.play()
	return true


func stop_voice() -> void:
	if _voice.playing:
		_voice.stop()
	_restore_music_after_voice()


func is_voice_playing() -> bool:
	return _voice.playing


func voice_path(voice_id: String) -> String:
	for extension in VOICE_EXTENSIONS:
		var path := "%s%s.%s" % [voice_dir, voice_id, extension]
		if ResourceLoader.exists(path) or FileAccess.file_exists(path):
			return path
	return ""


func _voice_stream(voice_id: String) -> AudioStream:
	var path := voice_path(voice_id)
	if path.is_empty():
		return null
	if ResourceLoader.exists(path):
		return load(path) as AudioStream
	if path.ends_with(".wav"):
		return AudioStreamWAV.load_from_file(path)
	return AudioStreamOggVorbis.load_from_file(path)


func _duck_music() -> void:
	if _music_bus_before_voice != null:
		return
	var bus := AudioServer.get_bus_index(SoundCatalog.BUS_MUSIC)
	_music_bus_before_voice = AudioServer.get_bus_volume_db(bus)
	AudioServer.set_bus_volume_db(bus, float(_music_bus_before_voice) - VOICE_MUSIC_DUCK_DB)


func _restore_music_after_voice() -> void:
	if _music_bus_before_voice == null:
		return
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(SoundCatalog.BUS_MUSIC), float(_music_bus_before_voice))
	_music_bus_before_voice = null

# ---------------------------------------------------------------------------
# Volumen general
# ---------------------------------------------------------------------------

## `volume` es lineal, de 0 (silencio) a 1. Se guarda en user://settings.cfg.
func set_master_volume(volume: float, save: bool = true) -> void:
	_master_volume = clampf(volume, 0.0, 1.0)
	AudioServer.set_bus_volume_db(MASTER_BUS, linear_to_db(maxf(_master_volume, 0.0001)))
	AudioServer.set_bus_mute(MASTER_BUS, _master_volume <= 0.0)
	if save:
		_save_master_volume()


func get_master_volume() -> float:
	return _master_volume


func _load_master_volume() -> float:
	return float(UserSettings.load_value(SETTINGS_SECTION, SETTINGS_KEY, DEFAULT_MASTER_VOLUME))


func _save_master_volume() -> void:
	UserSettings.save_value(SETTINGS_SECTION, SETTINGS_KEY, _master_volume)

# ---------------------------------------------------------------------------
# Reproductores
# ---------------------------------------------------------------------------

func _prepare(player: AudioStreamPlayer, sound_name: String, stream: AudioStream, entry: Dictionary) -> void:
	_kill_tween(player)
	player.stop()
	player.stream_paused = false
	player.stream = stream
	player.bus = entry.get("bus", SoundCatalog.BUS_SFX)
	player.volume_db = float(entry.get("volume_db", 0.0))
	_sound_of[player] = sound_name


func _halt(player: AudioStreamPlayer) -> void:
	_kill_tween(player)
	player.stop()
	player.stream_paused = false


func _is_busy(player: AudioStreamPlayer) -> bool:
	return player.playing or player.stream_paused


func _players_of(sound_name: String) -> Array[AudioStreamPlayer]:
	var players: Array[AudioStreamPlayer] = []
	for player in _pool:
		if _sound_of.get(player, "") == sound_name and _is_busy(player):
			players.append(player)
	return players


## Un reproductor libre; si están todos ocupados, el efecto suelto más antiguo.
func _free_player() -> AudioStreamPlayer:
	for player in _pool:
		if not _is_busy(player):
			return player
	for player in _pool:
		if not SoundCatalog.entry(_sound_of[player]).get("loop", false):
			return player
	return _pool[0]


func _fade_to(player: AudioStreamPlayer, volume_db: float, fade: float) -> void:
	_kill_tween(player)
	if fade <= 0.0:
		player.volume_db = volume_db
		return
	var tween := create_tween()
	tween.tween_property(player, "volume_db", volume_db, fade)
	_tweens[player] = tween


func _fade_out(player: AudioStreamPlayer, fade: float) -> void:
	if not player.playing:
		return
	_kill_tween(player)
	if fade <= 0.0:
		player.stop()
		return
	var tween := create_tween()
	tween.tween_property(player, "volume_db", SILENT_DB, fade)
	tween.tween_callback(player.stop)
	_tweens[player] = tween


func _kill_tween(player: AudioStreamPlayer) -> void:
	var tween: Tween = _tweens.get(player)
	if tween != null and tween.is_valid():
		tween.kill()
	_tweens.erase(player)

# ---------------------------------------------------------------------------
# Archivos
# ---------------------------------------------------------------------------

## El stream de un sonido, cargado una sola vez. null (con un aviso único) si el
## nombre no está en el catálogo o falta su archivo.
func stream_for(sound_name: String) -> AudioStream:
	return _stream_for(sound_name)


func _stream_for(sound_name: String) -> AudioStream:
	if _streams.has(sound_name):
		return _streams[sound_name]
	if not SoundCatalog.has(sound_name):
		_warn_once(sound_name, "AudioManager: «%s» no está en SoundCatalog." % sound_name)
		return null
	var entry := SoundCatalog.entry(sound_name)
	var path := _resolve(entry["file"])
	var stream: AudioStream = load(path) if path != "" else null
	if stream == null:
		_warn_once(sound_name, "AudioManager: falta el archivo de «%s» (%s)." % [sound_name, entry["file"]])
		return null
	_apply_loop(stream, entry.get("loop", false))
	_streams[sound_name] = stream
	return stream


## La ruta del catálogo o, si se sustituyó por otro formato, la del archivo
## con el mismo nombre y otra extensión.
func _resolve(path: String) -> String:
	if ResourceLoader.exists(path):
		return path
	for extension in REPLACEMENT_EXTENSIONS:
		var candidate := "%s.%s" % [path.get_basename(), extension]
		if ResourceLoader.exists(candidate):
			return candidate
	return ""


## El bucle lo decide el catálogo, no la importación: así un archivo de
## sustitución se comporta igual sin tocar sus opciones de importación.
func _apply_loop(stream: AudioStream, loop: bool) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = loop
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = loop
	elif stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
		if loop:
			wav.loop_begin = 0
			wav.loop_end = int(wav.get_length() * wav.mix_rate)


func _warn_once(key: String, message: String) -> void:
	if _warned.has(key):
		return
	_warned[key] = true
	push_warning(message)