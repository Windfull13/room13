extends SceneTree

## Runner mínimo de pruebas, en modo headless:
##
##   godot --headless --path . --script res://tests/run_tests.gd [--report] [--only=texto]
##
## Ejecuta todas las suites tests/test_*.gd y sale con código 1 si alguna
## comprobación falla, para que sirva en cualquier cadena de integración.
## Con --report escribe docs/informe_de_pruebas.md con las cifras reales de esta
## ejecución (fecha, comprobaciones por suite, total, duración y resultado).
## Con --only=texto solo se ejecutan las suites cuyo nombre lo contiene.

const TESTS_DIR := "res://tests/"
const REPORT_PATH := "res://docs/informe_de_pruebas.md"
const REPORT_FLAG := "--report"
const ONLY_PREFIX := "--only="
const NEWLINE := "\n"
const Reporter := preload("res://tests/reporter.gd")

var _suite_rows: Array[Dictionary] = []


func _init() -> void:
	# Los autoloads (AudioManager) se registran tras _init: hasta el primer
	# fotograma, cualquier script que los use fallaría al compilar.
	await process_frame
	var started := Time.get_ticks_msec()
	var reporter := Reporter.new()
	for path in _suite_paths():
		await _run_suite(path, reporter)
	await root.get_node("AudioManager").release_all()
	var seconds := (Time.get_ticks_msec() - started) / 1000.0
	print("=== %d comprobaciones correctas, %d fallidas ===" % [reporter.passed, reporter.failed])
	if reporter.failed > 0:
		print("FALLOS:")
		for failure in reporter.failures:
			print("  - ", failure)
	if _wants_report():
		_write_report(reporter, seconds)
	quit(1 if reporter.failed > 0 else 0)


func _run_suite(path: String, reporter: Reporter) -> void:
	var passed_before := reporter.passed
	var failed_before := reporter.failed
	var started := Time.get_ticks_msec()
	var script := load(path) as GDScript
	if script == null or not script.can_instantiate():
		reporter.check(false, "la suite %s compila" % path.get_file())
	else:
		await script.new().run(reporter, self)
	_suite_rows.append({
		"suite": path.get_file(),
		"passed": reporter.passed - passed_before,
		"failed": reporter.failed - failed_before,
		"seconds": (Time.get_ticks_msec() - started) / 1000.0,
	})


func _matches_filter(file_name: String) -> bool:
	var only := _only_filter()
	return only.is_empty() or file_name.contains(only)


func _only_filter() -> String:
	for argument in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if argument.begins_with(ONLY_PREFIX):
			return argument.trim_prefix(ONLY_PREFIX)
	return ""


func _wants_report() -> bool:
	return OS.get_cmdline_args().has(REPORT_FLAG) or OS.get_cmdline_user_args().has(REPORT_FLAG)


func _write_report(reporter: Reporter, seconds: float) -> void:
	var lines: Array[String] = [
		"# Informe de pruebas — La Habitación 13", "",
		"Generado automáticamente por `tests/run_tests.gd --report`. No editar a mano.", "",
		"- **Fecha:** %s" % Time.get_datetime_string_from_system(false, true),
		"- **Godot:** %s" % Engine.get_version_info()["string"],
		"- **Versión del juego:** %s" % ProjectSettings.get_setting("application/config/version", "?"),
		"- **Comprobaciones:** %d correctas, %d fallidas (total %d)" % [reporter.passed, reporter.failed, reporter.passed + reporter.failed],
		"- **Duración:** %.1f s" % seconds,
		"- **Resultado:** %s" % ("APROBADO" if reporter.failed == 0 else "CON FALLOS"), "",
		"| Suite | Correctas | Fallidas | Duración |", "|---|---|---|---|",
	]
	for row in _suite_rows:
		lines.append("| `%s` | %d | %d | %.1f s |" % [row["suite"], row["passed"], row["failed"], row["seconds"]])
	if reporter.failed > 0:
		lines.append_array(["", "## Fallos", ""])
		for failure in reporter.failures:
			lines.append("- " + failure)
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("No se pudo escribir %s" % REPORT_PATH)
		return
	file.store_string(NEWLINE.join(lines) + NEWLINE)
	file.close()
	print("informe de pruebas: ", REPORT_PATH)


func _suite_paths() -> Array[String]:
	var paths: Array[String] = []
	var dir := DirAccess.open(TESTS_DIR)
	if dir == null:
		push_error("No se encontró la carpeta de pruebas: %s" % TESTS_DIR)
		return paths
	for file_name in dir.get_files():
		if file_name.begins_with("test_") and file_name.ends_with(".gd") and _matches_filter(file_name):
			paths.append(TESTS_DIR + file_name)
	paths.sort()
	return paths