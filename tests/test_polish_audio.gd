extends RefCounted

## Bloque C1: audio medido. Pico ≤ −3 dBFS, sin continua, sonoridad de cada
## categoría dentro de ±4 dB, bucles sin clic y todos los archivos del catálogo
## presentes. Las cifras las escribe dev/audio/build_audio.py tras decodificar
## cada archivo; aquí se comprueba que siguen siendo las de los archivos
## actuales (mismo tamaño) y se vuelven a medir los WAV leyendo sus muestras.

const Reporter := preload("res://tests/reporter.gd")
const SoundCatalog := preload("res://scripts/audio/sound_catalog.gd")
const METRICS := "res://dev/audio/audio_metrics.json"
const INVENTORY := "res://docs/audio_inventario.md"
const PEAK_CEILING_DB := -3.0
const DC_LIMIT := 0.001
const TOLERANCE_DB := 4.0
const SEAM_LIMIT := 1.5
const REMEASURE_TOLERANCE_DB := 0.3
const CATEGORIES: Array[String] = ["musica", "ambiente", "efectos", "sustos"]

var _report: Reporter
var _files: Array = []


func run(report: Reporter, _tree: SceneTree) -> void:
	report.start("Pulido C1: audio medido")
	_report = report
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(METRICS))
	_report.check(parsed is Dictionary and (parsed as Dictionary).has("files"), "existe dev/audio/audio_metrics.json con las medidas")
	if not parsed is Dictionary:
		return
	_files = parsed["files"]
	_check_catalog_files_exist()
	_check_metrics_are_current()
	_check_peaks_and_dc()
	_check_loudness_by_category()
	_check_loops()
	_check_wavs_independently()
	_check_inventory()


func _project_path(entry: Dictionary) -> String:
	return "res://" + String(entry["file"])


func _check_catalog_files_exist() -> void:
	var missing: Array[String] = []
	var unmeasured: Array[String] = []
	var measured := {}
	for entry in _files:
		measured[_project_path(entry)] = true
	for sound_name: String in SoundCatalog.SOUNDS:
		var path: String = SoundCatalog.SOUNDS[sound_name]["file"]
		if not FileAccess.file_exists(path):
			missing.append(path)
		elif not measured.has(path):
			unmeasured.append(path)
	_report.check(missing.is_empty(), "todos los archivos referenciados en SoundCatalog existen %s" % str(missing))
	_report.check(unmeasured.is_empty(), "todos están medidos %s" % str(unmeasured))


func _check_metrics_are_current() -> void:
	var stale: Array[String] = []
	for entry in _files:
		var file := FileAccess.open(_project_path(entry), FileAccess.READ)
		if file == null or file.get_length() != int(entry["bytes"]):
			stale.append(String(entry["name"]))
	_report.check(stale.is_empty(), "las medidas corresponden a los archivos actuales (mismo tamaño) %s" % str(stale))


func _check_peaks_and_dc() -> void:
	var loud: Array[String] = []
	var offset: Array[String] = []
	var highest := -INF
	for entry in _files:
		highest = maxf(highest, float(entry["peak_dbfs"]))
		if float(entry["peak_dbfs"]) > PEAK_CEILING_DB:
			loud.append("%s %.1f" % [entry["name"], entry["peak_dbfs"]])
		if absf(float(entry["dc"])) > DC_LIMIT:
			offset.append("%s %.4f" % [entry["name"], entry["dc"]])
	_report.check(loud.is_empty(), "ningún archivo supera −3 dBFS de pico (máximo %.1f dBFS) %s" % [highest, str(loud)])
	_report.check(offset.is_empty(), "ningún archivo tiene componente continua %s" % str(offset))


func _check_loudness_by_category() -> void:
	for category in CATEGORIES:
		var values: Array[float] = []
		for entry in _files:
			if entry["category"] == category:
				values.append(float(entry["loudness_db"]))
		var mean := 0.0
		for value in values:
			mean += value / values.size()
		var spread := 0.0
		for value in values:
			spread = maxf(spread, absf(value - mean))
		_report.check(values.size() > 0 and spread <= TOLERANCE_DB, "%s: %d archivos con sonoridad media %.1f dB y desviación máxima %.1f dB (≤ ±4)" % [category, values.size(), mean, spread])


func _check_loops() -> void:
	var clicks: Array[String] = []
	var loops := 0
	for entry in _files:
		if entry.has("seam"):
			loops += 1
			if float(entry["seam"]) > SEAM_LIMIT:
				clicks.append("%s %.2f" % [entry["name"], entry["seam"]])
	_report.check(loops >= 8 and clicks.is_empty(), "los %d bucles empalman sin clic (costura ≤ %.1f) %s" % [loops, SEAM_LIMIT, str(clicks)])


## Vuelve a medir pico y continua leyendo las muestras de cada WAV.
func _check_wavs_independently() -> void:
	var mismatched: Array[String] = []
	var checked := 0
	for entry in _files:
		var path := _project_path(entry)
		if not path.ends_with(".wav"):
			continue
		var wav := AudioStreamWAV.load_from_file(ProjectSettings.globalize_path(path))
		if wav == null or wav.format != AudioStreamWAV.FORMAT_16_BITS:
			mismatched.append(String(entry["name"]) + " (no legible)")
			continue
		var measured := _peak_and_dc(wav.data)
		checked += 1
		if absf(measured.x - float(entry["peak_dbfs"])) > REMEASURE_TOLERANCE_DB or absf(measured.y) > DC_LIMIT:
			mismatched.append("%s pico %.2f / %.2f dc %.4f" % [entry["name"], measured.x, entry["peak_dbfs"], measured.y])
	_report.check(checked > 20 and mismatched.is_empty(), "medidos de nuevo %d WAV desde sus muestras: coinciden pico y continua %s" % [checked, str(mismatched)])


func _peak_and_dc(data: PackedByteArray) -> Vector2:
	var peak := 0
	var total := 0.0
	var count := data.size() / 2
	for i in range(count):
		var value := data.decode_s16(i * 2)
		peak = maxi(peak, absi(value))
		total += value
	return Vector2(20.0 * log(maxf(peak / 32768.0, 1e-9)) / log(10.0), total / maxi(count, 1) / 32768.0)


func _check_inventory() -> void:
	var text := FileAccess.get_file_as_string(INVENTORY)
	var missing: Array[String] = []
	for entry in _files:
		if not text.contains(String(entry["file"])):
			missing.append(String(entry["name"]))
	_report.check(not text.is_empty() and missing.is_empty(), "docs/audio_inventario.md lista cada archivo con origen y categoría %s" % str(missing))
	_report.check(text.contains("CC0") and text.contains("Generado") and text.contains("Fácil de reemplazar"), "el inventario indica origen (CC0 o generado) y si es fácil de reemplazar")
