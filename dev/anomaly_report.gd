extends RefCounted

## Textos comunes de las herramientas de desarrollo (galería, catálogo
## exportado, hoja de contacto): nombres de enumeraciones y descripción del
## efecto o sonido de una anomalía. Se carga con load(), no con class_name.

const MISSING := "—"


static func difficulty_name(anomaly: AnomalyData) -> String:
	return AnomalyData.Difficulty.keys()[anomaly.difficulty]


static func topic_name(anomaly: AnomalyData) -> String:
	return AnomalyData.Topic.keys()[anomaly.theme]


## Orden de las listas: por dificultad y, dentro de ella, por id.
static func sorted(catalog: Array[AnomalyData]) -> Array[AnomalyData]:
	var result: Array[AnomalyData] = catalog.duplicate()
	result.sort_custom(func(a: AnomalyData, b: AnomalyData) -> bool:
		if a.difficulty != b.difficulty:
			return a.difficulty < b.difficulty
		return a.id < b.id)
	return result


## Qué hace la anomalía además de cambiar objetos: efecto de entorno, sonido y susto.
static func effect_text(anomaly: AnomalyData) -> String:
	var parts: Array[String] = []
	if not anomaly.ambience.is_empty():
		parts.append(_ambience_text(anomaly.ambience))
	if anomaly.jumpscare_scene != null:
		parts.append("susto %s" % anomaly.jumpscare_scene.resource_path.get_file().get_basename())
	return " · ".join(parts) if not parts.is_empty() else MISSING


static func _ambience_text(effect_name: String) -> String:
	var effect: Dictionary = EntityAmbience.EFFECTS.get(effect_name, {})
	var text := effect_name
	var details: Array[String] = []
	if not effect.get("target", "").is_empty():
		details.append("%s en %s" % [effect.get("kind", ""), effect["target"]])
	elif effect.get("kind", "") != "":
		details.append(effect["kind"])
	if effect.has("sound"):
		details.append("sonido %s" % effect["sound"])
	if effect.has("interval"):
		details.append("cada %s s" % effect["interval"])
	return "%s (%s)" % [text, ", ".join(details)] if not details.is_empty() else text
