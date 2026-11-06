extends Node2D

## Herramienta interna de desarrollo.
##
## Aplica una o varias anomalías del catálogo sobre la habitación base para
## poder verlas en pantalla sin recorrer la partida. No forma parte del juego.

## Identificadores de anomalía separados por comas.
@export var anomaly_ids: String = "figura_ventana"
## Muestra la puerta como queda tras acertar.
@export var door_open: bool = false

func _ready() -> void:
	var room := $RoomBase as Room
	if door_open:
		room.unlock_door()
	for raw in anomaly_ids.split(",", false):
		var id := raw.strip_edges()
		if id.is_empty():
			continue
		var path := "res://resources/anomalies/%s.tres" % id
		if not ResourceLoader.exists(path):
			print("no existe: ", id)
			continue
		room.apply_anomaly(load(path) as AnomalyData)
		print("aplicada: ", id)