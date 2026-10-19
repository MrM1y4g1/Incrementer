class_name UpgradeCard
extends PanelContainer
## One upgrade in the Upgrades tab: its name, what it does and a buy button. A part's next upgrade also shows
## before it unlocks, dimmed, with how many of the part it needs.

signal buy_pressed(id: StringName)

var upgrade: UpgradeDef

var _button: Button
var _name_label: Label
var _need_label: Label
## The part whose units bought unlock this upgrade, in the plural, or "" for upgrades that only need bits.
var _part_name := ""


func _init(def: UpgradeDef, content: Content) -> void:
	upgrade = def
	theme_type_variation = &"RowPanel"

	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	add_child(box)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	box.add_child(text)

	_name_label = Label.new()
	_name_label.text = def.display_name
	_name_label.add_theme_font_size_override("font_size", 15)
	text.add_child(_name_label)

	var effect_label := Label.new()
	effect_label.text = describe(def, content)
	effect_label.add_theme_font_size_override("font_size", 12)
	effect_label.add_theme_color_override("font_color", Palette.MUTED)
	text.add_child(effect_label)

	_need_label = Label.new()
	_need_label.add_theme_font_size_override("font_size", 12)
	_need_label.add_theme_color_override("font_color", Palette.AMBER)
	_need_label.visible = false
	text.add_child(_need_label)
	var part := def.requires_tier - 1
	if part >= 0 and part < content.layers.size():
		_part_name = content.layers[part].plural_name

	_button = Button.new()
	_button.custom_minimum_size = Vector2(150, 0)
	_button.pressed.connect(func() -> void: buy_pressed.emit(upgrade.id))
	box.add_child(_button)


func refresh(state: GameState) -> void:
	var locked := not Economy.upgrade_visible(state, upgrade) and _part_name != ""
	_need_label.visible = locked
	if locked:
		_name_label.add_theme_color_override("font_color", Palette.MUTED)
		_need_label.text = "Unlocks at %d %s bought (%d now)" % [upgrade.requires_bought, _part_name, state.layer_bought[upgrade.requires_tier - 1]]
		_button.text = "Locked"
		_button.disabled = true
		return
	_name_label.remove_theme_color_override("font_color")
	var needed := Formulas.width_for(upgrade.cost)
	if needed > state.register_bits:
		_button.text = "Needs %d-bit" % needed
		_button.disabled = true
		return
	_button.text = "Buy  %s" % NumberFormat.amount(upgrade.cost)
	_button.disabled = state.count < upgrade.cost


## Plain-language effect, such as "Loops output ×2".
static func describe(def: UpgradeDef, content: Content) -> String:
	var value := _short(def.value)
	match def.effect:
		UpgradeDef.Effect.LAYER_MULTIPLIER:
			var i := def.layer_tier - 1
			var target := content.layers[i].plural_name if i >= 0 and i < content.layers.size() else "Layer"
			return "%s output ×%s" % [target, value]
		UpgradeDef.Effect.ALL_MULTIPLIER:
			return "Count per second ×%s" % value
		UpgradeDef.Effect.CLICK_MULTIPLIER:
			return "Clicks ×%s" % value
		UpgradeDef.Effect.CLICK_FROM_RATE:
			return "Clicks also add %s%% of Count per second" % _short(def.value * 100.0)
	return ""


## 2 rather than 2.0, and 1.5 stays 1.5.
static func _short(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(roundi(value))
	return String.num(value, 2)
