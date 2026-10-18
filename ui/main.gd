extends Control
## The grey-box main screen (milestone M1): register on top, Increment and Widen in the middle,
## the parts list on the right and a status bar along the bottom. The layout follows the
## wireframe in plan section 4; the look is a stand-in until M5.
##
## Dev flags, passed after `--` on the command line:
##   --no-save              do not read or write the save file (handled by SaveManager)
##   --autoplay=<seconds>   fast-forward a scripted player before the first frame
##   --capture=<png path>   save a screenshot after a few frames, then quit

const REFRESH_SECONDS := 0.1
const OFFLINE_REPORT_MIN_SECONDS := 60.0
const PARTS_WIDTH := 480.0

var _mode: int = Economy.BuyMode.ONE
var _capture_path := ""

var _register: RegisterDisplay
var _register_label: Label
var _bits_label: Label
var _count_label: Label
var _rate_label: Label
var _increment_button: Button
var _widen_button: Button
var _stats_label: Label
var _status_label: Label
var _rows: Array[LayerRow] = []
var _offline_panel: PanelContainer
var _offline_label: Label


func _ready() -> void:
	theme = ThemeFactory.build()
	_build()
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
	_build_offline_panel()


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
	count_panel.custom_minimum_size = Vector2(PARTS_WIDTH, 150)
	top.add_child(count_panel)
	var count_box := VBoxContainer.new()
	count_box.add_theme_constant_override("separation", 2)
	count_panel.add_child(count_box)
	count_box.add_child(_label("COUNT", 13, Palette.MUTED))
	_count_label = _label("0", 48, Palette.CYAN)
	count_box.add_child(_count_label)
	_rate_label = _label("", 16, Palette.ICE)
	count_box.add_child(_rate_label)
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
	center_box.add_theme_constant_override("separation", 16)
	center.add_child(center_box)

	_increment_button = Button.new()
	_increment_button.text = "INCREMENT   +1"
	_increment_button.custom_minimum_size = Vector2(340, 96)
	_increment_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_increment_button.add_theme_font_size_override("font_size", 28)
	_increment_button.pressed.connect(_on_increment)
	center_box.add_child(_increment_button)

	_widen_button = Button.new()
	_widen_button.custom_minimum_size = Vector2(340, 52)
	_widen_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_widen_button.pressed.connect(_on_widen)
	center_box.add_child(_widen_button)

	_stats_label = _label("", 13, Palette.MUTED)
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_box.add_child(_stats_label)

	middle.add_child(_build_parts_list())
	return middle


func _build_parts_list() -> Control:
	var parts := PanelContainer.new()
	parts.custom_minimum_size = Vector2(PARTS_WIDTH, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	parts.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	box.add_child(header)
	var title := _label("PARTS", 13, Palette.MUTED)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var group := ButtonGroup.new()
	for mode: int in [Economy.BuyMode.ONE, Economy.BuyMode.TEN, Economy.BuyMode.MAX]:
		var mode_button := Button.new()
		mode_button.toggle_mode = true
		mode_button.button_group = group
		mode_button.button_pressed = mode == _mode
		mode_button.text = "Max" if mode == Economy.BuyMode.MAX else "×%d" % mode
		mode_button.custom_minimum_size = Vector2(56, 0)
		mode_button.add_theme_font_size_override("font_size", 13)
		mode_button.pressed.connect(_on_mode.bind(mode))
		header.add_child(mode_button)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	for i: int in Game.layers.size():
		var row := LayerRow.new(i)
		row.buy_pressed.connect(_on_buy)
		list.add_child(row)
		_rows.append(row)
	return parts


func _build_status_bar() -> Control:
	var bar := PanelContainer.new()
	var box := HBoxContainer.new()
	bar.add_child(box)
	_status_label = _label("", 13, Palette.MUTED)
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_status_label)
	box.add_child(_label("Incrementer %s  ·  M1 grey box" % ProjectSettings.get_setting("application/config/version"), 13, Palette.MUTED))
	return bar


func _build_offline_panel() -> void:
	_offline_panel = PanelContainer.new()
	_offline_panel.visible = false
	_offline_panel.custom_minimum_size = Vector2(420, 0)
	_offline_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(_offline_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_offline_panel.add_child(box)
	box.add_child(_label("WHILE YOU WERE AWAY", 13, Palette.MUTED))
	_offline_label = _label("", 18, Palette.ICE)
	_offline_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_offline_label)
	var close := Button.new()
	close.text = "Continue"
	close.pressed.connect(func() -> void: _offline_panel.visible = false)
	box.add_child(close)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


# --- Updates ------------------------------------------------------------------

func _refresh() -> void:
	var state := Game.state
	var layers := Game.layers
	var full := Economy.is_full(state)
	var cap := Formulas.register_cap(state.register_bits)

	_count_label.text = NumberFormat.amount(state.count)
	_rate_label.text = "+%s per second" % NumberFormat.rate(Economy.count_per_second(state, layers))
	_rate_label.add_theme_color_override("font_color", Palette.AMBER if full else Palette.ICE)
	_register.show_value(state.register_bits, state.count, full)
	_register_label.text = "REGISTER  ·  %d-BIT  ·  HOLDS %s" % [state.register_bits, NumberFormat.amount(cap)]
	if full:
		_bits_label.text = "Full. Widen the register to keep counting."
		_bits_label.add_theme_color_override("font_color", Palette.AMBER)
	else:
		var used := log(state.count + 1.0) / log(2.0)
		_bits_label.text = "%.1f of %d bits used" % [used, state.register_bits]
		_bits_label.add_theme_color_override("font_color", Palette.MUTED)

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

	_stats_label.text = "Clicks %d   ·   Peak %s   ·   Played %s" % [state.total_clicks, NumberFormat.amount(state.peak_count), NumberFormat.duration(state.play_time)]
	_status_label.text = SaveManager.status_text()

	# Show the unlocked layers plus the next one, so the list grows as the run does.
	var teaser_shown := false
	for row: LayerRow in _rows:
		var unlocked := Economy.is_unlocked(state, layers[row.index])
		row.visible = unlocked or not teaser_shown
		if not unlocked:
			teaser_shown = true
		if row.visible:
			row.refresh(state, layers, _mode)


func _show_offline_report() -> void:
	if SaveManager.offline_seconds < OFFLINE_REPORT_MIN_SECONDS:
		return
	_offline_label.text = "The machine ran for %s while you were gone and counted %s more." % [
		NumberFormat.duration(SaveManager.offline_seconds), NumberFormat.amount(SaveManager.offline_gain)]
	_offline_panel.visible = true


# --- Input --------------------------------------------------------------------

func _on_increment() -> void:
	Game.click()
	_refresh()


func _on_widen() -> void:
	Game.widen()
	_refresh()


func _on_buy(index: int) -> void:
	Game.buy(index, _mode)
	_refresh()


func _on_mode(mode: int) -> void:
	_mode = mode
	_refresh()


# --- Dev tools ----------------------------------------------------------------

func _apply_dev_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--autoplay="):
			AutoPlayer.play(Game.state, Game.layers, arg.get_slice("=", 1).to_float())
		elif arg.begins_with("--capture="):
			_capture_path = arg.get_slice("=", 1)


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
