class_name RegisterDisplay
extends Control
## Draws the register: one cell per bit, most significant bit first.
## Up to 64 bits sit in one row; wider registers stack into rows of 64.
## A float keeps 53 significant bits, so only the top 53 bits of the Count are shown exactly.
## Lower bits of a large Count shimmer, because they change too fast and too finely to show.
## Cells above the Count's highest bit are empty, so the grid fills up as the run goes on.
## Bad bits are red and crossed out; the one holding the Count pulses and fills with cyan as it scrubs.

const ROW_LIMIT := 64
const MAX_CELL_WIDTH := 56.0

var _bits := 8
var _value := 0.0
var _full := false
var _flash_color := Color(1, 1, 1, 0)
var _bad_bits: Array[int] = []
var _blocked := false
var _scrub_progress := 0.0


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


func _process(_delta: float) -> void:
	# The blocking bit pulses, so it needs drawing between the screen's 10 Hz refreshes.
	if _blocked and not Settings.reduced_motion:
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


func _draw() -> void:
	var columns := mini(_bits, ROW_LIMIT)
	var rows := ceili(float(_bits) / columns)
	var gap := 6.0 if columns <= 16 else (3.0 if rows == 1 else 2.0)
	var cell_w := minf((size.x - gap * (columns - 1)) / columns, MAX_CELL_WIDTH)
	var cell_h := minf(size.y, cell_w * 1.5) if rows == 1 else (size.y - gap * (rows - 1)) / rows
	var grid_h := cell_h * rows + gap * (rows - 1)
	var origin := Vector2(0.0, (size.y - grid_h) / 2.0)
	var magnitude := floori(log(_value) / log(2.0)) if _value >= 1.0 else -1
	var exact_from := magnitude - 52
	var tick := int(Time.get_ticks_msec() / 120)
	var outline := cell_w >= 8.0 and cell_h >= 8.0

	for i: int in _bits:
		var bit := _bits - 1 - i
		var column := i % columns
		var row := floori(float(i) / columns)
		var rect := Rect2(origin + Vector2(column * (cell_w + gap), row * (cell_h + gap)), Vector2(cell_w, cell_h))
		if _bad_bits.has(bit):
			_draw_fault(rect, bit, outline)
			continue
		var color: Color
		if _full:
			color = Palette.AMBER
		elif bit > magnitude:
			color = Color(0, 0, 0, 0)
		elif bit >= exact_from:
			color = Palette.CYAN if _is_set(_value, bit) else Color(Palette.CYAN, 0.08)
		else:
			# Below float precision: a gentle shimmer instead of fake digits.
			var noise := float(((bit * 7919 + tick * 104729) % 97)) / 97.0
			color = Color(Palette.CYAN, 0.1 + noise * 0.25)

		if color.a > 0.0:
			if color.a >= 0.99 and outline:
				draw_rect(rect.grow(2.0), Color(color, 0.16))
			draw_rect(rect, color)
		if outline and color.a < 0.99:
			draw_rect(rect, Palette.LINE, false, 1.0)
		elif not outline and color.a == 0.0:
			draw_rect(rect, Color(Palette.LINE, 0.6))
		if _flash_color.a > 0.0:
			draw_rect(rect, _flash_color)


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
	draw_rect(rect, line, false, 1.5)
	var inset := rect.grow(-minf(rect.size.x, rect.size.y) * 0.22)
	draw_line(inset.position, inset.end, line, 1.5)
	draw_line(Vector2(inset.end.x, inset.position.y), Vector2(inset.position.x, inset.end.y), line, 1.5)


static func _is_set(value: float, bit: int) -> bool:
	if value < 1.0:
		return false
	return fmod(floor(value / pow(2.0, bit)), 2.0) >= 1.0
