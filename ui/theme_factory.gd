class_name ThemeFactory
extends RefCounted
## Builds the grey-box Theme in code: thin 1 px lines on dark panels, cyan for anything you can press.
## M5 replaces this with a Theme resource, real fonts and corner-bracket frames.


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font = Fonts.body()
	theme.default_font_size = 17

	theme.set_stylebox("panel", "PanelContainer", _box(Palette.PANEL, Palette.LINE, 1, 4, 14.0))
	theme.set_type_variation("RowPanel", "PanelContainer")
	theme.set_stylebox("panel", "RowPanel", _box(Palette.ROW, Palette.LINE, 1, 3, 6.0))
	theme.set_type_variation("OverlayPanel", "PanelContainer")
	theme.set_stylebox("panel", "OverlayPanel", _box(Palette.PANEL, Color(Palette.CYAN, 0.35), 1, 6, 20.0))
	theme.set_type_variation("ToastPanel", "PanelContainer")
	theme.set_stylebox("panel", "ToastPanel", _box(Palette.PANEL, Palette.VIOLET, 1, 4, 12.0))
	theme.set_type_variation("AchievementOn", "PanelContainer")
	theme.set_stylebox("panel", "AchievementOn", _box(Color(Palette.VIOLET, 0.1), Palette.VIOLET, 1, 3, 10.0))
	theme.set_type_variation("AchievementOff", "PanelContainer")
	theme.set_stylebox("panel", "AchievementOff", _box(Color(0, 0, 0, 0), Palette.LINE, 1, 3, 10.0))

	theme.set_type_variation("DangerPanel", "PanelContainer")
	theme.set_stylebox("panel", "DangerPanel", _box(Palette.PANEL, Palette.MAGENTA, 1, 6, 20.0))
	theme.set_type_variation("OverflowToast", "PanelContainer")
	theme.set_stylebox("panel", "OverflowToast", _box(Palette.PANEL, Palette.MAGENTA, 1, 4, 12.0))
	theme.set_type_variation("OverflowButton", "Button")
	theme.set_stylebox("normal", "OverflowButton", _box(Color(Palette.MAGENTA, 0.08), Color(Palette.MAGENTA, 0.6), 1, 3, 10.0))
	theme.set_stylebox("hover", "OverflowButton", _box(Color(Palette.MAGENTA, 0.16), Color(Palette.MAGENTA, 0.9), 1, 3, 10.0))
	theme.set_stylebox("pressed", "OverflowButton", _box(Color(Palette.MAGENTA, 0.3), Palette.MAGENTA, 1, 3, 10.0))

	# Starting over can't be undone, so it gets amber, the colour that asks for attention.
	theme.set_type_variation("WarningPanel", "PanelContainer")
	theme.set_stylebox("panel", "WarningPanel", _box(Palette.PANEL, Palette.AMBER, 1, 6, 20.0))
	theme.set_type_variation("WarningButton", "Button")
	theme.set_stylebox("normal", "WarningButton", _box(Color(Palette.AMBER, 0.08), Color(Palette.AMBER, 0.6), 1, 3, 10.0))
	theme.set_stylebox("hover", "WarningButton", _box(Color(Palette.AMBER, 0.16), Color(Palette.AMBER, 0.9), 1, 3, 10.0))
	theme.set_stylebox("pressed", "WarningButton", _box(Color(Palette.AMBER, 0.3), Palette.AMBER, 1, 3, 10.0))

	# The main choice on a screen, such as Continue on the start screen.
	theme.set_type_variation("PrimaryButton", "Button")
	theme.set_stylebox("normal", "PrimaryButton", _box(Color(Palette.CYAN, 0.16), Palette.CYAN, 1, 3, 10.0))
	theme.set_stylebox("hover", "PrimaryButton", _box(Color(Palette.CYAN, 0.26), Palette.CYAN, 1, 3, 10.0))
	theme.set_stylebox("pressed", "PrimaryButton", _box(Color(Palette.CYAN, 0.36), Palette.CYAN, 1, 3, 10.0))
	theme.set_stylebox("focus", "PrimaryButton", _box(Color(0, 0, 0, 0), Color(Palette.ICE, 0.7), 1, 3, 10.0))

	theme.set_stylebox("normal", "TextEdit", _box(Palette.ROW, Palette.LINE, 1, 3, 8.0))
	theme.set_stylebox("focus", "TextEdit", _box(Color(0, 0, 0, 0), Palette.CYAN, 1, 3, 8.0))
	theme.set_color("font_color", "TextEdit", Palette.ICE)
	theme.set_color("font_color", "CheckButton", Palette.ICE)
	theme.set_color("font_hover_color", "CheckButton", Palette.ICE)
	theme.set_color("font_pressed_color", "CheckButton", Palette.ICE)
	theme.set_color("font_hover_pressed_color", "CheckButton", Palette.ICE)

	theme.set_stylebox("panel", "PopupMenu", _box(Palette.PANEL, Palette.LINE, 1, 4, 6.0))
	theme.set_stylebox("hover", "PopupMenu", _box(Color(Palette.CYAN, 0.15), Color(0, 0, 0, 0), 0, 3, 4.0))
	theme.set_color("font_color", "PopupMenu", Palette.ICE)
	theme.set_color("font_hover_color", "PopupMenu", Palette.ICE)
	theme.set_stylebox("slider", "HSlider", _box(Palette.LINE, Color(0, 0, 0, 0), 0, 2, 2.0))
	theme.set_stylebox("grabber_area", "HSlider", _box(Palette.CYAN, Color(0, 0, 0, 0), 0, 2, 2.0))
	theme.set_stylebox("grabber_area_highlight", "HSlider", _box(Palette.CYAN, Color(0, 0, 0, 0), 0, 2, 2.0))

	theme.set_stylebox("scroll", "VScrollBar", _box(Color(Palette.LINE, 0.25), Color(0, 0, 0, 0), 0, 3, 3.0))
	theme.set_stylebox("grabber", "VScrollBar", _box(Palette.LINE, Color(0, 0, 0, 0), 0, 3, 3.0))
	theme.set_stylebox("grabber_highlight", "VScrollBar", _box(Color(Palette.CYAN, 0.5), Color(0, 0, 0, 0), 0, 3, 3.0))
	theme.set_stylebox("grabber_pressed", "VScrollBar", _box(Palette.CYAN, Color(0, 0, 0, 0), 0, 3, 3.0))

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
