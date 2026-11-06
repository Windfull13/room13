extends RefCounted

## Cada susto carga, se instancia y termina avisando. El reproductor nunca se
## queda atascado, ni siquiera cuando la escena falta o no es un susto.

const Reporter := preload("res://tests/reporter.gd")
const JUMPSCARE_DIR := "res://scenes/jumpscares/"
const BASE_SCENE := "res://scenes/jumpscares/jumpscare_base.tscn"
const EXPECTED_SCENES := 9
const MIN_DURATION := 1.0
const MAX_DURATION := 2.0
const FRAME_BUDGET := 900

var _finished := false


func run(report: Reporter, tree: SceneTree) -> void:
	report.start("Sustos: escenas, duración y fin garantizado")
	var player := JumpscarePlayer.new()
	tree.root.add_child(player)
	await tree.process_frame
	var scenes := _scene_paths()
	report.check(scenes.size() == EXPECTED_SCENES, "hay %d escenas de susto (encontradas %d)" % [EXPECTED_SCENES, scenes.size()])
	for path in scenes:
		await _check_scene(report, tree, player, path)
	await _check_never_stuck(report, tree, player)
	player.queue_free()
	await tree.process_frame
	_check_layer_order(report)


## El susto se dibuja por encima de la HUD y por debajo del fundido.
func _check_layer_order(report: Reporter) -> void:
	var game := (load("res://scenes/partida.tscn") as PackedScene).instantiate()
	var hud := (game.get_node("HUD") as CanvasLayer).layer
	var jumpscares := (game.get_node("Jumpscares") as CanvasLayer).layer
	var transition := (game.get_node("Transition") as CanvasLayer).layer
	report.check(hud < jumpscares and jumpscares < transition, "capas: HUD %d < sustos %d < fundido %d" % [hud, jumpscares, transition])
	game.free()


func _scene_paths() -> Array[String]:
	var paths: Array[String] = []
	var dir := DirAccess.open(JUMPSCARE_DIR)
	if dir == null:
		return paths
	for file_name in dir.get_files():
		if file_name.ends_with(".tscn") and file_name != "jumpscare_base.tscn":
			paths.append(JUMPSCARE_DIR + file_name)
	paths.sort()
	return paths


func _check_scene(report: Reporter, tree: SceneTree, player: JumpscarePlayer, path: String) -> void:
	var file_name := path.get_file()
	var packed: PackedScene = load(path)
	if packed == null:
		report.check(false, "%s carga" % file_name)
		return
	var probe := packed.instantiate()
	report.check(probe is JumpscareBase, "%s es un susto" % file_name)
	report.check(probe.duration >= MIN_DURATION and probe.duration <= MAX_DURATION, "%s dura entre 1 y 2 s (%.1f)" % [file_name, probe.duration])
	var sprites := 0
	for child in probe.get_node("Visual").get_children():
		if child is Sprite2D:
			sprites += 1
	report.check(sprites > 0, "%s tiene dibujo propio (%d sprites)" % [file_name, sprites])
	probe.free()
	player.last_played_path = ""
	report.check(await _play_and_wait(tree, player, packed), "%s termina y avisa" % file_name)
	report.check(player.last_played_path == path, "%s es el susto reproducido" % file_name)
	await tree.process_frame
	report.check(player.get_child_count() == 0, "%s no deja nodos colgados" % file_name)


func _check_never_stuck(report: Reporter, tree: SceneTree, player: JumpscarePlayer) -> void:
	report.check(await _play_and_wait(tree, player, null), "sin escena, el reproductor avisa igualmente")
	report.check(await _play_and_wait(tree, player, load("res://scenes/player.tscn")), "con una escena que no es susto, avisa igualmente")
	report.check(await _play_and_wait(tree, player, load(BASE_SCENE)), "con la escena base, avisa igualmente")


func _play_and_wait(tree: SceneTree, player: JumpscarePlayer, packed: PackedScene) -> bool:
	_finished = false
	player.finished.connect(_on_player_finished)
	player.play(packed, 0.0)
	for i in range(FRAME_BUDGET):
		if _finished:
			break
		await tree.process_frame
	player.finished.disconnect(_on_player_finished)
	return _finished


func _on_player_finished() -> void:
	_finished = true