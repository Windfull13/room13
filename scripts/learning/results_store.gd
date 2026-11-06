class_name ResultsStore
extends RefCounted

## Guarda un JSON por participante en user://resultados/<id>.json. No conoce el
## juego: recibe un diccionario ya construido. Si no se puede escribir, devuelve
## false y no imprime errores.

const DEFAULT_DIRECTORY := "user://resultados/"
const ID_LENGTH := 8
const HEX_DIGITS := "0123456789abcdef"
const JSON_INDENT := "\t"

var directory: String


func _init(target_directory: String = DEFAULT_DIRECTORY) -> void:
	directory = target_directory if target_directory.ends_with("/") else target_directory + "/"


## Un identificador anónimo válido son 8 caracteres hexadecimales.
static func is_valid_id(participant_id: String) -> bool:
	if participant_id.length() != ID_LENGTH:
		return false
	for character in participant_id:
		if not HEX_DIGITS.contains(character):
			return false
	return true


static func new_id(rng: RandomNumberGenerator) -> String:
	return "%08x" % rng.randi()


func path_for(participant_id: String) -> String:
	return directory + participant_id + ".json"


func global_directory() -> String:
	return ProjectSettings.globalize_path(directory)


## Crea la carpeta si hace falta. Falla sin ruido si algún tramo de la ruta es un archivo.
func ensure_directory() -> bool:
	if DirAccess.dir_exists_absolute(directory):
		return true
	if _path_crosses_a_file():
		return false
	return DirAccess.make_dir_recursive_absolute(directory) == OK


func save(record: Dictionary) -> bool:
	var participant_id := String(record.get("participant_id", ""))
	if not is_valid_id(participant_id) or not ensure_directory():
		return false
	var file := FileAccess.open(path_for(participant_id), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(record, JSON_INDENT))
	file.close()
	return true


func load_record(participant_id: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path_for(participant_id)))
	return parsed if parsed is Dictionary else {}


func _path_crosses_a_file() -> bool:
	var parts := directory.trim_suffix("/").split("/")
	var prefix := ""
	for part in parts:
		prefix += part + "/"
		if FileAccess.file_exists(prefix.trim_suffix("/")):
			return true
	return false
