extends SceneTree

## Genera docs/catalogo_anomalias.md a partir de los .tres del catálogo.
##
##   godot --headless --path . --script res://dev/export_catalog.gd

const ANOMALY_DIR := "res://resources/anomalies/"
const OUTPUT := "res://docs/catalogo_anomalias.md"
const REPORT_SCRIPT := "res://dev/anomaly_report.gd"
const HEADER := "| id | nombre | objeto | tema | dificultad | peligrosa | pista | significado | efecto o sonido |"
const SEPARATOR := "|---|---|---|---|---|---|---|---|---|"


func _init() -> void:
	# Los autoloads existen a partir del primer fotograma.
	await process_frame
	var report: GDScript = load(REPORT_SCRIPT)
	var catalog: Array[AnomalyData] = []
	catalog.assign(CatalogLoader.load_all(ANOMALY_DIR, AnomalyData))
	var lines: Array[String] = _header(catalog.size())
	for anomaly in report.sorted(catalog):
		lines.append(_row(anomaly, report))
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	file.close()
	print("catálogo exportado: %d anomalías en %s" % [catalog.size(), OUTPUT])
	quit()


func _header(total: int) -> Array[String]:
	return [
		"# Catálogo de anomalías",
		"",
		"Generado por `dev/export_catalog.gd` a partir de `resources/anomalies/*.tres`. No editar a mano.",
		"",
		"%d anomalías, ordenadas por dificultad." % total,
		"",
		HEADER,
		SEPARATOR,
	]


func _row(anomaly: AnomalyData, report: GDScript) -> String:
	var cells: Array[String] = [
		"`%s`" % anomaly.id,
		anomaly.display_name,
		anomaly.focus_object,
		report.topic_name(anomaly),
		report.difficulty_name(anomaly),
		"sí" if anomaly.is_dangerous else "no",
		anomaly.tell,
		anomaly.meaning,
		report.effect_text(anomaly),
	]
	return "| " + " | ".join(cells) + " |"
