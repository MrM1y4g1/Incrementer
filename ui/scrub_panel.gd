class_name ScrubPanel
extends PanelContainer
## The scrub puzzle for the bad bit holding the Count: a word of bits with one flipped. Every row and column
## should hold an even number of 1s; flipping the bit where the odd row and the odd column cross fixes both.
## Solving it clears the bad bit for free.

signal closed
signal solved

const CELL_SIZE := 46.0

## The bad bit this puzzle scrubs, so the main screen can tell when it has been cleared some other way.
var bit := -1

var _grid: ParityGrid
var _title: Label
var _table: GridContainer
var _cells: Array[Button] = []
var _row_marks: Array[Label] = []
var _column_marks: Array[Label] = []


func _init() -> void:
	theme_type_variation = &"FaultPanel"
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	add_child(root)

	_title = _label("", 12, Palette.FAULT)
	_title.add_theme_font_override("font", Fonts.heading())
	root.add_child(_title)
	var help := _label("One bit in this word has flipped. Every row and column should hold an even number of 1s, and the lines marked ODD don't. Click bits to flip them until every line reads OK.", 15, Palette.ICE)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(help)

	var center := CenterContainer.new()
	root.add_child(center)
	_table = GridContainer.new()
	_table.add_theme_constant_override("h_separation", 6)
	_table.add_theme_constant_override("v_separation", 6)
	center.add_child(_table)

	var buttons := HBoxContainer.new()
	root.add_child(buttons)
	var note := _label("Closing leaves the bit to scrub itself.", 13, Palette.MUTED)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(note)
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(100, 0)
	close.pressed.connect(func() -> void: closed.emit())
	buttons.add_child(close)


## Builds the puzzle for the lowest bad bit.
func open_for(state: GameState) -> void:
	bit = Economy.next_fault(state)
	_grid = Economy.scrub_puzzle(state)
	_title.text = "SCRUB BAD BIT %d" % bit
	for child: Node in _table.get_children():
		child.queue_free()
	_cells.clear()
	_row_marks.clear()
	_column_marks.clear()
	_table.columns = _grid.size + 1
	for row: int in _grid.size:
		for column: int in _grid.size:
			var cell := Button.new()
			cell.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
			cell.add_theme_font_override("font", Fonts.mono())
			cell.add_theme_font_size_override("font_size", 20)
			cell.focus_mode = Control.FOCUS_NONE
			cell.pressed.connect(_on_cell.bind(row * _grid.size + column))
			_table.add_child(cell)
			_cells.append(cell)
		var mark := _mark()
		_table.add_child(mark)
		_row_marks.append(mark)
	for column: int in _grid.size:
		var mark := _mark()
		_table.add_child(mark)
		_column_marks.append(mark)
	_table.add_child(Control.new())
	_show()


func _on_cell(index: int) -> void:
	_grid.flip(index)
	Audio.play("click")
	_show()
	if _grid.solved():
		solved.emit()


func _show() -> void:
	for i: int in _cells.size():
		var is_set := _grid.cells[i] == 1
		_cells[i].text = "1" if is_set else "0"
		_cells[i].add_theme_color_override("font_color", Palette.CYAN if is_set else Palette.MUTED)
		_cells[i].add_theme_color_override("font_hover_color", Palette.CYAN if is_set else Palette.ICE)
	for i: int in _grid.size:
		_set_mark(_row_marks[i], _grid.row_even(i))
		_set_mark(_column_marks[i], _grid.column_even(i))


func _set_mark(mark: Label, even: bool) -> void:
	mark.text = "OK" if even else "ODD"
	mark.add_theme_color_override("font_color", Palette.MUTED if even else Palette.FAULT)


func _mark() -> Label:
	var mark := _label("", 12, Palette.MUTED)
	mark.add_theme_font_override("font", Fonts.heading())
	mark.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE * 0.5)
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return mark


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
