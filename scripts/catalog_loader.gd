class_name CatalogLoader
extends RefCounted

## Carga de recursos por carpeta.
##
## Unifica la lectura de las rondas y del catálogo de anomalías, que antes
## repetían el mismo bucle de ficheros con pequeñas diferencias.


## Devuelve, ordenados por nombre, los recursos .tres del directorio que sean
## instancias del tipo pedido (por ejemplo RoomData o AnomalyData).
static func load_all(directory: String, required_type: Variant) -> Array:
	var found: Array = []
	var dir := DirAccess.open(directory)
	if dir == null:
		push_error("No se pudo abrir la carpeta de recursos: %s" % directory)
		return found
	var file_names := dir.get_files()
	file_names.sort()
	for file_name in file_names:
		if not file_name.ends_with(".tres"):
			continue
		var resource = load(directory + file_name)
		if is_instance_of(resource, required_type):
			found.append(resource)
	return found