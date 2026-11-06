extends RefCounted

## Todos los sonidos del juego: nombre → archivo, volumen, bus y bucle.
##
## Para cambiar un sonido basta con sustituir su archivo por otro con el mismo
## nombre (si cambia la extensión, AudioManager también lo encuentra).
## Campos opcionales: "loop" (false) y "pitch_jitter" (0, variación aleatoria
## del tono para que un efecto repetido no suene idéntico).

const SFX_DIR := "res://assets/audio/"
const MUSIC_DIR := "res://assets/audio/music/"

const BUS_MUSIC := "Music"
const BUS_AMBIENT := "Ambient"
const BUS_SFX := "SFX"
const BUS_DANGER := "Danger"
const BUSES: Array[String] = [BUS_MUSIC, BUS_AMBIENT, BUS_SFX, BUS_DANGER]

const SOUNDS := {
	# Música
	"music_menu": {"file": MUSIC_DIR + "music_menu.ogg", "volume_db": -7.9, "bus": BUS_MUSIC, "loop": true},
	"music_calm": {"file": MUSIC_DIR + "music_calm.ogg", "volume_db": -9.3, "bus": BUS_MUSIC, "loop": true},
	"music_tense": {"file": MUSIC_DIR + "music_tense.ogg", "volume_db": -6.7, "bus": BUS_MUSIC, "loop": true},
	"music_end": {"file": MUSIC_DIR + "music_end.ogg", "volume_db": -8.2, "bus": BUS_MUSIC, "loop": true},
	# Ambiente y peligro
	"ambient_room": {"file": SFX_DIR + "ambient_room.ogg", "volume_db": -7.2, "bus": BUS_AMBIENT, "loop": true},
	"danger_heartbeat": {"file": SFX_DIR + "danger_heartbeat.ogg", "volume_db": 2.6, "bus": BUS_DANGER, "loop": true},
	# Jugador y habitación
	"footstep": {"file": SFX_DIR + "footstep.wav", "volume_db": -10.4, "bus": BUS_SFX, "pitch_jitter": 0.08},
	"message_open": {"file": SFX_DIR + "message_open.wav", "volume_db": -7.2, "bus": BUS_SFX},
	"message_close": {"file": SFX_DIR + "message_close.wav", "volume_db": -8.5, "bus": BUS_SFX},
	"door_locked": {"file": SFX_DIR + "door_locked.wav", "volume_db": -7.7, "bus": BUS_SFX},
	"door_unlock": {"file": SFX_DIR + "door_unlock.wav", "volume_db": -4.3, "bus": BUS_SFX},
	"door_cross": {"file": SFX_DIR + "door_cross.wav", "volume_db": -2.3, "bus": BUS_SFX},
	# Interfaz
	"ui_click": {"file": SFX_DIR + "ui_click.wav", "volume_db": -4.2, "bus": BUS_SFX},
	"ui_hover": {"file": SFX_DIR + "ui_hover.wav", "volume_db": -11.5, "bus": BUS_SFX, "pitch_jitter": 0.05},
	"ui_decision_anomaly": {"file": SFX_DIR + "ui_decision_anomaly.wav", "volume_db": -5.9, "bus": BUS_SFX},
	"ui_decision_no_anomaly": {"file": SFX_DIR + "ui_decision_no_anomaly.wav", "volume_db": -6.0, "bus": BUS_SFX},
	# Resultado y transiciones
	"success": {"file": SFX_DIR + "success.wav", "volume_db": -1.3, "bus": BUS_SFX},
	"fail": {"file": SFX_DIR + "fail.wav", "volume_db": 1.8, "bus": BUS_SFX},
	"fade": {"file": SFX_DIR + "fade.wav", "volume_db": -5.2, "bus": BUS_SFX},
	# Sustos (uno por entidad; lo pide cada escena con JumpscareBase.sound_name)
	"jumpscare_cama": {"file": SFX_DIR + "jumpscare_cama.wav", "volume_db": -2.7, "bus": BUS_SFX},
	"jumpscare_armario": {"file": SFX_DIR + "jumpscare_armario.wav", "volume_db": 1.0, "bus": BUS_SFX},
	"jumpscare_ventana": {"file": SFX_DIR + "jumpscare_ventana.wav", "volume_db": -4.7, "bus": BUS_SFX},
	"jumpscare_espejo": {"file": SFX_DIR + "jumpscare_espejo.wav", "volume_db": -0.7, "bus": BUS_SFX},
	"jumpscare_testigo_cuarto": {"file": SFX_DIR + "jumpscare_testigo_cuarto.wav", "volume_db": 3.7, "bus": BUS_SFX},
	"jumpscare_testigo_esquina": {"file": SFX_DIR + "jumpscare_testigo_esquina.wav", "volume_db": 4.6, "bus": BUS_SFX},
	"jumpscare_cuervo": {"file": SFX_DIR + "jumpscare_cuervo.wav", "volume_db": 4.9, "bus": BUS_SFX},
	"jumpscare_oscuridad": {"file": SFX_DIR + "jumpscare_oscuridad.wav", "volume_db": 4.2, "bus": BUS_SFX},
	# Sonidos de anomalías no peligrosas: siempre más suaves que cualquier susto
	"anomaly_phone_ring": {"file": SFX_DIR + "anomaly_phone_ring.wav", "volume_db": -14.0, "bus": BUS_SFX},
	"anomaly_knocks": {"file": SFX_DIR + "anomaly_knocks.wav", "volume_db": -19.4, "bus": BUS_SFX},
	"anomaly_music_box": {"file": SFX_DIR + "anomaly_music_box.wav", "volume_db": -12.5, "bus": BUS_SFX},
	"anomaly_dead_line": {"file": SFX_DIR + "anomaly_dead_line.wav", "volume_db": -12.2, "bus": BUS_SFX},
	"ambient_traffic": {"file": SFX_DIR + "ambient_traffic.ogg", "volume_db": -18.3, "bus": BUS_AMBIENT, "loop": true},
	# Recuerdos del pasillo (la familia reutiliza anomaly_music_box)
	"memory_murmur": {"file": SFX_DIR + "memory_murmur.wav", "volume_db": -11.2, "bus": BUS_SFX},
	"memory_rain": {"file": SFX_DIR + "memory_rain.ogg", "volume_db": -12.8, "bus": BUS_AMBIENT, "loop": true},
	"memory_ticking": {"file": SFX_DIR + "memory_ticking.wav", "volume_db": -6.3, "bus": BUS_SFX},
	"jumpscare_tres_senales": {"file": SFX_DIR + "jumpscare_tres_senales.wav", "volume_db": 0.8, "bus": BUS_SFX},
}


static func has(sound_name: String) -> bool:
	return SOUNDS.has(sound_name)


static func entry(sound_name: String) -> Dictionary:
	return SOUNDS.get(sound_name, {})


static func is_music(sound_name: String) -> bool:
	return entry(sound_name).get("bus", "") == BUS_MUSIC