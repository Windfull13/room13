extends RefCounted

## AnomalySelector con generador de azar de semilla fija: tramos de dificultad,
## sin repetir anomalía en una partida, sin repetir objeto ni tema seguidos,
## 30 % de rondas normales y ningún callejón sin salida.

const Reporter := preload("res://tests/reporter.gd")
const ANOMALY_DIR := "res://resources/anomalies/"
const SEED := 20261023
const GAMES := 3000
const DECISION_ROUNDS := 10
const DRAWS := 10000
const NORMAL_TOLERANCE := 0.02
const TIER_TOLERANCE := 0.04
const MAX_RELAXED_SHARE := 0.08
const EASY := AnomalyData.Difficulty.EASY
const MEDIUM := AnomalyData.Difficulty.MEDIUM
const HARD := AnomalyData.Difficulty.HARD
const TIER_EARLY := "EARLY"
const TIER_MIDDLE := "MIDDLE"
const TIER_LATE := "LATE"

var _report: Reporter
var _catalog: Array[AnomalyData] = []
var _always := func(_anomaly: AnomalyData) -> bool: return true


func run(report: Reporter, _tree: SceneTree) -> void:
	report.start("AnomalySelector: tramos, no repetición, temas y 30 % normales")
	_report = report
	_catalog.assign(CatalogLoader.load_all(ANOMALY_DIR, AnomalyData))
	_report.check(_catalog.size() == 36, "el catálogo se carga (%d anomalías)" % _catalog.size())
	_check_only_compatible()
	_check_simulated_games()
	_check_normal_rooms()
	_check_never_null_with_candidates()
	_check_relaxation_order()
	_check_varios_never_repeats()
	_check_empty_cases()


## Juega muchas partidas de 10 rondas y comprueba todas las reglas a la vez.
func _check_simulated_games() -> void:
	var selector := AnomalySelector.new(_seeded())
	var in_tier := {TIER_EARLY: 0, TIER_MIDDLE: 0, TIER_LATE: 0}
	var total := {TIER_EARLY: 0, TIER_MIDDLE: 0, TIER_LATE: 0}
	var middle_medium := 0
	var late_hard := 0
	var repeats := 0
	var theme_repeats := 0
	var focus_repeats := 0
	var relaxed := 0
	var anomaly_rounds := 0
	var normals := 0
	var rounds := 0
	for game in range(GAMES):
		var state := RunState.new()
		for round_number in range(1, DECISION_ROUNDS + 1):
			state.index = round_number
			var last_focus := state.last_focus_object
			var last_theme := state.last_theme
			var chosen := selector.pick(_catalog, _always, round_number, state)
			rounds += 1
			if chosen == null:
				normals += 1
				state.record(null)
				continue
			anomaly_rounds += 1
			repeats += 1 if state.used_ids.has(chosen.id) else 0
			var relaxation := selector.last_relaxation
			relaxed += 1 if relaxation != AnomalySelector.Relaxation.STRICT else 0
			theme_repeats += 1 if chosen.theme == last_theme and relaxation < AnomalySelector.Relaxation.ANY_THEME else 0
			focus_repeats += 1 if _same_focus(chosen.focus_object, last_focus) and relaxation < AnomalySelector.Relaxation.ANY_FOCUS else 0
			if relaxation < AnomalySelector.Relaxation.ANY_DIFFICULTY:
				var tier := _tier_of(round_number)
				total[tier] += 1
				in_tier[tier] += 1 if _in_tier(chosen.difficulty, tier) else 0
				middle_medium += 1 if tier == TIER_MIDDLE and chosen.difficulty == MEDIUM else 0
				late_hard += 1 if tier == TIER_LATE and chosen.difficulty == HARD else 0
			state.record(chosen)
	_report.check(repeats == 0, "ninguna anomalía se repite dentro de una partida (%d repeticiones en %d partidas)" % [repeats, GAMES])
	_report.check(theme_repeats == 0 and focus_repeats == 0, "no repite tema (%d) ni objeto (%d) seguidos mientras haya alternativa" % [theme_repeats, focus_repeats])
	_report.check(float(relaxed) / anomaly_rounds <= MAX_RELAXED_SHARE, "relajar las reglas es raro: %.1f %% de las rondas con anomalía" % (100.0 * relaxed / anomaly_rounds))
	_report.check(in_tier[TIER_EARLY] == total[TIER_EARLY] and total[TIER_EARLY] > 0, "rondas 1-3: solo EASY (%d de %d)" % [in_tier[TIER_EARLY], total[TIER_EARLY]])
	_report.check(in_tier[TIER_MIDDLE] == total[TIER_MIDDLE] and total[TIER_MIDDLE] > 0, "rondas 4-7: solo MEDIUM o EASY (%d de %d)" % [in_tier[TIER_MIDDLE], total[TIER_MIDDLE]])
	_report.check(in_tier[TIER_LATE] == total[TIER_LATE] and total[TIER_LATE] > 0, "rondas 8-10: solo HARD o MEDIUM (%d de %d)" % [in_tier[TIER_LATE], total[TIER_LATE]])
	var middle_share: float = float(middle_medium) / float(total[TIER_MIDDLE])
	var late_share: float = float(late_hard) / float(total[TIER_LATE])
	_report.check(absf(middle_share - AnomalySelector.MIDDLE_MEDIUM_SHARE) < TIER_TOLERANCE, "rondas 4-7: %.0f %% MEDIUM (objetivo 70 %%)" % (100.0 * middle_share))
	_report.check(absf(late_share - AnomalySelector.LATE_HARD_SHARE) < TIER_TOLERANCE, "rondas 8-10: %.0f %% HARD (objetivo 50 %%)" % (100.0 * late_share))
	var normal_share := float(normals) / rounds
	_report.check(absf(normal_share - AnomalySelector.NORMAL_ROOM_CHANCE) < NORMAL_TOLERANCE, "el %.1f %% de las rondas queda normal (objetivo 30 %%)" % (100.0 * normal_share))


func _check_normal_rooms() -> void:
	var selector := AnomalySelector.new(_seeded())
	var normals := 0
	for i in range(DRAWS):
		if selector.pick(_catalog, _always, 1 + i % DECISION_ROUNDS, RunState.new()) == null:
			normals += 1
	var share := float(normals) / DRAWS
	_report.check(absf(share - AnomalySelector.NORMAL_ROOM_CHANCE) < NORMAL_TOLERANCE, "%d sorteos: %.1f %% de habitaciones normales" % [DRAWS, 100.0 * share])


## Con estados de partida al azar, pick_anomaly nunca devuelve null si hay compatibles.
func _check_never_null_with_candidates() -> void:
	var selector := AnomalySelector.new(_seeded())
	var rng := _seeded()
	var nulls := 0
	for i in range(DRAWS):
		var state := RunState.new()
		var allowed := {}
		for anomaly in _catalog:
			if rng.randf() < 0.6:
				state.used_ids.append(anomaly.id)
			if rng.randf() < 0.3:
				allowed[anomaly.id] = true
		allowed[_catalog[rng.randi() % _catalog.size()].id] = true
		state.last_theme = rng.randi() % 16
		state.last_focus_object = AnomalyData.FOCUS_OBJECTS[rng.randi() % AnomalyData.FOCUS_OBJECTS.size()]
		var round_number := 1 + rng.randi() % DECISION_ROUNDS
		var chosen := selector.pick_anomaly(_catalog, func(anomaly: AnomalyData) -> bool: return allowed.has(anomaly.id), round_number, state)
		nulls += 1 if chosen == null else 0
	_report.check(nulls == 0, "%d sorteos con estados al azar: ninguno devuelve null habiendo compatibles (%d)" % [DRAWS, nulls])


## Orden de relajación: primero el tema, luego el objeto, luego el tramo.
func _check_relaxation_order() -> void:
	var selector := AnomalySelector.new(_seeded())
	var same_theme := _make("a", "silla", AnomalyData.Topic.DUELO, EASY)
	var state := RunState.new()
	state.last_theme = AnomalyData.Topic.DUELO
	var pick := selector.pick_anomaly([same_theme], _always, 1, state)
	_report.check(pick == same_theme and selector.last_relaxation == AnomalySelector.Relaxation.ANY_THEME, "si solo queda el mismo tema, se relaja el tema primero")
	var same_focus := _make("b", "silla", AnomalyData.Topic.MIEDO, EASY)
	state.last_theme = AnomalyData.Topic.MIEDO
	state.last_focus_object = "silla"
	pick = selector.pick_anomaly([same_focus], _always, 1, state)
	_report.check(pick == same_focus and selector.last_relaxation == AnomalySelector.Relaxation.ANY_FOCUS, "si además es el mismo objeto, se relaja el objeto después")
	var wrong_tier := _make("c", "reloj", AnomalyData.Topic.CULPA, HARD)
	pick = selector.pick_anomaly([wrong_tier], _always, 1, RunState.new())
	_report.check(pick == wrong_tier and selector.last_relaxation == AnomalySelector.Relaxation.ANY_DIFFICULTY, "si el tramo no tiene nada, se relaja el tramo al final")
	var used := RunState.new()
	used.used_ids.append("c")
	pick = selector.pick_anomaly([wrong_tier], _always, 1, used)
	_report.check(pick == wrong_tier and selector.last_relaxation == AnomalySelector.Relaxation.ALLOW_REPEATS, "como último recurso se permite repetir antes que devolver null")


func _check_varios_never_repeats() -> void:
	var selector := AnomalySelector.new(_seeded())
	var several := _make("v", AnomalyData.FOCUS_ANY, AnomalyData.Topic.MIEDO, EASY)
	var state := RunState.new()
	state.last_focus_object = AnomalyData.FOCUS_ANY
	var pick := selector.pick_anomaly([several], _always, 1, state)
	_report.check(pick == several and selector.last_relaxation == AnomalySelector.Relaxation.STRICT, "«varios» tras «varios» no cuenta como repetición")
	state.last_focus_object = "puerta"
	pick = selector.pick_anomaly([several], _always, 1, state)
	_report.check(pick == several and selector.last_relaxation == AnomalySelector.Relaxation.STRICT, "«varios» tras un objeto concreto no cuenta como repetición")


func _check_only_compatible() -> void:
	var selector := AnomalySelector.new(_seeded())
	var allowed := {"figura_cama": true, "figura_armario": true}
	var bad := 0
	for i in range(DRAWS):
		var chosen := selector.pick(_catalog, func(anomaly: AnomalyData) -> bool: return allowed.has(anomaly.id), 5, RunState.new())
		bad += 1 if chosen != null and not allowed.has(chosen.id) else 0
	_report.check(bad == 0, "solo elige anomalías compatibles con la habitación")


func _check_empty_cases() -> void:
	var selector := AnomalySelector.new(_seeded())
	var empty: Array[AnomalyData] = []
	_report.check(selector.pick_anomaly(empty, _always, 1, RunState.new()) == null, "catálogo vacío: nada que elegir")
	_report.check(selector.pick_anomaly(_catalog, func(_anomaly: AnomalyData) -> bool: return false, 1, RunState.new()) == null, "nada compatible: nada que elegir")


func _tier_of(round_number: int) -> String:
	if round_number <= AnomalySelector.EARLY_LAST_ROUND:
		return TIER_EARLY
	return TIER_MIDDLE if round_number <= AnomalySelector.MIDDLE_LAST_ROUND else TIER_LATE


func _in_tier(difficulty: AnomalyData.Difficulty, tier: String) -> bool:
	match tier:
		TIER_EARLY:
			return difficulty == EASY
		TIER_MIDDLE:
			return difficulty == MEDIUM or difficulty == EASY
	return difficulty == HARD or difficulty == MEDIUM


func _same_focus(focus: String, last: String) -> bool:
	return focus == last and focus != "" and focus != AnomalyData.FOCUS_ANY


func _make(anomaly_id: String, focus: String, topic: AnomalyData.Topic, difficulty: AnomalyData.Difficulty) -> AnomalyData:
	var anomaly := AnomalyData.new()
	anomaly.id = anomaly_id
	anomaly.focus_object = focus
	anomaly.theme = topic
	anomaly.difficulty = difficulty
	return anomaly


func _seeded() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	return rng
