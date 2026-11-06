extends JumpscareBase

## El reflejo que ya no eres tú: una identidad deformada por el duelo. El
## protagonista se mueve; su reflejo le imita un instante y de pronto deja de
## hacerlo y se lanza contra el cristal, que se resquebraja.

const MIMIC_UNTIL := 0.45
const LUNGE_AT := 0.8
const SWAY := 16.0
const SWAY_SPEED := 9.0
const REFLECTION_HOME := Vector2(640, 385)
const REFLECTION_NEAR := Vector2(640, 430)
const SCALE_FROM := 7.0
const SCALE_TO := 15.0

@onready var _protagonista: Sprite2D = $Visual/Protagonista
@onready var _reflejo: Sprite2D = $Visual/Reflejo
@onready var _grietas: Array[Node] = $Visual/Grietas.get_children()

var _protagonista_home := Vector2.ZERO


func _on_start() -> void:
	_protagonista_home = _protagonista.position
	_reflejo.position = REFLECTION_HOME
	_reflejo.scale = Vector2.ONE * SCALE_FROM
	for crack in _grietas:
		(crack as CanvasItem).modulate.a = 0.0


func _on_update(elapsed: float) -> void:
	var sway := sin(elapsed * SWAY_SPEED) * SWAY
	_protagonista.position = _protagonista_home + Vector2(sway, 0)
	var mimic := 1.0 - ramp(elapsed, MIMIC_UNTIL, MIMIC_UNTIL + 0.05)
	var lunge := smooth(ramp(elapsed, LUNGE_AT, LUNGE_AT + 0.18))
	_reflejo.position = REFLECTION_HOME.lerp(REFLECTION_NEAR, lunge) + Vector2(-sway * mimic, 0)
	_reflejo.scale = Vector2.ONE * lerpf(SCALE_FROM, SCALE_TO, lunge)
	_reflejo.modulate.a = lerpf(0.78, 1.0, lunge)
	for i in range(_grietas.size()):
		(_grietas[i] as CanvasItem).modulate.a = ramp(elapsed, LUNGE_AT + 0.1 + i * 0.05, LUNGE_AT + 0.16 + i * 0.05)