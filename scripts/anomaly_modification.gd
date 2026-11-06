class_name AnomalyModification
extends Resource

## Una única modificación aplicada a un objeto de la habitación para construir
## una anomalía. Las anomalías se describen como datos, no como excepciones
## dispersas por el código.

## Los nuevos modos se añaden al final para no alterar el valor numérico de los
## modos ya serializados en los recursos .tres existentes.
enum Mode {
	ROTATE,       ## Gira el nodo objetivo (rotation_degrees).
	SET_TEXTURE,  ## Cambia la textura del nodo objetivo (debe ser Sprite2D).
	SHOW,         ## Hace visible el nodo objetivo.
	HIDE,         ## Oculta el nodo objetivo.
	SET_POSITION, ## Coloca el nodo objetivo en una posición concreta.
	SET_MODULATE, ## Tiñe/oscurece el nodo objetivo (color y alfa).
	SET_SCALE,    ## Escala el nodo objetivo.
	SET_FLIP_H,   ## Voltea el nodo objetivo horizontalmente (debe ser Sprite2D).
	SET_COLLISION_DISABLED, ## Desactiva la colisión del nodo objetivo (CollisionShape2D).
}

@export var mode: Mode = Mode.SHOW
## Ruta del nodo objetivo relativa al contenedor "World" de la habitación.
@export var target_node: String = ""
## Ángulo para el modo ROTATE.
@export var rotation_degrees: float = 0.0
## Textura para el modo SET_TEXTURE.
@export var texture: Texture2D = null
## Posición para el modo SET_POSITION.
@export var position: Vector2 = Vector2.ZERO
## Color (incluida el alfa) para el modo SET_MODULATE.
@export var color: Color = Color(1, 1, 1, 1)
## Escala para el modo SET_SCALE.
@export var scale: Vector2 = Vector2.ONE
## Volteo horizontal para el modo SET_FLIP_H.
@export var flip: bool = false