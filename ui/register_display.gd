class_name RegisterDisplay
extends Control
## Draws the register: one cell per bit, most significant bit on the left.
## Up to 64 bits sit in one row; wider registers stack into rows of 32 (32 × 32 at 1024 bits).
## A float keeps 53 significant bits, so on wider registers only the top 53 lit cells are exact.

const ROW_LIMIT := 64
const GRID_COLUMNS := 32
const MAX_CELL_WIDTH := 56.0

var _bits := 8
var _value := 0.0
var _full := false


func show_value(bits: int, value: float, full: bool) -> void:
	if bits == _bits and value == _value and full == _full:
		return
	_bits = bits
	_value = value
	_full = full
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var columns := _bits if _bits <= ROW_LIMIT else GRID_COLUMNS
	var rows := ceili(float(_bits) / columns)
	var gap := 6.0 if columns <= 16 else 3.0
	var cell_w := minf((size.x - gap * (columns - 1)) / columns, MAX_CELL_WIDTH)
	var cell_h := minf((size.y - gap * (rows - 1)) / rows, cell_w * 1.5 if rows == 1 else cell_w)
	var grid_h := cell_h * rows + gap * (rows - 1)
	var origin := Vector2(0.0, (size.y - grid_h) / 2.0)
	var lit := Palette.AMBER if _full else Palette.CYAN
	var glow := Color(lit, 0.16)

	for i: int in _bits:
		var column := i % columns
		var row := floori(float(i) / columns)
		var rect := Rect2(origin + Vector2(column * (cell_w + gap), row * (cell_h + gap)), Vector2(cell_w, cell_h))
		# A full register is all ones. Past 53 bits the cap itself can't be stored exactly as a float,
		# so reading the bits back would show it as empty.
		if _full or _is_set(_value, _bits - 1 - i):
			draw_rect(rect.grow(2.0), glow)
			draw_rect(rect, lit)
		else:
			draw_rect(rect, Palette.LINE, false, 1.0)


static func _is_set(value: float, bit: int) -> bool:
	if value < 1.0:
		return false
	return fmod(floor(value / pow(2.0, bit)), 2.0) >= 1.0
