class_name JumpscarePlayer
extends CanvasLayer

## Lanza el susto de la entidad que ha matado al jugador y avisa al terminar.
##
## El coordinador solo escucha `finished`: no sabe qué forma tiene el susto.
## Si la escena falta o no termina, el aviso sale igualmente al agotarse el
## tiempo de seguridad, así que nunca se puede quedar atascado.

## Se emite una sola vez por susto, pase lo que pase.
signal finished

const FALLBACK_DURATION := 1.2
const SAFETY_MARGIN := 0.8

var _running := false
## Ruta de la escena del último susto reproducido ("" si no hubo).
var last_played_path: String = ""


## Reproduce `jumpscare_scene`. Con null solo espera un instante y avisa.
## `time_scale` acorta el susto (las pruebas lo ponen a 0).
func play(jumpscare_scene: PackedScene, time_scale: float = 1.0) -> void:
	if _running:
		return
	_running = true
	last_played_path = jumpscare_scene.resource_path if jumpscare_scene != null else ""
	var duration := FALLBACK_DURATION
	if jumpscare_scene != null:
		var instance: Node = jumpscare_scene.instantiate()
		if instance is JumpscareBase:
			var jumpscare := instance as JumpscareBase
			duration = jumpscare.duration
			add_child(jumpscare)
			jumpscare.finished.connect(_on_jumpscare_finished.bind(jumpscare))
			jumpscare.play(time_scale)
		elif instance != null:
			instance.free()
	get_tree().create_timer(duration * time_scale + SAFETY_MARGIN).timeout.connect(_on_safety_timeout)


## Libera lo que quede colgado (se usa al reiniciar la partida).
func clear() -> void:
	_running = false
	for child in get_children():
		child.queue_free()


func _on_jumpscare_finished(jumpscare: JumpscareBase) -> void:
	if is_instance_valid(jumpscare):
		jumpscare.queue_free()
	_notify_finished()


func _on_safety_timeout() -> void:
	_notify_finished()


func _notify_finished() -> void:
	if not _running:
		return
	_running = false
	finished.emit()