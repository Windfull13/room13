extends RefCounted

## Todas las pantallas del juego, cada una llevada a un estado representativo.
## Lo usan tests/test_polish_layout.gd (comprobación geométrica a 4
## resoluciones) y dev/capture_evidence.gd (capturas reales para docs/evidencias).
##
## Cada pantalla se monta dentro de un SubViewport del tamaño de la resolución
## con size_2d_override = 1280×720: es lo mismo que hace el modo de estirado
## canvas_items del proyecto con la ventana real.

const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const BASE_SIZE := Vector2i(1280, 720)
const RESOLUTIONS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(1366, 768), Vector2i(1600, 900)]
const SCREENS: Array[String] = [
	"menu", "opciones", "creditos", "pre_juego", "trivia", "como_jugar", "historia",
	"habitacion", "galeria_anomalias", "pasillo_recuerdo", "susto", "cinematica",
	"resultados", "encuesta", "ayuda",
]
const TITLES := {
	"menu": "Menú principal", "opciones": "Opciones", "creditos": "Créditos",
	"pre_juego": "Pre-juego: propósito y consentimiento", "trivia": "Trivia (pregunta 1/8)",
	"como_jugar": "Cómo jugar", "historia": "Historia de entrada", "habitacion": "Habitación de referencia",
	"galeria_anomalias": "Galería de anomalías (herramienta)", "pasillo_recuerdo": "Pasillo con recuerdo (hacia la ronda 3)",
	"susto": "Susto (cama)", "cinematica": "Cinemática «La última puerta»", "resultados": "Resultados",
	"encuesta": "Encuesta", "ayuda": "Ayuda y agradecimiento",
}
const LEAF_TYPES: Array[String] = ["Label", "Button", "CheckBox", "LineEdit", "HSlider"]
const MIN_VISIBLE_ALPHA := 0.05
const LONG_TEXT := 60
const MIN_LONG_TEXT_SIZE := 22
const MENU_ENTRY_SECONDS := 1.3


## Un SubViewport de la resolución pedida que dibuja a 1280×720 lógicos.
static func make_viewport(resolution: Vector2i) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = resolution
	viewport.size_2d_override = BASE_SIZE
	viewport.size_2d_override_stretch = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	return viewport


## Monta la pantalla en `viewport` y la deja en su estado. Devuelve su nodo raíz.
static func open(screen: String, viewport: SubViewport, tree: SceneTree) -> Node:
	match screen:
		"menu", "opciones", "creditos":
			return await _menu(screen, viewport, tree)
		"pre_juego", "trivia":
			return await _pre_game(screen, viewport, tree)
		"como_jugar":
			var howto := _dark_host(viewport)
			var view := HowToView.new()
			howto.add_child(view)
			view.setup(LearningContent.default(), "CONTINUAR")
			await _seconds(tree, 0.5)
			return howto
		"historia":
			var host := _dark_host(viewport)
			var pages := PageView.new()
			host.add_child(pages)
			pages.show_pages(LearningContent.default().intro_pages, LearningContent.default().page_hint)
			await _seconds(tree, 0.9)
			return host
		"habitacion":
			return await _room(viewport, tree)
		"galeria_anomalias":
			var gallery: Node = (load("res://dev/anomaly_gallery.tscn") as PackedScene).instantiate()
			viewport.add_child(gallery)
			await _seconds(tree, 0.5)
			return gallery
		"pasillo_recuerdo":
			return await _corridor(viewport, tree)
		"susto":
			var scare: Node = (load("res://scenes/jumpscares/jumpscare_figura_cama.tscn") as PackedScene).instantiate()
			viewport.add_child(scare)
			scare.call("play", 1.0)
			await _seconds(tree, 0.45)
			return scare
		"cinematica":
			return await _cinematic(viewport, tree)
		"resultados", "encuesta", "ayuda":
			return await _post_view(screen, viewport, tree)
	return null


static func close(root: Node) -> void:
	if root != null and is_instance_valid(root):
		if root.has_method("set") and root.get("navigates") != null:
			root.set("navigates", false)
		root.queue_free()

# ---------------------------------------------------------------------------
# Comprobación geométrica
# ---------------------------------------------------------------------------

## Problemas de maquetación: controles visibles fuera de la pantalla lógica,
## solapados entre sí o con el texto recortado. Devuelve una lista legible.
static func layout_problems(root: Node) -> Array[String]:
	var problems: Array[String] = []
	var screen := Rect2(Vector2.ZERO, Vector2(BASE_SIZE)).grow(1.0)
	var leaves := visible_leaves(root)
	for control in leaves:
		var rect := control.get_global_rect()
		if not _inside_scroll(control) and not screen.encloses(rect):
			problems.append("fuera de la pantalla: %s %s" % [_describe(control), rect])
		if _clips_text(control):
			problems.append("texto recortado: %s (necesita %s, tiene %s)" % [_describe(control), control.get_combined_minimum_size(), control.size])
	for i in range(leaves.size()):
		for j in range(i + 1, leaves.size()):
			if _overlap(leaves[i], leaves[j]):
				problems.append("solapados: %s y %s" % [_describe(leaves[i]), _describe(leaves[j])])
	return problems


## Bloques de texto largo con letra pequeña (aviso, no error).
static func small_long_texts(root: Node) -> Array[String]:
	var found: Array[String] = []
	for control in visible_leaves(root):
		var label := control as Label
		if label != null and label.text.length() > LONG_TEXT and label.get_theme_font_size("font_size") < MIN_LONG_TEXT_SIZE:
			found.append("%s (%d px)" % [_describe(label), label.get_theme_font_size("font_size")])
	return found


static func visible_leaves(root: Node) -> Array[Control]:
	var leaves: Array[Control] = []
	for node in root.find_children("*", "Control", true, false):
		var control := node as Control
		if not LEAF_TYPES.has(control.get_class()) or not control.is_visible_in_tree():
			continue
		if control is Label and (control as Label).text.strip_edges().is_empty():
			continue
		if _effective_alpha(control) < MIN_VISIBLE_ALPHA or control.size.x < 1.0 or control.size.y < 1.0:
			continue
		if _inside_scroll(control) and not _scroll_of(control).get_global_rect().intersects(control.get_global_rect()):
			continue
		leaves.append(control)
	return leaves


static func _overlap(a: Control, b: Control) -> bool:
	if a.is_ancestor_of(b) or b.is_ancestor_of(a):
		return false
	var shared := _shown_rect(a).intersection(_shown_rect(b))
	return shared.size.x > 2.0 and shared.size.y > 2.0


## Lo que se ve de un control: dentro de un ScrollContainer, solo la parte no recortada.
static func _shown_rect(control: Control) -> Rect2:
	var scroll := _scroll_of(control)
	if scroll == null:
		return control.get_global_rect()
	return control.get_global_rect().intersection(scroll.get_global_rect())


static func _clips_text(control: Control) -> bool:
	var label := control as Label
	if label != null and label.autowrap_mode != TextServer.AUTOWRAP_OFF:
		return false
	var needed := control.get_combined_minimum_size()
	return needed.x > control.size.x + 1.0 or needed.y > control.size.y + 1.0


static func _effective_alpha(item: CanvasItem) -> float:
	var alpha := 1.0
	var node: Node = item
	while node != null:
		if node is CanvasItem:
			alpha *= (node as CanvasItem).modulate.a * (node as CanvasItem).self_modulate.a if node == item else (node as CanvasItem).modulate.a
		node = node.get_parent()
	return alpha


static func _inside_scroll(control: Control) -> bool:
	return _scroll_of(control) != null


static func _scroll_of(control: Control) -> ScrollContainer:
	var node := control.get_parent()
	while node != null:
		if node is ScrollContainer:
			return node as ScrollContainer
		node = node.get_parent()
	return null


static func _describe(control: Control) -> String:
	var text := ""
	if control is Label:
		text = (control as Label).text
	elif control is Button:
		text = (control as Button).text
	return "%s «%s»" % [control.name, text.substr(0, 32).replace("\n", " ")]

# ---------------------------------------------------------------------------
# Montaje de cada pantalla
# ---------------------------------------------------------------------------

static func _seconds(tree: SceneTree, seconds: float) -> void:
	await tree.create_timer(seconds).timeout


static func _dark_host(viewport: SubViewport) -> Control:
	var host := Control.new()
	host.theme = UiTheme.build()
	host.size = Vector2(BASE_SIZE)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.025, 0.022, 0.03)
	backdrop.size = Vector2(BASE_SIZE)
	host.add_child(backdrop)
	viewport.add_child(host)
	return host


static func _menu(screen: String, viewport: SubViewport, tree: SceneTree) -> Node:
	var menu: Node = (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
	viewport.add_child(menu)
	await _seconds(tree, MENU_ENTRY_SECONDS)
	if screen == "opciones":
		menu.call("_show_screen", menu.get_node("OptionsScreen"))
	elif screen == "creditos":
		menu.call("_show_screen", menu.get_node("CreditsScreen"))
	await _seconds(tree, 0.4)
	return menu


static func _pre_game(screen: String, viewport: SubViewport, tree: SceneTree) -> Node:
	var flow := (load("res://scenes/learning/pre_game.tscn") as PackedScene).instantiate() as LearningFlow
	flow.navigates = false
	viewport.add_child(flow)
	await _seconds(tree, 0.5)
	if screen == "trivia":
		(flow.current_view() as InfoView).buttons()[1].pressed.emit()
		await _seconds(tree, 0.3)
		for node in flow.current_view().find_children("*", "Button", true, false):
			if (node as Button).text == "EMPEZAR":
				(node as Button).pressed.emit()
		await _seconds(tree, 0.5)
	return flow


static func _room(viewport: SubViewport, tree: SceneTree) -> Node:
	var game := (load("res://scenes/partida.tscn") as PackedScene).instantiate() as GameManager
	game.pacing = 0.0
	game.ending_scene = ""
	viewport.add_child(game)
	for i in range(600):
		if game.state == GameManager.State.REFERENCIA and not game._busy:
			break
		await tree.process_frame
	await _seconds(tree, 0.5)
	return game


static func _corridor(viewport: SubViewport, tree: SceneTree) -> Node:
	var corridor := (load("res://scenes/corridor.tscn") as PackedScene).instantiate() as Corridor
	viewport.add_child(corridor)
	var memory := MemoryTexts.default().corridor_memory_for(3)
	corridor.play(10.0, "Habitación 3 / 10", LearningContent.default().corridor_cards[2], memory)
	await _seconds(tree, 2.2)
	return corridor


static func _cinematic(viewport: SubViewport, tree: SceneTree) -> Node:
	var cinematic := (load("res://scenes/cinematic/last_door.tscn") as PackedScene).instantiate() as LastDoorCinematic
	cinematic.navigates = false
	cinematic.pacing = 0.25
	viewport.add_child(cinematic)
	for i in range(3000):
		if cinematic.phase == LastDoorCinematic.Phase.LIGHT and cinematic._elapsed > cinematic._duration(cinematic.phase) * 0.45:
			break
		await tree.process_frame
	cinematic.set_process(false)
	await tree.process_frame
	return cinematic


static func _post_view(screen: String, viewport: SubViewport, tree: SceneTree) -> Node:
	var host := _dark_host(viewport)
	var content := LearningContent.default()
	var questions := LearningContent.questions()
	match screen:
		"resultados":
			var pre := {}
			var post := {}
			for i in range(questions.size()):
				pre[questions[i].id] = questions[i].correct_index if i < 3 else -1
				post[questions[i].id] = questions[i].correct_index if i != 4 else 2
			var results := ResultsView.new()
			host.add_child(results)
			results.setup(questions, pre, post, content.results_memories_line % [7, ObjectMemoryCatalog.default().count()])
		"encuesta":
			var survey := SurveyView.new()
			host.add_child(survey)
			survey.setup(content)
		"ayuda":
			var help := InfoView.new()
			host.add_child(help)
			help.setup(content.help_title, [content.help_text, content.thanks_text], [content.help_button])
	await _seconds(tree, 0.5)
	return host
