class_name EntityAmbience
extends Node

## Efectos del entorno que acompañan a una entidad: la lámpara parpadea, la
## ventana se enfría, el armario vibra... Actúan sobre objetos que ya existen
## en la habitación y se deshacen por completo al parar. La única pieza nueva
## es la «pista luminosa» de las anomalías sonoras: una luz mínima que parpadea
## con el sonido y desaparece al parar.
##
## Cada anomalía nombra su efecto (AnomalyData.ambience). "cuando" decide si es
## continuo ("siempre") o solo mientras el jugador está dentro del radio de
## aviso de la entidad ("alerta").

const WHEN_ALWAYS := "siempre"
const WHEN_ALERT := "alerta"
const WORLD_TARGET := ""

const FLICKER_STEPS: Array[Vector2] = [Vector2(0.35, 0.06), Vector2(1.0, 0.05), Vector2(0.55, 0.08), Vector2(1.0, 0.9)]
const TREMBLE_AMPLITUDE := 1.6
const TREMBLE_STEPS := 6
const SHAKE_STEPS := 8
const TREMBLE_STEP_TIME := 0.035
const TREMBLE_PAUSE := 2.4
const PULSE_TIME := 2.6
const DIM_TIME := 0.5

const EFFECTS := {
	"lampara_parpadea": {"target": "Lamp", "kind": "flicker", "when": WHEN_ALERT},
	"habitacion_se_apaga": {"target": WORLD_TARGET, "kind": "dim", "when": WHEN_ALERT, "tint": Color(0.6, 0.6, 0.68, 1)},
	"ventana_fria": {"target": "Window/Sprite", "kind": "pulse", "when": WHEN_ALWAYS, "tint": Color(0.6, 0.72, 1.0, 1)},
	"armario_vibra": {"target": "Wardrobe", "kind": "tremble", "when": WHEN_ALWAYS},
	"cama_cruje": {"target": "Bed", "kind": "tremble", "when": WHEN_ALWAYS},
	"espejo_parpadea": {"target": "Mirror", "kind": "flicker", "when": WHEN_ALWAYS},
	"telefono_vibra": {"target": "Phone", "kind": "tremble", "when": WHEN_ALWAYS},
	"cielo_oscuro": {"target": "Window/Sprite", "kind": "pulse", "when": WHEN_ALWAYS, "tint": Color(0.45, 0.5, 0.65, 1)},
	"trafico_lejano": {"target": WORLD_TARGET, "kind": "sound_only", "when": WHEN_ALWAYS, "sound": "ambient_traffic"},
	# Con "interval" el sonido se repite cada N segundos y la vibración (si la hay) va con él.
	"telefono_suena": {"target": "Phone", "kind": "tremble", "when": WHEN_ALWAYS, "sound": "anomaly_phone_ring", "interval": 6.0, "cue": "led_telefono"},
	"puerta_golpes": {"target": "Door", "kind": "tremble", "when": WHEN_ALWAYS, "sound": "anomaly_knocks", "interval": 9.0, "cue": "luz_bajo_puerta"},
	"caja_musica": {"target": WORLD_TARGET, "kind": "sound_only", "when": WHEN_ALWAYS, "sound": "anomaly_music_box", "interval": 10.0},
	"linea_muerta": {"target": WORLD_TARGET, "kind": "sound_only", "when": WHEN_ALWAYS, "sound": "anomaly_dead_line", "interval": 5.0},
}
## Pistas luminosas: rectángulo relativo al objeto, color, halo (radio, 0 = sin
## halo) y parpadeos por cada vez que suena (encendido y apagado en segundos).
const CUES := {
	"led_telefono": {"rect": Rect2(8, -9, 2, 2), "color": Color(1.0, 0.36, 0.26), "halo": 9.0, "blinks": 4, "on": 0.2, "off": 0.18},
	"luz_bajo_puerta": {"rect": Rect2(-30, -2, 60, 2), "color": Color(1.0, 0.86, 0.6), "halo": 0.0, "blinks": 3, "on": 0.22, "off": 0.16},
}
const CUE_TEXTURE := preload("res://assets/generated/px_white.png")
const CUE_HALO_ALPHA := 0.45
const CUE_Z_INDEX := 3
const CUE_NODE_NAME := "PistaLuminosa"

## Los efectos con intervalo empiezan tras esta espera, ya dentro de la ronda.
const REPEAT_START_DELAY := 1.5

var _world: Node2D
var _effect: Dictionary = {}
var _tween: Tween
## Temporizador de los efectos con intervalo.
var _repeat_tween: Tween
var _fired := 0
## Pista luminosa del efecto actual (null si no tiene) y su parpadeo.
var _cue: Node2D = null
var _cue_tween: Tween
## Sonido de fondo que acompaña al efecto (se corta al parar).
var _sound := ""
## Propiedades originales del objeto afectado: se restauran al parar.
var _original: Dictionary = {}


func setup(world: Node2D) -> void:
	_world = world


## Prepara el efecto de una anomalía. Los continuos arrancan ya.
func start(effect_name: String) -> void:
	stop()
	_effect = EFFECTS.get(effect_name, {})
	if _effect.is_empty():
		return
	_sound = _effect.get("sound", "")
	if _effect.has("interval"):
		_schedule_repeat(REPEAT_START_DELAY)
		return
	if not _sound.is_empty():
		AudioManager.play(_sound)
	if _effect["when"] == WHEN_ALWAYS:
		_play()


## El jugador entra o sale del radio de aviso de la entidad.
func set_alert(alert: bool) -> void:
	if _effect.is_empty() or _effect["when"] != WHEN_ALERT:
		return
	if alert:
		_play()
	else:
		_halt()


func is_running() -> bool:
	return _is_alive(_tween) or _is_alive(_repeat_tween)


## Veces que ha sonado un efecto con intervalo desde que arrancó.
func repeats_fired() -> int:
	return _fired


## La pausa congela las repeticiones y el sonido en curso, y se reanuda igual.
func set_paused(paused: bool) -> void:
	for tween in [_tween, _repeat_tween, _cue_tween]:
		if _is_alive(tween):
			if paused:
				tween.pause()
			else:
				tween.play()
	if not _sound.is_empty():
		AudioManager.set_paused(_sound, paused)


func _is_alive(tween: Tween) -> bool:
	return tween != null and tween.is_valid()


func _schedule_repeat(delay: float) -> void:
	_repeat_tween = create_tween()
	_repeat_tween.tween_interval(delay)
	_repeat_tween.tween_callback(_fire_repeat)


func _fire_repeat() -> void:
	_fired += 1
	AudioManager.play(_sound)
	if _effect["kind"] == "tremble":
		_shake_once()
	_blink_cue()
	_schedule_repeat(_effect["interval"])


## Una sacudida corta del objeto, sincronizada con el sonido que acaba de salir.
func _shake_once() -> void:
	var target := _target_node()
	if target == null:
		return
	if _is_alive(_tween):
		_tween.kill()
	if not _original.has(target):
		_remember(target)
	var base: Vector2 = _original[target]["position"]
	_tween = create_tween()
	for i in range(SHAKE_STEPS):
		var side := 1.0 if i % 2 == 0 else -1.0
		_tween.tween_property(target, "position", base + Vector2(side * TREMBLE_AMPLITUDE, 0), TREMBLE_STEP_TIME)
	_tween.tween_property(target, "position", base, TREMBLE_STEP_TIME)


func cue_node() -> Node2D:
	return _cue


## La luz se crea la primera vez que suena y parpadea con cada repetición.
func _blink_cue() -> void:
	var cue_name: String = _effect.get("cue", "")
	if cue_name.is_empty() or _target_node() == null:
		return
	var cue: Dictionary = CUES[cue_name]
	if _cue == null:
		_cue = _build_cue(cue)
	if _is_alive(_cue_tween):
		_cue_tween.kill()
	_cue_tween = create_tween()
	for i in range(int(cue["blinks"])):
		_cue_tween.tween_property(_cue, "modulate:a", 1.0, 0.04)
		_cue_tween.tween_interval(cue["on"])
		_cue_tween.tween_property(_cue, "modulate:a", 0.0, 0.04)
		_cue_tween.tween_interval(cue["off"])


func _build_cue(cue: Dictionary) -> Node2D:
	var target := _target_node()
	var rect: Rect2 = cue["rect"]
	var holder := Node2D.new()
	holder.name = CUE_NODE_NAME
	holder.position = target.position + rect.get_center()
	holder.z_index = CUE_Z_INDEX
	holder.modulate.a = 0.0
	if float(cue["halo"]) > 0.0:
		holder.add_child(_cue_halo(cue["color"], cue["halo"]))
	var core := Sprite2D.new()
	core.texture = CUE_TEXTURE
	core.scale = rect.size / CUE_TEXTURE.get_size()
	core.modulate = cue["color"]
	holder.add_child(core)
	_world.add_child(holder)
	return holder


func _cue_halo(color: Color, radius: float) -> Sprite2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(color, CUE_HALO_ALPHA))
	gradient.set_color(1, Color(color, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = int(radius * 2.0)
	texture.height = int(radius * 2.0)
	var halo := Sprite2D.new()
	halo.texture = texture
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	halo.material = material
	return halo


func _remove_cue() -> void:
	if _is_alive(_cue_tween):
		_cue_tween.kill()
	_cue_tween = null
	if _cue != null and is_instance_valid(_cue):
		if _cue.get_parent() != null:
			_cue.get_parent().remove_child(_cue)
		_cue.queue_free()
	_cue = null


func current_effect_target() -> Node2D:
	return _target_node() if not _effect.is_empty() else null


func stop() -> void:
	_halt()
	if not _sound.is_empty():
		AudioManager.stop(_sound)
		_sound = ""
	_effect = {}


func _exit_tree() -> void:
	stop()


func _play() -> void:
	if is_running() or _effect["kind"] == "sound_only":
		return
	var target := _target_node()
	if target == null:
		return
	_remember(target)
	_tween = create_tween().set_loops()
	match _effect["kind"]:
		"flicker":
			_flicker(target)
		"tremble":
			_tremble(target)
		"pulse", "dim":
			_pulse(target)


func _halt() -> void:
	if _is_alive(_tween):
		_tween.kill()
	_tween = null
	if _is_alive(_repeat_tween):
		_repeat_tween.kill()
	_repeat_tween = null
	_fired = 0
	_remove_cue()
	for node: Node2D in _original:
		if is_instance_valid(node):
			node.position = _original[node]["position"]
			node.modulate = _original[node]["modulate"]
	_original.clear()


func _remember(target: Node2D) -> void:
	_original[target] = {"position": target.position, "modulate": target.modulate}


func _target_node() -> Node2D:
	var path: String = _effect["target"]
	return _world if path == WORLD_TARGET else _world.get_node_or_null(path) as Node2D


func _flicker(target: Node2D) -> void:
	var base: Color = _original[target]["modulate"]
	for step in FLICKER_STEPS:
		_tween.tween_property(target, "modulate", Color(base.r * step.x, base.g * step.x, base.b * step.x, base.a), step.y)


func _tremble(target: Node2D) -> void:
	var base: Vector2 = _original[target]["position"]
	_tween.tween_interval(TREMBLE_PAUSE)
	for i in range(TREMBLE_STEPS):
		var sign_x := 1.0 if i % 2 == 0 else -1.0
		_tween.tween_property(target, "position", base + Vector2(sign_x * TREMBLE_AMPLITUDE, 0), TREMBLE_STEP_TIME)
	_tween.tween_property(target, "position", base, TREMBLE_STEP_TIME)


func _pulse(target: Node2D) -> void:
	var base: Color = _original[target]["modulate"]
	var tint: Color = _effect["tint"]
	var time: float = DIM_TIME if _effect["kind"] == "dim" else PULSE_TIME
	_tween.tween_property(target, "modulate", base * tint, time).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(target, "modulate", base, time).set_trans(Tween.TRANS_SINE)