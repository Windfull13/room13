extends RefCounted

## Coherencia del contenido: rondas, catálogo, nodos objetivo y sustos.

const Reporter := preload("res://tests/reporter.gd")
const ROOM_BASE := "res://scenes/rooms/room_base.tscn"
const EXPECTED_ROOMS := 11
const EXPECTED_DECISIONS := 10
const EXPECTED_ANOMALIES := 36
const EXPECTED_JUMPSCARES := ["cuervo_en_el_marco", "figura_armario", "figura_cama", "figura_en_el_espejo", "figura_ventana", "oscuridad_total", "testigo_cuarto", "testigo_esquina", "tres_senales"]
const DANGEROUS_WITHOUT_JUMPSCARE: Array[String] = []


func run(report: Reporter, tree: SceneTree) -> void:
	report.start("Integridad de datos")
	var rooms: Array[RoomData] = []
	rooms.assign(CatalogLoader.load_all("res://resources/rooms/", RoomData))
	var catalog: Array[AnomalyData] = []
	catalog.assign(CatalogLoader.load_all("res://resources/anomalies/", AnomalyData))
	_check_export_listing(report)
	_check_rooms(report, rooms)
	_check_catalog(report, catalog)
	await _check_targets(report, tree, catalog)
	_check_jumpscares(report, catalog)


func _check_rooms(report: Reporter, rooms: Array[RoomData]) -> void:
	report.check(rooms.size() == EXPECTED_ROOMS, "hay %d rondas (encontradas %d)" % [EXPECTED_ROOMS, rooms.size()])
	var references := 0
	var decisions := 0
	var wrong_scene := 0
	var orders: Array[int] = []
	for room in rooms:
		if room.is_reference:
			references += 1
		else:
			decisions += 1
		if room.scene_path != ROOM_BASE:
			wrong_scene += 1
		orders.append(room.order)
	report.check(references == 1, "hay 1 habitación de referencia (encontradas %d)" % references)
	report.check(decisions == EXPECTED_DECISIONS, "hay %d habitaciones de decisión (encontradas %d)" % [EXPECTED_DECISIONS, decisions])
	report.check(wrong_scene == 0, "todas las rondas usan room_base.tscn (%d no lo hacen)" % wrong_scene)
	orders.sort()
	var consecutive := orders.size() == EXPECTED_ROOMS
	for i in range(orders.size()):
		if orders[i] != i:
			consecutive = false
	report.check(consecutive, "los órdenes van de 0 a %d sin huecos: %s" % [EXPECTED_ROOMS - 1, str(orders)])


func _check_catalog(report: Reporter, catalog: Array[AnomalyData]) -> void:
	report.check(catalog.size() == EXPECTED_ANOMALIES, "hay %d anomalías (encontradas %d)" % [EXPECTED_ANOMALIES, catalog.size()])
	var dangerous := 0
	var duplicated := 0
	var seen := {}
	for anomaly in catalog:
		if anomaly.is_dangerous:
			dangerous += 1
		if seen.has(anomaly.id):
			duplicated += 1
		seen[anomaly.id] = true
	report.check(dangerous * 2 < catalog.size(), "menos de la mitad son peligrosas (%d de %d)" % [dangerous, catalog.size()])
	report.check(duplicated == 0, "no hay identificadores repetidos (%d repetidos)" % duplicated)


func _check_targets(report: Reporter, tree: SceneTree, catalog: Array[AnomalyData]) -> void:
	var room := (load(ROOM_BASE) as PackedScene).instantiate() as Room
	tree.root.add_child(room)
	await tree.process_frame
	var world := room.get_node("World")
	var missing: Array[String] = []
	var incompatible: Array[String] = []
	for anomaly in catalog:
		for modification in anomaly.modifications:
			if modification is AnomalyModification:
				var target: String = (modification as AnomalyModification).target_node
				if world.get_node_or_null(NodePath(target)) == null:
					missing.append("%s -> %s" % [anomaly.id, target])
		if not room.can_apply(anomaly):
			incompatible.append(anomaly.id)
	report.check(missing.is_empty(), "todos los target_node existen en room_base: %s" % str(missing))
	report.check(incompatible.is_empty(), "las %d anomalías se pueden aplicar en room_base: %s" % [catalog.size(), str(incompatible)])
	room.free()


func _check_jumpscares(report: Reporter, catalog: Array[AnomalyData]) -> void:
	var with_jumpscare: Array[String] = []
	var scene_paths: Array[String] = []
	var dangerous_without: Array[String] = []
	var safe_with := 0
	for anomaly in catalog:
		if anomaly.jumpscare_scene == null:
			if anomaly.is_dangerous:
				dangerous_without.append(anomaly.id)
			continue
		with_jumpscare.append(anomaly.id)
		scene_paths.append(anomaly.jumpscare_scene.resource_path)
		if not anomaly.is_dangerous:
			safe_with += 1
	with_jumpscare.sort()
	report.check(with_jumpscare == EXPECTED_JUMPSCARES, "los sustos son exactamente los de las nueve peligrosas: %s" % str(with_jumpscare))
	report.check(_unique(scene_paths).size() == scene_paths.size(), "ninguna anomalía comparte escena de susto")
	report.check(safe_with == 0, "ninguna anomalía inofensiva tiene susto (%d la tienen)" % safe_with)
	report.check(dangerous_without == DANGEROUS_WITHOUT_JUMPSCARE, "no queda ninguna peligrosa sin susto: %s" % str(dangerous_without))


func _unique(values: Array[String]) -> Array[String]:
	var unique: Array[String] = []
	for value in values:
		if not unique.has(value):
			unique.append(value)
	return unique

## En un proyecto exportado DirAccess lista «x.tres.remap»: se deben cargar igual.
func _check_export_listing(report: Reporter) -> void:
	var listed := PackedStringArray(["b.tres.remap", "a.tres", "c.tres.import", "a.tres.remap", "readme.txt", "d.gd"])
	var names := CatalogLoader.resource_names(listed)
	report.check(names == ["a.tres", "b.tres", "c.tres"], "CatalogLoader entiende el listado de un proyecto exportado (.remap, duplicados): %s" % str(names))
