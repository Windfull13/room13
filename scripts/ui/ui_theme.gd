extends RefCounted

## Lenguaje visual común de la interfaz (menú principal, pausa, HUD): letra
## gótica, fondos oscuros casi negros y un único acento cálido, sin brillos
## modernos. Las etiquetas grandes usan la variación «Titulo» (negra gótica).

const UI_FONT := preload("res://assets/fonts/PirataOne-Regular.ttf")
const TITLE_FONT := preload("res://assets/fonts/UnifrakturCook-Bold.ttf")

const TITLE_VARIATION := &"Titulo"
const DEFAULT_FONT_SIZE := 24
const BUTTON_MARGIN_X := 30
const BUTTON_MARGIN_Y := 12
const BORDER_WIDTH := 2
const ACCENT_BORDER := 5
const CORNER_RADIUS := 3
const PANEL_MARGIN := 18

const INK := Color(0.91, 0.88, 0.82)
const INK_DIM := Color(0.62, 0.6, 0.58)
const ACCENT := Color(0.86, 0.66, 0.38)
const BLOOD := Color(0.52, 0.09, 0.09)
const BORDER_IDLE := Color(0.34, 0.31, 0.3)
const BORDER_HOVER := Color(0.7, 0.55, 0.36)


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font = UI_FONT
	theme.default_font_size = DEFAULT_FONT_SIZE
	_style_buttons(theme)
	_style_titles(theme)
	theme.set_stylebox("panel", "PanelContainer", panel_style())
	return theme


## Panel oscuro de los menús (opciones, créditos, pausa).
static func panel_style() -> StyleBoxFlat:
	return _box(Color(0.035, 0.03, 0.04, 0.95), BORDER_IDLE, PANEL_MARGIN, PANEL_MARGIN, BORDER_WIDTH)


static func _style_buttons(theme: Theme) -> void:
	theme.set_stylebox("normal", "Button", _button_box(Color(0.07, 0.06, 0.07, 0.9), BORDER_IDLE, 0))
	theme.set_stylebox("hover", "Button", _button_box(Color(0.13, 0.1, 0.09, 0.96), BORDER_HOVER, ACCENT_BORDER))
	theme.set_stylebox("focus", "Button", _button_box(Color(0.13, 0.1, 0.09, 0.96), BORDER_HOVER, ACCENT_BORDER))
	theme.set_stylebox("pressed", "Button", _button_box(Color(0.03, 0.025, 0.03, 1.0), BLOOD, ACCENT_BORDER))
	theme.set_stylebox("disabled", "Button", _button_box(Color(0.06, 0.06, 0.06, 0.55), Color(0.2, 0.2, 0.2), 0))
	theme.set_color("font_color", "Button", INK)
	theme.set_color("font_hover_color", "Button", Color(1, 0.95, 0.85))
	theme.set_color("font_focus_color", "Button", Color(1, 0.95, 0.85))
	theme.set_color("font_pressed_color", "Button", ACCENT)
	theme.set_color("font_disabled_color", "Button", Color(0.4, 0.4, 0.4))


static func _style_titles(theme: Theme) -> void:
	theme.add_type(TITLE_VARIATION)
	theme.set_type_variation(TITLE_VARIATION, "Label")
	theme.set_font("font", TITLE_VARIATION, TITLE_FONT)
	theme.set_color("font_color", TITLE_VARIATION, INK)
	theme.set_color("font_outline_color", TITLE_VARIATION, Color(0, 0, 0, 0.95))
	theme.set_constant("outline_size", TITLE_VARIATION, 6)


## Botón con un filo de acento a la izquierda cuando está activo (hover o foco).
static func _button_box(background: Color, border: Color, accent_left: int) -> StyleBoxFlat:
	var box := _box(background, border, BUTTON_MARGIN_X, BUTTON_MARGIN_Y, BORDER_WIDTH)
	if accent_left > 0:
		box.border_width_left = accent_left
	return box


static func _box(background: Color, border: Color, margin_x: int, margin_y: int, border_width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(CORNER_RADIUS)
	box.content_margin_left = margin_x
	box.content_margin_right = margin_x
	box.content_margin_top = margin_y
	box.content_margin_bottom = margin_y
	return box