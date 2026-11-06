extends RefCounted

## Bloque C2: las 15 pantallas, a 1280×720, 1920×1080, 1366×768 y 1600×900.
## Ningún control visible queda fuera de la pantalla, solapado con otro ni con
## el texto recortado. Las capturas reales las hace dev/capture_evidence.gd.

const Reporter := preload("res://tests/reporter.gd")
const ScreenCatalog := preload("res://dev/screen_catalog.gd")

var _report: Reporter
var _tree: SceneTree


func run(report: Reporter, tree: SceneTree) -> void:
	report.start("Pulido C2: pantallas a 4 resoluciones sin solapes")
	_report = report
	_tree = tree
	var small_texts := {}
	for resolution in ScreenCatalog.RESOLUTIONS:
		for screen in ScreenCatalog.SCREENS:
			var viewport := ScreenCatalog.make_viewport(resolution)
			tree.root.add_child(viewport)
			var root := await ScreenCatalog.open(screen, viewport, tree)
			var problems: Array[String] = ["no se pudo abrir"]
			if root != null:
				problems = ScreenCatalog.layout_problems(root)
			_report.check(problems.is_empty(), "%s a %dx%d: sin controles fuera, solapados ni recortados %s" % [screen, resolution.x, resolution.y, str(problems)])
			for text in ScreenCatalog.small_long_texts(root) if root != null else []:
				small_texts[screen + ": " + text] = true
			ScreenCatalog.close(root)
			await tree.process_frame
			viewport.queue_free()
			AudioManager.stop_all()
			await tree.process_frame
	if not small_texts.is_empty():
		print("    aviso: textos largos con letra < 22 px: ", small_texts.keys())
	await tree.process_frame
	_report.check(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT) == 0, "montar y desmontar las 60 pantallas no deja nodos huérfanos")
