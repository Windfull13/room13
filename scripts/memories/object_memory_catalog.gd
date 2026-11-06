class_name ObjectMemoryCatalog
extends Resource

## Los recuerdos de objeto y los textos que los acompañan, en un único .tres
## (resources/learning/object_memories.tres) para poder editarlos sin código.

const CATALOG_PATH := "res://resources/learning/object_memories.tres"

@export var panel_title: String = ""
@export var notice_text: String = ""
@export var prompt_verb: String = ""
## Lista de ObjectMemory. Se declara como Array[Resource]: un Array tipado con la
## clase del propio juego deja referencias colgadas al cerrar Godot.
@export var entries: Array[Resource] = []


## Cargado por ResourceLoader (que ya lo cachea mientras alguien lo use).
static func default() -> ObjectMemoryCatalog:
	return load(CATALOG_PATH) as ObjectMemoryCatalog


## El recuerdo de una anomalía, o null si no tiene.
func for_anomaly(anomaly_id: String) -> ObjectMemory:
	for entry in entries:
		var memory := entry as ObjectMemory
		if memory != null and memory.anomaly_id == anomaly_id:
			return memory
	return null


func count() -> int:
	return entries.size()
