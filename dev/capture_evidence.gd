extends Node

## Capturas de evidencia de todas las pantallas (necesita ventana, no headless):
##
##   godot --path . res://dev/capture_evidence.tscn
##
## Escribe docs/evidencias/<pantalla>.png a 1280×720, las mismas a 1920×1080,
## 1366×768 y 1600×900 en docs/evidencias/resoluciones/<ancho>x<alto>/, y el
## índice docs/evidencias/README.md con la comprobación de maquetación de cada una.

const ScreenCatalog := preload("res://dev/screen_catalog.gd")
const OUT_DIR := "res://docs/evidencias/"
const RESOLUTION_DIR := OUT_DIR + "resoluciones/"
const INDEX_PATH := OUT_DIR + "README.md"
const SETTLE_FRAMES := 3

var _rows: Array[String] = []


func _ready() -> void:
	AudioManager.set_master_volume(0.0, false)
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for resolution in ScreenCatalog.RESOLUTIONS:
		for screen in ScreenCatalog.SCREENS:
			await _capture(screen, resolution)
	_write_index()
	print("evidencias: %d capturas en %s" % [_rows.size(), OUT_DIR])
	await AudioManager.release_all()
	get_tree().quit()


func _capture(screen: String, resolution: Vector2i) -> void:
	var viewport := ScreenCatalog.make_viewport(resolution)
	add_child(viewport)
	var root := await ScreenCatalog.open(screen, viewport, get_tree())
	for i in range(SETTLE_FRAMES):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := _path_for(screen, resolution)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	var problems: Array[String] = ["no se pudo abrir"]
	if root != null:
		problems = ScreenCatalog.layout_problems(root)
	_rows.append("| %s | %dx%d | `%s` | %s |" % [ScreenCatalog.TITLES[screen], resolution.x, resolution.y, path.trim_prefix(OUT_DIR), "ok" if problems.is_empty() else "; ".join(problems)])
	ScreenCatalog.close(root)
	await get_tree().process_frame
	viewport.queue_free()
	AudioManager.stop_all()
	await get_tree().process_frame


func _path_for(screen: String, resolution: Vector2i) -> String:
	if resolution == ScreenCatalog.BASE_SIZE:
		return OUT_DIR + screen + ".png"
	return "%s%dx%d/%s.png" % [RESOLUTION_DIR, resolution.x, resolution.y, screen]


func _write_index() -> void:
	var lines: Array[String] = [
		"# Evidencias visuales — La Habitación 13", "",
		"Generadas por `dev/capture_evidence.gd` (`godot --path . res://dev/capture_evidence.tscn`) el %s." % Time.get_datetime_string_from_system(false, true), "",
		"Cada pantalla se dibuja a la resolución indicada con el mismo estirado `canvas_items` del juego (1280×720 lógicos).",
		"La columna «Maquetación» es la comprobación por código: ningún control visible fuera de la pantalla, solapado ni con el texto recortado.", "",
		"| Pantalla | Resolución | Archivo | Maquetación |", "|---|---|---|---|",
	]
	lines.append_array(_rows)
	var file := FileAccess.open(INDEX_PATH, FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	file.close()
