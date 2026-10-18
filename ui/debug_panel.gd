class_name DebugPanel
extends PanelContainer
## Developer tools. Only created in debug builds; F3 shows and hides it.

var _wipe_button: Button
var _wipe_armed := false


func _init() -> void:
	theme_type_variation = &"OverlayPanel"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	box.add_child(_label("DEBUG  ·  F3 TO HIDE"))

	var count_row := _row(box, "Count")
	count_row.add_child(_button("Fill register", _fill_register))
	count_row.add_child(_button("+1 hour", _add_hour))

	var speed_row := _row(box, "Speed")
	var group := ButtonGroup.new()
	for speed: float in [1.0, 10.0, 100.0]:
		var speed_button := _button("×%d" % int(speed), _set_speed.bind(speed))
		speed_button.toggle_mode = true
		speed_button.button_group = group
		speed_button.button_pressed = is_equal_approx(Game.speed, speed)
		speed_row.add_child(speed_button)

	var bits_row := _row(box, "Register")
	for bits: int in Formulas.REGISTER_WIDTHS:
		bits_row.add_child(_button(str(bits), _set_bits.bind(bits)))

	var carry_row := _row(box, "Carry")
	carry_row.add_child(_button("+10", _add_carry.bind(10.0)))
	carry_row.add_child(_button("+1,000", _add_carry.bind(1000.0)))
	carry_row.add_child(_button("+1 billion", _add_carry.bind(1e9)))

	var save_row := _row(box, "Save")
	_wipe_button = _button("Wipe save", _wipe)
	save_row.add_child(_wipe_button)


func _fill_register() -> void:
	Economy.add_count(Game.state, Formulas.register_cap(Game.state.register_bits))


func _add_hour() -> void:
	Economy.catch_up(Game.state, Game.content, 3600.0)


func _set_speed(speed: float) -> void:
	Game.speed = speed


func _add_carry(amount: float) -> void:
	Game.state.carry += amount
	Game.state.total_carry += amount


func _set_bits(bits: int) -> void:
	Game.state.register_bits = bits
	Game.state.count = minf(Game.state.count, Formulas.register_cap(bits))


## Two presses: the first arms the button, the second wipes.
func _wipe() -> void:
	if not _wipe_armed:
		_wipe_armed = true
		_wipe_button.text = "Press again to wipe"
		return
	_wipe_armed = false
	_wipe_button.text = "Wipe save"
	SaveManager.wipe()


func _row(parent: Container, title: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var label := _label(title)
	label.custom_minimum_size = Vector2(72, 0)
	row.add_child(label)
	return row


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 13)
	button.pressed.connect(action)
	return button


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Palette.MUTED)
	return label
