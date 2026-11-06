class_name CorridorMemory
extends Resource

## Un recuerdo del pasillo: la viñeta enmarcada y su pie de dos líneas que se
## ven en el pasillo que lleva a la ronda `round_number`.

@export var round_number: int = 0
@export var title: String = ""
@export var vignette_scene: PackedScene
@export var caption_lines: PackedStringArray = []


func caption() -> String:
	return "\n".join(caption_lines)
