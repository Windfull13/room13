class_name UserSettings
extends RefCounted

## Lectura y escritura de user://settings.cfg (volumen, pantalla completa...).
## Si el archivo no se puede leer o escribir, devuelve el valor por defecto o
## false, sin errores: el juego sigue con lo que tenga en memoria.

const DEFAULT_PATH := "user://settings.cfg"

## Las pruebas lo apuntan a otro archivo para no tocar los ajustes reales.
static var path: String = DEFAULT_PATH


static func load_value(section: String, key: String, default_value: Variant) -> Variant:
	var config := ConfigFile.new()
	if not FileAccess.file_exists(path) or config.load(path) != OK:
		return default_value
	return config.get_value(section, key, default_value)


static func save_value(section: String, key: String, value: Variant) -> bool:
	if not _folder_is_writable():
		return false
	var config := ConfigFile.new()
	if FileAccess.file_exists(path):
		config.load(path)
	config.set_value(section, key, value)
	return config.save(path) == OK


## Una carpeta que no existe (o un archivo donde debería haber carpeta) no se puede escribir.
static func _folder_is_writable() -> bool:
	return DirAccess.dir_exists_absolute(path.get_base_dir())
