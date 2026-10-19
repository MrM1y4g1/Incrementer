class_name LayerRow
extends PanelContainer
## One row of the parts list: the tier icon, the layer's name, units bought and when its next upgrade
## unlocks, how many it owns and how fast that grows (the layer above writes new copies), what it makes,
## and its buy button.

signal buy_pressed(index: int)

var index := 0

var _icon: TierIcon
var _name_label: Label
var _bought_label: Label
var _upgrade_label: Label
var _detail_label: Label
var _button: Button


func _init(row_index: int) -> void:
	index = row_index
	theme_type_variation = &"RowPanel"

	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)

	_icon = TierIcon.new(row_index + 1)
	box.add_child(_icon)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	box.add_child(text)

	var title := HBoxContainer.new()
	title.add_theme_constant_override("separation", 8)
	text.add_child(title)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 16)
	title.add_child(_name_label)
	_bought_label = Label.new()
	_bought_label.add_theme_font_override("font", Fonts.mono())
	_bought_label.add_theme_font_size_override("font_size", 11)
	_bought_label.add_theme_color_override("font_color", Palette.MUTED)
	_bought_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.add_child(_bought_label)
	# Clipped, so a long hint never pushes the buy button, and in the narrower body font, to fit "upgrade at 100".
	_upgrade_label = Label.new()
	_upgrade_label.add_theme_font_size_override("font_size", 12)
	_upgrade_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_upgrade_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_upgrade_label.clip_text = true
	_upgrade_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_child(_upgrade_label)

	_detail_label = Label.new()
	_detail_label.add_theme_font_override("font", Fonts.mono())
	_detail_label.add_theme_font_size_override("font_size", 11)
	_detail_label.add_theme_color_override("font_color", Palette.MUTED)
	_detail_label.clip_text = true
	_detail_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.add_child(_detail_label)

	_button = Button.new()
	_button.custom_minimum_size = Vector2(118, 0)
	_button.add_theme_font_override("font", Fonts.mono())
	_button.add_theme_font_size_override("font_size", 12)
	_button.pressed.connect(func() -> void: buy_pressed.emit(index))
	box.add_child(_button)


## A quick highlight after a purchase.
func flash() -> void:
	modulate = Color(1.6, 1.6, 1.6)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.35)


func refresh(state: GameState, content: Content, mode: int) -> void:
	var layer := content.layers[index]
	_name_label.text = layer.display_name
	if not Economy.is_unlocked(state, layer):
		_icon.set_style(Palette.LINE, false)
		_name_label.add_theme_color_override("font_color", Palette.MUTED)
		_bought_label.text = ""
		_upgrade_label.text = ""
		_detail_label.text = "Unlocks at %d-bit" % layer.unlock_bits
		_button.text = "Locked"
		_button.disabled = true
		return

	var bought := state.layer_bought[index]
	_icon.set_style(Palette.CYAN, bought > 0)
	_name_label.remove_theme_color_override("font_color")
	_bought_label.text = "%d bought" % bought
	var next := Economy.next_part_upgrade(state, content, index)
	if next == null or not Economy.upgrade_possible(state, next):
		_upgrade_label.text = ""
	elif Economy.upgrade_visible(state, next):
		_upgrade_label.text = "·  new upgrade"
		_upgrade_label.add_theme_color_override("font_color", Palette.AMBER)
	else:
		_upgrade_label.text = "·  upgrade at %d" % next.requires_bought
		_upgrade_label.add_theme_color_override("font_color", Palette.MUTED)

	var owned := state.layer_amount[index]
	var growth := 0.0
	if index + 1 < content.layers.size():
		growth = state.layer_amount[index + 1] * Economy.layer_rate(state, content, index + 1)
	var makes := owned * Economy.layer_rate(state, content, index)
	var target := "Count" if index == 0 else content.layers[index - 1].plural_name
	var owned_text := NumberFormat.amount(owned)
	if growth > 0.0:
		owned_text += " (+%s/s)" % NumberFormat.rate(growth)
	_detail_label.text = "%s  →  %s %s/s" % [owned_text, NumberFormat.rate(makes), target]

	var n := Economy.buy_count(state, content, index, mode)
	# Past about 2^1024 a price no longer fits in a float.
	if not is_finite(Economy.next_cost(state, content, index)):
		_button.text = "Maxed"
		_button.disabled = true
		return
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
