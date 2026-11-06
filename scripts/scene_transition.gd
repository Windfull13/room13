class_name SceneTransition
extends CanvasLayer

## Transición básica entre habitaciones mediante un fundido a negro.
## Durante el fundido bloquea el ratón para evitar pulsaciones accidentales.

@onready var _rect: ColorRect = $FadeRect

## Duración del fundido.
const FADE_TIME := 0.35

func _ready() -> void:
	# Arranca en negro para ofrecer un fundido de entrada al iniciar la partida.
	_rect.color = Color(0, 0, 0, 1)
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP

## Oscurece la pantalla y espera a terminar. Con duración 0 es instantáneo.
func fade_out(duration: float = FADE_TIME) -> void:
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	if duration <= 0.0:
		_rect.color.a = 1.0
		return
	var tween := create_tween()
	tween.tween_property(_rect, "color:a", 1.0, duration)
	await tween.finished

## Aclara la pantalla y espera a terminar. Con duración 0 es instantáneo.
func fade_in(duration: float = FADE_TIME) -> void:
	if duration <= 0.0:
		_rect.color.a = 0.0
		_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	var tween := create_tween()
	tween.tween_property(_rect, "color:a", 0.0, duration)
	await tween.finished
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE