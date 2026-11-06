extends Control

## Herramienta interna: reproduce cualquiera de los sustos sin jugar.
## Crea un botón por cada anomalía del catálogo que tenga susto.

const CATALOG_DIR := "res://resources/anomalies/"

@onready var _buttons: VBoxContainer = $Panel/Margin/Buttons
@onready var _status: Label = $Panel/Margin/Buttons/Status
@onready var _jumpscares: JumpscarePlayer = $Jumpscares


func _ready() -> void:
	for anomaly: AnomalyData in CatalogLoader.load_all(CATALOG_DIR, AnomalyData):
		if anomaly.jumpscare_scene != null:
			_add_button(anomaly)
	_jumpscares.finished.connect(_on_finished)


func _add_button(anomaly: AnomalyData) -> void:
	var button := Button.new()
	button.name = anomaly.id
	button.text = anomaly.id
	button.custom_minimum_size = Vector2(320, 44)
	button.pressed.connect(_play.bind(anomaly))
	_buttons.add_child(button)


func _play(anomaly: AnomalyData) -> void:
	_set_buttons_enabled(false)
	_status.text = "Reproduciendo: %s" % anomaly.id
	_jumpscares.play(anomaly.jumpscare_scene)


func _on_finished() -> void:
	_status.text = "Elige un susto"
	_set_buttons_enabled(true)


func _set_buttons_enabled(enabled: bool) -> void:
	for child in _buttons.get_children():
		if child is Button:
			(child as Button).disabled = not enabled