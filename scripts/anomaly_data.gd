class_name AnomalyData
extends Resource

## Descripción de una anomalía concreta.
##
## Una anomalía modifica objetos reales de la habitación (girar la silla,
## cambiar el reloj, mostrar una figura en la ventana...) mediante una lista de
## modificaciones y, opcionalmente, añade una criatura al escenario.

enum Difficulty { EASY, MEDIUM, HARD }
enum Topic {
	INFANCIA, ACOSO, AISLAMIENTO, AUTOESTIMA, CULPA, DUELO, FAMILIA, RECUERDOS,
	RELACIONES, AUTOCUIDADO, AGOTAMIENTO, ESPERANZA, PERCEPCION, IDENTIDAD, MIEDO, ACEPTACION,
}

## Claves válidas de `focus_object`. «varios» nunca cuenta como repetición.
const FOCUS_ANY := "varios"
const FOCUS_OBJECTS: Array[String] = [
	"alfombra", "espejo", "foto", "retrato", "lampara", "peluche", "reloj", "silla",
	"telefono", "luz", "arana", "carta", "dibujo", "llaves", "ventana", "puerta",
	"muneca", "planta", "escritorio", "cama", "armario", "testigo", FOCUS_ANY,
]
const MAX_MEANING_LENGTH := 90

## Identificador único y estable.
@export var id: String = ""
## Nombre legible.
@export var display_name: String = ""
## Descripción interna de qué cambia respecto a la referencia.
@export_multiline var description: String = ""
## Significado breve (≤ 90 caracteres). Se muestra al acertar la anomalía.
@export_multiline var meaning: String = ""
## Objeto de la habitación sobre el que actúa (uno de FOCUS_OBJECTS).
@export var focus_object: String = FOCUS_ANY
@export var difficulty: Difficulty = Difficulty.EASY
@export var theme: Topic = Topic.INFANCIA
## La pista observable: qué debe notar el jugador.
@export var tell: String = ""

## Si es peligrosa, ignorarla (responder «NO HAY ANOMALÍA») es letal.
@export var is_dangerous: bool = false

## Modificaciones aplicadas a los objetos de la habitación.
## (Array sin tipar para garantizar la serialización en .tres; cada elemento
## debe ser un AnomalyModification.)
@export var modifications: Array = []

## Criatura que aparece con esta anomalía (opcional).
@export var monster_scene: PackedScene = null
## Índice del punto de aparición de la criatura dentro de la habitación
## ("MonsterSpawn1", "MonsterSpawn2"...). Así la misma anomalía funciona en
## cualquier habitación sin conocer sus coordenadas.
@export var monster_spawn_index: int = 1

## Susto que se reproduce si esta anomalía mata al jugador (null = sin susto).
@export var jumpscare_scene: PackedScene = null

## Efecto que la entidad produce sobre la habitación (clave de
## EntityAmbience.EFFECTS; vacío = ninguno).
@export var ambience: String = ""