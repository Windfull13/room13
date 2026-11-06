extends RefCounted

## Catálogo de 36 anomalías: datos exactos, reconversión del frasco, aplicar y
## revertir, peligrosas con entidad/susto/efecto, sonidos con intervalo (se
## repiten, vibran, y se detienen al responder, fallar, reiniciar y pausar),
## significado al acertar y colocación de los objetos nuevos.

const Reporter := preload("res://tests/reporter.gd")
const GameDriver := preload("res://tests/game_driver.gd")
const SoundCatalog := preload("res://scripts/audio/sound_catalog.gd")
const ANOMALY_DIR := "res://resources/anomalies/"
const ROOM_SCENE := "res://scenes/rooms/room_base.tscn"
const JUMPSCARE_DIR := "res://scenes/jumpscares/"
const AUDIO_DIR := "res://assets/audio/"
const EXPECTED_TOTAL := 36
const EXPECTED_BY_DIFFICULTY := {AnomalyData.Difficulty.EASY: 10, AnomalyData.Difficulty.MEDIUM: 18, AnomalyData.Difficulty.HARD: 8}
const EXPECTED_DANGEROUS := 9
const NEW_ANOMALIES: Array[String] = ["telefono_sonando", "comida_sin_tocar", "notas_bajo_la_puerta", "golpes_en_la_puerta", "caja_de_musica", "espejo_cubierto", "planta_con_flor"]
const OLD_PREFIX := "Interpretación"
## Peligrosas cuya amenaza no es un sprite de entidad (oscuridad, objetos).
const WITHOUT_ENTITY_SPRITE: Array[String] = ["oscuridad_total", "tres_senales"]
const SOUND_ANOMALIES: Array[String] = ["telefono_sonando", "golpes_en_la_puerta", "caja_de_musica", "telefono_descolgado"]
const SOUND_PREFIX_ANOMALY := "anomaly_"
const SOUND_PREFIX_JUMPSCARE := "jumpscare_"
## Se acelera el tiempo del juego para no esperar los 5-10 s reales de cada intervalo.
const TIME_SCALE := 6.0
const WAIT_DEADLINE_MS := 6000
const SHAKE_WATCH_MS := 400
const PAUSE_WATCH_MS := 1500
const SCREEN := Rect2(0, 0, 1280, 720)
const NEW_OBJECTS_ON_DESK: Array[String] = ["DeskGlass", "DeskPlate", "MusicBox"]
const NEW_FLOOR_NOTES: Array[String] = ["DoorNote1", "DoorNote2", "DoorNote3"]
const FLOOR_RECT := Rect2(288, 216, 704, 384)
const MIN_FLOWER_SHARE := 0.6
const LONGEST_PROMPT := "E — Examinar Fotografía familiar"
## Objetos de la habitación con los que los nuevos no deben solaparse.
const OTHER_OBJECTS: Array[String] = ["Photograph", "Book", "Phone", "Lamp", "Letter", "Keys", "Spider", "Doll", "Toy", "Clock", "Drawing", "WifePhoto", "Handprint", "Crow", "Window", "Door", "Chair", "Bed", "Wardrobe", "Mirror", "Plant"]

## id → [objeto, tema, dificultad] del catálogo definitivo.
const TABLE := {
	"alfombra_movida": ["alfombra", AnomalyData.Topic.PERCEPCION, AnomalyData.Difficulty.EASY],
	"espejo_girado": ["espejo", AnomalyData.Topic.IDENTIDAD, AnomalyData.Difficulty.EASY],
	"foto_invertida": ["foto", AnomalyData.Topic.DUELO, AnomalyData.Difficulty.EASY],
	"lampara_apagada": ["lampara", AnomalyData.Topic.AGOTAMIENTO, AnomalyData.Difficulty.EASY],
	"peluche_girado": ["peluche", AnomalyData.Topic.INFANCIA, AnomalyData.Difficulty.EASY],
	"reloj_torcido": ["reloj", AnomalyData.Topic.AGOTAMIENTO, AnomalyData.Difficulty.EASY],
	"silla_ausente": ["silla", AnomalyData.Topic.AISLAMIENTO, AnomalyData.Difficulty.EASY],
	"silla_girada": ["silla", AnomalyData.Topic.PERCEPCION, AnomalyData.Difficulty.EASY],
	"telefono_sonando": ["telefono", AnomalyData.Topic.RELACIONES, AnomalyData.Difficulty.EASY],
	"oscuridad_total": ["luz", AnomalyData.Topic.AISLAMIENTO, AnomalyData.Difficulty.EASY],
	"aranna_en_el_suelo": ["arana", AnomalyData.Topic.MIEDO, AnomalyData.Difficulty.MEDIUM],
	"carta_abierta": ["carta", AnomalyData.Topic.CULPA, AnomalyData.Difficulty.MEDIUM],
	"dibujo_en_la_pared": ["dibujo", AnomalyData.Topic.INFANCIA, AnomalyData.Difficulty.MEDIUM],
	"llaves_en_el_suelo": ["llaves", AnomalyData.Topic.AISLAMIENTO, AnomalyData.Difficulty.MEDIUM],
	"luz_en_la_ventana": ["ventana", AnomalyData.Topic.ESPERANZA, AnomalyData.Difficulty.MEDIUM],
	"marca_en_la_puerta": ["puerta", AnomalyData.Topic.DUELO, AnomalyData.Difficulty.MEDIUM],
	"muneca_en_el_suelo": ["muneca", AnomalyData.Topic.ACEPTACION, AnomalyData.Difficulty.MEDIUM],
	"planta_invertida": ["planta", AnomalyData.Topic.AUTOCUIDADO, AnomalyData.Difficulty.MEDIUM],
	"telefono_descolgado": ["telefono", AnomalyData.Topic.AISLAMIENTO, AnomalyData.Difficulty.MEDIUM],
	"comida_sin_tocar": ["escritorio", AnomalyData.Topic.AUTOCUIDADO, AnomalyData.Difficulty.MEDIUM],
	"notas_bajo_la_puerta": ["puerta", AnomalyData.Topic.ACOSO, AnomalyData.Difficulty.MEDIUM],
	"golpes_en_la_puerta": ["puerta", AnomalyData.Topic.ACOSO, AnomalyData.Difficulty.MEDIUM],
	"caja_de_musica": ["escritorio", AnomalyData.Topic.FAMILIA, AnomalyData.Difficulty.MEDIUM],
	"espejo_cubierto": ["espejo", AnomalyData.Topic.AUTOESTIMA, AnomalyData.Difficulty.MEDIUM],
	"cuervo_en_el_marco": ["ventana", AnomalyData.Topic.DUELO, AnomalyData.Difficulty.MEDIUM],
	"figura_cama": ["cama", AnomalyData.Topic.INFANCIA, AnomalyData.Difficulty.MEDIUM],
	"figura_armario": ["armario", AnomalyData.Topic.INFANCIA, AnomalyData.Difficulty.MEDIUM],
	"figura_ventana": ["ventana", AnomalyData.Topic.AISLAMIENTO, AnomalyData.Difficulty.MEDIUM],
	"foto_cambiada": ["foto", AnomalyData.Topic.RECUERDOS, AnomalyData.Difficulty.HARD],
	"reloj_detenido": ["reloj", AnomalyData.Topic.DUELO, AnomalyData.Difficulty.HARD],
	"retrato_ajeno": ["retrato", AnomalyData.Topic.RELACIONES, AnomalyData.Difficulty.HARD],
	"planta_con_flor": ["planta", AnomalyData.Topic.ESPERANZA, AnomalyData.Difficulty.HARD],
	"figura_en_el_espejo": ["espejo", AnomalyData.Topic.IDENTIDAD, AnomalyData.Difficulty.HARD],
	"testigo_cuarto": ["testigo", AnomalyData.Topic.CULPA, AnomalyData.Difficulty.HARD],
	"testigo_esquina": ["testigo", AnomalyData.Topic.CULPA, AnomalyData.Difficulty.HARD],
	"tres_senales": ["varios", AnomalyData.Topic.MIEDO, AnomalyData.Difficulty.HARD],
}

## Sonido, objeto que vibra e intervalo de los cuatro efectos nuevos.
const NEW_EFFECTS := {
	"telefono_suena": {"target": "Phone", "kind": "tremble", "sound": "anomaly_phone_ring", "interval": 6.0},
	"puerta_golpes": {"target": "Door", "kind": "tremble", "sound": "anomaly_knocks", "interval": 9.0},
	"caja_musica": {"target": "", "kind": "sound_only", "sound": "anomaly_music_box", "interval": 10.0},
	"linea_muerta": {"target": "", "kind": "sound_only", "sound": "anomaly_dead_line", "interval": 5.0},
}
const AMBIENCE_OF := {"telefono_sonando": "telefono_suena", "golpes_en_la_puerta": "puerta_golpes", "caja_de_musica": "caja_musica", "telefono_descolgado": "linea_muerta"}

var _report: Reporter
var _tree: SceneTree
var _catalog: Array[AnomalyData] = []
var _by_id := {}


func run(report: Reporter, tree: SceneTree) -> void:
	report.start("Catálogo de anomalías: datos, sonidos, significado y colocación")
	_report = report
	_tree = tree
	_catalog.assign(CatalogLoader.load_all(ANOMALY_DIR, AnomalyData))
	for anomaly in _catalog:
		_by_id[anomaly.id] = anomaly
	_check_catalog_data()
	_check_frasco_removed()
	_check_dangerous_and_harmless()
	_check_effect_definitions()
	_check_sound_files_and_levels()
	await _check_targets_and_round_trip()
	var driver := GameDriver.new(tree)
	await driver.boot()
	for anomaly_id in SOUND_ANOMALIES:
		await _check_sound_anomaly(driver, anomaly_id)
	await _check_meaning_on_success(driver)
	await _check_new_objects_layout(driver)
	await driver.shutdown()

# ---------------------------------------------------------------------------
# Datos del catálogo
# ---------------------------------------------------------------------------

func _check_catalog_data() -> void:
	_report.check(_catalog.size() == EXPECTED_TOTAL and _by_id.size() == EXPECTED_TOTAL, "hay %d anomalías con ids únicos (%d)" % [EXPECTED_TOTAL, _by_id.size()])
	var counts := {AnomalyData.Difficulty.EASY: 0, AnomalyData.Difficulty.MEDIUM: 0, AnomalyData.Difficulty.HARD: 0}
	var dangerous := 0
	for anomaly in _catalog:
		counts[anomaly.difficulty] += 1
		dangerous += 1 if anomaly.is_dangerous else 0
	for difficulty in EXPECTED_BY_DIFFICULTY:
		_report.check(counts[difficulty] == EXPECTED_BY_DIFFICULTY[difficulty], "dificultad %s: %d anomalías (esperadas %d)" % [AnomalyData.Difficulty.keys()[difficulty], counts[difficulty], EXPECTED_BY_DIFFICULTY[difficulty]])
	_report.check(dangerous == EXPECTED_DANGEROUS and _catalog.size() - dangerous == EXPECTED_TOTAL - EXPECTED_DANGEROUS, "%d peligrosas y %d no peligrosas" % [dangerous, _catalog.size() - dangerous])
	var wrong: Array[String] = []
	for anomaly_id: String in TABLE:
		var anomaly := _by_id.get(anomaly_id) as AnomalyData
		if anomaly == null:
			wrong.append("%s (falta)" % anomaly_id)
			continue
		var row: Array = TABLE[anomaly_id]
		if anomaly.focus_object != row[0] or anomaly.theme != row[1] or anomaly.difficulty != row[2]:
			wrong.append(anomaly_id)
	_report.check(wrong.is_empty() and TABLE.size() == EXPECTED_TOTAL, "objeto, tema y dificultad coinciden con la tabla definitiva: %s" % str(wrong))
	for anomaly in _catalog:
		_check_texts(anomaly)
	for anomaly_id in NEW_ANOMALIES:
		_report.check(_by_id.has(anomaly_id), "existe la anomalía nueva %s" % anomaly_id)


func _check_texts(anomaly: AnomalyData) -> void:
	var complete := not anomaly.description.is_empty() and not anomaly.display_name.is_empty() and not anomaly.tell.is_empty()
	var short_meaning := not anomaly.meaning.is_empty() and anomaly.meaning.length() <= AnomalyData.MAX_MEANING_LENGTH and not anomaly.meaning.begins_with(OLD_PREFIX)
	var valid_focus := AnomalyData.FOCUS_OBJECTS.has(anomaly.focus_object)
	_report.check(complete and short_meaning and valid_focus, "%s: nombre, descripción, pista, significado (%d ≤ 90, sin prefijo) y objeto válidos" % [anomaly.id, anomaly.meaning.length()])


func _check_frasco_removed() -> void:
	_report.check(not _by_id.has("frasco_volcado") and not FileAccess.file_exists(ANOMALY_DIR + "frasco_volcado.tres"), "frasco_volcado ya no existe")
	_report.check(not FileAccess.file_exists(JUMPSCARE_DIR + "jumpscare_frasco_volcado.tscn") and not FileAccess.file_exists("res://scripts/jumpscares/jumpscare_frasco_volcado.gd"), "su susto (escena y script) está borrado")
	_report.check(not SoundCatalog.has("jumpscare_frasco") and not FileAccess.file_exists(AUDIO_DIR + "jumpscare_frasco.wav"), "su sonido está borrado del catálogo y del disco")
	_report.check(not EntityAmbience.EFFECTS.has("recuerdo_borroso"), "el efecto «recuerdo_borroso» ya no existe")
	var pills := 0
	for file_name in DirAccess.get_files_at(ANOMALY_DIR) + DirAccess.get_files_at(JUMPSCARE_DIR):
		var directory := ANOMALY_DIR if file_name.get_extension() == "tres" else JUMPSCARE_DIR
		var text := FileAccess.get_file_as_string(directory + file_name).to_lower()
		pills += 1 if text.contains("pastilla") or text.contains("pills") else 0
	_report.check(pills == 0, "ninguna anomalía ni susto menciona pastillas (%d)" % pills)
	var room := (load(ROOM_SCENE) as PackedScene).instantiate()
	_report.check(room.get_node("World").get_node_or_null("Pills") == null, "room_base ya no tiene el nodo Pills")
	room.free()
	var comida := _by_id.get("comida_sin_tocar") as AnomalyData
	_report.check(comida != null and not comida.is_dangerous and comida.jumpscare_scene == null and comida.monster_scene == null and comida.ambience.is_empty(), "comida_sin_tocar no es peligrosa: sin entidad, sin susto y sin efecto")
	_report.check(comida != null and comida.modifications.size() == 2, "comida_sin_tocar muestra vaso y plato (%d modificaciones)" % (comida.modifications.size() if comida != null else -1))


func _check_dangerous_and_harmless() -> void:
	var scenes: Array[String] = []
	var room := (load(ROOM_SCENE) as PackedScene).instantiate()
	for anomaly in _catalog:
		if anomaly.is_dangerous:
			scenes.append(anomaly.jumpscare_scene.resource_path if anomaly.jumpscare_scene != null else "")
			_report.check(anomaly.jumpscare_scene != null and not anomaly.ambience.is_empty() and EntityAmbience.EFFECTS.has(anomaly.ambience), "%s (peligrosa): tiene susto y efecto de entorno" % anomaly.id)
			_report.check(_has_entity(anomaly, room), "%s (peligrosa): tiene su entidad o manifestación" % anomaly.id)
		else:
			_report.check(anomaly.jumpscare_scene == null and anomaly.monster_scene == null, "%s: no peligrosa, sin susto ni criatura" % anomaly.id)
	room.free()
	var unique := {}
	for path in scenes:
		unique[path] = true
	_report.check(scenes.size() == EXPECTED_DANGEROUS and unique.size() == EXPECTED_DANGEROUS and not unique.has(""), "los %d sustos son distintos (%d únicos)" % [scenes.size(), unique.size()])


## Entidad: criatura, sprite del grupo «entidades» o, en las dos peligrosas que no
## tienen sprite (oscuridad, tres señales), una manifestación visible.
func _has_entity(anomaly: AnomalyData, room: Node) -> bool:
	if anomaly.monster_scene != null:
		return true
	for modification: AnomalyModification in anomaly.modifications:
		var node := room.get_node("World").get_node_or_null(NodePath(modification.target_node))
		if node != null and node.is_in_group(Room.ENTITY_GROUP):
			return true
	return WITHOUT_ENTITY_SPRITE.has(anomaly.id) and not anomaly.modifications.is_empty()


func _check_effect_definitions() -> void:
	for effect_name: String in NEW_EFFECTS:
		var expected: Dictionary = NEW_EFFECTS[effect_name]
		var effect: Dictionary = EntityAmbience.EFFECTS.get(effect_name, {})
		var same: bool = effect.get("target", "?") == expected["target"] and effect.get("kind", "") == expected["kind"] and effect.get("sound", "") == expected["sound"] and is_equal_approx(effect.get("interval", -1.0), expected["interval"]) and effect.get("when", "") == EntityAmbience.WHEN_ALWAYS
		_report.check(same, "el efecto %s está definido como pide el diseño" % effect_name)
	for anomaly_id: String in AMBIENCE_OF:
		_report.check((_by_id[anomaly_id] as AnomalyData).ambience == AMBIENCE_OF[anomaly_id], "%s usa el efecto %s" % [anomaly_id, AMBIENCE_OF[anomaly_id]])
	_report.check(is_equal_approx(EntityAmbience.REPEAT_START_DELAY, 1.5), "los efectos con intervalo empiezan 1,5 s después de entrar en la ronda")


func _check_sound_files_and_levels() -> void:
	var anomaly_peaks := {}
	var jumpscare_peaks := {}
	for sound_name: String in SoundCatalog.SOUNDS:
		if sound_name.begins_with(SOUND_PREFIX_ANOMALY):
			anomaly_peaks[sound_name] = _effective_peak_db(sound_name)
		elif sound_name.begins_with(SOUND_PREFIX_JUMPSCARE):
			jumpscare_peaks[sound_name] = _effective_peak_db(sound_name)
	_report.check(anomaly_peaks.size() == 4, "hay 4 sonidos de anomalía en el catálogo: %s" % str(anomaly_peaks.keys()))
	for sound_name: String in anomaly_peaks:
		var stream: AudioStream = AudioManager.stream_for(sound_name)
		_report.check(stream != null and stream.get_length() > 0.0, "%s existe, carga y dura %.1f s" % [sound_name, stream.get_length() if stream != null else 0.0])
	var loudest_anomaly: float = anomaly_peaks.values().max()
	var quietest_jumpscare: float = jumpscare_peaks.values().min()
	_report.check(jumpscare_peaks.size() == EXPECTED_DANGEROUS, "hay %d sonidos de susto" % jumpscare_peaks.size())
	_report.check(loudest_anomaly < quietest_jumpscare, "el sonido de anomalía más fuerte (%.1f dB) es más suave que el susto más suave (%.1f dB)" % [loudest_anomaly, quietest_jumpscare])


## Pico real del sonido: el del archivo más el volumen del catálogo.
func _effective_peak_db(sound_name: String) -> float:
	var entry: Dictionary = SoundCatalog.entry(sound_name)
	var wav := AudioStreamWAV.load_from_file(entry["file"])
	var peak := 0
	if wav != null:
		for offset in range(0, wav.data.size() - 1, 2):
			peak = maxi(peak, absi(wav.data.decode_s16(offset)))
	return linear_to_db(maxf(peak / 32768.0, 0.00001)) + float(entry["volume_db"])

# ---------------------------------------------------------------------------
# Aplicar y revertir
# ---------------------------------------------------------------------------

func _check_targets_and_round_trip() -> void:
	var room := (load(ROOM_SCENE) as PackedScene).instantiate() as Room
	_tree.root.add_child(room)
	await _tree.process_frame
	var missing: Array[String] = []
	var broken: Array[String] = []
	var baseline := _signature(room)
	for anomaly in _catalog:
		for modification: AnomalyModification in anomaly.modifications:
			if room.get_node("World").get_node_or_null(NodePath(modification.target_node)) == null:
				missing.append("%s → %s" % [anomaly.id, modification.target_node])
		room.apply_anomaly(anomaly)
		await _tree.process_frame
		room.reset()
		await _tree.process_frame
		await _tree.process_frame
		if _signature(room) != baseline:
			broken.append(anomaly.id)
	_report.check(missing.is_empty(), "todo target_node existe en room_base.tscn: %s" % str(missing))
	_report.check(broken.is_empty(), "las %d anomalías se aplican y se revierten sin dejar nodos ni colisiones rotas: %s" % [_catalog.size(), str(broken)])
	room.queue_free()
	await _tree.process_frame


## Foto del estado de la habitación: nodos, visibilidad, colisiones y posiciones.
func _signature(room: Node) -> String:
	var parts: Array[String] = []
	for node in room.get_node("World").find_children("*", "", true, false):
		var entry := str(node.get_path())
		if node is CanvasItem:
			entry += " v%s m%s" % [(node as CanvasItem).visible, (node as CanvasItem).modulate]
		if node is Node2D:
			entry += " p%s r%.2f s%s" % [(node as Node2D).position, (node as Node2D).rotation, (node as Node2D).scale]
		if node is CollisionShape2D:
			entry += " d%s" % (node as CollisionShape2D).disabled
		parts.append(entry)
	return "\n".join(parts)

# ---------------------------------------------------------------------------
# Sonidos con intervalo
# ---------------------------------------------------------------------------

func _check_sound_anomaly(driver: GameDriver, anomaly_id: String) -> void:
	var anomaly := _by_id[anomaly_id] as AnomalyData
	var effect: Dictionary = EntityAmbience.EFFECTS[anomaly.ambience]
	var sound: String = effect["sound"]
	var label := anomaly_id
	_report.check(not anomaly.modifications.is_empty() or effect["kind"] == "tremble", "%s: el sonido tiene también una pista visual (objeto o vibración)" % label)
	await _enter(driver, anomaly)
	var ambience := driver.room().ambience()
	_report.check(ambience.repeats_fired() == 0 and not AudioManager.is_active(sound), "%s: al entrar aún no suena (espera 1,5 s)" % label)
	Engine.time_scale = TIME_SCALE
	var target := driver.room().get_node("World/" + effect["target"]) as Node2D if effect["target"] != "" else null
	var rest_position := target.position if target != null else Vector2.ZERO
	_report.check(await _wait_for_repeats(ambience, 1), "%s: suena por primera vez" % label)
	_report.check(AudioManager.is_active(sound), "%s: se oye «%s» al primer aviso" % [label, sound])
	var shook := true
	if target != null:
		shook = await _watch_shake(target, rest_position)
	_report.check(shook, "%s: la vibración va con el sonido" % label)
	_report.check(await _wait_for_repeats(ambience, 2), "%s: el sonido se repite (%d veces)" % [label, ambience.repeats_fired()])
	await _check_pause(driver, ambience, sound, label)
	Engine.time_scale = 1.0
	driver.answer(AnswerEvaluator.Answer.ANOMALY)
	await _tree.process_frame
	_report.check(not AudioManager.is_active(sound) and not ambience.is_running(), "%s: al responder correctamente el sonido y el efecto se detienen" % label)
	if target != null:
		_report.check(target.position == rest_position, "%s: el objeto vuelve a su sitio" % label)
	await _check_fail_stops(driver, anomaly, sound, label)
	await _check_restart_stops(driver, anomaly, sound, label)


func _check_pause(driver: GameDriver, ambience: EntityAmbience, sound: String, label: String) -> void:
	driver.manager._toggle_pause()
	var fired := ambience.repeats_fired()
	await _wait_real(PAUSE_WATCH_MS)
	_report.check(ambience.repeats_fired() == fired and not AudioManager.is_playing(sound), "%s: durante la pausa no se repite ni suena" % label)
	driver.manager._toggle_pause()
	_report.check(await _wait_for_repeats(ambience, fired + 1), "%s: al reanudar vuelve a repetirse" % label)


func _check_fail_stops(driver: GameDriver, anomaly: AnomalyData, sound: String, label: String) -> void:
	await _enter(driver, anomaly)
	Engine.time_scale = TIME_SCALE
	await _wait_for_repeats(driver.room().ambience(), 1)
	Engine.time_scale = 1.0
	driver.answer(AnswerEvaluator.Answer.NO_ANOMALY)
	await _tree.process_frame
	_report.check(not AudioManager.is_active(sound), "%s: al fallar se detiene su sonido" % label)
	await driver.await_state(GameManager.State.REFERENCIA)
	await driver.await_idle()


func _check_restart_stops(driver: GameDriver, anomaly: AnomalyData, sound: String, label: String) -> void:
	await _enter(driver, anomaly)
	Engine.time_scale = TIME_SCALE
	await _wait_for_repeats(driver.room().ambience(), 1)
	Engine.time_scale = 1.0
	await driver.restart()
	_report.check(not AudioManager.is_active(sound), "%s: al reiniciar no queda su sonido" % label)


func _enter(driver: GameDriver, anomaly: AnomalyData) -> void:
	await driver.restart()
	await driver.enter_decision_room()
	await driver.force_anomaly(anomaly)


func _wait_for_repeats(ambience: EntityAmbience, count: int) -> bool:
	var deadline := Time.get_ticks_msec() + WAIT_DEADLINE_MS
	while ambience.repeats_fired() < count and Time.get_ticks_msec() < deadline:
		await _tree.process_frame
	return ambience.repeats_fired() >= count


func _watch_shake(target: Node2D, rest_position: Vector2) -> bool:
	var deadline := Time.get_ticks_msec() + SHAKE_WATCH_MS
	while Time.get_ticks_msec() < deadline:
		if target.position != rest_position:
			return true
		await _tree.process_frame
	return false


func _wait_real(milliseconds: int) -> void:
	var deadline := Time.get_ticks_msec() + milliseconds
	while Time.get_ticks_msec() < deadline:
		await _tree.process_frame

# ---------------------------------------------------------------------------
# Significado al acertar
# ---------------------------------------------------------------------------

func _check_meaning_on_success(driver: GameDriver) -> void:
	var hud := driver.manager._hud
	var panel := hud.get_node("Root/ResultContainer/ResultPanel") as Control
	var meaning_label := hud.get_node("Root/ResultContainer/ResultPanel/Margin/ResultBox/ResultMeaning") as Label
	var avoided: Array[Control] = [hud._round_label, hud._danger_label, hud._notice_label, hud._prompt_label]
	var bad: Array[String] = []
	for anomaly in _catalog:
		await driver.restart()
		await driver.enter_decision_room()
		await driver.force_anomaly(anomaly)
		driver.answer(AnswerEvaluator.Answer.ANOMALY)
		await _tree.process_frame
		await _tree.process_frame
		var rect := panel.get_global_rect()
		var inside := SCREEN.encloses(rect)
		var clear := avoided.all(func(label: Control) -> bool: return not rect.intersects(label.get_global_rect()))
		if not (meaning_label.visible and meaning_label.text == anomaly.meaning and inside and clear):
			bad.append(anomaly.id)
	_report.check(bad.is_empty(), "al acertar aparece el significado, cabe en pantalla y no tapa la HUD (%d anomalías): %s" % [_catalog.size(), str(bad)])
	await driver.restart()
	await driver.enter_decision_room()
	await driver.force_anomaly(null)
	driver.answer(AnswerEvaluator.Answer.NO_ANOMALY)
	await _tree.process_frame
	_report.check(not meaning_label.visible and meaning_label.text.is_empty(), "en una ronda normal no aparece ningún significado")
	await driver.restart()
	await driver.enter_decision_room()
	await driver.force_anomaly(_by_id["figura_cama"] as AnomalyData)
	driver.answer(AnswerEvaluator.Answer.NO_ANOMALY)
	await _tree.process_frame
	_report.check(not meaning_label.visible, "al fallar no se muestra el significado")
	await driver.await_state(GameManager.State.REFERENCIA)
	await driver.await_idle()

# ---------------------------------------------------------------------------
# Colocación de los objetos nuevos
# ---------------------------------------------------------------------------

func _check_new_objects_layout(driver: GameDriver) -> void:
	await driver.restart()
	await driver.enter_decision_room()
	await driver.force_anomaly(null)
	var world := driver.room().get_node("World")
	var hud := driver.manager._hud
	var hud_rects: Array[Rect2] = []
	for control: Control in [hud._round_label, hud._danger_label, hud._notice_label, hud._decision_bar.get_child(0)]:
		hud_rects.append(control.get_global_rect())
	hud_rects.append(_prompt_text_rect(hud._prompt_label))
	var desk := _used_rect(world.get_node("Desk/Sprite"))
	for item_name in NEW_OBJECTS_ON_DESK:
		_check_object(world, item_name, desk, hud_rects, "el escritorio")
	var mirror_cover := world.get_node("Mirror/Cover") as Sprite2D
	_check_object(world, "Mirror/Cover", _used_rect(world.get_node("Mirror")), hud_rects, "el espejo")
	var door_footprint := _footprint(world.get_node("Door"))
	for note_name in NEW_FLOOR_NOTES:
		var note_rect := _used_rect(world.get_node(note_name))
		_report.check(FLOOR_RECT.encloses(note_rect) and not note_rect.intersects(door_footprint), "%s está en el suelo, junto a la puerta y fuera de su marco" % note_name)
		_check_object(world, note_name, FLOOR_RECT, hud_rects, "el suelo")
	var flower_rect := _used_rect(world.get_node("Plant/Flower"))
	var plant_rect := _used_rect(world.get_node("Plant"))
	var inside_share := flower_rect.intersection(plant_rect).get_area() / flower_rect.get_area()
	_report.check(inside_share >= MIN_FLOWER_SHARE, "la flor nace sobre la planta (%d %% dentro de ella)" % roundi(inside_share * 100.0))
	_check_object(world, "Plant/Flower", Rect2(), hud_rects, "la planta")
	_report.check(mirror_cover.visible == false and world.get_node("DeskGlass").visible == false, "los objetos nuevos empiezan ocultos")
	var overlap_pairs := _new_object_overlaps(world)
	_report.check(overlap_pairs.is_empty(), "ningún objeto nuevo se solapa con otro de la habitación: %s" % str(overlap_pairs))


## Lo que ocupa de verdad el aviso «E — Examinar …» (centrado) con el texto más largo.
func _prompt_text_rect(label: Label) -> Rect2:
	var font := label.get_theme_font("font")
	var size := label.get_theme_font_size("font_size")
	var text_width := font.get_string_size(LONGEST_PROMPT, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var box := label.get_global_rect()
	return Rect2(box.get_center().x - text_width / 2.0, box.position.y, text_width, box.size.y)


func _check_object(world: Node, path: String, support: Rect2, hud_rects: Array[Rect2], support_name: String) -> void:
	var sprite := world.get_node(path) as Sprite2D
	var rect := _used_rect(sprite)
	if support.has_area():
		_report.check(support.encloses(rect), "%s queda dentro de %s %s" % [path, support_name, rect])
	var screen_rect := sprite.get_global_transform_with_canvas() * sprite.get_rect()
	var under_hud := hud_rects.any(func(hud_rect: Rect2) -> bool: return screen_rect.intersects(hud_rect))
	_report.check(SCREEN.encloses(screen_rect) and not under_hud, "%s no queda bajo la HUD ni fuera de pantalla" % path)


func _new_object_overlaps(world: Node) -> Array[String]:
	var overlaps: Array[String] = []
	var fresh: Array[String] = []
	fresh.append_array(NEW_OBJECTS_ON_DESK)
	fresh.append_array(NEW_FLOOR_NOTES)
	fresh.append_array(["Mirror/Cover", "Plant/Flower"])
	for path in fresh:
		var rect := _used_rect(world.get_node(path))
		for other in OTHER_OBJECTS + fresh:
			if other == path or path.begins_with(other + "/"):
				continue
			var node := world.get_node_or_null(other)
			if node == null:
				continue
			var sprite := node if node is Sprite2D else node.get_node_or_null("Sprite")
			if sprite != null and rect.intersects(_used_rect(sprite)):
				overlaps.append("%s × %s" % [path, other])
	return overlaps


## Lo realmente dibujado del sprite, en coordenadas del mundo.
func _used_rect(sprite_node: Node) -> Rect2:
	var sprite := sprite_node as Sprite2D
	var image := sprite.texture.get_image()
	var used := image.get_used_rect()
	var local := Rect2(Vector2(used.position) - Vector2(image.get_size()) / 2.0 + sprite.offset, Vector2(used.size))
	return sprite.get_global_transform() * local


func _footprint(body: Node) -> Rect2:
	var shape := body.get_node("CollisionShape2D") as CollisionShape2D
	var size := (shape.shape as RectangleShape2D).size
	return Rect2(shape.global_position - size / 2.0, size)
