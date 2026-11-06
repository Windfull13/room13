class_name VolumeSlider
extends HSlider

## Volumen general del juego. Funciona en cualquier menú: basta con instanciar
## scenes/ui/volume_control.tscn. AudioManager guarda el valor al cambiarlo.


func _ready() -> void:
	min_value = 0.0
	max_value = 1.0
	step = 0.01
	set_value_no_signal(AudioManager.get_master_volume())
	value_changed.connect(AudioManager.set_master_volume)