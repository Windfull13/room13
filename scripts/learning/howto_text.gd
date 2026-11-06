class_name HowToText
extends RefCounted

## Construye el texto de «Cómo jugar» con las teclas REALES del InputMap, de modo
## que si se reasignan los controles el texto sigue siendo cierto.

const MOVE_ACTIONS: Array[String] = ["move_up", "move_left", "move_down", "move_right"]
const INTERACT_ACTIONS: Array[String] = ["interact"]
const PAUSE_ACTIONS: Array[String] = ["pause"]

const ARROW_KEYS: Array[Key] = [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]
const ESCAPE_NAME := "Esc"
const ARROWS_NAME := "las flechas"
const JOIN_WORD := " o "

const PLACEHOLDERS: Dictionary = {
	"{mover}": MOVE_ACTIONS,
	"{interactuar}": INTERACT_ACTIONS,
	"{pausa}": PAUSE_ACTIONS,
	"{decidir_hay}": ["decide_anomaly"],
	"{decidir_no_hay}": ["decide_no_anomaly"],
	"{pantalla_completa}": ["toggle_fullscreen"],
}


## Objetivo, controles (con las teclas sustituidas) y la regla de reinicio.
static func build(content: LearningContent) -> String:
	var lines: PackedStringArray = [content.howto_goal, ""]
	for control in content.howto_controls:
		lines.append("• " + substitute(control))
	lines.append("")
	lines.append(content.howto_rule)
	return "\n".join(lines)


static func substitute(template: String) -> String:
	var result := template
	for placeholder: String in PLACEHOLDERS:
		result = result.replace(placeholder, describe_actions(PLACEHOLDERS[placeholder]))
	return result


## «W, A, S, D o las flechas», «E», «Esc»... según lo que tengan asignado las acciones.
static func describe_actions(actions: Array) -> String:
	var letters: Array[String] = []
	var has_arrows := false
	for action: String in actions:
		for event in InputMap.action_get_events(action):
			var key := event as InputEventKey
			if key == null:
				continue
			if ARROW_KEYS.has(key.physical_keycode):
				has_arrows = true
			else:
				_append_unique(letters, key_label(key))
	if has_arrows:
		letters.append(ARROWS_NAME)
	return _join(letters)


static func key_label(key: InputEventKey) -> String:
	var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
	if code == KEY_ESCAPE:
		return ESCAPE_NAME
	return OS.get_keycode_string(code)


static func _append_unique(list: Array[String], value: String) -> void:
	if not list.has(value):
		list.append(value)


## «a, b, c o d»: comas y una «o» antes del último elemento.
static func _join(items: Array[String]) -> String:
	if items.size() <= 1:
		return "".join(items)
	var head := ", ".join(items.slice(0, items.size() - 1))
	return head + JOIN_WORD + items[items.size() - 1]
