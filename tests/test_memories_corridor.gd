extends RefCounted

## Bloque B2: recuerdos del pasillo. Los pasillos hacia las rondas 3, 5, 7 y 9
## muestran viñeta y pie y después la tarjeta; el resto, solo la tarjeta. Las
## viñetas se instancian, terminan y no dejan nodos huérfanos.

const Reporter := preload("res://tests/reporter.gd")
const GameDriver := preload("res://tests/game_driver.gd")
const MEMORY_ROUNDS: Array[int] = [3, 5, 7, 9]
const CORRIDOR_PACING := 0.1
const FRAME_BUDGET := 2400
const VIGNETTE_PLAY_SECONDS := 0.3

var _report: Reporter
var _tree: SceneTree
var _texts: MemoryTexts
var _content: LearningContent


func run(report: Reporter, tree: SceneTree) -> void:
	report.start("Recuerdos del pasillo: viñetas, pies y duración")
	_report = report
	_tree = tree
	_texts = MemoryTexts.default()
	_content = LearningContent.default()
	_check_data()
	_check_durations()
	await _check_vignettes_alone()
	await _check_corridors_in_game()

# ---------------------------------------------------------------------------
# Datos y duración
# ---------------------------------------------------------------------------

func _check_data() -> void:
	var rounds: Array[int] = []
	for entry in _texts.corridor_memories:
		var memory := entry as CorridorMemory
		rounds.append(memory.round_number)
		_report.check(memory.caption_lines.size() == 2 and memory.vignette_scene != null, "recuerdo hacia la ronda %d: pie de dos líneas y viñeta" % memory.round_number)
	_report.check(rounds == MEMORY_ROUNDS, "hay recuerdos de pasillo para las rondas 3, 5, 7 y 9: %s" % str(rounds))
	var night := _texts.corridor_memory_for(7)
	_report.check(night.caption() == "Esa noche llovía y esperabas en casa.\nHubo un silencio largo, y después, el teléfono.", "el pie de «La noche» es el texto definitivo")


func _check_durations() -> void:
	var all_ok := true
	for entry in _texts.corridor_memories:
		var memory := entry as CorridorMemory
		var card := _content.corridor_cards[memory.round_number - 1]
		var characters := memory.caption_lines[0].length() + memory.caption_lines[1].length() + card.length()
		var expected := minf(maxf(GameManager.CORRIDOR_TIME, 2.2 + 0.045 * characters), 12.0)
		all_ok = all_ok and is_equal_approx(GameManager.corridor_time_for(card, memory.caption()), expected)
	_report.check(all_ok, "con recuerdo, el pasillo dura 2,2 + 0,045 × (pie + tarjeta), mínimo 3,4 s y tope 12 s")
	_report.check(GameManager.corridor_time_for("x".repeat(40), "y".repeat(400)) == 12.0, "un pie larguísimo respeta el tope de 12 s")
	_report.check(GameManager.corridor_time_for("x".repeat(200)) == 7.0, "sin recuerdo sigue el tope de 7 s")

# ---------------------------------------------------------------------------
# Viñetas sueltas
# ---------------------------------------------------------------------------

func _check_vignettes_alone() -> void:
	var orphans_before: int = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	for entry in _texts.corridor_memories:
		var memory := entry as CorridorMemory
		var vignette := memory.vignette_scene.instantiate() as MemoryVignette
		_report.check(vignette != null, "%s: la viñeta es una MemoryVignette" % memory.title)
		_tree.root.add_child(vignette)
		await _tree.process_frame
		var viewport := vignette.find_children("*", "SubViewport", true, false)
		_report.check(viewport.size() == 1 and (viewport[0] as SubViewport).size == MemoryVignette.RESOLUTION, "%s: se pinta en un SubViewport de 192×108" % memory.title)
		var screen := vignette.find_children("*", "TextureRect", true, false)
		_report.check(screen.size() == 1 and (screen[0] as TextureRect).texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "%s: se amplía con filtro nearest" % memory.title)
		var ended := [false]
		vignette.finished.connect(func() -> void: ended[0] = true)
		vignette.play(VIGNETTE_PLAY_SECONDS)
		await _tree.create_timer(VIGNETTE_PLAY_SECONDS * 0.5).timeout
		_report.check(vignette.is_playing() and vignette.progress > 0.0 and vignette.progress < 1.0, "%s: avanza mientras se reproduce" % memory.title)
		for i in range(FRAME_BUDGET):
			if ended[0]:
				break
			await _tree.process_frame
		_report.check(ended[0] and vignette.progress == 1.0, "%s: termina y emite finished" % memory.title)
		_report.check(vignette.sound_name.is_empty() or not AudioManager.is_active(vignette.sound_name), "%s: su sonido (%s) se apaga al terminar" % [memory.title, vignette.sound_name])
		vignette.queue_free()
		await _tree.process_frame
	await _tree.process_frame
	var orphans: int = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	_report.check(orphans <= orphans_before, "las viñetas no dejan nodos huérfanos (%d → %d)" % [orphans_before, orphans])
	var family := _texts.corridor_memory_for(5).vignette_scene.instantiate()
	_report.check(family.get("sound_name") == "anomaly_music_box", "la familia reutiliza anomaly_music_box")
	family.free()

# ---------------------------------------------------------------------------
# En la partida
# ---------------------------------------------------------------------------

func _check_corridors_in_game() -> void:
	var driver := GameDriver.new(_tree)
	await driver.boot()
	var manager := driver.manager
	var rounds := manager._rooms.size()
	var right := 0
	var order_ok := 0
	var timing_ok := 0
	for next_index in range(1, rounds + 1):
		if next_index > 1:
			driver.answer(driver.correct_answer())
		manager.pacing = CORRIDOR_PACING
		driver.cross_door()
		var seen := await _watch(manager)
		manager.pacing = 0.0
		var expects_memory := MEMORY_ROUNDS.has(next_index) and next_index < rounds
		right += 1 if seen["memory"] == expects_memory else 0
		order_ok += 1 if not expects_memory or (seen["caption_first"] and seen["card_after"]) else 0
		var memory := _texts.corridor_memory_for(next_index) if expects_memory else null
		var card: String = _content.closing_card if next_index == rounds else _content.corridor_cards[next_index - 1]
		var walk := GameManager.corridor_time_for(card, memory.caption() if memory != null else "") * CORRIDOR_PACING
		timing_ok += 1 if seen["seconds"] >= walk * 0.9 and seen["seconds"] <= walk + 2.2 else 0
		if next_index < rounds:
			await driver.await_idle()
			await driver.await_state(GameManager.State.EXPLORACION)
	_report.check(right == rounds, "solo los pasillos hacia 3, 5, 7 y 9 tienen recuerdo (%d de %d correctos)" % [right, rounds])
	_report.check(order_ok == rounds, "primero el recuerdo con su pie y después la tarjeta")
	_report.check(timing_ok == rounds, "las duraciones reales siguen la fórmula con tiempo escalado (%d de %d)" % [timing_ok, rounds])
	await driver.shutdown()
	await _tree.process_frame
	_report.check(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT) == 0, "tras once pasillos no quedan nodos huérfanos")


func _watch(manager: GameManager) -> Dictionary:
	var corridor: Corridor = null
	for i in range(FRAME_BUDGET):
		for child in manager.get_children():
			if child is Corridor:
				corridor = child
		if corridor != null:
			break
		await _tree.process_frame
	if corridor == null:
		return {"memory": false, "caption_first": false, "card_after": false, "seconds": 0.0}
	var has_memory := false
	var caption_first := false
	var card_after := false
	var started := Time.get_ticks_msec()
	while is_instance_valid(corridor) and not corridor.is_queued_for_deletion():
		has_memory = has_memory or corridor.has_memory()
		var caption_alpha: float = corridor._caption_label.modulate.a
		var card_alpha: float = corridor._card_label.modulate.a
		caption_first = caption_first or (caption_alpha > 0.5 and card_alpha < 0.1)
		card_after = card_after or (caption_first and card_alpha > 0.9 and caption_alpha < 0.1)
		await _tree.process_frame
	return {"memory": has_memory, "caption_first": caption_first, "card_after": card_after, "seconds": (Time.get_ticks_msec() - started) / 1000.0}
