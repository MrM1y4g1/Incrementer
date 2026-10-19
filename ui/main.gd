extends Control
## The main screen, laid out as in the wireframe in plan section 4: the register and Count readout on
## top, the schematic of the machine in the middle with the actions beneath it, parts and upgrades on
## the right, and a status bar along the bottom.
##
## Click the register or press Space to increment. F3 shows the debug panel in debug builds.
## Dev flags, passed after `--` on the command line:
##   --no-save              do not read or write the save or settings (handled by SaveManager, Settings)
##   --mute                 no sound (also implied by --capture)
##   --autoplay=<seconds>   fast-forward a scripted player before the first frame
##   --open=<views>         open views at start, comma-separated:
##                          title, upgrades, stats, firmware, settings, save, start-over, overflow, ending, debug, toast,
##                          fault (puts a bad bit just above the Count and fills up to it), scrub,
##                          wear (starts three bits wearing, at different stages),
##                          tutorial-<step> (shows that tutorial step: count, incrementer, upgrade, wear or bad-bit)
##                          (--autoplay and --capture skip the start screen and the tutorial unless --open asks for them)
##   --capture=<png path>   save a screenshot after a few frames, then quit

const REFRESH_SECONDS := 0.1
const SIDE_WIDTH := 470.0
## The screen is laid out for this size and drawn at exactly this size, centred in the window. It only
## shrinks, to fit a smaller window, so it looks the same as the screenshots on any monitor.
const SCREEN_SIZE := Vector2(1280, 720)
const TOAST_SECONDS := 4.0

var _mode: int = Economy.BuyMode.ONE
var _capture_path := ""

var _register_panel: FramePanel
var _register: RegisterDisplay
var _register_label: Label
var _bits_label: Label
var _refresh_button: Button
var _repair_button: Button
var _scrub_button: Button
var _count_label: Label
var _rate_label: Label
var _boost_label: Label
var _carry_label: Label
var _schematic: SchematicView
var _increment_button: Button
var _widen_button: Button
var _clock_button: Button
var _overflow_button: Button
var _status_label: Label
var _firmware_button: Button
var _parts_tab: Button
var _upgrades_tab: Button
var _mode_box: HBoxContainer
var _parts_scroll: ScrollContainer
var _upgrades_scroll: ScrollContainer
var _upgrades_empty: Label
var _rows: Array[LayerRow] = []
var _cards: Array[UpgradeCard] = []
var _toasts: VBoxContainer
var _fx: FxLayer
var _debug_panel: DebugPanel
var _title: TitleScreen
var _skip_title := false
# Bad bits cleared so far, bad bits now, bits worn this run and whether a bad bit was holding the Count,
# to notice changes between refreshes. -1 until the first refresh.
var _faults_cleared := -1
var _bad_seen := -1
var _wear_seen := -1
var _lost_seen := -1.0
var _was_blocked := false

# The tutorial: the step whose card is open, the step whose hint is showing, and whether it's off
# (for --autoplay and --capture).
var _tutorial: TutorialOverlay
var _hint: TutorialHint
var _tutorial_step := ""
var _hint_step := ""
var _tutorial_off := false

# Overlays: only one is open at a time, over a shared backdrop.
var _backdrop: ColorRect
var _overlays: Array[Control] = []
var _stats_panel: StatsPanel
var _firmware_panel: FirmwarePanel
var _settings_panel: SettingsPanel
var _save_panel: SavePanel
var _ending_panel: EndingPanel
var _confirm_panel: PanelContainer
var _confirm_label: Label
var _scrub_panel: ScrubPanel
var _start_over_panel: PanelContainer
var _start_over_status: Label


func _ready() -> void:
	theme = ThemeFactory.build()
	_place_screen()
	get_tree().root.size_changed.connect(_place_screen)
	_build()
	EventBus.achievement_unlocked.connect(_on_achievement)
	EventBus.overflowed.connect(_on_overflowed)
	EventBus.register_widened.connect(_on_widened)
	EventBus.game_ended.connect(func() -> void: _open(_ending_panel))
	Settings.changed.connect(_apply_settings)
	_apply_settings()
	_apply_dev_args()
	# --autoplay may have changed bad bits since the settings refresh; that is no reason to flash or beep.
	_faults_cleared = -1
	_bad_seen = -1
	_wear_seen = -1
	_lost_seen = -1.0

	var timer := Timer.new()
	timer.wait_time = REFRESH_SECONDS
	timer.autostart = true
	timer.timeout.connect(_refresh)
	add_child(timer)

	_refresh()
	# Screenshots and the autoplayer go straight to the machine.
	if _skip_title:
		_title.visible = false
	else:
		_show_title()
	if _capture_path != "":
		_capture.call_deferred()


## Centres the screen at its own size, and shrinks everything only when the window is too small to hold it.
func _place_screen() -> void:
	var window := get_window()
	window.content_scale_factor = minf(1.0, minf(window.size.x / SCREEN_SIZE.x, window.size.y / SCREEN_SIZE.y))
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -SCREEN_SIZE.x / 2.0
	offset_top = -SCREEN_SIZE.y / 2.0
	offset_right = SCREEN_SIZE.x / 2.0
	offset_bottom = SCREEN_SIZE.y / 2.0


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed:
		return
	if key.keycode == KEY_SPACE and not _backdrop.visible and not _title.visible and not _tutorial.visible:
		_on_increment()
		get_viewport().set_input_as_handled()
		return
	if key.echo:
		return
	if key.keycode == KEY_F3 and _debug_panel != null:
		_debug_panel.visible = not _debug_panel.visible
	elif key.keycode == KEY_ESCAPE:
		if _tutorial.visible:
			_on_tutorial_dismissed()
		else:
			_close_overlays()


# --- Layout -------------------------------------------------------------------

func _build() -> void:
	var background := ColorRect.new()
	background.color = Palette.VOID
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 20)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)
	root.add_child(_build_top())
	root.add_child(_build_middle())
	root.add_child(_build_status_bar())

	_fx = FxLayer.new()
	add_child(_fx)
	_hint = TutorialHint.new()
	add_child(_hint)
	# Above the machine, below the overlays, so Settings and the Start over question open over it.
	_title = TitleScreen.new()
	_title.continue_pressed.connect(_on_title_continue)
	_title.new_game_pressed.connect(_ask_start_over)
	_title.settings_pressed.connect(func() -> void: _open(_settings_panel))
	_title.quit_pressed.connect(_quit)
	add_child(_title)
	_build_overlays()


func _build_top() -> Control:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)

	var register_panel := FramePanel.new()
	_register_panel = register_panel
	register_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	register_panel.custom_minimum_size = Vector2(0, 156)
	register_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	register_panel.tooltip_text = "Click the register, or press Space, to increment. Click a worn bit to refresh it."
	register_panel.gui_input.connect(func(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			_on_register_clicked())
	top.add_child(register_panel)
	var register_box := VBoxContainer.new()
	register_box.add_theme_constant_override("separation", 8)
	register_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	register_panel.add_child(register_box)
	_register_label = _heading("")
	register_box.add_child(_register_label)
	_register = RegisterDisplay.new()
	_register.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_register.custom_minimum_size = Vector2(0, 70)
	_register.mouse_filter = Control.MOUSE_FILTER_IGNORE
	register_box.add_child(_register)
	# The fault buttons share the line under the register, so the panel keeps its height when they appear.
	var status_row := HBoxContainer.new()
	status_row.custom_minimum_size = Vector2(0, 28)
	status_row.add_theme_constant_override("separation", 6)
	register_box.add_child(status_row)
	_bits_label = _label("", 13, Palette.MUTED)
	_bits_label.add_theme_font_override("font", Fonts.mono())
	_bits_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bits_label.clip_text = true
	_bits_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status_row.add_child(_bits_label)
	_refresh_button = _fault_button(_on_refresh_all)
	_refresh_button.theme_type_variation = &"WearButton"
	_refresh_button.text = "REFRESH"
	status_row.add_child(_refresh_button)
	_repair_button = _fault_button(_on_repair)
	status_row.add_child(_repair_button)
	_scrub_button = _fault_button(_open_scrub)
	_scrub_button.text = "SCRUB"
	status_row.add_child(_scrub_button)

	var count_panel := FramePanel.new()
	count_panel.custom_minimum_size = Vector2(SIDE_WIDTH, 156)
	top.add_child(count_panel)
	var count_box := VBoxContainer.new()
	count_box.add_theme_constant_override("separation", 0)
	count_panel.add_child(count_box)
	count_box.add_child(_heading("COUNT"))
	_count_label = _label("0", 46, Palette.CYAN)
	_count_label.add_theme_font_override("font", Fonts.readout())
	count_box.add_child(_count_label)
	_rate_label = _label("", 15, Palette.ICE)
	_rate_label.add_theme_font_override("font", Fonts.mono())
	count_box.add_child(_rate_label)
	_boost_label = _label("", 13, Palette.MUTED)
	count_box.add_child(_boost_label)
	_carry_label = _label("", 13, Palette.VIOLET)
	count_box.add_child(_carry_label)
	# A Label asks for the width of its text, so long numbers would widen this panel and squeeze the
	# register every time the text changed. Clipped labels leave the panel at SIDE_WIDTH.
	for label: Label in [_count_label, _rate_label, _boost_label, _carry_label]:
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return top


func _build_middle() -> Control:
	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 14)

	var machine := FramePanel.new()
	machine.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_child(machine)
	var machine_box := VBoxContainer.new()
	machine_box.add_theme_constant_override("separation", 10)
	machine.add_child(machine_box)
	_schematic = SchematicView.new()
	_schematic.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_schematic.state = Game.state
	_schematic.content = Game.content
	machine_box.add_child(_schematic)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	machine_box.add_child(actions)
	_increment_button = Button.new()
	_increment_button.custom_minimum_size = Vector2(196, 96)
	_increment_button.add_theme_font_override("font", Fonts.readout())
	_increment_button.add_theme_font_size_override("font_size", 20)
	_increment_button.pressed.connect(_on_increment)
	actions.add_child(_increment_button)
	var side_actions := VBoxContainer.new()
	side_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_actions.add_theme_constant_override("separation", 8)
	actions.add_child(side_actions)
	var pair := HBoxContainer.new()
	pair.add_theme_constant_override("separation", 8)
	side_actions.add_child(pair)
	_widen_button = _action_button(_on_widen)
	pair.add_child(_widen_button)
	_clock_button = _action_button(_on_overclock)
	pair.add_child(_clock_button)
	_overflow_button = _action_button(_ask_overflow)
	_overflow_button.theme_type_variation = &"OverflowButton"
	side_actions.add_child(_overflow_button)

	middle.add_child(_build_side_panel())
	return middle


func _build_side_panel() -> Control:
	var side := FramePanel.new()
	side.custom_minimum_size = Vector2(SIDE_WIDTH, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	side.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	box.add_child(header)
	var tabs := ButtonGroup.new()
	_parts_tab = _tab_button("Parts", tabs, true)
	header.add_child(_parts_tab)
	_upgrades_tab = _tab_button("Upgrades", tabs, false)
	header.add_child(_upgrades_tab)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	_mode_box = HBoxContainer.new()
	_mode_box.add_theme_constant_override("separation", 6)
	header.add_child(_mode_box)
	var modes := ButtonGroup.new()
	for mode: int in [Economy.BuyMode.ONE, Economy.BuyMode.TEN, Economy.BuyMode.MAX]:
		var mode_button := _tab_button("Max" if mode == Economy.BuyMode.MAX else "×%d" % mode, modes, mode == _mode)
		mode_button.custom_minimum_size = Vector2(50, 0)
		mode_button.pressed.connect(_on_mode.bind(mode))
		_mode_box.add_child(mode_button)

	_parts_scroll = _scroll()
	box.add_child(_parts_scroll)
	var parts_list := _list()
	_parts_scroll.add_child(parts_list)
	for i: int in Game.content.layers.size():
		var row := LayerRow.new(i)
		row.buy_pressed.connect(_on_buy)
		parts_list.add_child(row)
		_rows.append(row)

	_upgrades_scroll = _scroll()
	_upgrades_scroll.visible = false
	box.add_child(_upgrades_scroll)
	var upgrades_list := _list()
	_upgrades_scroll.add_child(upgrades_list)
	_upgrades_empty = _label("No upgrades available yet. Buy more layers or widen the register.", 14, Palette.MUTED)
	_upgrades_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	upgrades_list.add_child(_upgrades_empty)
	for upgrade: UpgradeDef in Game.content.upgrades:
		var card := UpgradeCard.new(upgrade, Game.content)
		card.buy_pressed.connect(_on_buy_upgrade)
		upgrades_list.add_child(card)
		_cards.append(card)

	_parts_tab.pressed.connect(_show_tab.bind(false))
	_upgrades_tab.pressed.connect(_show_tab.bind(true))
	return side


func _build_status_bar() -> Control:
	var bar := FramePanel.new()
	bar.bracket_color = Color(Palette.LINE, 0.9)
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	bar.add_child(box)
	_status_label = _label("", 13, Palette.MUTED)
	_status_label.add_theme_font_override("font", Fonts.mono())
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_status_label)
	_firmware_button = _small_button("Firmware", func() -> void: _open(_firmware_panel))
	box.add_child(_firmware_button)
	box.add_child(_small_button("Stats", func() -> void: _open(_stats_panel)))
	box.add_child(_small_button("Settings", func() -> void: _open(_settings_panel)))
	box.add_child(_small_button("Save data", func() -> void: _open(_save_panel)))
	var version := _label("  v%s" % ProjectSettings.get_setting("application/config/version"), 12, Palette.MUTED)
	version.add_theme_font_override("font", Fonts.mono())
	box.add_child(version)
	return bar


func _build_overlays() -> void:
	_backdrop = ColorRect.new()
	_backdrop.color = Color(Palette.VOID, 0.8)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.visible = false
	_backdrop.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.is_pressed():
			_close_overlays())
	add_child(_backdrop)

	_stats_panel = StatsPanel.new(Game.content)
	_stats_panel.closed.connect(_close_overlays)
	_add_overlay(_stats_panel, Vector2(1040, 600))

	_firmware_panel = FirmwarePanel.new(Game.content)
	_firmware_panel.closed.connect(_close_overlays)
	_firmware_panel.buy_pressed.connect(func(id: StringName) -> void:
		Game.buy_firmware(id)
		_refresh())
	_add_overlay(_firmware_panel, Vector2(1140, 620))

	_settings_panel = SettingsPanel.new()
	_settings_panel.closed.connect(_close_overlays)
	_add_overlay(_settings_panel, Vector2(620, 0))

	_save_panel = SavePanel.new()
	_save_panel.closed.connect(_close_overlays)
	_save_panel.start_over_pressed.connect(_ask_start_over)
	_add_overlay(_save_panel, Vector2(720, 420))

	_ending_panel = EndingPanel.new()
	_ending_panel.closed.connect(_close_overlays)
	_add_overlay(_ending_panel, Vector2(760, 560))

	_confirm_panel = PanelContainer.new()
	_confirm_panel.theme_type_variation = &"DangerPanel"
	_add_overlay(_confirm_panel, Vector2(520, 0))
	var confirm_box := VBoxContainer.new()
	confirm_box.add_theme_constant_override("separation", 14)
	_confirm_panel.add_child(confirm_box)
	var confirm_title := _heading("OVERFLOW?")
	confirm_title.add_theme_color_override("font_color", Palette.MAGENTA)
	confirm_box.add_child(confirm_title)
	_confirm_label = _label("", 17, Palette.ICE)
	_confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirm_box.add_child(_confirm_label)
	var confirm_buttons := HBoxContainer.new()
	confirm_buttons.add_theme_constant_override("separation", 8)
	confirm_box.add_child(confirm_buttons)
	var go := _small_button("Overflow", _confirm_overflow)
	go.theme_type_variation = &"OverflowButton"
	go.custom_minimum_size = Vector2(140, 40)
	confirm_buttons.add_child(go)
	var cancel := _small_button("Cancel", _close_overlays)
	cancel.custom_minimum_size = Vector2(110, 40)
	confirm_buttons.add_child(cancel)

	_scrub_panel = ScrubPanel.new()
	_scrub_panel.closed.connect(_close_overlays)
	_scrub_panel.solved.connect(_on_scrubbed)
	_add_overlay(_scrub_panel, Vector2(480, 0))

	_start_over_panel = PanelContainer.new()
	_start_over_panel.theme_type_variation = &"WarningPanel"
	_add_overlay(_start_over_panel, Vector2(520, 0))
	var start_box := VBoxContainer.new()
	start_box.add_theme_constant_override("separation", 14)
	_start_over_panel.add_child(start_box)
	var start_title := _heading("START OVER?")
	start_title.add_theme_color_override("font_color", Palette.AMBER)
	start_box.add_child(start_title)
	var start_text := _label("This erases your whole game: the Count, Carry, Firmware, achievements, stats and run history. Settings stay.

To keep a copy, press Copy save and paste it somewhere safe. Import, in Save data, loads it again.", 17, Palette.ICE)
	start_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	start_box.add_child(start_text)
	_start_over_status = _label("", 13, Palette.MUTED)
	start_box.add_child(_start_over_status)
	var start_buttons := HBoxContainer.new()
	start_buttons.add_theme_constant_override("separation", 8)
	start_box.add_child(start_buttons)
	var erase := _small_button("Start over", _confirm_start_over)
	erase.theme_type_variation = &"WarningButton"
	erase.custom_minimum_size = Vector2(140, 40)
	start_buttons.add_child(erase)
	var copy := _small_button("Copy save", _copy_save)
	copy.custom_minimum_size = Vector2(120, 40)
	start_buttons.add_child(copy)
	var keep := _small_button("Cancel", _close_overlays)
	keep.custom_minimum_size = Vector2(110, 40)
	start_buttons.add_child(keep)

	_toasts = VBoxContainer.new()
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.anchor_left = 1.0
	_toasts.anchor_right = 1.0
	_toasts.offset_left = -344.0
	_toasts.offset_right = -24.0
	_toasts.offset_top = 24.0
	_toasts.add_theme_constant_override("separation", 8)
	add_child(_toasts)

	# Over everything else, toasts included, because the game is paused while it's open.
	_tutorial = TutorialOverlay.new()
	_tutorial.dismissed.connect(_on_tutorial_dismissed)
	_tutorial.skipped.connect(_on_tutorial_skipped)
	add_child(_tutorial)

	if OS.is_debug_build():
		_debug_panel = DebugPanel.new()
		_debug_panel.visible = false
		_debug_panel.position = Vector2(40, 200)
		add_child(_debug_panel)


func _add_overlay(panel: Control, min_size: Vector2) -> void:
	panel.visible = false
	panel.custom_minimum_size = min_size
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	_overlays.append(panel)


func _action_button(action: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 44)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 15)
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.pressed.connect(action)
	return button


func _fault_button(action: Callable) -> Button:
	var button := Button.new()
	button.theme_type_variation = &"FaultButton"
	button.add_theme_font_size_override("font_size", 13)
	button.visible = false
	button.pressed.connect(action)
	return button


func _small_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 14)
	button.pressed.connect(action)
	return button


func _tab_button(text: String, group: ButtonGroup, pressed: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.button_group = group
	button.button_pressed = pressed
	button.add_theme_font_size_override("font_size", 14)
	return button


func _scroll() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	return scroll


func _list() -> VBoxContainer:
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	return list


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _heading(text: String) -> Label:
	var label := _label(text, 12, Palette.MUTED)
	label.add_theme_font_override("font", Fonts.heading())
	return label


# --- Updates ------------------------------------------------------------------

func _refresh() -> void:
	var state := Game.state
	var content := Game.content
	Economy.refresh_effects(state, content)
	_schematic.state = state
	var full := Economy.is_full(state)
	var cap := Formulas.register_cap(state.register_bits)

	_count_label.text = NumberFormat.amount(state.count)
	_rate_label.text = "+%s per second" % NumberFormat.rate(Economy.count_per_second(state, content))
	_rate_label.add_theme_color_override("font_color", Palette.AMBER if full else Palette.ICE)
	_boost_label.text = "Clock %s Hz  ·  %d achievements, +%d%%" % [
		NumberFormat.rate(Formulas.clock_multiplier(state.clock_level)), state.achievements.size(),
		roundi(state.achievements.size() * Formulas.ACHIEVEMENT_BONUS * 100.0)]
	# Name the Carry bonus, and while it ripples in, say where it's heading and when it gets there.
	var carry_text := ""
	if state.total_carry > 0.0:
		carry_text = "Carry bonus ×%s" % NumberFormat.amount(Economy.carry_bonus_now(state))
		var ripple_left := Formulas.CARRY_RIPPLE_SECONDS - state.run_time
		if ripple_left > 0.0:
			carry_text += ", ×%s in %s" % [NumberFormat.amount(Formulas.carry_bonus(state.total_carry)), NumberFormat.duration(ripple_left)]
	if state.carry >= 1.0:
		carry_text += "%s%s Carry to spend" % ["  ·  " if carry_text != "" else "", NumberFormat.amount(state.carry)]
	_carry_label.text = carry_text

	var fault := Economy.next_fault(state)
	var blocked := Economy.is_blocked(state)
	var wear: Dictionary[int, float] = {}
	var most_worn := -1
	for bit: int in state.wearing:
		wear[bit] = Economy.wear_level(state, bit)
		if most_worn < 0 or wear[bit] > wear[most_worn]:
			most_worn = bit
	_register.show_faults(state.bad_bits, blocked, state.blocked_time / state.scrub_seconds if blocked else 0.0)
	_register.show_wear(wear)
	_register.show_value(state.register_bits, state.count, full)
	_register_label.text = "REGISTER  ·  %d-BIT  ·  HOLDS %s" % [state.register_bits, NumberFormat.amount(cap)]
	if blocked:
		var held := "holds the Count" if state.count <= Formulas.below_bit(fault) else "stops the Count growing"
		_bits_label.text = "Bad bit %d %s. It scrubs itself in %s." % [fault, held, NumberFormat.duration(Economy.scrub_time_left(state))]
		_bits_label.add_theme_color_override("font_color", Palette.FAULT)
	elif most_worn >= 0:
		var left := NumberFormat.duration((1.0 - wear[most_worn]) * Formulas.WEAR_SECONDS)
		if wear.size() == 1:
			_bits_label.text = "Bit %d is wearing out: it goes bad in %s. Click it or press Refresh." % [most_worn, left]
		else:
			_bits_label.text = "%d bits are wearing out. Bit %d goes bad in %s." % [wear.size(), most_worn, left]
		_bits_label.add_theme_color_override("font_color", Palette.AMBER)
	elif full:
		_bits_label.text = "Full. Widen the register or Overflow to keep counting." if Economy.can_overflow(state) else "Full. Widen the register to keep counting."
		_bits_label.add_theme_color_override("font_color", Palette.AMBER)
	else:
		_bits_label.text = "%.1f of %d bits used" % [log(state.count + 1.0) / log(2.0), state.register_bits]
		if fault >= 0:
			_bits_label.text += "  ·  bad bit ahead at %d" % fault
		_bits_label.add_theme_color_override("font_color", Palette.MUTED)
	_refresh_button.visible = most_worn >= 0
	_refresh_button.text = "REFRESH" if wear.size() <= 1 else "REFRESH %d" % wear.size()
	_repair_button.visible = blocked
	_scrub_button.visible = blocked
	if blocked:
		_repair_button.text = "REPAIR  %s" % NumberFormat.amount(Economy.repair_cost(state))
		_repair_button.disabled = not Economy.can_repair(state)
	_notice_faults(state, blocked)

	_increment_button.text = "INCREMENT\n+%s" % NumberFormat.amount(Economy.click_value(state, content))
	_refresh_widen(state, content)
	_refresh_clock(state, cap)
	_refresh_overflow(state, content)

	_status_label.text = "Run %s  ·  played %s  ·  %s" % [NumberFormat.duration(state.run_time), NumberFormat.duration(state.play_time), SaveManager.status_text()]
	_status_label.add_theme_color_override("font_color", Palette.AMBER if SaveManager.storage_at_risk() or SaveManager.newer_save else Palette.MUTED)
	_firmware_button.visible = state.total_carry > 0.0 or not state.firmware.is_empty()

	# Parts: the unlocked layers plus the next one, so the list grows as the run does.
	var teaser_shown := false
	for row: LayerRow in _rows:
		var unlocked := Economy.is_unlocked(state, content.layers[row.index])
		row.visible = unlocked or not teaser_shown
		if not unlocked:
			teaser_shown = true
		if row.visible:
			row.refresh(state, content, _mode)

	# Upgrades: everything whose requirements are met, cheapest first.
	var visible_count := 0
	var affordable := 0
	for card: UpgradeCard in _cards:
		card.visible = Economy.upgrade_visible(state, card.upgrade)
		if card.visible:
			visible_count += 1
			card.refresh(state)
			if Economy.can_buy_upgrade(state, card.upgrade):
				affordable += 1
	_upgrades_empty.visible = visible_count == 0
	_upgrades_tab.text = "Upgrades  %d" % affordable if affordable > 0 else "Upgrades"

	if _stats_panel.visible:
		_stats_panel.refresh(state, content)
	if _firmware_panel.visible:
		_firmware_panel.refresh(state, content)
	_check_tutorial(state, content)


func _refresh_widen(state: GameState, content: Content) -> void:
	var next := Formulas.next_width(state.register_bits)
	if next < 0:
		_widen_button.text = "Register at full width"
		_widen_button.disabled = true
	elif next > Economy.max_bits(state, content):
		_widen_button.text = "%d-bit needs %s" % [next, _wide_bus_name(next, content)]
		_widen_button.disabled = true
	else:
		_widen_button.text = "WIDEN TO %d-BIT   %s" % [next, NumberFormat.amount(Economy.widen_cost(state))]
		_widen_button.disabled = not Economy.can_widen(state, content)


func _refresh_clock(state: GameState, cap: float) -> void:
	var clock_cost := Economy.clock_cost(state)
	if clock_cost > cap:
		_clock_button.text = "OVERCLOCK   needs %d-bit" % Formulas.width_for(clock_cost)
		_clock_button.disabled = true
		return
	_clock_button.text = "OVERCLOCK TO %s Hz   %s" % [
		NumberFormat.rate(Formulas.clock_multiplier(state.clock_level + 1)), NumberFormat.amount(clock_cost)]
	_clock_button.disabled = not Economy.can_overclock(state)


func _refresh_overflow(state: GameState, content: Content) -> void:
	if Economy.can_overflow(state):
		_overflow_button.disabled = false
		# The next run's full Carry bonus, next to this run's in the Count panel, shows whether it's worth it.
		var gain := Economy.overflow_gain(state, content)
		_overflow_button.text = "OVERFLOW   +%s CARRY   ·   NEXT RUN ×%s" % [
			NumberFormat.amount(gain), NumberFormat.amount(Formulas.carry_bonus(state.total_carry + gain))]
	elif state.overflows > 0 or state.register_bits >= 64:
		_overflow_button.disabled = true
		_overflow_button.text = "Overflow needs a full 64-bit register"
	else:
		_overflow_button.disabled = true
		_overflow_button.text = "Overflow: fill a 64-bit register first"


func _wide_bus_name(bits: int, content: Content) -> String:
	for node: FirmwareDef in content.firmware:
		if node.effect == FirmwareDef.Effect.WIDE_BUS and int(node.value) == bits:
			return node.display_name
	return "Firmware"


func _apply_settings() -> void:
	_fx.reduced_motion = Settings.reduced_motion
	_schematic.reduced_motion = Settings.reduced_motion
	_refresh()


func _show_tab(upgrades: bool) -> void:
	_parts_scroll.visible = not upgrades
	_upgrades_scroll.visible = upgrades
	_mode_box.visible = not upgrades
	_parts_tab.button_pressed = not upgrades
	_upgrades_tab.button_pressed = upgrades


func _open(panel: Control) -> void:
	for overlay: Control in _overlays:
		overlay.visible = overlay == panel
	_backdrop.visible = true
	if panel == _stats_panel:
		_stats_panel.refresh(Game.state, Game.content)
	elif panel == _firmware_panel:
		_firmware_panel.refresh(Game.state, Game.content)
	elif panel == _settings_panel:
		_settings_panel.refresh()
	elif panel == _save_panel:
		_save_panel.show_export(SaveManager.export_text())
	elif panel == _ending_panel:
		_ending_panel.refresh(Game.state)


func _close_overlays() -> void:
	for overlay: Control in _overlays:
		overlay.visible = false
	_backdrop.visible = false


## Sounds when a bit starts to wear and when one goes bad or starts holding the Count, and a flash when a
## bad bit clears. The scrub puzzle closes if its bit was cleared some other way. The tutorial explains
## the first worn and bad bits.
func _notice_faults(state: GameState, blocked: bool) -> void:
	var cleared := state.faults_repaired + state.faults_scrubbed + state.faults_waited
	if (blocked and not _was_blocked) or (_bad_seen >= 0 and state.bad_bits.size() > _bad_seen):
		Audio.play("fault", 0.0)
	elif _wear_seen >= 0 and state.wear_started > 0 and state.wear_started != _wear_seen:
		Audio.play("wear", 0.0)
	if _faults_cleared >= 0 and cleared > _faults_cleared:
		_register.flash(Color(Palette.CYAN, 0.5))
	# A bit that held a 1 took its value with it: show what the Count lost.
	if _lost_seen >= 0.0 and state.count_lost > _lost_seen:
		var rect := _register.get_global_rect()
		_fx.float_text(rect.get_center(), "-%s" % NumberFormat.amount(state.count_lost - _lost_seen), Palette.FAULT)
		_register.flash(Color(Palette.FAULT, 0.35))
	if _scrub_panel.visible and _scrub_panel.bit != Economy.next_fault(state):
		_close_overlays()
	_faults_cleared = cleared
	_bad_seen = state.bad_bits.size()
	_wear_seen = state.wear_started
	_lost_seen = state.count_lost
	_was_blocked = blocked


## Clicking a worn bit, or right next to one, refreshes it. Anywhere else on the register increments.
func _on_register_clicked() -> void:
	var bit := _register.worn_bit_near(_register.get_local_mouse_position())
	if bit < 0:
		_on_increment()
		return
	if Game.refresh_bit(bit):
		_on_refreshed(_register.get_global_transform() * _register.bit_rect(bit).get_center(), 1)


func _on_refresh_all() -> void:
	var refreshed := Game.refresh_all()
	if refreshed > 0:
		var rect := _refresh_button.get_global_rect()
		_on_refreshed(Vector2(rect.get_center().x, rect.position.y), refreshed)


func _on_refreshed(at: Vector2, bits: int) -> void:
	Audio.play("refresh")
	_fx.float_text(at, "REFRESHED" if bits == 1 else "%d REFRESHED" % bits, Palette.CYAN)
	_refresh()


func _on_repair() -> void:
	if Game.repair_fault():
		Audio.play("buy")
	_refresh()


func _open_scrub() -> void:
	if Economy.next_fault(Game.state) < 0:
		return
	_scrub_panel.open_for(Game.state)
	_open(_scrub_panel)


func _on_scrubbed() -> void:
	if Game.scrub_fault():
		Audio.play("upgrade")
	_close_overlays()
	_refresh()


func _show_title() -> void:
	_title.refresh(Game.state)
	_title.visible = true
	_title.focus_primary()


func _on_title_continue() -> void:
	_title.visible = false
	get_viewport().gui_release_focus()


func _ask_start_over() -> void:
	_start_over_status.visible = false
	_open(_start_over_panel)


func _copy_save() -> void:
	DisplayServer.clipboard_set(SaveManager.export_text())
	_start_over_status.text = "Copied. Paste it somewhere safe before you start over."
	_start_over_status.visible = true


func _confirm_start_over() -> void:
	SaveManager.start_over()
	_hint_step = ""
	_hint.stop()
	_close_overlays()
	_title.visible = false
	get_viewport().gui_release_focus()
	_show_tab(false)
	_refresh()


## Quit on the start screen. Quitting from code skips the window's close request, so save first.
func _quit() -> void:
	if SaveManager.enabled:
		SaveManager.save_game()
	get_tree().quit()


func _toast(variation: StringName, heading: String, heading_color: Color, title: String, body: String, seconds: float = TOAST_SECONDS) -> void:
	var toast := PanelContainer.new()
	toast.theme_type_variation = variation
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	toast.add_child(box)
	var head := _heading(heading)
	head.add_theme_color_override("font_color", heading_color)
	box.add_child(head)
	# Wrapped, so a long message stays inside the toast column instead of running off the screen.
	for line: Label in [_label(title, 17, Palette.ICE), _label(body, 13, Palette.MUTED)]:
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(line)
	_toasts.add_child(toast)
	var tween := toast.create_tween()
	tween.tween_interval(seconds)
	tween.tween_property(toast, "modulate:a", 0.0, 0.5)
	tween.tween_callback(toast.queue_free)


func _on_achievement(id: StringName) -> void:
	var achievement: AchievementDef = Game.content.achievement_by_id.get(id)
	if achievement != null:
		_toast(&"ToastPanel", "ACHIEVEMENT  ·  +1% OUTPUT", Palette.VIOLET, achievement.display_name, achievement.description)


func _on_overflowed(carry: float) -> void:
	_register.flash(Color(1, 1, 1, 0.9))
	_fx.flash(Color(1, 1, 1, 0.75), 0.9)
	_fx.shockwave(_schematic.get_global_rect().get_center(), Palette.MAGENTA)
	var total := Game.state.total_carry
	_toast(&"OverflowToast", "OVERFLOW", Palette.MAGENTA, "+%s Carry" % NumberFormat.amount(carry), "Carry bonus ×%s, rippling in over %d minutes. Spend Carry on Firmware." % [
		NumberFormat.amount(Formulas.carry_bonus(total)), roundi(Formulas.CARRY_RIPPLE_SECONDS / 60.0)])


func _on_widened(_bits: int) -> void:
	_register.flash(Color(Palette.CYAN, 0.6))
	_fx.flash(Color(Palette.CYAN, 0.12), 0.4)


# --- Tutorial -----------------------------------------------------------------

## Ends the hint once its step is done, keeps it on its target, and opens the next step that is due,
## unless the start screen or another panel is open.
func _check_tutorial(state: GameState, content: Content) -> void:
	if _hint_step != "":
		if Tutorial.is_done(_hint_step, state):
			_hint_step = ""
			_hint.stop()
		else:
			_hint.place(_local_rect(_tutorial_target(_hint_step)))
	if _tutorial_off or _tutorial_step != "" or _title.visible or _backdrop.visible:
		return
	var step := Tutorial.next_step(state, content)
	if step != "":
		_show_tutorial(step)


## Pauses the game and explains a step, next to the part of the screen it's about.
func _show_tutorial(step: String) -> void:
	_tutorial_step = step
	Tutorial.mark_shown(Game.state, step)
	Game.paused = true
	_hint_step = ""
	_hint.stop()
	if step == "incrementer":
		_show_tab(false)
	elif step == "upgrade":
		_show_tab(true)
	# Let the layout settle after a tab switch before measuring where the target is.
	await get_tree().process_frame
	await get_tree().process_frame
	var text := _tutorial_text(step, Game.state, Game.content)
	_tutorial.open(text[0], text[1], _local_rect(_tutorial_target(step)))


func _on_tutorial_dismissed() -> void:
	var step := _tutorial_step
	_close_tutorial()
	# Point at what to do next until the player has done it.
	if step != "" and not Tutorial.is_done(step, Game.state):
		_hint_step = step
		_hint.show_on(_local_rect(_tutorial_target(step)))


func _on_tutorial_skipped() -> void:
	Tutorial.skip(Game.state)
	_close_tutorial()


func _close_tutorial() -> void:
	_tutorial_step = ""
	_tutorial.visible = false
	Game.paused = false
	get_viewport().gui_release_focus()


## What each step points at.
func _tutorial_target(step: String) -> Control:
	match step:
		"count":
			return _increment_button
		"incrementer":
			return _rows[0]
		"upgrade":
			for card: UpgradeCard in _cards:
				if card.visible and Economy.can_buy_upgrade(Game.state, card.upgrade):
					return card
			return _upgrades_tab
	return _register_panel


## [title, body] for a step, with the numbers the player sees right now.
func _tutorial_text(step: String, state: GameState, content: Content) -> Array[String]:
	match step:
		"count":
			return ["Count up", "You are a counter inside a machine. Press INCREMENT, or Space, to add 1 to the Count.\n\nThe register at the top holds the Count in binary: each lit cell is a 1. An %d-bit register holds up to %s. Widen it to count higher." % [
				state.register_bits, NumberFormat.amount(Formulas.register_cap(state.register_bits))]]
		"incrementer":
			return ["Buy an Incrementer", "You can afford an Incrementer. Each one adds %s to the Count every second by itself, so the Count keeps rising while you do other things.\n\nParts cost more each time you buy one, and every %d of the same part doubles its output." % [
				NumberFormat.rate(Economy.layer_rate(state, content, 0)), Formulas.MILESTONE_EVERY]]
		"upgrade":
			var target := _tutorial_target("upgrade") as UpgradeCard
			var which := ""
			if target != null:
				which = "%s (%s) costs %s. " % [target.upgrade.display_name, UpgradeCard.describe(target.upgrade, content), NumberFormat.amount(target.upgrade.cost)]
			return ["Buy an upgrade", "Upgrades are one-off boosts, bought with Count. %sBuy it here, under Upgrades.\n\nNew upgrades appear as you buy parts and widen the register. They last until you Overflow." % which]
		"wear":
			var bit := -1
			for worn: int in state.wearing:
				bit = worn
			return ["A bit is wearing out", "The machine's storage is old. Bit %d has started to wear: it glows amber, turns red, and %d seconds later it goes bad. If it holds a 1 then, the Count loses what that bit was worth.\n\nClick the bit, or press REFRESH under the register, to rewrite it in time. Bits wear out anywhere in the register, and more often as the machine ages." % [
				bit, roundi(Formulas.WEAR_SECONDS)]]
		"bad bit":
			var fault := Economy.next_fault(state)
			var lost := ""
			# The run log says whether the bit held a 1 when it went bad.
			for k: int in range(state.events.size() - 1, -1, -1):
				var event: Array = state.events[k]
				if event[1] != "bad bit" or not event[2] is Dictionary:
					continue
				var detail: Dictionary = event[2]
				if int(detail.get("bit", -1)) != fault:
					continue
				var amount := float(detail.get("lost", 0.0))
				if amount > 0.0:
					lost = " It held a 1, so the Count lost %s." % NumberFormat.amount(amount)
				break
			return ["A bit has gone bad", "Bit %d went bad before it was refreshed.%s The Count can't grow past a bad bit: it stops just below it, or if it's already higher, it stops growing.\n\nREPAIR the bit with Count, SCRUB it for free by solving a parity puzzle, or wait: %d seconds after it starts holding the Count, it scrubs itself." % [
				fault, lost, roundi(state.scrub_seconds)]]
	return ["", ""]


## Where a control is, in this screen's coordinates.
func _local_rect(control: Control) -> Rect2:
	var to_local := get_global_transform().affine_inverse()
	var rect := control.get_global_rect()
	return Rect2(to_local * rect.position, rect.size)


# --- Input --------------------------------------------------------------------

func _on_increment() -> void:
	var gain := Economy.click_value(Game.state, Game.content)
	Game.click()
	Audio.play("click")
	var rect := _increment_button.get_global_rect()
	_fx.float_text(Vector2(rect.get_center().x + randf_range(-30.0, 30.0), rect.position.y - 8.0), "+%s" % NumberFormat.amount(gain), Palette.CYAN)
	if not Settings.reduced_motion:
		_increment_button.pivot_offset = _increment_button.size / 2.0
		_increment_button.scale = Vector2(0.95, 0.95)
		_increment_button.create_tween().tween_property(_increment_button, "scale", Vector2.ONE, 0.12)
	_refresh()


func _on_widen() -> void:
	Game.widen()
	_refresh()


func _on_overclock() -> void:
	Game.overclock()
	_refresh()


func _ask_overflow() -> void:
	var state := Game.state
	if not Economy.can_overflow(state):
		return
	var gain := Economy.overflow_gain(state, Game.content)
	var total := state.total_carry + gain
	_confirm_label.text = "You'll earn %s Carry. The Count, every layer, the register, the clock and this run's upgrades reset. Carry, Firmware, achievements and stats stay.\n\nCarry multiplies Count per second: ×%s next run, up from ×%s. The bonus starts at ×1 and ripples in over the first %d minutes of each run, so you climb the widths again, faster each time.\n\nOverflow when a run slows down: the next one gets further." % [
		NumberFormat.amount(gain), NumberFormat.amount(Formulas.carry_bonus(total)), NumberFormat.amount(Formulas.carry_bonus(state.total_carry)), roundi(Formulas.CARRY_RIPPLE_SECONDS / 60.0)]
	_open(_confirm_panel)


func _confirm_overflow() -> void:
	_close_overlays()
	# Straight to the Firmware screen, where the new Carry gets spent.
	if Game.overflow() > 0.0:
		_open(_firmware_panel)
	_refresh()


func _on_buy(index: int) -> void:
	if Game.buy(index, _mode) > 0:
		_rows[index].flash()
	_refresh()


func _on_buy_upgrade(id: StringName) -> void:
	Game.buy_upgrade(id)
	_refresh()


func _on_mode(mode: int) -> void:
	_mode = mode
	_refresh()


# --- Dev tools ----------------------------------------------------------------

func _apply_dev_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--autoplay="):
			_skip_title = true
			_tutorial_off = true
			AutoPlayer.play(Game.state, Game.content, arg.get_slice("=", 1).to_float())
		elif arg.begins_with("--capture="):
			_skip_title = true
			_tutorial_off = true
			_tutorial.read_seconds = 0.0
			_capture_path = arg.get_slice("=", 1)
		elif arg.begins_with("--open="):
			for view: String in arg.get_slice("=", 1).split(","):
				_open_view.call_deferred(view)


func _open_view(view: String) -> void:
	match view:
		"title":
			_show_title()
		"start-over":
			_ask_start_over()
		"fault":
			# For screenshots: a bad bit just above the Count, with the Count filled up to it.
			var state := Game.state
			var bit := mini(state.register_bits - 1, floori(log(maxf(2.0, state.count)) / log(2.0)) + 2)
			if not state.bad_bits.has(bit):
				state.bad_bits.append(bit)
				state.bad_bits.sort()
			Economy.add_count(state, Formulas.register_cap(state.register_bits))
			state.blocked_time = 0.4 * state.scrub_seconds
			_refresh()
		"scrub":
			_open_scrub()
		"wear":
			# For screenshots: three bits wearing, just started, halfway and nearly bad.
			var state := Game.state
			var middle := floori(state.register_bits / 2.0)
			for pick: Vector2 in [Vector2(state.register_bits - 3, 0.05), Vector2(middle, 0.5), Vector2(2, 0.92)]:
				if not state.bad_bits.has(int(pick.x)):
					state.wearing[int(pick.x)] = Formulas.WEAR_SECONDS * pick.y
			_refresh()
		"tutorial-count", "tutorial-incrementer", "tutorial-upgrade", "tutorial-wear", "tutorial-bad-bit":
			var step := view.trim_prefix("tutorial-").replace("-", " ")
			var middle := floori(Game.state.register_bits / 2.0)
			if step == "wear" and Game.state.wearing.is_empty():
				Game.state.wearing[middle] = 12.0
			if step == "bad bit" and Game.state.bad_bits.is_empty():
				Game.state.bad_bits.append(middle)
			_refresh()
			_show_tutorial(step)
		"upgrades":
			_show_tab(true)
		"stats":
			_open(_stats_panel)
		"firmware":
			_open(_firmware_panel)
		"settings":
			_open(_settings_panel)
		"save":
			_open(_save_panel)
		"ending":
			_open(_ending_panel)
		"overflow":
			_ask_overflow()
		"overflow-fx":
			# Replays the Overflow flash and shockwave, for screenshots.
			_on_overflowed(32.0)
		"debug":
			if _debug_panel != null:
				_debug_panel.visible = true
		"toast":
			# Replays the latest achievement's pop-up, for screenshots.
			if not Game.state.achievements.is_empty():
				_on_achievement(Game.state.achievements[-1])


func _capture() -> void:
	for _frame: int in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := _capture_path
	if path.is_relative_path():
		path = ProjectSettings.globalize_path("res://").path_join(path)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := image.save_png(path)
	print("Captured %s: %s" % [path, error_string(err)])
	get_tree().quit(0 if err == OK else 1)
