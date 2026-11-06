class_name Interactable
extends Area2D

## Objeto del escenario con el que el jugador puede interactuar al acercarse y
## pulsar E. Solo aporta datos: el GameManager decide qué hacer con el mensaje.

## Nombre visible del objeto.
@export var display_name: String = "Objeto"
## Verbo que se muestra en la indicación ("Examinar", "Abrir"...).
@export var prompt_verb: String = "Examinar"
## Texto que aparece al interactuar.
@export_multiline var message: String = ""
## Identificador de una acción especial ("" = solo mostrar el mensaje).
@export var action_id: String = ""
## Texto del botón de acción del mensaje (vacío = solo botón de cerrar).
@export var action_button_text: String = ""
## Entre varios al alcance gana el de mayor prioridad (un recuerdo disponible) y, a igualdad, el más cercano.
@export var pick_priority: int = 0

## ¿Está disponible esta interacción ahora mismo?
func is_active() -> bool:
	return monitoring and visible

## Devuelve los datos de la interacción.
func get_data() -> Dictionary:
	return {
		"name": display_name,
		"message": message,
		"action_id": action_id,
		"button_text": action_button_text,
	}