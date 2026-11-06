extends JumpscareBase

## Las tres señales en una sola secuencia: la mano marcada, la ventana y la
## figura que acaba llenando la pantalla.

const FIRST_BEAT_END := 0.55
const SECOND_BEAT_START := 0.33
const SECOND_BEAT_END := 1.05

@onready var _mano: Sprite2D = $Visual/Mano
@onready var _ventana: Sprite2D = $Visual/Ventana
@onready var _figura: Sprite2D = $Visual/Figura


func _on_start() -> void:
	_mano.position = Vector2(430, 330)
	_mano.modulate = Color(0.62, 0.14, 0.14, 0.0)
	_ventana.position = Vector2(1160, 330)
	_ventana.modulate = Color(1, 1, 1, 0)
	_figura.position = Vector2(640, 370)
	_figura.scale = Vector2(1.5, 1.5)
	_figura.modulate = Color(0.75, 0.75, 0.82, 0.0)


func _on_update(elapsed: float) -> void:
	_update_handprint(elapsed)
	_update_window(elapsed)
	_update_figure(elapsed)


func _update_handprint(elapsed: float) -> void:
	if elapsed < FIRST_BEAT_END:
		_mano.modulate.a = clampf(elapsed / FIRST_BEAT_END, 0.0, 1.0)
	else:
		_mano.modulate.a = clampf(1.0 - (elapsed - FIRST_BEAT_END) / 0.4, 0.0, 1.0)


func _update_window(elapsed: float) -> void:
	if elapsed < SECOND_BEAT_START:
		return
	var entering := clampf((elapsed - SECOND_BEAT_START) / 0.35, 0.0, 1.0)
	_ventana.position.x = lerpf(1160.0, 830.0, entering)
	_ventana.modulate.a = entering
	if elapsed > SECOND_BEAT_END:
		_ventana.modulate.a = clampf(1.0 - (elapsed - SECOND_BEAT_END) / 0.3, 0.0, 1.0)


func _update_figure(elapsed: float) -> void:
	if elapsed < SECOND_BEAT_END:
		return
	var progress := clampf((elapsed - SECOND_BEAT_END) / (total_duration() - SECOND_BEAT_END), 0.0, 1.0)
	_figura.modulate.a = progress
	_figura.scale = Vector2.ONE * lerpf(1.5, 7.0, progress * progress)