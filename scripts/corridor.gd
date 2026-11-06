class_name Corridor
extends CanvasLayer

## Pasillo de transición entre dos habitaciones. No es una ronda ni un mapa: el
## protagonista lo cruza andando de una puerta a la siguiente mientras se
## apaga el ruido de la habitación que deja atrás. Se construye con las mismas
## baldosas y sprites del juego.

const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const FLOOR_TILESET := preload("res://resources/floor_tileset.tres")
const WALL_TILESET := preload("res://resources/wall_tileset.tres")
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const WHITE := preload("res://assets/generated/px_white.png")
const DOOR := preload("res://assets/generated/px_door_wall.png")
const LAMP := preload("res://assets/generated/px_lamp.png")
const RUG := preload("res://assets/generated/px_rug.png")

const TILE := 64
const COLUMNS := 20
const WALL_TOP := 150.0
const WALL_ROWS := 3
const FLOOR_ROWS := 2
const FLOOR_TOP := WALL_TOP + WALL_ROWS * TILE
const SPRITE_SCALE := 1.3
const WALKER_SCALE := 1.3
const WALKER_FEET_Y := 424.0
const WALKER_START_X := 200.0
const WALKER_END_X := 1040.0
const DOOR_BASE_Y := FLOOR_TOP + 6.0
const DOOR_LEFT_X := 130.0
const DOOR_RIGHT_X := 1150.0
const SIDE_DOOR_XS: Array[float] = [430.0, 700.0]
const LAMP_XS: Array[float] = [300.0, 565.0, 850.0]
const STEP_FRAMES: Array[int] = [0, 2]
const ARRIVAL_PAUSE := 0.7
const DOOR_LIGHT_TIME := 0.5
const FLICKER_STEPS: Array[Vector2] = [Vector2(0.55, 0.07), Vector2(1.0, 0.06), Vector2(0.75, 0.1), Vector2(1.0, 1.4)]
const GLOW_COLOR := Color(1.0, 0.82, 0.5, 0.5)
const CARD_WIDTH := 900.0
const CARD_TOP := 520.0
const CARD_FONT_SIZE := 30
const CARD_COLOR := Color(0.88, 0.84, 0.76)
const CARD_FADE_TIME := 0.9
## Recuerdo enmarcado en la pared (pasillos hacia las rondas 3, 5, 7 y 9).
const FRAME_CENTER_X := 565.0
const FRAME_TOP := WALL_TOP + 12.0
const FRAME_BORDER := 8.0
const FRAME_COLOR := Color(0.24, 0.16, 0.1)
const FRAME_EDGE := Color(0.08, 0.05, 0.03)
const CAPTION_COLOR := Color(0.95, 0.88, 0.74)
## Parte del paseo dedicada al recuerdo, según la longitud de sus textos (con límites).
const MEMORY_SHARE_MIN := 0.4
const MEMORY_SHARE_MAX := 0.7
## En pasillos cortos (pruebas), los fundidos del pie y la tarjeta se acortan en proporción.
const MEMORY_FADE_SHARE := 0.2
const SOUND_STEP := "footstep"
const SOUND_ARRIVE := "door_unlock"

@onready var _stage: Node2D = $Stage
@onready var _label: Label = $Stage/DestinationLabel

var _walker: AnimatedSprite2D
var _card_label: Label
var _caption_label: Label
var _vignette: MemoryVignette = null
## Lo que tapa el marco (puertas laterales y lámpara central): se oculta con recuerdo.
var _behind_frame: Array[CanvasItem] = []
var _destination_light: Array[Sprite2D] = []


func _ready() -> void:
	_label.add_theme_font_override("font", UiTheme.UI_FONT)
	_build_shell()
	_build_doors()
	_build_lamps()
	_build_runner()
	_build_walker()
	_build_card_label()
	_caption_label = _make_text_label(CAPTION_COLOR)


## Cruza el pasillo en `seconds` segundos. Con 0 no anima nada. La tarjeta de
## aprendizaje (si la hay) aparece bajo el texto de la ronda y se queda hasta
## salir. Con `memory`, antes se ve el recuerdo enmarcado con su pie.
func play(seconds: float, destination_text: String, card: String = "", memory: CorridorMemory = null) -> void:
	_label.text = destination_text
	_card_label.text = card
	if memory != null:
		_play_memory(memory, seconds, card)
	elif not card.is_empty() and seconds > 0.0:
		_fade_label(_card_label, 1.0)
	else:
		_card_label.modulate.a = 1.0
	if seconds <= 0.0:
		await get_tree().process_frame
		return
	_walker.position.x = WALKER_START_X
	_walker.play("walk_side")
	var tween := create_tween()
	tween.tween_property(_walker, "position:x", WALKER_END_X, seconds)
	await tween.finished
	_walker.play("idle_side")
	_open_destination_door()
	var pause := create_tween()
	pause.tween_interval(ARRIVAL_PAUSE)
	await pause.finished


func has_memory() -> bool:
	return _vignette != null


func vignette() -> MemoryVignette:
	return _vignette


func caption_text() -> String:
	return _caption_label.text


func card_text() -> String:
	return _card_label.text


func walker_x() -> float:
	return _walker.position.x


func is_destination_lit() -> bool:
	return not _destination_light.is_empty() and _destination_light[0].modulate.a > 0.0

# ---------------------------------------------------------------------------
# Construcción
# ---------------------------------------------------------------------------

func _build_shell() -> void:
	_add_tiles(WALL_TILESET, Vector2(0, WALL_TOP), WALL_ROWS, Color(0.7, 0.7, 0.8), -20)
	_add_tiles(FLOOR_TILESET, Vector2(0, FLOOR_TOP), FLOOR_ROWS, Color(0.62, 0.6, 0.62), -20)
	_add_strip(Rect2(0, FLOOR_TOP - 18, COLUMNS * TILE, 18), Color(0.17, 0.11, 0.09), -15)
	_add_strip(Rect2(0, FLOOR_TOP, COLUMNS * TILE, 16), Color(0, 0, 0, 0.38), -14)
	_add_strip(Rect2(0, FLOOR_TOP + FLOOR_ROWS * TILE - 14, COLUMNS * TILE, 14), Color(0, 0, 0, 0.3), -14)


func _add_tiles(tile_set: TileSet, origin: Vector2, rows: int, tint: Color, z: int) -> void:
	var tiles := TileMapLayer.new()
	tiles.tile_set = tile_set
	tiles.position = origin
	tiles.scale = Vector2(2, 2)
	tiles.modulate = tint
	tiles.z_index = z
	for x in range(COLUMNS):
		for y in range(rows):
			tiles.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
	_stage.add_child(tiles)


func _add_strip(rect: Rect2, color: Color, z: int) -> void:
	var strip := Sprite2D.new()
	strip.texture = WHITE
	strip.position = rect.get_center()
	strip.scale = rect.size / Vector2(WHITE.get_size())
	strip.modulate = color
	strip.z_index = z
	_stage.add_child(strip)


func _build_doors() -> void:
	_add_door(DOOR_LEFT_X, Color(0.5, 0.5, 0.58))
	for x in SIDE_DOOR_XS:
		_behind_frame.append(_add_door(x, Color(0.42, 0.42, 0.5)))
	_add_door(DOOR_RIGHT_X, Color(0.95, 0.95, 1.0))
	_destination_light = [
		_add_light(Rect2(DOOR_RIGHT_X + 24 - 2, DOOR_BASE_Y - 130, 4, 118), GLOW_COLOR),
		_add_light(Rect2(DOOR_RIGHT_X - 50, DOOR_BASE_Y, 100, 22), Color(1.0, 0.82, 0.5, 0.22)),
	]
	_label.position = Vector2(DOOR_RIGHT_X - 130, DOOR_BASE_Y - 190)


func _build_card_label() -> void:
	_card_label = _make_text_label(CARD_COLOR)


func _make_text_label(color: Color) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(CARD_WIDTH, 0)
	label.position = Vector2((COLUMNS * TILE - CARD_WIDTH) / 2.0, CARD_TOP)
	label.add_theme_font_override("font", UiTheme.UI_FONT)
	label.add_theme_font_size_override("font_size", CARD_FONT_SIZE)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	label.add_theme_constant_override("outline_size", 8)
	label.modulate.a = 0.0
	_stage.add_child(label)
	return label


func _fade_label(label: Label, alpha: float, time: float = CARD_FADE_TIME) -> void:
	create_tween().tween_property(label, "modulate:a", alpha, time)


## Recuerdo: viñeta enmarcada y pie; después, la tarjeta de aprendizaje.
func _play_memory(memory: CorridorMemory, seconds: float, card: String) -> void:
	_hang_frame(memory)
	_caption_label.text = memory.caption()
	var memory_time := seconds * memory_share(memory.caption(), card)
	_vignette.play(memory_time)
	if seconds <= 0.0:
		_caption_label.modulate.a = 0.0
		_card_label.modulate.a = 1.0
		return
	var fade := minf(CARD_FADE_TIME, memory_time * MEMORY_FADE_SHARE)
	_fade_label(_caption_label, 1.0, fade)
	var swap := create_tween()
	swap.tween_interval(memory_time - fade)
	swap.tween_callback(_fade_label.bind(_caption_label, 0.0, fade))
	swap.tween_interval(fade)
	swap.tween_callback(_fade_label.bind(_card_label, 1.0, fade))


## Qué parte del paseo es para el recuerdo (el resto, para la tarjeta).
static func memory_share(caption: String, card: String) -> float:
	var total := caption.length() + card.length()
	if total == 0:
		return MEMORY_SHARE_MIN
	return clampf(float(caption.length()) / total, MEMORY_SHARE_MIN, MEMORY_SHARE_MAX)


func _hang_frame(memory: CorridorMemory) -> void:
	for item in _behind_frame:
		item.visible = false
	_vignette = memory.vignette_scene.instantiate() as MemoryVignette
	var inner := _vignette.display_size
	var origin := Vector2(FRAME_CENTER_X - inner.x / 2.0, FRAME_TOP)
	_add_frame_rect(origin, inner, FRAME_BORDER + 2.0, FRAME_EDGE)
	_add_frame_rect(origin, inner, FRAME_BORDER, FRAME_COLOR)
	_vignette.position = origin
	_stage.add_child(_vignette)


func _add_frame_rect(origin: Vector2, inner: Vector2, border: float, color: Color) -> void:
	var rect := ColorRect.new()
	rect.color = color
	rect.position = origin - Vector2.ONE * border
	rect.size = inner + Vector2.ONE * border * 2.0
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(rect)


func _add_door(x: float, tint: Color) -> Sprite2D:
	var door := Sprite2D.new()
	door.texture = DOOR
	door.scale = Vector2.ONE * SPRITE_SCALE
	door.position = Vector2(x, DOOR_BASE_Y - DOOR.get_height() * SPRITE_SCALE / 2.0)
	door.modulate = tint
	_stage.add_child(door)
	return door


## Luz de la puerta de destino: empieza apagada y se enciende al llegar.
func _add_light(rect: Rect2, color: Color) -> Sprite2D:
	var light := Sprite2D.new()
	light.texture = WHITE
	light.position = rect.get_center()
	light.scale = rect.size / Vector2(WHITE.get_size())
	light.modulate = Color(color.r, color.g, color.b, 0.0)
	light.set_meta("target_alpha", color.a)
	_stage.add_child(light)
	return light


func _open_destination_door() -> void:
	AudioManager.play(SOUND_ARRIVE)
	for light in _destination_light:
		create_tween().tween_property(light, "modulate:a", light.get_meta("target_alpha"), DOOR_LIGHT_TIME)


func _build_lamps() -> void:
	for i in range(LAMP_XS.size()):
		var x := LAMP_XS[i]
		var lamp := Sprite2D.new()
		lamp.texture = LAMP
		lamp.scale = Vector2.ONE * 0.8
		lamp.position = Vector2(x, WALL_TOP + 100)
		_stage.add_child(lamp)
		var glow := _add_glow(Vector2(x, WALL_TOP + 110), 150.0)
		glow.z_index = 2
		_add_glow(Vector2(x, FLOOR_TOP + 50), 170.0).scale.y *= 0.45
		if i == 1:
			_flicker(glow)
			_behind_frame.append_array([lamp, glow])


func _add_glow(center: Vector2, radius: float) -> Sprite2D:
	var glow := Sprite2D.new()
	glow.texture = _glow_texture()
	glow.position = center
	glow.scale = Vector2.ONE * (radius * 2.0 / glow.texture.get_width())
	glow.material = _additive_material()
	_stage.add_child(glow)
	return glow


func _flicker(glow: Sprite2D) -> void:
	var tween := create_tween().set_loops()
	for step in FLICKER_STEPS:
		tween.tween_property(glow, "modulate:a", step.x, step.y)


func _build_runner() -> void:
	var runner := Sprite2D.new()
	runner.texture = RUG
	runner.scale = Vector2(3.6, 0.7)
	runner.position = Vector2(640, WALKER_FEET_Y - 14)
	runner.z_index = -10
	runner.modulate = Color(0.8, 0.75, 0.75)
	_stage.add_child(runner)


func _build_walker() -> void:
	var player := PLAYER_SCENE.instantiate()
	var frames := (player.get_node("AnimatedSprite2D") as AnimatedSprite2D).sprite_frames
	player.free()
	_walker = AnimatedSprite2D.new()
	_walker.sprite_frames = frames
	_walker.scale = Vector2.ONE * WALKER_SCALE
	_walker.position = Vector2(WALKER_START_X, WALKER_FEET_Y - 41.6)
	_walker.play("idle_side")
	_walker.frame_changed.connect(_on_walker_frame_changed)
	_stage.add_child(_walker)


func _on_walker_frame_changed() -> void:
	if _walker.animation == &"walk_side" and _walker.frame in STEP_FRAMES:
		AudioManager.play(SOUND_STEP)


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