class_name TitleScreen
extends Control
## The start screen: the game's name over a 16-bit counter that ticks over, then Continue (Start for a new
## save), New game, Settings and Quit. It covers the main screen, and the machine keeps running underneath,
## as it does while the player is away.

signal continue_pressed
signal new_game_pressed
signal settings_pressed
signal quit_pressed

const COUNTER_BITS := 16
## Seconds per increment of the counter.
const COUNTER_STEP := 0.15
## Shown instead of a moving counter when reduced motion is on.
const STILL_VALUE := 0b0100_1001_0110_1101
const BUTTON_SIZE := Vector2(320, 48)

var _counter: RegisterDisplay
var _value := 0
var _elapsed := 0.0
var _continue: Button
var _summary: Label
var _new_game: Button


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Palette.VOID
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var frame := FramePanel.new()
	frame.custom_minimum_size = Vector2(600, 0)
	center.add_child(frame)
	var margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 30)
	frame.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	# A machine that has been counting for a while, not one that just switched on.
	_value = randi_range(0, 1 << 12)
	box.add_child(_text("A COUNTER INSIDE A FORGOTTEN MACHINE", Fonts.heading(), 13, Palette.MUTED))
	var title_font := Fonts.readout() as FontVariation
	title_font.spacing_glyph = 6
	box.add_child(_text("INCREMENTER", title_font, 64, Palette.CYAN))
	_counter = RegisterDisplay.new()
	_counter.custom_minimum_size = Vector2(0, 36)
	box.add_child(_counter)
	box.add_child(_gap(18))

	_continue = _button("", func() -> void: continue_pressed.emit())
	_continue.theme_type_variation = &"PrimaryButton"
	box.add_child(_continue)
	_summary = _text("", Fonts.mono(), 13, Palette.MUTED)
	box.add_child(_summary)
	_new_game = _button("New game", func() -> void: new_game_pressed.emit())
	box.add_child(_new_game)
	box.add_child(_button("Settings", func() -> void: settings_pressed.emit()))
	# A browser tab has nothing to quit to.
	if not OS.has_feature("web"):
		box.add_child(_button("Quit", func() -> void: quit_pressed.emit()))
	box.add_child(_gap(8))
	box.add_child(_text("v%s" % ProjectSettings.get_setting("application/config/version"), Fonts.mono(), 12, Palette.MUTED))


## Shows Continue with a summary of the save, or Start when there's nothing to continue.
func refresh(state: GameState) -> void:
	var started := state.total_clicks > 0 or state.total_produced > 0.0 or state.overflows > 0
	_continue.text = "CONTINUE" if started else "START"
	_summary.visible = started
	_new_game.visible = started
	if not started:
		return
	var progress := "V1 complete"
	if not state.ended:
		match state.overflows:
			0:
				progress = "no Overflows yet"
			1:
				progress = "1 Overflow"
			_:
				progress = "%d Overflows" % state.overflows
	_summary.text = "%d-bit register  ·  %s  ·  played %s" % [state.register_bits, progress, NumberFormat.duration(state.play_time)]


## Puts keyboard focus on Continue, so Enter or Space starts the game.
func focus_primary() -> void:
	_continue.grab_focus.call_deferred()


func _process(delta: float) -> void:
	if not visible:
		return
	if Settings.reduced_motion:
		_counter.show_value(COUNTER_BITS, STILL_VALUE, false)
		return
	_elapsed += delta
	while _elapsed >= COUNTER_STEP:
		_elapsed -= COUNTER_STEP
		# Wraps to 0 after 65535: the counter overflows too.
		_value = (_value + 1) % (1 << COUNTER_BITS)
	_counter.show_value(COUNTER_BITS, _value, false)


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = BUTTON_SIZE
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(action)
	return button


func _text(text: String, font: Font, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _gap(height: float) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, height)
	return gap
