extends RefCounted

## Las seis combinaciones posibles de AnswerEvaluator.

const Reporter := preload("res://tests/reporter.gd")


func run(report: Reporter, _tree: SceneTree) -> void:
	report.start("AnswerEvaluator: seis combinaciones")
	var answer := AnswerEvaluator.Answer
	var verdict := AnswerEvaluator.Verdict
	report.check(AnswerEvaluator.evaluate(false, false, answer.NO_ANOMALY) == verdict.CORRECT, "habitación normal + NO HAY = CORRECTO")
	report.check(AnswerEvaluator.evaluate(false, false, answer.ANOMALY) == verdict.INCORRECT, "habitación normal + HAY = INCORRECTO")
	report.check(AnswerEvaluator.evaluate(true, false, answer.ANOMALY) == verdict.CORRECT, "anomalía inofensiva + HAY = CORRECTO")
	report.check(AnswerEvaluator.evaluate(true, false, answer.NO_ANOMALY) == verdict.INCORRECT, "anomalía inofensiva + NO HAY = INCORRECTO")
	report.check(AnswerEvaluator.evaluate(true, true, answer.ANOMALY) == verdict.CORRECT, "anomalía peligrosa + HAY = CORRECTO")
	report.check(AnswerEvaluator.evaluate(true, true, answer.NO_ANOMALY) == verdict.DEATH, "anomalía peligrosa + NO HAY = MUERTE")