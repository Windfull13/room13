extends RefCounted

## Bloques D y E1: documentación, evidencias, informe de pruebas generado y
## preset de exportación para Windows.

const Reporter := preload("res://tests/reporter.gd")
const ScreenCatalog := preload("res://dev/screen_catalog.gd")
const REQUIRED_DOCS: Array[String] = [
	"res://README.md", "res://CREDITS.md", "res://docs/arquitectura.md", "res://docs/manual_de_usuario.md",
	"res://docs/plan_de_pruebas_con_usuarios.md", "res://docs/aprendizaje_y_evaluacion.md",
	"res://docs/guion_de_voces.md", "res://docs/audio_inventario.md", "res://docs/progreso_fase5.md",
	"res://docs/informe_de_pruebas.md", "res://docs/evidencias/README.md", "res://docs/cumplimiento_rubrica.md",
]
const README_MUST: Array[String] = ["Requisitos", "Ejecutar", "Exportar", "Controles", "Estructura", "Pruebas", "run_tests.gd"]
const REPORT := "res://docs/informe_de_pruebas.md"
const EVIDENCE_DIR := "res://docs/evidencias/"
const PRESETS := "res://export_presets.cfg"
const EXCLUDED: Array[String] = ["dev/*", "tests/*", "legacy/*", "docs/*", "resources/legacy_*/*"]

var _report: Reporter


func run(report: Reporter, _tree: SceneTree) -> void:
	report.start("Documentación, evidencias e informe de pruebas, exportación")
	_report = report
	_check_docs_exist()
	_check_readme_and_credits()
	_check_architecture()
	_check_test_report()
	_check_evidence()
	_check_export_preset()


func _check_docs_exist() -> void:
	var missing: Array[String] = []
	for path in REQUIRED_DOCS:
		if FileAccess.get_file_as_string(path).strip_edges().is_empty():
			missing.append(path)
	_report.check(missing.is_empty(), "existen (y no están vacíos) todos los documentos pedidos %s" % str(missing))


func _check_readme_and_credits() -> void:
	var readme := FileAccess.get_file_as_string("res://README.md")
	for section in README_MUST:
		_report.check(readme.contains(section), "README.md trata «%s»" % section)
	var credits := FileAccess.get_file_as_string("res://CREDITS.md")
	_report.check(credits.contains("Integrantes del equipo") and credits.contains("Open Font License") and credits.contains("CC0") and credits.contains("Voces (pendientes"), "CREDITS.md tiene el campo del equipo, fuentes y licencias, audio y voces pendientes")


func _check_architecture() -> void:
	var text := FileAccess.get_file_as_string("res://docs/arquitectura.md")
	for topic in ["mermaid", "AnomalySelector", "EntityAmbience", "AudioManager", "Session", "ResultsStore", "SOLID", "MemorySpot"]:
		_report.check(text.contains(topic), "docs/arquitectura.md cubre «%s»" % topic)


## El informe lo escribe el runner: su total debe ser la suma de sus suites.
func _check_test_report() -> void:
	var text := FileAccess.get_file_as_string(REPORT)
	_report.check(text.contains("Generado automáticamente por `tests/run_tests.gd --report`") and text.contains("**Fecha:**") and text.contains("**Duración:**"), "docs/informe_de_pruebas.md lo generó el runner (fecha, duración)")
	var passed := 0
	var failed := 0
	var suites := 0
	for line in text.split("\n"):
		if line.begins_with("| `test_"):
			var cells := line.split("|")
			passed += cells[2].strip_edges().to_int()
			failed += cells[3].strip_edges().to_int()
			suites += 1
	var stated := "**Comprobaciones:** %d correctas, %d fallidas" % [passed, failed]
	_report.check(suites >= 1 and text.contains(stated), "el total del informe (de la ejecución anterior) es la suma real de sus %d suites (%d correctas)" % [suites, passed])


func _check_evidence() -> void:
	var index := FileAccess.get_file_as_string(EVIDENCE_DIR + "README.md")
	var missing: Array[String] = []
	var wrong_size: Array[String] = []
	for screen in ScreenCatalog.SCREENS:
		var path := EVIDENCE_DIR + screen + ".png"
		if not FileAccess.file_exists(path) or not index.contains(screen + ".png"):
			missing.append(screen)
			continue
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		if image == null or image.get_size() != ScreenCatalog.BASE_SIZE:
			wrong_size.append(screen)
	_report.check(missing.is_empty(), "docs/evidencias tiene una captura por pantalla e índice (%d) %s" % [ScreenCatalog.SCREENS.size(), str(missing)])
	_report.check(wrong_size.is_empty(), "las capturas principales son de 1280×720 %s" % str(wrong_size))
	var other_resolutions := 0
	for resolution in ScreenCatalog.RESOLUTIONS:
		if resolution != ScreenCatalog.BASE_SIZE:
			for screen in ScreenCatalog.SCREENS:
				if FileAccess.file_exists("%sresoluciones/%dx%d/%s.png" % [EVIDENCE_DIR, resolution.x, resolution.y, screen]):
					other_resolutions += 1
	_report.check(other_resolutions == ScreenCatalog.SCREENS.size() * 3, "también hay capturas a 1920×1080, 1366×768 y 1600×900 (%d)" % other_resolutions)
	var rows := 0
	var ok_rows := 0
	for line in index.split("\n"):
		if line.begins_with("| ") and line.contains(".png"):
			rows += 1
			ok_rows += 1 if line.ends_with("| ok |") else 0
	_report.check(rows == ScreenCatalog.SCREENS.size() * ScreenCatalog.RESOLUTIONS.size() and ok_rows == rows, "el índice registra las %d capturas y todas pasan la maquetación (%d ok)" % [rows, ok_rows])


func _check_export_preset() -> void:
	var config := ConfigFile.new()
	_report.check(config.load(PRESETS) == OK, "existe export_presets.cfg")
	_report.check(config.get_value("preset.0", "platform", "") == "Windows Desktop" and config.get_value("preset.0.options", "binary_format/architecture", "") == "x86_64", "el preset es Windows Desktop x86_64")
	_report.check(String(config.get_value("preset.0", "export_path", "")).get_file() == "La Habitacion 13.exe", "el ejecutable se llama «La Habitacion 13»")
	_report.check(String(config.get_value("preset.0", "include_filter", "")).contains("*.md"), "incluye *.md (CREDITS.md lo lee el menú)")
	var exclude := String(config.get_value("preset.0", "exclude_filter", ""))
	var absent: Array[String] = []
	for pattern in EXCLUDED:
		if not exclude.contains(pattern):
			absent.append(pattern)
	_report.check(absent.is_empty(), "excluye dev, tests, legacy, docs y resources/legacy_* %s" % str(absent))
	_report.check(ProjectSettings.get_setting("application/config/version") == "1.0.0", "la versión del juego es 1.0.0")
