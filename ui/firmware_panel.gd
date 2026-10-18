class_name FirmwarePanel
extends PanelContainer
## The Firmware screen: permanent upgrades bought with Carry, in columns from cheap to expensive,
## plus switches for the autobuyers that Firmware unlocks.

signal closed
signal buy_pressed(id: StringName)

## [switch key, Firmware effect that unlocks it, label]
const AUTOBUY_SWITCHES := [
	["low", FirmwareDef.Effect.AUTOBUY_LOW, "Buy Incrementers to Threads"],
	["high", FirmwareDef.Effect.AUTOBUY_HIGH, "Buy Processes to Hypervisors"],
	["clock", FirmwareDef.Effect.AUTO_CLOCK, "Overclock"],
	["widen", FirmwareDef.Effect.AUTO_WIDEN, "Widen the register"],
]

var _title: Label
var _cards := {}
var _switches := {}
var _automation: HBoxContainer


func _init(content: Content) -> void:
	theme_type_variation = &"OverlayPanel"
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	_title = _label("", 13, Palette.MUTED)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(func() -> void: closed.emit())
	header.add_child(close)

	root.add_child(_label("Firmware is permanent: it stays through every Overflow. Each column needs a node from the column before it.", 13, Palette.MUTED))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var columns := HBoxContainer.new()
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 10)
	scroll.add_child(columns)

	var column_boxes := {}
	for node: FirmwareDef in content.firmware:
		if not column_boxes.has(node.column):
			var box := VBoxContainer.new()
			box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			box.add_theme_constant_override("separation", 8)
			columns.add_child(box)
			column_boxes[node.column] = box
		var column_box: VBoxContainer = column_boxes[node.column]
		column_box.add_child(_card(node, content))

	_automation = HBoxContainer.new()
	_automation.add_theme_constant_override("separation", 16)
	root.add_child(_automation)
	_automation.add_child(_label("AUTOMATION", 12, Palette.MUTED))
	for entry: Array in AUTOBUY_SWITCHES:
		var key: String = entry[0]
		var check := CheckButton.new()
		check.text = entry[2]
		check.add_theme_font_size_override("font_size", 13)
		check.toggled.connect(func(on: bool) -> void: Game.set_autobuy(key, on))
		_automation.add_child(check)
		_switches[key] = check


func refresh(state: GameState, content: Content) -> void:
	_title.text = "FIRMWARE  ·  %s CARRY TO SPEND" % NumberFormat.amount(state.carry)
	for id: StringName in _cards:
		var node: FirmwareDef = content.firmware_by_id[id]
		var parts: Dictionary = _cards[id]
		var panel: PanelContainer = parts["panel"]
		var button: Button = parts["button"]
		if Economy.owns_firmware(state, id):
			panel.theme_type_variation = &"AchievementOn"
			button.text = "Owned"
			button.disabled = true
		elif Economy.firmware_available(state, node):
			panel.theme_type_variation = &"RowPanel"
			button.text = "Buy  %s Carry" % NumberFormat.amount(node.cost)
			button.disabled = state.carry < node.cost
		else:
			panel.theme_type_variation = &"AchievementOff"
			button.text = "Needs %s" % _requirement_names(node, content)
			button.disabled = true

	var any_switch := false
	for entry: Array in AUTOBUY_SWITCHES:
		var key: String = entry[0]
		var check: CheckButton = _switches[key]
		var effect: FirmwareDef.Effect = entry[1]
		Economy.refresh_effects(state, content)
		check.visible = state.has_firmware_effect(effect)
		check.set_pressed_no_signal(bool(state.autobuy.get(key, true)))
		any_switch = any_switch or check.visible
	_automation.visible = any_switch


func _card(node: FirmwareDef, content: Content) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"RowPanel"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	box.add_child(_label(node.display_name, 15, Palette.ICE))
	var description := _label(node.description, 12, Palette.MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(description)
	var button := Button.new()
	button.add_theme_font_size_override("font_size", 13)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.pressed.connect(func() -> void: buy_pressed.emit(node.id))
	box.add_child(button)
	_cards[node.id] = {"panel": panel, "button": button}
	var _unused := content
	return panel


func _requirement_names(node: FirmwareDef, content: Content) -> String:
	var names := PackedStringArray()
	for requirement: String in node.requires:
		var required: FirmwareDef = content.firmware_by_id.get(StringName(requirement))
		names.append(required.display_name if required != null else requirement)
	return ", ".join(names)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
