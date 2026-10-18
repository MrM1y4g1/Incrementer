class_name SavePanel
extends PanelContainer
## Save export and import as text. Browsers can lose site data, so this is the player's backup.

signal closed

var _text: TextEdit
var _status: Label


func _init() -> void:
	theme_type_variation = &"OverlayPanel"
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	root.add_child(_label("SAVE DATA", 13, Palette.MUTED))
	var help := _label("This text is your whole game. Copy it somewhere safe to back it up, or paste a saved copy here and press Import to load it.", 14, Palette.ICE)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(help)

	_text = TextEdit.new()
	_text.custom_minimum_size = Vector2(0, 180)
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_text.add_theme_font_size_override("font_size", 12)
	root.add_child(_text)

	_status = _label("", 13, Palette.MUTED)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_status)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	root.add_child(buttons)
	buttons.add_child(_button("Copy", _copy))
	buttons.add_child(_button("Import", _import))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(spacer)
	buttons.add_child(_button("Close", func() -> void: closed.emit()))


## Fills the box with the current game.
func show_export(text: String) -> void:
	_text.text = text
	_status.text = ""


func _copy() -> void:
	DisplayServer.clipboard_set(_text.text)
	_status.text = "Copied."
	_status.add_theme_color_override("font_color", Palette.MUTED)


func _import() -> void:
	var problem := SaveManager.import_text(_text.text)
	if problem == "":
		_status.text = "Loaded."
		_status.add_theme_color_override("font_color", Palette.MUTED)
	else:
		_status.text = problem
		_status.add_theme_color_override("font_color", Palette.AMBER)


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(100, 0)
	button.pressed.connect(action)
	return button


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
