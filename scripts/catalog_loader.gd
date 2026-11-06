class_name CatalogLoader
extends RefCounted

## Carga de recursos por carpeta.
##
## Unifica la lectura de las rondas y del catálogo de anomalías, que antes
## repetían el mismo bucle de ficheros con pequeñas diferencias.


## En un proyecto exportado, DirAccess lista los recursos como «x.tres.remap»
## (o «x.tres.import»): se quita ese sufijo para poder cargarlos con su nombre
## original, y se descartan los duplicados y lo que no sea .tres.
static func resource_names(listed_files: PackedStringArray) -> Array[String]:
	var names: Array[String] = []
	for listed in listed_files:
		var name := listed.trim_suffix(".remap").trim_suffix(".import")
		if name.ends_with(".tres") and not names.has(name):
			names.append(name)
	names.sort()
	return names


## Devuelve, ordenados por nombre, los recursos .tres del directorio que sean
## instancias del tipo pedido (por ejemplo RoomData o AnomalyData).
static func load_all(directory: String, required_type: Variant) -> Array:
	var found: Array = []
	var dir := DirAccess.open(directory)
	if dir == null:
		push_error("No se pudo abrir la carpeta de recursos: %s" % directory)
		return found
	for file_name in resource_names(dir.get_files()):
		var resource = load(directory + file_name)
		if is_instance_of(resource, required_type):
			found.append(resource)
	return found