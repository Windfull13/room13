extends RefCounted

## Convierte CREDITS.md en BBCode para un RichTextLabel. Solo entiende lo que
## usa ese archivo: títulos, tablas, negritas, código y enlaces.

const TITLE_SIZE := 30
const SECTION_SIZE := 24
const ROW_BULLET := "•  "
const CELL_SEPARATOR := "  —  "

static var _link := _regex("\\[([^\\]]+)\\]\\([^)]+\\)")
static var _bare_link := _regex("<(https?://[^>]+)>")
static var _bold := _regex("\\*\\*([^*]+)\\*\\*")
static var _code := _regex("`([^`]+)`")


static func from_markdown(markdown: String) -> String:
	var lines: Array[String] = []
	var previous_was_prose := false
	for raw_line in markdown.split("\n"):
		var line := raw_line.strip_edges()
		var is_prose := _is_prose(line)
		if _is_table_separator(line):
			_mark_last_as_header(lines)
		elif is_prose and previous_was_prose:
			lines[-1] += " " + _inline(line)
		else:
			lines.append(_convert_line(line))
		previous_was_prose = is_prose
	return "\n".join(lines).strip_edges()


## Texto corrido: sus saltos de línea en el archivo no son saltos reales.
static func _is_prose(line: String) -> bool:
	return not line.is_empty() and not line.begins_with("#") and not line.begins_with("|") and not line.begins_with("- ")


static func _convert_line(line: String) -> String:
	if line.begins_with("- "):
		return ROW_BULLET + _inline(line.substr(2))
	if line.begins_with("### "):
		return "[b]%s[/b]" % _inline(line.substr(4))
	if line.begins_with("## "):
		return "[font_size=%d][b]%s[/b][/font_size]" % [SECTION_SIZE, _inline(line.substr(3))]
	if line.begins_with("# "):
		return "[font_size=%d][b]%s[/b][/font_size]" % [TITLE_SIZE, _inline(line.substr(2))]
	if line.begins_with("|"):
		return ROW_BULLET + CELL_SEPARATOR.join(_cells(line))
	return _inline(line)


static func _inline(text: String) -> String:
	text = _link.sub(text, "$1", true)
	text = _bare_link.sub(text, "$1", true)
	text = _bold.sub(text, "[b]$1[/b]", true)
	return _code.sub(text, "$1", true)


static func _cells(row: String) -> Array[String]:
	var cells: Array[String] = []
	for cell in row.trim_prefix("|").trim_suffix("|").split("|"):
		cells.append(_inline(cell.strip_edges()))
	return cells


static func _is_table_separator(line: String) -> bool:
	return line.begins_with("|") and line.replace("|", "").replace("-", "").replace(":", "").strip_edges().is_empty()


## La fila anterior al separador es la cabecera de la tabla: va en cursiva y
## sin viñeta.
static func _mark_last_as_header(lines: Array[String]) -> void:
	if lines.is_empty():
		return
	lines[-1] = "[i]%s[/i]" % lines[-1].trim_prefix(ROW_BULLET)


static func _regex(pattern: String) -> RegEx:
	var regex := RegEx.new()
	regex.compile(pattern)
	return regex