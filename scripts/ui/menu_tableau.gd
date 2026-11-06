class_name MenuTableau
extends Node2D

## Imagen viva del menú principal: una pared con la fotografía de la familia, la
## lámpara de una mesa y un peluche en el suelo. De vez en cuando la luz falla;
## en la oscuridad la fotografía cambia (falta alguien) y algo se asoma. Todo
## con el arte del juego, ampliado, y con tweens propios: al salir del menú no
## queda ninguna espera pendiente.

const FLOOR_TILESET := preload("res://resources/floor_tileset.tres")
const WALL_TILESET := preload("res://resources/wall_tileset.tres")
const WHITE := preload("res://assets/generated/px_white.png")
const PHOTO_NORMAL := preload("res://assets/generated/px_photo_normal.png")
const PHOTO_ALTERED := preload("res://assets/generated/px_photo_anomaly_c.png")
const TABLE := preload("res://assets/generated/px_table_c.png")
const LAMP := preload("res://assets/generated/px_lamp.png")
const TOY := preload("res://assets/generated/px_toy.png")
const WITNESS := preload("res://assets/generated/px_monster_witness.png")

const SIZE := Vector2(560, 600)
const TILE := 96
const WALL_ROWS := 5
const FLOOR_TOP := 480.0
const PHOTO_CENTER := Vector2(280, 215)
const PHOTO_SCALE := 4.6
const TABLE_BASE := Vector2(300, 548)
const TABLE_SCALE := 2.4
const LAMP_BASE := Vector2(195, 470)
const LAMP_SCALE := 2.6
const TOY_BASE := Vector2(450, 585)
const TOY_SCALE := 2.0
const WITNESS_BASE := Vector2(470, 520)
const WITNESS_SCALE := 3.2
const GLOW_COLOR := Color(1.0, 0.8, 0.48, 0.55)
const GLOW_RADIUS := 270.0
const SHADE_DARK := 0.92
const WITNESS_ALPHA := 0.55
const NORMAL_TIME := 7.0
const ALTERED_TIME := 5.0
const BLACKOUT_TIME := 0.09
const BLACKOUT_HOLD := 0.4
const RECOVER_TIME := 0.7
const FLICKER_STEPS: Array[Vector2] = [Vector2(0.62, 0.08), Vector2(1.0, 0.07), Vector2(0.8, 0.12), Vector2(1.0, 1.8)]
const DUST_COUNT := 26

var _photo: Sprite2D
var _glow: Sprite2D
var _shade: ColorRect
var _witness: Sprite2D


func _ready() -> void:
	_build_shell()
	_build_props()
	_build_effects()
	_flicker_lamp()
	_start_cycle()


## Estado visible ahora (para las pruebas): ¿la fotografía está alterada?
func is_photo_altered() -> bool:
	return _photo.texture == PHOTO_ALTERED

# ---------------------------------------------------------------------------
# Construcción
# ---------------------------------------------------------------------------

func _build_shell() -> void:
	_add_tiles(WALL_TILESET, Vector2.ZERO, WALL_ROWS, Color(0.34, 0.34, 0.44))
	_add_tiles(FLOOR_TILESET, Vector2(0, FLOOR_TOP), 2, Color(0.5, 0.46, 0.46))
	_add_strip(Rect2(0, FLOOR_TOP - 26, SIZE.x, 26), Color(0.14, 0.09, 0.08))
	_add_strip(Rect2(0, FLOOR_TOP, SIZE.x, 20), Color(0, 0, 0, 0.4))


func _add_tiles(tile_set: TileSet, origin: Vector2, rows: int, tint: Color) -> void:
	var tiles := TileMapLayer.new()
	tiles.tile_set = tile_set
	tiles.position = origin
	tiles.scale = Vector2.ONE * (TILE / 32.0)
	tiles.modulate = tint
	tiles.z_index = -20
	for x in range(ceili(SIZE.x / TILE)):
		for y in range(rows):
			tiles.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
	add_child(tiles)


func _add_strip(rect: Rect2, color: Color) -> void:
	var strip := Sprite2D.new()
	strip.texture = WHITE
	strip.position = rect.get_center()
	strip.scale = rect.size / Vector2(WHITE.get_size())
	strip.modulate = color
	strip.z_index = -15
	add_child(strip)


func _build_props() -> void:
	_add_prop(TABLE, TABLE_BASE, TABLE_SCALE)
	_add_prop(LAMP, LAMP_BASE, LAMP_SCALE)
	_add_prop(TOY, TOY_BASE, TOY_SCALE)
	_photo = Sprite2D.new()
	_photo.texture = PHOTO_NORMAL
	_photo.position = PHOTO_CENTER
	_photo.scale = Vector2.ONE * PHOTO_SCALE
	add_child(_photo)
	_witness = Sprite2D.new()
	_witness.texture = WITNESS
	_witness.position = WITNESS_BASE - Vector2(0, WITNESS.get_height() * WITNESS_SCALE / 2.0)
	_witness.scale = Vector2.ONE * WITNESS_SCALE
	_witness.modulate = Color(0.55, 0.58, 0.7, 0.0)
	_witness.z_index = -5
	add_child(_witness)


## Un objeto apoyado en el suelo o en la mesa: `base` es el centro de su base.
func _add_prop(texture: Texture2D, base: Vector2, scale_factor: float) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.scale = Vector2.ONE * scale_factor
	sprite.position = base - Vector2(0, texture.get_height() * scale_factor / 2.0)
	add_child(sprite)


func _build_effects() -> void:
	_glow = Sprite2D.new()
	_glow.texture = _glow_texture()
	_glow.position = LAMP_BASE - Vector2(0, 60)
	_glow.scale = Vector2.ONE * (GLOW_RADIUS * 2.0 / _glow.texture.get_width())
	_glow.material = _additive_material()
	_glow.z_index = 5
	add_child(_glow)
	_shade = ColorRect.new()
	_shade.color = Color(0, 0, 0, 0)
	_shade.size = SIZE
	_shade.z_index = 20
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	add_child(_make_dust())


func _make_dust() -> CPUParticles2D:
	var dust := CPUParticles2D.new()
	dust.texture = WHITE
	dust.amount = DUST_COUNT
	dust.lifetime = 9.0
	dust.preprocess = 9.0
	dust.position = SIZE / 2.0
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = SIZE / 2.0
	dust.direction = Vector2(0.3, -1.0)
	dust.spread = 30.0
	dust.gravity = Vector2.ZERO
	dust.initial_velocity_min = 3.0
	dust.initial_velocity_max = 9.0
	dust.scale_amount_min = 0.12
	dust.scale_amount_max = 0.3
	dust.color = Color(1.0, 0.9, 0.7, 0.22)
	dust.z_index = 10
	return dust

# ---------------------------------------------------------------------------
# Animación
# ---------------------------------------------------------------------------

func _flicker_lamp() -> void:
	var tween := create_tween().set_loops()
	for step in FLICKER_STEPS:
		tween.tween_property(_glow, "modulate:a", step.x, step.y)


## Ciclo eterno: foto normal → apagón (se altera) → foto alterada → apagón (vuelve).
func _start_cycle() -> void:
	var cycle := create_tween().set_loops()
	cycle.tween_interval(NORMAL_TIME)
	cycle.tween_callback(_blackout.bind(true))
	cycle.tween_interval(ALTERED_TIME)
	cycle.tween_callback(_blackout.bind(false))


func _blackout(becomes_altered: bool) -> void:
	var tween := create_tween()
	tween.tween_property(_shade, "color:a", SHADE_DARK, BLACKOUT_TIME)
	tween.tween_callback(_show_photo.bind(becomes_altered))
	tween.tween_interval(BLACKOUT_HOLD)
	tween.tween_property(_shade, "color:a", 0.0, RECOVER_TIME).set_trans(Tween.TRANS_SINE)
	if becomes_altered:
		_flash_witness()


## Algo se asoma durante el apagón y se disuelve cuando vuelve la luz.
func _flash_witness() -> void:
	var tween := create_tween()
	tween.tween_property(_witness, "modulate:a", WITNESS_ALPHA, BLACKOUT_TIME)
	tween.tween_interval(BLACKOUT_HOLD + 0.2)
	tween.tween_property(_witness, "modulate:a", 0.0, RECOVER_TIME * 1.6)


func _show_photo(altered: bool) -> void:
	_photo.texture = PHOTO_ALTERED if altered else PHOTO_NORMAL


static func _glow_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, GLOW_COLOR)
	gradient.set_color(1, Color(GLOW_COLOR, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	return texture


static func _additive_material() -> CanvasItemMaterial:
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return additive