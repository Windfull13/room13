class_name AnswerEvaluator
extends RefCounted

## Sistema de evaluación de respuestas.
##
## No analiza píxeles: recibe el estado real de la habitación (¿había anomalía?
## ¿era peligrosa?) y la respuesta del jugador. La anomalía se elige en tiempo
## de ejecución, así que se evalúa la que realmente se aplicó en esa visita.

## Respuesta que puede dar el jugador.
enum Answer {
	NO_ANOMALY, ## «NO HAY ANOMALÍA».
	ANOMALY,    ## «HAY UNA ANOMALÍA».
}

## Resultado de evaluar una respuesta.
enum Verdict {
	CORRECT,   ## La respuesta coincide con el estado real de la habitación.
	INCORRECT, ## La respuesta no coincide con el estado real de la habitación.
	DEATH,     ## Se ignoró una anomalía peligrosa: consecuencia letal.
}

## Evalúa la respuesta para el estado real de la habitación en esta visita.
static func evaluate(has_anomaly: bool, is_dangerous: bool, answer: Answer) -> Verdict:
	var player_claims_anomaly: bool = answer == Answer.ANOMALY

	if player_claims_anomaly == has_anomaly:
		return Verdict.CORRECT

	# Si había una anomalía peligrosa y el jugador afirmó que no había nada, la
	# consecuencia es letal. Reconocer la amenaza nunca es letal por sí mismo.
	if has_anomaly and is_dangerous and not player_claims_anomaly:
		return Verdict.DEATH

	return Verdict.INCORRECT