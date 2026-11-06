class_name RunState
extends RefCounted

## Marcador de la partida en curso: por dónde va, cuántas rondas ha acertado y
## qué anomalías han salido ya. No conoce nodos ni interfaz.

## Índice de la ronda que se está jugando (0 = referencia, 1-10 = decisión).
var index: int = 0
## Decisiones acertadas desde el último reinicio.
var correct: int = 0
## Identificador de la anomalía mostrada en la ronda anterior ("" si no hubo).
var previous_anomaly_id: String = ""
## Anomalías que ya han salido en esta partida: no se repiten.
var used_ids: Array[String] = []
## Objeto y tema de la última ronda que tuvo anomalía (las normales no cuentan).
var last_focus_object: String = ""
var last_theme: int = -1


## Deja el marcador listo para una partida nueva.
func restart() -> void:
	index = 0
	correct = 0
	previous_anomaly_id = ""
	used_ids.clear()
	last_focus_object = ""
	last_theme = -1


## Anota lo que ha salido en una ronda (null = habitación normal).
func record(anomaly: AnomalyData) -> void:
	previous_anomaly_id = anomaly.id if anomaly != null else ""
	if anomaly == null:
		return
	used_ids.append(anomaly.id)
	last_focus_object = anomaly.focus_object
	last_theme = anomaly.theme
