class_name RoomData
extends Resource

## Datos de una ronda: la habitación de referencia o una de las diez
## habitaciones de decisión.
##
## NO define qué anomalía aparece. Cada habitación es un escenario reutilizable
## y el sistema de selección elige en tiempo de ejecución, del catálogo común,
## una anomalía compatible con esa habitación (o ninguna).

## Identificador único y estable.
@export var id: String = ""
## Nombre legible de la habitación (identidad propia: dormitorio, cocina...).
@export var display_name: String = ""
## Orden dentro de la secuencia de la partida (menor primero).
@export var order: int = 0
## Si es la habitación de referencia: normal, sin botones de decisión.
@export var is_reference: bool = false
## Escena de la habitación que se instancia al entrar en la ronda.
@export var scene_path: String = ""
## Pista narrativa de la ronda.
@export_multiline var narrative_clue: String = ""