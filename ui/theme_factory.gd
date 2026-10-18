class_name ThemeFactory
extends RefCounted
## Builds the grey-box Theme in code: thin 1 px lines on dark panels, cyan for anything you can press.
## M5 replaces this with a Theme resource, real fonts and corner-bracket frames.


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 16

	theme.set_stylebox("panel", "PanelContainer", _box(Palette.PANEL, Palette.LINE, 1, 4, 14.0))
	theme.set_type_variation("RowPanel", "PanelContainer")
	theme.set_stylebox("panel", "RowPanel", _box(Palette.ROW, Palette.LINE, 1, 3, 6.0))

	theme.set_stylebox("normal", "Button", _box(Color(Palette.CYAN, 0.06), Color(Palette.CYAN, 0.55), 1, 3, 10.0))
	theme.set_stylebox("hover", "Button", _box(Color(Palette.CYAN, 0.14), Color(Palette.CYAN, 0.9), 1, 3, 10.0))
	theme.set_stylebox("pressed", "Button", _box(Color(Palette.CYAN, 0.28), Palette.CYAN, 1, 3, 10.0))
	theme.set_stylebox("hover_pressed", "Button", _box(Color(Palette.CYAN, 0.32), Palette.CYAN, 1, 3, 10.0))
	theme.set_stylebox("disabled", "Button", _box(Color(0, 0, 0, 0), Palette.LINE, 1, 3, 10.0))
	theme.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), Palette.ICE, 2, 3, 10.0))
	theme.set_color("font_color", "Button", Palette.ICE)
	theme.set_color("font_hover_color", "Button", Palette.ICE)
	theme.set_color("font_pressed_color", "Button", Palette.ICE)
	theme.set_color("font_hover_pressed_color", "Button", Palette.ICE)
	theme.set_color("font_focus_color", "Button", Palette.ICE)
	theme.set_color("font_disabled_color", "Button", Palette.MUTED)

	theme.set_color("font_color", "Label", Palette.ICE)
	return theme


static func _box(bg: Color, border: Color, border_width: int, radius: int, padding: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(padding)
	return box
