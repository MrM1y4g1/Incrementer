class_name StatsPanel
extends PanelContainer
## The stats screen: run numbers on the left, every achievement on the right.

signal closed

const STAT_NAMES: PackedStringArray = ["Played", "This run", "Clicks", "Peak Count", "Total counted", "Register", "Clock", "Upgrades", "Overflows", "Carry earned", "Firmware", "Achievements", "Worn bits refreshed", "Bad bits cleared"]

var _values := {}
var _cells := {}
var _summary: Label


func _init(content: Content) -> void:
	theme_type_variation = &"OverlayPanel"

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	var title := _label("STATS", 13, Palette.MUTED)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(func() -> void: closed.emit())
	header.add_child(close)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 32)
	root.add_child(body)

	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", 24)
	stats.add_theme_constant_override("v_separation", 10)
	stats.custom_minimum_size = Vector2(280, 0)
	body.add_child(stats)
	for stat_name: String in STAT_NAMES:
		stats.add_child(_label(stat_name, 14, Palette.MUTED))
		var value := _label("", 14, Palette.ICE)
		stats.add_child(value)
		_values[stat_name] = value

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	body.add_child(right)
	_summary = _label("", 13, Palette.MUTED)
	right.add_child(_summary)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	for achievement: AchievementDef in content.achievements:
		var cell := PanelContainer.new()
		cell.custom_minimum_size = Vector2(178, 0)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cell_box := VBoxContainer.new()
		cell_box.add_theme_constant_override("separation", 2)
		cell.add_child(cell_box)
		cell_box.add_child(_label(achievement.display_name, 14, Palette.ICE))
		var description := _label(achievement.description, 12, Palette.MUTED)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cell_box.add_child(description)
		grid.add_child(cell)
		_cells[achievement.id] = cell


func refresh(state: GameState, content: Content) -> void:
	_set_stat("Played", NumberFormat.duration(state.play_time))
	_set_stat("Clicks", str(state.total_clicks))
	_set_stat("Peak Count", NumberFormat.amount(state.peak_count))
	_set_stat("Total counted", NumberFormat.amount(state.total_produced))
	_set_stat("Register", "%d-bit" % state.register_bits)
	_set_stat("Clock", "%s Hz  (level %d)" % [NumberFormat.rate(Formulas.clock_multiplier(state.clock_level)), state.clock_level])
	_set_stat("This run", NumberFormat.duration(state.run_time))
	_set_stat("Upgrades", "%d of %d" % [state.upgrades.size(), content.upgrades.size()])
	_set_stat("Overflows", str(state.overflows))
	_set_stat("Carry earned", NumberFormat.amount(state.total_carry))
	_set_stat("Firmware", "%d of %d" % [state.firmware.size(), content.firmware.size()])
	var unlocked := state.achievements.size()
	_set_stat("Achievements", "%d of %d" % [unlocked, content.achievements.size()])
	_set_stat("Worn bits refreshed", str(state.faults_refreshed))
	_set_stat("Bad bits cleared", "%d repaired, %d scrubbed, %d waited out" % [state.faults_repaired, state.faults_scrubbed, state.faults_waited])
	_summary.text = "ACHIEVEMENTS  ·  %d UNLOCKED  ·  +%d%% OUTPUT" % [unlocked, roundi(unlocked * Formulas.ACHIEVEMENT_BONUS * 100.0)]
	for id: StringName in _cells:
		var cell: PanelContainer = _cells[id]
		cell.theme_type_variation = &"AchievementOn" if state.achievements.has(id) else &"AchievementOff"


func _set_stat(stat_name: String, text: String) -> void:
	var label: Label = _values[stat_name]
	label.text = text


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
