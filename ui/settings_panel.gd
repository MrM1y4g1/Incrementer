class_name SettingsPanel
extends PanelContainer
## Settings: number format, volumes, reduced motion, how often the game autosaves, and whether bad bits
## appear. That last one belongs to the save, not to settings.cfg.

signal closed

const NOTATION_LABELS: PackedStringArray = ["Standard: 1.23 M, 18.4 Qi", "Scientific: 1.23e6", "Engineering: 12.3e15", "Bits: 20.2 bits"]
const AUTOSAVE_LABELS: PackedStringArray = ["Every 15 seconds", "Every 30 seconds", "Every minute", "Every 2 minutes"]

var _notation: OptionButton
var _music: HSlider
var _sfx: HSlider
var _motion: CheckButton
var _autosave: OptionButton
var _faults: CheckButton


func _init() -> void:
	theme_type_variation = &"OverlayPanel"
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 18)
	add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	var title := Label.new()
	title.text = "SETTINGS"
	title.add_theme_font_override("font", Fonts.heading())
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Palette.MUTED)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(func() -> void: closed.emit())
	header.add_child(close)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 14)
	root.add_child(grid)

	_notation = OptionButton.new()
	for label: String in NOTATION_LABELS:
		_notation.add_item(label)
	_notation.item_selected.connect(func(i: int) -> void: Settings.set_value("notation", i))
	_row(grid, "Number format", _notation)

	_music = _slider(func(v: float) -> void: Settings.set_value("music_volume", v))
	_row(grid, "Music", _music)
	_sfx = _slider(func(v: float) -> void: Settings.set_value("sfx_volume", v))
	_row(grid, "Sound effects", _sfx)

	_motion = CheckButton.new()
	_motion.text = "Fewer moving effects"
	_motion.toggled.connect(func(on: bool) -> void: Settings.set_value("reduced_motion", on))
	_row(grid, "Reduced motion", _motion)

	_autosave = OptionButton.new()
	for label: String in AUTOSAVE_LABELS:
		_autosave.add_item(label)
	_autosave.item_selected.connect(func(i: int) -> void: Settings.set_value("autosave_seconds", Settings.AUTOSAVE_CHOICES[i]))
	_row(grid, "Autosave", _autosave)

	_faults = CheckButton.new()
	_faults.text = "Bits wear out and go bad"
	_faults.toggled.connect(func(on: bool) -> void: Game.set_faults_on(on))
	_row(grid, "Bad bits", _faults)


## Shows the current settings without triggering any change signals.
func refresh() -> void:
	_notation.select(Settings.notation)
	_music.set_value_no_signal(Settings.music_volume)
	_sfx.set_value_no_signal(Settings.sfx_volume)
	_motion.set_pressed_no_signal(Settings.reduced_motion)
	_autosave.select(maxi(0, Settings.AUTOSAVE_CHOICES.find(Settings.autosave_seconds)))
	_faults.set_pressed_no_signal(Game.state.faults_on)


func _row(grid: GridContainer, text: String, control: Control) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Palette.MUTED)
	grid.add_child(label)
	control.custom_minimum_size = Vector2(320, 0)
	grid.add_child(control)


func _slider(on_change: Callable) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(on_change)
	return slider
