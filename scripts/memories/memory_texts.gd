class_name MemoryTexts
extends Resource

## Recuerdos del pasillo y textos de la cinemática final, en
## resources/learning/memory_texts.tres para editarlos sin tocar código.

const TEXTS_PATH := "res://resources/learning/memory_texts.tres"

@export_group("Pasillo")
## Lista de CorridorMemory (Array[Resource] por lo mismo que en ObjectMemoryCatalog).
@export var corridor_memories: Array[Resource] = []

@export_group("Cinemática «La última puerta»")
@export_multiline var cinematic_warning: String = ""
@export var cinematic_skip_hint: String = ""
## Una línea por fragmento de recuerdo (aparecen en orden).
@export var cinematic_fragment_lines: PackedStringArray = []
@export var cinematic_final_lines: PackedStringArray = []
@export var cinematic_wife_voice: String = ""
@export var cinematic_wife_line: String = ""
@export var cinematic_girl_voice: String = ""
@export var cinematic_girl_line: String = ""


## Cargado por ResourceLoader (que ya lo cachea mientras alguien lo use).
static func default() -> MemoryTexts:
	return load(TEXTS_PATH) as MemoryTexts


## El recuerdo del pasillo que lleva a la ronda de decisión `round_number`, o null.
func corridor_memory_for(round_number: int) -> CorridorMemory:
	for entry in corridor_memories:
		var memory := entry as CorridorMemory
		if memory != null and memory.round_number == round_number:
			return memory
	return null
