extends Control

## Hoja de contacto: cada anomalía en su habitación normal y anómala, y la
## diferencia visible en la zona de su objeto. Necesita ventana (renderiza):
##
##   godot --path . res://dev/contact_sheet.tscn
##
## Escribe dev/out/anomaly_contact_sheet.png y dev/out/anomaly_contact_metrics.txt
## y sale sola. Con --headless no hay render y no sirve.

const AnomalyReport := preload("res://dev/anomaly_report.gd")
const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const ROOM_SCENE := preload("res://scenes/rooms/room_base.tscn")
const ANOMALY_DIR := "res://resources/anomalies/"
const OUT_DIR := "res://dev/out/"
const SHEET_PATH := OUT_DIR + "anomaly_contact_sheet.png"
const METRICS_PATH := OUT_DIR + "anomaly_contact_metrics.txt"
const PARTIAL_METRICS_PATH := OUT_DIR + "anomaly_contact_metrics_parcial.txt"
const VIEW_SIZE := Vector2i(860, 640)
const VIEW_CENTER := Vector2(640, 332)
const ZONE_MARGIN := 24.0
const CHANGE_THRESHOLD := 0.08
## Píxeles distintos que hacen falta para que un cambio se vea.
const MIN_CHANGED_STATIC := 40
const MIN_CHANGED_MOTION := 12
## Las pistas luminosas de las anomalías sonoras, medidas aparte (luz encendida frente a apagada).
const MIN_CHANGED_CUE := 60
const CUE_WAIT_SECONDS := 3.0
## Con la variable de entorno ZIVA_ONLY="id1,id2" se miden solo esas anomalías.
const ONLY_ENV := "ZIVA_ONLY"
const SETTLE_FRAMES := 4
const MOTION_START_SECONDS := 1.45
const MOTION_WATCH_SECONDS := 0.9
const COLUMNS := 6
const CELL_SIZE := Vector2(214, 150)
const THUMB_SIZE := Vector2(100, 100)
const MUTE_VOLUME := 0.0

var _viewport: SubViewport
var _room: Room
var _results: Array[Dictionary] = []


## Con ZIVA_ONLY solo se miden algunas: las cifras van a otro archivo y no hay hoja.
var _partial: bool = false


func _ready() -> void:
	AudioManager.set_master_volume(MUTE_VOLUME, false)
	_viewport = SubViewport.new()
	_viewport.size = VIEW_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	var camera := Camera2D.new()
	camera.position = VIEW_CENTER
	_viewport.add_child(camera)
	_run()


func _run() -> void:
	var catalog: Array[AnomalyData] = []
	catalog.assign(CatalogLoader.load_all(ANOMALY_DIR, AnomalyData))
	var only := OS.get_environment(ONLY_ENV).split(",", false)
	_partial = not only.is_empty()
	for anomaly in AnomalyReport.sorted(catalog):
		if only.is_empty() or only.has(anomaly.id):
			_results.append(await _measure(anomaly))
	await _write_outputs()
	get_tree().quit()


func _measure(anomaly: AnomalyData) -> Dictionary:
	_room = ROOM_SCENE.instantiate() as Room
	_viewport.add_child(_room)
	await _frames(SETTLE_FRAMES)
	var zone := _zone(anomaly).grow(ZONE_MARGIN).intersection(_view_rect())
	var normal := await _capture()
	_room.apply_anomaly(anomaly)
	await _frames(SETTLE_FRAMES)
	var needs_motion := anomaly.modifications.is_empty() and anomaly.monster_scene == null
	var best := await _capture()
	var changed := _changed_pixels(normal, best, zone)
	if needs_motion:
		changed = maxi(changed, await _watch_motion(normal, zone))
		best = await _capture()
	var minimum := MIN_CHANGED_MOTION if needs_motion else MIN_CHANGED_STATIC
	var cue_changed := await _measure_cue(zone)
	_room.queue_free()
	await _frames(1)
	return {"anomaly": anomaly, "zone": zone, "normal": normal, "after": best, "changed": changed, "minimum": minimum, "cue": cue_changed}


## Píxeles que cambia la pista luminosa por sí sola (-1 si la anomalía no tiene).
func _measure_cue(zone: Rect2) -> int:
	var ambience := _room.ambience()
	var deadline := Time.get_ticks_msec() + int(CUE_WAIT_SECONDS * 1000.0)
	while Time.get_ticks_msec() < deadline:
		var cue := ambience.cue_node()
		if cue != null and cue.modulate.a > 0.99:
			var lit := await _capture()
			cue.visible = false
			await _frames(1)
			var dark := await _capture()
			cue.visible = true
			return _changed_pixels(dark, lit, zone)
		await _frames(1)
	return -1


func _watch_motion(normal: Image, zone: Rect2) -> int:
	await get_tree().create_timer(MOTION_START_SECONDS).timeout
	var most := 0
	var deadline := Time.get_ticks_msec() + int(MOTION_WATCH_SECONDS * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await _frames(1)
		most = maxi(most, _changed_pixels(normal, await _capture(), zone))
	return most


func _capture() -> Image:
	await RenderingServer.frame_post_draw
	return _viewport.get_texture().get_image()


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame


func _view_rect() -> Rect2:
	return Rect2(VIEW_CENTER - Vector2(VIEW_SIZE) / 2.0, Vector2(VIEW_SIZE))


func _to_pixels(world_rect: Rect2) -> Rect2i:
	return Rect2i(world_rect.position - _view_rect().position, world_rect.size)


## Zona del objeto: lo que tocan sus modificaciones, la criatura o el objeto que vibra.
func _zone(anomaly: AnomalyData) -> Rect2:
	var rects: Array[Rect2] = []
	var world := _room.get_node("World")
	for modification: AnomalyModification in anomaly.modifications:
		if modification.target_node == "Darkness":
			return _view_rect()
		var node := world.get_node_or_null(NodePath(modification.target_node))
		if node != null:
			rects.append(_node_rect(node))
	var monster := _room.get_monster()
	if monster != null:
		rects.append(_node_rect(monster))
	var effect: Dictionary = EntityAmbience.EFFECTS.get(anomaly.ambience, {})
	if rects.is_empty() and effect.get("target", "") != "":
		rects.append(_node_rect(world.get_node(effect["target"])))
	if rects.is_empty():
		return _view_rect()
	var zone := rects[0]
	for rect in rects:
		zone = zone.merge(rect)
	return zone


func _node_rect(node: Node) -> Rect2:
	var sprites: Array[Node] = node.find_children("*", "Sprite2D", true, false)
	if node is Sprite2D:
		sprites.append(node)
	var rect := Rect2()
	var first := true
	for sprite_node in sprites:
		var sprite := sprite_node as Sprite2D
		var sprite_rect := sprite.get_global_transform() * sprite.get_rect()
		rect = sprite_rect if first else rect.merge(sprite_rect)
		first = false
	return rect


func _changed_pixels(before: Image, after: Image, zone: Rect2) -> int:
	var area := _to_pixels(zone)
	var changed := 0
	for y in range(maxi(area.position.y, 0), mini(area.end.y, before.get_height())):
		for x in range(maxi(area.position.x, 0), mini(area.end.x, before.get_width())):
			var a := before.get_pixel(x, y)
			var b := after.get_pixel(x, y)
			if maxf(maxf(absf(a.r - b.r), absf(a.g - b.g)), absf(a.b - b.b)) > CHANGE_THRESHOLD:
				changed += 1
	return changed


# ---------------------------------------------------------------------------
# Salida
# ---------------------------------------------------------------------------

func _write_outputs() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var lines: Array[String] = ["id | píxeles distintos | mínimo | zona | pista luminosa (mín. %d) | resultado" % MIN_CHANGED_CUE]
	for result in _results:
		var anomaly: AnomalyData = result["anomaly"]
		var cue: int = result["cue"]
		var passed: bool = result["changed"] >= result["minimum"] and (cue < 0 or cue >= MIN_CHANGED_CUE)
		lines.append("%s | %d | %d | %s | %s | %s" % [anomaly.id, result["changed"], result["minimum"], result["zone"], "-" if cue < 0 else str(cue), "ok" if passed else "POR DEBAJO"])
	var file := FileAccess.open(PARTIAL_METRICS_PATH if _partial else METRICS_PATH, FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	file.close()
	if not _partial:
		await _save_sheet()
	print("hoja de contacto: %s (%d anomalías)" % [SHEET_PATH, _results.size()])


func _save_sheet() -> void:
	var rows := ceili(float(_results.size()) / COLUMNS)
	var sheet := SubViewport.new()
	sheet.size = Vector2i(CELL_SIZE.x * COLUMNS, CELL_SIZE.y * rows)
	sheet.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sheet)
	var background := ColorRect.new()
	background.color = Color(0.04, 0.04, 0.05)
	background.size = Vector2(sheet.size)
	sheet.add_child(background)
	for i in range(_results.size()):
		sheet.add_child(_make_cell(_results[i], Vector2(i % COLUMNS, i / COLUMNS) * CELL_SIZE))
	await _frames(3)
	await RenderingServer.frame_post_draw
	sheet.get_texture().get_image().save_png(ProjectSettings.globalize_path(SHEET_PATH))


func _make_cell(result: Dictionary, origin: Vector2) -> Control:
	var anomaly: AnomalyData = result["anomaly"]
	var passed: bool = result["changed"] >= result["minimum"]
	var cell := Control.new()
	cell.position = origin
	var title := Label.new()
	title.theme = UiTheme.build()
	title.text = "%s  %d px" % [anomaly.id, result["changed"]]
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.85) if passed else Color(1.0, 0.4, 0.4))
	title.position = Vector2(4, 0)
	cell.add_child(title)
	cell.add_child(_thumb(result["normal"], result["zone"], Vector2(4, 26)))
	cell.add_child(_thumb(result["after"], result["zone"], Vector2(4 + THUMB_SIZE.x + 6, 26)))
	return cell


## Recorte de la zona, ampliado sin suavizar para mantener el píxel.
func _thumb(image: Image, zone: Rect2, position: Vector2) -> TextureRect:
	var area := _to_pixels(zone)
	var crop := image.get_region(area.intersection(Rect2i(Vector2i.ZERO, image.get_size())))
	var fit := minf(THUMB_SIZE.x / crop.get_width(), THUMB_SIZE.y / crop.get_height())
	crop.resize(maxi(int(crop.get_width() * fit), 1), maxi(int(crop.get_height() * fit), 1), Image.INTERPOLATE_NEAREST)
	var rect := TextureRect.new()
	rect.texture = ImageTexture.create_from_image(crop)
	rect.position = position
	rect.size = Vector2(crop.get_size())
	return rect
