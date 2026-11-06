class_name JumpscareBase
extends Node2D

## Susto de muerte: partes comunes de todos los sustos.
##
## Cada susto hereda esta escena y sobrescribe _on_start y _on_update para
## animar lo suyo. La secuencia termina siempre: cuando se agota `duration`,
## el aviso `finished` sale aunque la animación propia no haya hecho nada.

## Se emite una sola vez, cuando la secuencia termina.
signal finished

## Duración total de la secuencia, en segundos (entre 1 y 2).
@export var duration: float = 1.3
## Color del destello inicial (cada entidad usa el suyo).
@export var flash_color: Color = Color(1, 1, 1, 1)
## Sonido del golpe (nombre de SoundCatalog). Arranca con el destello.
@export var sound_name: String = ""

const SHAKE_STRENGTH := 9.0
const SHAKE_DECAY := 0.55
const FLASH_TIME := 0.16
const GLOW_SIZE := 128
const WHITE := preload("res://assets/generated/px_white.png")

@onready var _visual: Node2D = $Visual
@onready var _flash: ColorRect = $Flash

var _elapsed := 0.0
var _done := false
var _time_scale := 1.0


## Reproduce la secuencia. `time_scale` acorta la duración sin cambiar el dibujo
## (las pruebas lo ponen a 0 para recorrer partidas enteras sin esperar).
func play(time_scale: float = 1.0) -> void:
	if _done:
		return
	_time_scale = time_scale
	if not sound_name.is_empty():
		AudioManager.play(sound_name)
	_flash.color = Color(flash_color.r, flash_color.g, flash_color.b, 1.0)
	var tween := create_tween()
	tween.tween_property(_flash, "color:a", 0.0, FLASH_TIME * maxf(time_scale, 0.01))
	_on_start()
	while _elapsed < duration * time_scale:
		await get_tree().process_frame
		_elapsed += get_process_delta_time()
		_apply_shake()
		_on_update(_elapsed)
	_emit_finished()


## Aspecto inicial del susto concreto.
func _on_start() -> void:
	pass


## Avance de 0 a 1 entre dos instantes (para encadenar los tiempos de un susto).
static func ramp(value: float, from: float, to: float) -> float:
	return clampf(inverse_lerp(from, to, value), 0.0, 1.0)


## Arranque y frenado suaves de un avance de 0 a 1.
static func smooth(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


## Mancha de luz que suma color (faros, ojos, destellos). Se añade encima.
func add_glow(center: Vector2, radius: float, color: Color) -> Sprite2D:
	var glow := Sprite2D.new()
	glow.texture = _glow_texture(color)
	glow.position = center
	glow.scale = Vector2.ONE * (radius * 2.0 / GLOW_SIZE)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = additive
	_visual.add_child(glow)
	return glow


## Rectángulo liso (el pixel blanco estirado). `z` ordena respecto al resto.
func add_block(rect: Rect2, color: Color, z: int = 0) -> Sprite2D:
	var block := Sprite2D.new()
	block.texture = WHITE
	block.position = rect.get_center()
	block.scale = rect.size / Vector2(WHITE.get_size())
	block.modulate = color
	block.z_index = z
	_visual.add_child(block)
	return block


static func _glow_texture(color: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, color)
	gradient.set_color(1, Color(color, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = GLOW_SIZE
	texture.height = GLOW_SIZE
	return texture


## Duración real de esta reproducción (ya escalada).
func total_duration() -> float:
	return duration * _time_scale


## Animación propia, en segundos desde el inicio de la secuencia.
func _on_update(_elapsed_seconds: float) -> void:
	pass


func _apply_shake() -> void:
	var strength := SHAKE_STRENGTH * (1.0 - clampf(_elapsed / SHAKE_DECAY, 0.0, 1.0))
	_visual.position = Vector2(randf_range(-strength, strength), randf_range(-strength, strength))


func _emit_finished() -> void:
	if _done:
		return
	_done = true
	finished.emit()
	queue_free()