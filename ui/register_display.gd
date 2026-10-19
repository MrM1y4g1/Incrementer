class_name RegisterDisplay
extends Control
## Draws the register: one cell per bit, most significant bit first.
## Up to 64 bits sit in one row; wider registers stack into rows of 64.
## A float keeps 53 significant bits, so only the top 53 bits of the Count are shown exactly.
## Lower bits of a large Count shimmer, because they change too fast and too finely to show.
## Cells above the Count's highest bit are empty, so the grid fills up as the run goes on.
## Worn bits glow amber and turn red as they wear, flickering faster near the end. Bad bits are red and
## crossed out; the one holding the Count pulses and fills with cyan as it scrubs.
## Everything is drawn with rects and one texture, never outlines or lines: the register redraws many times
## a second, and in the browser every outline or line drawn makes a new WebGL buffer (see SchematicView).

const ROW_LIMIT := 64
const MAX_CELL_WIDTH := 56.0

var _bits := 8
var _value := 0.0
var _full := false
var _flash_color := Color(1, 1, 1, 0)
var _bad_bits: Array[int] = []
var _blocked := false
var _scrub_progress := 0.0
## Worn bits and how far each has worn, 0 to 1.
var _wear: Dictionary[int, float] = {}
var _cross := _make_cross()

# The grid, worked out from the width and the control's size.
var _columns := 8
var _rows := 1
var _gap := 6.0
var _cell := Vector2.ONE
var _origin := Vector2.ZERO


func show_value(bits: int, value: float, full: bool) -> void:
	_bits = bits
	_value = value
	_full = full
	queue_redraw()


## Bad bits to draw, whether the lowest is holding the Count, and how far it has scrubbed itself (0 to 1).
func show_faults(bad_bits: Array[int], blocked: bool, scrub_progress: float) -> void:
	_bad_bits = bad_bits.duplicate()
	_blocked = blocked
	_scrub_progress = scrub_progress


## Worn bits to draw: bit → how far it has worn, 0 to 1.
func show_wear(levels: Dictionary[int, float]) -> void:
	_wear = levels


## The worn bit at or next to a point in this control, or -1. Generous, because the cells of a wide
## register are only a few pixels tall.
func worn_bit_near(point: Vector2) -> int:
	_layout()
	var reach := Vector2(maxf(8.0, _cell.x), maxf(8.0, _cell.y))
	var nearest := -1
	var nearest_distance := INF
	for bit: int in _wear:
		var rect := _cell_rect(_bits - 1 - bit)
		if not rect.grow_individual(reach.x, reach.y, reach.x, reach.y).has_point(point):
			continue
		var distance := rect.get_center().distance_to(point)
		if distance < nearest_distance:
			nearest = bit
			nearest_distance = distance
	return nearest


## Where a bit's cell is, in this control.
func bit_rect(bit: int) -> Rect2:
	_layout()
	return _cell_rect(_bits - 1 - bit)


func _process(_delta: float) -> void:
	# The blocking bit pulses and worn bits flicker, so they need drawing between the screen's 10 Hz refreshes.
	if (_blocked or not _wear.is_empty()) and not Settings.reduced_motion:
		queue_redraw()


## Briefly lights the whole register in a colour, for widening and the Overflow.
func flash(color: Color) -> void:
	_flash_color = color
	var tween := create_tween()
	tween.tween_property(self, "_flash_color:a", 0.0, 0.6).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_method(func(_t: float) -> void: queue_redraw(), 0.0, 1.0, 0.6)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _layout() -> void:
	_columns = mini(_bits, ROW_LIMIT)
	_rows = ceili(float(_bits) / _columns)
	_gap = 6.0 if _columns <= 16 else (3.0 if _rows == 1 else 2.0)
	_cell.x = minf((size.x - _gap * (_columns - 1)) / _columns, MAX_CELL_WIDTH)
	_cell.y = minf(size.y, _cell.x * 1.5) if _rows == 1 else (size.y - _gap * (_rows - 1)) / _rows
	var grid_h := _cell.y * _rows + _gap * (_rows - 1)
	_origin = Vector2(0.0, (size.y - grid_h) / 2.0)


## The cell in position `i`, counting from the most significant bit.
func _cell_rect(i: int) -> Rect2:
	var column := i % _columns
	var row := floori(float(i) / _columns)
	return Rect2(_origin + Vector2(column * (_cell.x + _gap), row * (_cell.y + _gap)), _cell)


func _draw() -> void:
	_layout()
	var magnitude := floori(log(_value) / log(2.0)) if _value >= 1.0 else -1
	var exact_from := magnitude - 52
	var tick := int(Time.get_ticks_msec() / 120)
	var outline := _cell.x >= 8.0 and _cell.y >= 8.0

	for i: int in _bits:
		var bit := _bits - 1 - i
		var rect := _cell_rect(i)
		if _bad_bits.has(bit):
			_draw_fault(rect, bit, outline)
		elif _wear.has(bit):
			_draw_worn(rect, _wear[bit], outline)
		else:
			_draw_bit(rect, bit, magnitude, exact_from, tick, outline)
		if _flash_color.a > 0.0:
			draw_rect(rect, _flash_color)


func _draw_bit(rect: Rect2, bit: int, magnitude: int, exact_from: int, tick: int, outline: bool) -> void:
	var color: Color
	if _full:
		color = Palette.AMBER
	elif bit > magnitude:
		color = Color(0, 0, 0, 0)
	elif bit >= exact_from:
		color = Palette.CYAN if Economy.is_bit_set(_value, bit) else Color(Palette.CYAN, 0.08)
	else:
		# Below float precision: a gentle shimmer instead of fake digits.
		var noise := float(((bit * 7919 + tick * 104729) % 97)) / 97.0
		color = Color(Palette.CYAN, 0.1 + noise * 0.25)

	if color.a > 0.0:
		if color.a >= 0.99 and outline:
			draw_rect(rect.grow(2.0), Color(color, 0.16))
		draw_rect(rect, color)
	if outline and color.a < 0.99:
		_outline(rect, Palette.LINE, 1.0)
	elif not outline and color.a == 0.0:
		draw_rect(rect, Color(Palette.LINE, 0.6))


## Amber when it starts to wear, red by the time it goes bad, flickering faster as it gets there. In a
## single row of small cells, markers above and below make it easier to spot.
func _draw_worn(rect: Rect2, level: float, outline: bool) -> void:
	var color := Palette.AMBER.lerp(Palette.FAULT, level)
	var strength := 1.0
	if not Settings.reduced_motion:
		var speed := 3.0 + 14.0 * level * level
		strength = 0.65 + 0.35 * sin(Time.get_ticks_msec() / 1000.0 * speed)
	draw_rect(rect.grow(2.0 + 2.0 * level), Color(color, (0.15 + 0.25 * level) * strength))
	if not outline:
		draw_rect(rect, Color(color, (0.6 + 0.4 * level) * strength))
		return
	draw_rect(rect, Color(color, (0.3 + 0.5 * level) * strength))
	_outline(rect, Color(color, strength), 1.5)
	var room := (size.y - rect.size.y) / 2.0 - 4.0
	if _rows == 1 and rect.size.x < 24.0 and room >= 6.0:
		var marker := Vector2(maxf(2.0, rect.size.x * 0.4), minf(12.0, room))
		var x := rect.get_center().x - marker.x / 2.0
		draw_rect(Rect2(Vector2(x, rect.position.y - 4.0 - marker.y), marker), Color(color, 0.8 * strength))
		draw_rect(Rect2(Vector2(x, rect.end.y + 4.0), marker), Color(color, 0.8 * strength))


func _draw_fault(rect: Rect2, bit: int, outline: bool) -> void:
	var holding := _blocked and bit == _bad_bits[0]
	var strength := 1.0
	if holding and not Settings.reduced_motion:
		strength = 0.6 + 0.4 * sin(Time.get_ticks_msec() / 150.0)
	if not outline:
		draw_rect(rect, Color(Palette.FAULT, strength))
		return
	draw_rect(rect.grow(2.0), Color(Palette.FAULT, 0.12 * strength))
	draw_rect(rect, Color(Palette.FAULT, 0.2 * strength))
	if holding and _scrub_progress > 0.0:
		var filled := rect.size.y * clampf(_scrub_progress, 0.0, 1.0)
		draw_rect(Rect2(rect.position.x, rect.end.y - filled, rect.size.x, filled), Color(Palette.CYAN, 0.45))
	var line := Color(Palette.FAULT, strength)
	_outline(rect, line, 1.5)
	var side := minf(rect.size.x, rect.size.y) * 0.6
	draw_texture_rect(_cross, Rect2(rect.get_center() - Vector2(side, side) / 2.0, Vector2(side, side)), false, line)


## A rectangle's border as four thin filled rects.
func _outline(rect: Rect2, color: Color, width: float) -> void:
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, width)), color)
	draw_rect(Rect2(rect.position.x, rect.end.y - width, rect.size.x, width), color)
	draw_rect(Rect2(rect.position.x, rect.position.y + width, width, rect.size.y - width * 2.0), color)
	draw_rect(Rect2(rect.end.x - width, rect.position.y + width, width, rect.size.y - width * 2.0), color)


## A white X, tinted when drawn.
static func _make_cross() -> Texture2D:
	var side := 32
	var image := Image.create(side, side, false, Image.FORMAT_RGBA8)
	for y: int in side:
		for x: int in side:
			var px := x + 0.5
			var py := y + 0.5
			# Distance to each diagonal, so the strokes have soft edges.
			var distance := minf(absf(px - py), absf(px + py - side)) / sqrt(2.0)
			image.set_pixel(x, y, Color(1, 1, 1, clampf(2.2 - distance, 0.0, 1.0)))
	return ImageTexture.create_from_image(image)
