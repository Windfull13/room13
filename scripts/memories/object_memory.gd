class_name ObjectMemory
extends Resource

## Un recuerdo guardado en un objeto. Se ofrece solo tras ACERTAR su anomalía
## (que nunca es peligrosa) y se lee una sola vez.

@export var anomaly_id: String = ""
## Nodo del objeto, relativo a World (p. ej. "Phone" o "DeskGlass").
@export var object_node: String = ""
## Nombre del objeto en la indicación («E — Recordar Teléfono»).
@export var object_name: String = ""
@export_multiline var text: String = ""
## Voz opcional (AudioManager.play_voice). Vacía: solo texto.
@export var voice_id: String = ""
## Si el objeto no tiene un Interactable usable, se crea uno temporal aquí (coordenadas de la habitación).
@export var interact_position: Vector2 = Vector2.ZERO
