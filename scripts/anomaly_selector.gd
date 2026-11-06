class_name AnomalySelector
extends RefCounted

## Reglas de aparición de las anomalías, sin depender del escenario ni de la
## interfaz. El generador de azar se inyecta, así que puede probarse con una
## semilla fija sin abrir ninguna escena.
##
## Orden de decisión: ¿habitación normal? → dificultad según el tramo de la
## partida → anomalía sin repetir, de objeto y tema distintos a los de la última
## ronda con anomalía. Si eso no deja nada, se relajan las reglas por niveles.

## Probabilidad de que una habitación de decisión quede completamente normal.
const NORMAL_ROOM_CHANCE := 0.30
## Tramos de la partida (rondas de decisión de 1 a 10).
const EARLY_LAST_ROUND := 3
const MIDDLE_LAST_ROUND := 7
## En el tramo medio, parte de las rondas que son MEDIUM (el resto, EASY).
const MIDDLE_MEDIUM_SHARE := 0.70
## En el tramo final, parte de las rondas que son HARD (el resto, MEDIUM).
const LATE_HARD_SHARE := 0.50

## Cada nivel relaja una regla más que el anterior.
enum Relaxation { STRICT, ANY_THEME, ANY_FOCUS, ANY_DIFFICULTY, ALLOW_REPEATS }

## Nivel de relajación que hizo falta en la última elección (para diagnóstico).
var last_relaxation: int = Relaxation.STRICT

var _rng: RandomNumberGenerator


func _init(rng: RandomNumberGenerator) -> void:
	_rng = rng


## Elige la anomalía de la ronda de decisión `round_number`, o null si la
## habitación queda normal. `is_compatible` responde si una anomalía encaja en
## la habitación actual; `state` guarda lo que ya ha salido en la partida.
func pick(candidates: Array[AnomalyData], is_compatible: Callable, round_number: int, state: RunState) -> AnomalyData:
	if _rng.randf() < NORMAL_ROOM_CHANCE:
		return null
	return pick_anomaly(candidates, is_compatible, round_number, state)


## Como `pick`, pero sin la posibilidad de habitación normal: solo devuelve null
## si no hay ninguna anomalía compatible.
func pick_anomaly(candidates: Array[AnomalyData], is_compatible: Callable, round_number: int, state: RunState) -> AnomalyData:
	var compatible := _compatible(candidates, is_compatible)
	var difficulty := _roll_difficulty(round_number)
	for level in Relaxation.values():
		var pool := _pool(compatible, difficulty, state, level)
		if not pool.is_empty():
			last_relaxation = level
			return pool[_rng.randi() % pool.size()]
	return null


func _compatible(candidates: Array[AnomalyData], is_compatible: Callable) -> Array[AnomalyData]:
	var result: Array[AnomalyData] = []
	for anomaly in candidates:
		if is_compatible.call(anomaly):
			result.append(anomaly)
	return result


func _roll_difficulty(round_number: int) -> AnomalyData.Difficulty:
	if round_number <= EARLY_LAST_ROUND:
		return AnomalyData.Difficulty.EASY
	if round_number <= MIDDLE_LAST_ROUND:
		return AnomalyData.Difficulty.MEDIUM if _rng.randf() < MIDDLE_MEDIUM_SHARE else AnomalyData.Difficulty.EASY
	return AnomalyData.Difficulty.HARD if _rng.randf() < LATE_HARD_SHARE else AnomalyData.Difficulty.MEDIUM


func _pool(compatible: Array[AnomalyData], difficulty: AnomalyData.Difficulty, state: RunState, level: int) -> Array[AnomalyData]:
	var pool: Array[AnomalyData] = []
	for anomaly in compatible:
		if level < Relaxation.ALLOW_REPEATS and state.used_ids.has(anomaly.id):
			continue
		if level < Relaxation.ANY_THEME and anomaly.theme == state.last_theme:
			continue
		if level < Relaxation.ANY_FOCUS and _repeats_focus(anomaly, state):
			continue
		if level < Relaxation.ANY_DIFFICULTY and anomaly.difficulty != difficulty:
			continue
		pool.append(anomaly)
	return pool


## «varios» (y la falta de objeto previo) nunca cuentan como repetición.
func _repeats_focus(anomaly: AnomalyData, state: RunState) -> bool:
	if anomaly.focus_object == AnomalyData.FOCUS_ANY or state.last_focus_object in ["", AnomalyData.FOCUS_ANY]:
		return false
	return anomaly.focus_object == state.last_focus_object
