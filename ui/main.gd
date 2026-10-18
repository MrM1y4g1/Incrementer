extends Control
## The grey-box main screen: register on top; Increment, Widen and Overclock in the middle; parts and
## upgrades on the right; a status bar with the stats screen along the bottom. The layout follows the
## wireframe in plan section 4; the look is a stand-in until M5.
##
## Dev flags, passed after `--` on the command line:
##   --no-save              do not read or write the save file (handled by SaveManager)
##   --autoplay=<seconds>   fast-forward a scripted player before the first frame
##   --open=<views>         open views at start, comma-separated: upgrades, stats, debug, toast
##   --capture=<png path>   save a screenshot after a few frames, then quit
## In debug builds, F3 shows the debug panel.

const REFRESH_SECONDS := 0.1
const OFFLINE_REPORT_MIN_SECONDS := 60.0
const SIDE_WIDTH := 480.0
const TOAST_SECONDS := 4.0

var _mode: int = Economy.BuyMode.ONE
var _capture_path := ""

var _register: RegisterDisplay
var _register_label: Label
var _bits_label: Label
var _count_label: Label
var _rate_label: Label
var _boost_label: Label
var _increment_button: Button
var _widen_button: Button
var _clock_button: Button
var _stats_label: Label
var _status_label: Label
var _parts_tab: Button
var _upgrades_tab: Button
var _mode_box: HBoxContainer
var _parts_scroll: ScrollContainer
var _upgrades_scroll: ScrollContainer
var _upgrades_empty: Label
var _rows: Array[LayerRow] = []
var _cards: Array[UpgradeCard] = []
var _backdrop: ColorRect
var _stats_panel: StatsPanel
var _debug_panel: DebugPanel
var _offline_panel: PanelContainer
var _offline_label: Label
var _toasts: VBoxContainer


func _ready() -> void:
	theme = ThemeFactory.build()
	_build()
	EventBus.achievement_unlocked.connect(_on_achievement)
	_apply_dev_args()

	var timer := Timer.new()
	timer.wait_time = REFRESH_SECONDS
	timer.autostart = true
	timer.timeout.connect(_refresh)
	add_child(timer)

	_refresh()
	_show_offline_report()
	if _capture_path != "":
		_capture.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_F3 and _debug_panel != null:
		_debug_panel.visible = not _debug_panel.visible
	elif key.keycode == KEY_ESCAPE:
		_close_stats()
		_offline_panel.visible = false


# --- Layout -------------------------------------------------------------------

func _build() -> void:
	var background := ColorRect.new()
	background.color = Palette.VOID
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)
	root.add_child(_build_top())
	root.add_child(_build_middle())
	root.add_child(_build_status_bar())

	_build_overlays()


func _build_top() -> Control:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)

	var register_panel := PanelContainer.new()
	register_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	register_panel.custom_minimum_size = Vector2(0, 150)
	top.add_child(register_panel)
	var register_box := VBoxContainer.new()
	register_box.add_theme_constant_override("separation", 8)
	register_panel.add_child(register_box)
	_register_label = _label("", 13, Palette.MUTED)
	register_box.add_child(_register_label)
	_register = RegisterDisplay.new()
	_register.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_register.custom_minimum_size = Vector2(0, 64)
	register_box.add_child(_register)
	_bits_label = _label("", 13, Palette.MUTED)
	register_box.add_child(_bits_label)

	var count_panel := PanelContainer.new()
	count_panel.custom_minimum_size = Vector2(SIDE_WIDTH, 150)
	top.add_child(count_panel)
	var count_box := VBoxContainer.new()
	count_box.add_theme_constant_override("separation", 0)
	count_panel.add_child(count_box)
	count_box.add_child(_label("COUNT", 13, Palette.MUTED))
	_count_label = _label("0", 44, Palette.CYAN)
	count_box.add_child(_count_label)
	_rate_label = _label("", 16, Palette.ICE)
	count_box.add_child(_rate_label)
	_boost_label = _label("", 13, Palette.MUTED)
	count_box.add_child(_boost_label)
	return top


func _build_middle() -> Control:
	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 16)

	var center := PanelContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_child(center)
	var center_box := VBoxContainer.new()
	center_box.alignment = BoxContainer.ALIGNMENT_CENTER
	center_box.add_theme_constant_override("separation", 14)
	center.add_child(center_box)

	_increment_button = _big_button(96, 28, _on_increment)
	center_box.add_child(_increment_button)
	_widen_button = _big_button(52, 16, _on_widen)
	center_box.add_child(_widen_button)
	_clock_button = _big_button(52, 16, _on_overclock)
	center_box.add_child(_clock_button)
	_stats_label = _label("", 13, Palette.MUTED)
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_box.add_child(_stats_label)

	middle.add_child(_build_side_panel())
	return middle


func _build_side_panel() -> Control:
	var side := PanelContainer.new()
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
		var mode_button := Button.new()
		mode_button.toggle_mode = true
		mode_button.button_group = modes
		mode_button.button_pressed = mode == _mode
		mode_button.text = "Max" if mode == Economy.BuyMode.MAX else "×%d" % mode
		mode_button.custom_minimum_size = Vector2(52, 0)
		mode_button.add_theme_font_size_override("font_size", 13)
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
	_upgrades_empty = _label("No upgrades available yet. Buy more layers or widen the register.", 13, Palette.MUTED)
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
	var bar := PanelContainer.new()
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	bar.add_child(box)
	_status_label = _label("", 13, Palette.MUTED)
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_status_label)
	var stats_button := Button.new()
	stats_button.text = "Stats and achievements"
	stats_button.add_theme_font_size_override("font_size", 13)
	stats_button.pressed.connect(_open_stats)
	box.add_child(stats_button)
	box.add_child(_label("Incrementer %s  ·  M2" % ProjectSettings.get_setting("application/config/version"), 13, Palette.MUTED))
	return bar


func _build_overlays() -> void:
	_backdrop = ColorRect.new()
	_backdrop.color = Color(Palette.VOID, 0.8)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.visible = false
	_backdrop.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.is_pressed():
			_close_stats())
	add_child(_backdrop)

	_stats_panel = StatsPanel.new(Game.content)
	_stats_panel.visible = false
	_stats_panel.closed.connect(_close_stats)
	_center(_stats_panel, Vector2(1040, 600))
	add_child(_stats_panel)

	_offline_panel = PanelContainer.new()
	_offline_panel.theme_type_variation = &"OverlayPanel"
	_offline_panel.visible = false
	_center(_offline_panel, Vector2(440, 0))
	add_child(_offline_panel)
	var offline_box := VBoxContainer.new()
	offline_box.add_theme_constant_override("separation", 12)
	_offline_panel.add_child(offline_box)
	offline_box.add_child(_label("WHILE YOU WERE AWAY", 13, Palette.MUTED))
	_offline_label = _label("", 18, Palette.ICE)
	_offline_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	offline_box.add_child(_offline_label)
	var close := Button.new()
	close.text = "Continue"
	close.pressed.connect(func() -> void: _offline_panel.visible = false)
	offline_box.add_child(close)

	_toasts = VBoxContainer.new()
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.anchor_left = 1.0
	_toasts.anchor_right = 1.0
	_toasts.offset_left = -344.0
	_toasts.offset_right = -24.0
	_toasts.offset_top = 24.0
	_toasts.add_theme_constant_override("separation", 8)
	add_child(_toasts)

	if OS.is_debug_build():
		_debug_panel = DebugPanel.new()
		_debug_panel.visible = false
		_debug_panel.position = Vector2(40, 206)
		add_child(_debug_panel)


func _center(panel: Control, min_size: Vector2) -> void:
	panel.custom_minimum_size = min_size
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH


func _big_button(height: float, font_size: int, action: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(360, height)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", font_size)
	button.pressed.connect(action)
	return button


func _tab_button(text: String, group: ButtonGroup, pressed: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.button_group = group
	button.button_pressed = pressed
	button.add_theme_font_size_override("font_size", 13)
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


# --- Updates ------------------------------------------------------------------

func _refresh() -> void:
	var state := Game.state
	var content := Game.content
	var full := Economy.is_full(state)
	var cap := Formulas.register_cap(state.register_bits)

	_count_label.text = NumberFormat.amount(state.count)
	_rate_label.text = "+%s per second" % NumberFormat.rate(Economy.count_per_second(state, content))
	_rate_label.add_theme_color_override("font_color", Palette.AMBER if full else Palette.ICE)
	_boost_label.text = "Clock %s Hz  ·  %d achievements, +%d%% output" % [
		NumberFormat.rate(Formulas.clock_multiplier(state.clock_level)), state.achievements.size(),
		roundi(state.achievements.size() * Formulas.ACHIEVEMENT_BONUS * 100.0)]

	_register.show_value(state.register_bits, state.count, full)
	_register_label.text = "REGISTER  ·  %d-BIT  ·  HOLDS %s" % [state.register_bits, NumberFormat.amount(cap)]
	if full:
		_bits_label.text = "Full. Widen the register to keep counting."
		_bits_label.add_theme_color_override("font_color", Palette.AMBER)
	else:
		_bits_label.text = "%.1f of %d bits used" % [log(state.count + 1.0) / log(2.0), state.register_bits]
		_bits_label.add_theme_color_override("font_color", Palette.MUTED)

	_increment_button.text = "INCREMENT   +%s" % NumberFormat.amount(Economy.click_value(state, content))

	var next := Formulas.next_width(state.register_bits)
	if next < 0:
		_widen_button.text = "Register at full width"
		_widen_button.disabled = true
	elif next > Economy.MAX_BITS_WITHOUT_FIRMWARE:
		_widen_button.text = "%d-bit needs Firmware" % next
		_widen_button.disabled = true
	else:
		_widen_button.text = "WIDEN TO %d-BIT   %s" % [next, NumberFormat.amount(Economy.widen_cost(state))]
		_widen_button.disabled = not Economy.can_widen(state)

	var clock_cost := Economy.clock_cost(state)
	var clock_from := NumberFormat.rate(Formulas.clock_multiplier(state.clock_level))
	var clock_to := NumberFormat.rate(Formulas.clock_multiplier(state.clock_level + 1))
	if clock_cost > cap:
		_clock_button.text = "OVERCLOCK   needs %d-bit" % Formulas.width_for(clock_cost)
		_clock_button.disabled = true
	else:
		_clock_button.text = "OVERCLOCK  %s → %s Hz   %s" % [clock_from, clock_to, NumberFormat.amount(clock_cost)]
		_clock_button.disabled = not Economy.can_overclock(state)

	_stats_label.text = "Clicks %d   ·   Peak %s   ·   Played %s" % [state.total_clicks, NumberFormat.amount(state.peak_count), NumberFormat.duration(state.play_time)]
	_status_label.text = SaveManager.status_text()

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


func _show_tab(upgrades: bool) -> void:
	_parts_scroll.visible = not upgrades
	_upgrades_scroll.visible = upgrades
	_mode_box.visible = not upgrades
	_parts_tab.button_pressed = not upgrades
	_upgrades_tab.button_pressed = upgrades


func _open_stats() -> void:
	_stats_panel.refresh(Game.state, Game.content)
	_stats_panel.visible = true
	_backdrop.visible = true


func _close_stats() -> void:
	_stats_panel.visible = false
	_backdrop.visible = false


func _show_offline_report() -> void:
	if SaveManager.offline_seconds < OFFLINE_REPORT_MIN_SECONDS:
		return
	_offline_label.text = "The machine ran for %s while you were gone and counted %s more." % [
		NumberFormat.duration(SaveManager.offline_seconds), NumberFormat.amount(SaveManager.offline_gain)]
	_offline_panel.visible = true


func _on_achievement(id: StringName) -> void:
	var achievement: AchievementDef = Game.content.achievement_by_id.get(id)
	if achievement == null:
		return
	var toast := PanelContainer.new()
	toast.theme_type_variation = &"ToastPanel"
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	toast.add_child(box)
	box.add_child(_label("ACHIEVEMENT  ·  +1% OUTPUT", 11, Palette.VIOLET))
	box.add_child(_label(achievement.display_name, 16, Palette.ICE))
	box.add_child(_label(achievement.description, 12, Palette.MUTED))
	_toasts.add_child(toast)
	var tween := toast.create_tween()
	tween.tween_interval(TOAST_SECONDS)
	tween.tween_property(toast, "modulate:a", 0.0, 0.5)
	tween.tween_callback(toast.queue_free)


# --- Input --------------------------------------------------------------------

func _on_increment() -> void:
	Game.click()
	_refresh()


func _on_widen() -> void:
	Game.widen()
	_refresh()


func _on_overclock() -> void:
	Game.overclock()
	_refresh()


func _on_buy(index: int) -> void:
	Game.buy(index, _mode)
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
			AutoPlayer.play(Game.state, Game.content, arg.get_slice("=", 1).to_float())
		elif arg.begins_with("--capture="):
			_capture_path = arg.get_slice("=", 1)
		elif arg.begins_with("--open="):
			for view: String in arg.get_slice("=", 1).split(","):
				match view:
					"upgrades":
						_show_tab(true)
					"stats":
						_open_stats.call_deferred()
					"debug":
						if _debug_panel != null:
							_debug_panel.visible = true
					"toast":
						# Replays the latest achievement's pop-up, for screenshots.
						if not Game.state.achievements.is_empty():
							_on_achievement.call_deferred(Game.state.achievements[-1])


func _capture() -> void:
	for _frame: int in 10:
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
