extends Control

## Galería de las 36 anomalías: cada una con «Normal» y «Anómala». Al pulsar
## «Anómala» se aplica sobre la habitación (con su efecto y sus sonidos) y se
## muestran su pista, su significado, su tema y su dificultad.

const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const AnomalyReport := preload("res://dev/anomaly_report.gd")
const ROOM_SCENE := preload("res://scenes/rooms/room_base.tscn")
const ANOMALY_DIR := "res://resources/anomalies/"
const ROOM_SCALE := 0.62
const ROOM_ORIGIN := Vector2(570, 14)
const WORLD_CORNER := Vector2(224, 24)
const NAME_WIDTH := 250.0
const ROW_FONT_SIZE := 18
const DANGER_MARK := " (P)"

@onready var _rows: VBoxContainer = $List/Rows
@onready var _stage: Node2D = $Stage
@onready var _info: Label = $Info

var _room: Room


func _ready() -> void:
	theme = UiTheme.build()
	_build_room()
	var catalog: Array[AnomalyData] = []
	catalog.assign(CatalogLoader.load_all(ANOMALY_DIR, AnomalyData))
	for anomaly in AnomalyReport.sorted(catalog):
		_rows.add_child(_make_row(anomaly))
	_show_normal()


func _build_room() -> void:
	_room = ROOM_SCENE.instantiate() as Room
	_room.scale = Vector2.ONE * ROOM_SCALE
	_room.position = ROOM_ORIGIN - WORLD_CORNER * ROOM_SCALE
	_stage.add_child(_room)


func _make_row(anomaly: AnomalyData) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = "%s · %s%s" % [AnomalyReport.difficulty_name(anomaly).substr(0, 1), anomaly.id, DANGER_MARK if anomaly.is_dangerous else ""]
	label.custom_minimum_size.x = NAME_WIDTH
	label.add_theme_font_size_override("font_size", ROW_FONT_SIZE)
	row.add_child(label)
	row.add_child(_make_button("Normal", _show_normal))
	row.add_child(_make_button("Anómala", _show_anomaly.bind(anomaly)))
	return row


func _make_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", ROW_FONT_SIZE)
	button.pressed.connect(action)
	return button


func _show_normal() -> void:
	_room.reset()
	_info.text = "Habitación normal."


func _show_anomaly(anomaly: AnomalyData) -> void:
	_room.reset()
	_room.apply_anomaly(anomaly)
	_info.text = "%s  (%s)\nObjeto: %s · Tema: %s · Dificultad: %s · %s\nPista: %s\nSignificado: %s\nEfecto: %s" % [
		anomaly.display_name, anomaly.id, anomaly.focus_object, AnomalyReport.topic_name(anomaly),
		AnomalyReport.difficulty_name(anomaly), "peligrosa" if anomaly.is_dangerous else "no peligrosa",
		anomaly.tell, anomaly.meaning, AnomalyReport.effect_text(anomaly),
	]
