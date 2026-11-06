class_name LearningUi
extends RefCounted

## Piezas de interfaz que comparten todas las pantallas de aprendizaje, para no
## repetir la creación de títulos, textos, botones y paneles.

const TEXT_SIZE := 26
const SMALL_TEXT_SIZE := 22
const TITLE_SIZE := 54
const BUTTON_SIZE := 28
const BUTTON_HEIGHT := 58.0
const PANEL_WIDTH := 960.0
const SECTION_GAP := 22
const FADE_TIME := 0.35
const DIM_TEXT := Color(0.7, 0.68, 0.66)
const CLICK_SOUND := "ui_click"


static func title(text: String, size: int = TITLE_SIZE) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"Titulo"
	label.add_theme_font_size_override("font_size", size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


## Texto largo con salto de línea automático dentro de un ancho fijo.
static func body(text: String, width: float = PANEL_WIDTH - 60.0, size: int = TEXT_SIZE) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(width, 0)
	label.add_theme_font_size_override("font_size", size)
	return label


static func hint(text: String) -> Label:
	var label := body(text, PANEL_WIDTH - 60.0, SMALL_TEXT_SIZE)
	label.add_theme_color_override("font_color", DIM_TEXT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


## Botón del tema con sus animaciones y el sonido de clic.
static func button(text: String, width: float = 340.0) -> Button:
	var made := Button.new()
	made.text = text
	made.custom_minimum_size = Vector2(width, BUTTON_HEIGHT)
	made.add_theme_font_size_override("font_size", BUTTON_SIZE)
	made.pressed.connect(AudioManager.play.bind(CLICK_SOUND))
	ButtonFx.attach(made)
	return made


## Panel oscuro centrado con una columna dentro. Devuelve la columna.
static func centered_column(host: Control, separation: int = SECTION_GAP) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", separation)
	panel.add_child(column)
	return column


## Fila horizontal centrada para botones.
static func button_row(buttons: Array[Button]) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	for each in buttons:
		row.add_child(each)
	return row


static func fade_in(node: CanvasItem, time: float = FADE_TIME) -> Tween:
	node.modulate.a = 0.0
	var tween := node.create_tween()
	tween.tween_property(node, "modulate:a", 1.0, time)
	return tween
