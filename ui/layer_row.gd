class_name LayerRow
extends PanelContainer
## One row of the parts list: the layer's name, what it owns and makes, and its buy button.

signal buy_pressed(index: int)

var index := 0

var _name_label: Label
var _detail_label: Label
var _button: Button


func _init(row_index: int) -> void:
	index = row_index
	theme_type_variation = &"RowPanel"

	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	add_child(box)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	box.add_child(text)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 15)
	text.add_child(_name_label)

	_detail_label = Label.new()
	_detail_label.add_theme_font_size_override("font_size", 12)
	_detail_label.add_theme_color_override("font_color", Palette.MUTED)
	text.add_child(_detail_label)

	_button = Button.new()
	_button.custom_minimum_size = Vector2(150, 0)
	_button.pressed.connect(func() -> void: buy_pressed.emit(index))
	box.add_child(_button)


func refresh(state: GameState, content: Content, mode: int) -> void:
	var layer := content.layers[index]
	if not Economy.is_unlocked(state, layer):
		_name_label.text = layer.display_name
		_name_label.add_theme_color_override("font_color", Palette.MUTED)
		_detail_label.text = "Unlocks at %d-bit" % layer.unlock_bits
		_button.text = "Locked"
		_button.disabled = true
		return

	_name_label.remove_theme_color_override("font_color")
	_name_label.text = "%s  ·  %d bought" % [layer.display_name, state.layer_bought[index]]
	var target := "Count" if index == 0 else content.layers[index - 1].plural_name
	var makes := state.layer_amount[index] * Economy.layer_rate(state, content, index)
	_detail_label.text = "%s owned  ·  +%s %s/s" % [NumberFormat.amount(state.layer_amount[index]), NumberFormat.rate(makes), target]

	var n := Economy.buy_count(state, content, index, mode)
	if mode == Economy.BuyMode.MAX:
		if n > 0:
			_button.text = "×%d  %s" % [n, NumberFormat.amount(Economy.cost_of(state, content, index, n))]
		else:
			_button.text = "Max  %s" % NumberFormat.amount(Economy.next_cost(state, content, index))
	elif mode == Economy.BuyMode.TEN:
		_button.text = "×10  %s" % NumberFormat.amount(Economy.cost_of(state, content, index, 10))
	else:
		_button.text = "Buy  %s" % NumberFormat.amount(Economy.next_cost(state, content, index))
	_button.disabled = n == 0
