class_name TriviaQuestion
extends Resource

## Una pregunta de la trivia. La opción correcta se guarda siempre por su índice
## en `options`; al mostrarla se barajan las opciones, pero las respuestas se
## registran con el índice original.

@export var id: String = ""
@export var topic: String = ""
@export_multiline var text: String = ""
@export var options: PackedStringArray = []
@export var correct_index: int = 0
@export_multiline var explanation: String = ""


func correct_option() -> String:
	return options[correct_index]
