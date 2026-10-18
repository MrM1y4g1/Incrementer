class_name SchematicView
extends Control
## The machine itself: one row per Software tier, tier 1 at the top, nearest the register.
## Each bought unit is a module drawn as a polygon with tier + 2 sides. A spine on the left carries
## pulses of light up from each row to the one above, faster when that layer produces more.
## Owned Firmware sits on the violet rail at the far left.

const MAX_MODULES := 12
const RAIL_WIDTH := 44.0
const LABEL_WIDTH := 96.0

var state: GameState
var content: Content
var reduced_motion := false

var _time := 0.0
var _heading_font := Fonts.heading()
var _mono_font := Fonts.mono()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	queue_redraw()


func _draw() -> void:
	if state == null or content == null or content.layers.is_empty():
		return
	_draw_firmware_rail()
	var rows := content.layers.size()
	var row_h := size.y / rows
	var spine_x := RAIL_WIDTH + LABEL_WIDTH - 10.0
	for i: int in rows:
		_draw_row(i, row_h, spine_x)


func _draw_firmware_rail() -> void:
	var x := RAIL_WIDTH * 0.5
	draw_line(Vector2(RAIL_WIDTH - 6.0, 4.0), Vector2(RAIL_WIDTH - 6.0, size.y - 4.0), Color(Palette.VIOLET, 0.25), 1.0)
	var per_column := maxi(1, int((size.y - 12.0) / 16.0))
	for k: int in state.firmware.size():
		var column := floori(float(k) / per_column)
		var row := k % per_column
		var center := Vector2(x - 8.0 + column * 14.0, 12.0 + row * 16.0)
		var diamond := Shapes.polygon(center, 5.0, 4)
		draw_colored_polygon(diamond, Color(Palette.VIOLET, 0.35))
		var outline := Shapes.outline(center, 5.0, 4)
		draw_polyline(outline, Palette.VIOLET, 1.0, true)


func _draw_row(i: int, row_h: float, spine_x: float) -> void:
	var layer := content.layers[i]
	var y := row_h * (i + 0.5)
	var unlocked := Economy.is_unlocked(state, layer)
	var bought := state.layer_bought[i]
	var owned := state.layer_amount[i]
	var label_color := Palette.MUTED if unlocked else Color(Palette.MUTED, 0.45)
	draw_string(_heading_font, Vector2(RAIL_WIDTH + 6.0, y + 4.0), layer.display_name.to_upper(),
		HORIZONTAL_ALIGNMENT_LEFT, LABEL_WIDTH - 20.0, 11, label_color)

	var x0 := spine_x + 14.0
	var spacing := minf((size.x - x0 - 46.0) / MAX_MODULES, row_h * 1.15)
	var radius := minf(spacing * 0.36, row_h * 0.34)
	var sides := layer.tier + 2
	var shown := mini(bought, MAX_MODULES)

	if unlocked:
		draw_line(Vector2(spine_x, y), Vector2(x0 + spacing * maxf(shown, 1.0) - spacing * 0.5, y), Color(Palette.LINE, 0.9), 1.0)
	for k: int in MAX_MODULES:
		var center := Vector2(x0 + spacing * (k + 0.5), y)
		if k < shown:
			draw_colored_polygon(Shapes.polygon(center, radius, sides), Color(Palette.CYAN, 0.12))
			draw_polyline(Shapes.outline(center, radius, sides), Palette.CYAN, 1.5, true)
		elif (unlocked and k < shown + 2) or (not unlocked and k < 2):
			_dashed_polygon(center, radius, sides, Color(Palette.LINE, 0.9 if unlocked else 0.5))
	if bought > MAX_MODULES:
		draw_string(_mono_font, Vector2(x0 + spacing * MAX_MODULES + 4.0, y + 4.0), "+%s" % NumberFormat.amount(bought - MAX_MODULES),
			HORIZONTAL_ALIGNMENT_LEFT, 44.0, 11, Palette.MUTED)

	# The link from this row up to the one above (tier 1 links to the register at the top edge).
	if not unlocked or owned <= 0.0:
		return
	var top := y - row_h if i > 0 else 0.0
	draw_line(Vector2(spine_x, y), Vector2(spine_x, top), Color(Palette.CYAN, 0.3), 1.0)
	var rate := owned * Economy.layer_rate(state, content, i)
	var pulses := clampi(1 + int(log(rate + 1.0) / log(10.0) / 4.0), 1, 4)
	for p: int in pulses:
		var progress := fmod(float(p) / pulses + (0.0 if reduced_motion else _time * 0.6), 1.0)
		draw_circle(Vector2(spine_x, lerpf(y, top, progress)), 2.5, Palette.CYAN, true, -1.0, true)


func _dashed_polygon(center: Vector2, radius: float, sides: int, color: Color) -> void:
	var points := Shapes.outline(center, radius, sides)
	for k: int in sides:
		draw_dashed_line(points[k], points[k + 1], color, 1.0, 3.0)
