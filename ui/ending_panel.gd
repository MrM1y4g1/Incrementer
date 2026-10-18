class_name EndingPanel
extends PanelContainer
## The V1 ending: shown once the 1024-bit register is full, with the totals and the run history.

signal closed

var _summary: Label
var _runs: GridContainer


func _init() -> void:
	theme_type_variation = &"OverlayPanel"
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	add_child(root)

	root.add_child(_label("THE MACHINE IS COMPLETE", 13, Palette.VIOLET))
	var headline := _label("Every bit of a 1024-bit register is set.", 30, Palette.ICE)
	headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(headline)
	var body := _label("The Count stands at 1.80 × 10^308, the largest number a 64-bit float can hold. There is nowhere left to count. The save stays yours: keep playing, Overflow again, or try for a faster run.", 15, Palette.MUTED)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(body)
	_summary = _label("", 15, Palette.ICE)
	root.add_child(_summary)

	root.add_child(_label("RUN HISTORY", 12, Palette.MUTED))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_runs = GridContainer.new()
	_runs.columns = 4
	_runs.add_theme_constant_override("h_separation", 40)
	_runs.add_theme_constant_override("v_separation", 4)
	scroll.add_child(_runs)

	var keep := Button.new()
	keep.text = "Keep counting"
	keep.size_flags_horizontal = Control.SIZE_SHRINK_END
	keep.pressed.connect(func() -> void: closed.emit())
	root.add_child(keep)


func refresh(state: GameState) -> void:
	_summary.text = "Finished in %s of play  ·  %d Overflows  ·  %s Carry earned  ·  %d clicks" % [
		NumberFormat.duration(state.ended_time if state.ended else state.play_time), state.overflows,
		NumberFormat.amount(state.total_carry), state.total_clicks]
	for child: Node in _runs.get_children():
		child.queue_free()
	for heading: String in ["RUN", "TIME", "PEAK", "CARRY"]:
		_runs.add_child(_label(heading, 11, Palette.MUTED))
	var first := maxi(0, state.overflows - state.runs.size()) + 1
	for i: int in state.runs.size():
		var run: Dictionary = state.runs[i]
		_runs.add_child(_label(str(first + i), 14, Palette.ICE))
		_runs.add_child(_label(NumberFormat.duration(float(run["time"])), 14, Palette.ICE))
		_runs.add_child(_label("%.0f bits" % float(run["bits"]), 14, Palette.ICE))
		_runs.add_child(_label("+%s" % NumberFormat.amount(float(run["carry"])), 14, Palette.ICE))


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
