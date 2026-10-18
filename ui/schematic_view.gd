class_name SchematicView
extends Control
## The machine itself: one row per Software tier, tier 1 at the top, nearest the register.
## Each bought unit is a module drawn as a polygon with tier + 2 sides. A spine on the left carries
## pulses of light up from each row to the one above, faster when that layer produces more.
## Owned Firmware sits on the violet rail at the far left.
##
## The modules are polygons, and in the browser every polygon drawn gets a fresh WebGL buffer. Redrawn every
## frame, they leaked about 2 MB a second until the tab ran out of memory (1.3.1). So the modules, labels and
## links redraw only when what they show changes, and only the pulses move every frame, drawn from one small
## dot texture so they add no new geometry.

const MAX_MODULES := 12
const RAIL_WIDTH := 44.0
const LABEL_WIDTH := 96.0
const PULSE_RADIUS := 2.5

var state: GameState
var content: Content
var reduced_motion := false

var _time := 0.0
var _heading_font := Fonts.heading()
var _mono_font := Fonts.mono()
var _pulses: Control
var _dot := _make_dot()
## What the drawn modules, labels and links show; they're redrawn only when it changes.
var _drawn := ""


func _ready() -> void:
	_pulses = Control.new()
	_pulses.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pulses.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pulses.draw.connect(_draw_pulses)
	add_child(_pulses)


func _process(delta: float) -> void:
	if not is_visible_in_tree() or state == null or content == null:
		return
	_time += delta
	var showing := _showing()
	if showing != _drawn:
		_drawn = showing
		queue_redraw()
	_pulses.queue_redraw()


## Everything the slow layer draws: modules shown per row, unlocked rows, links, Firmware and the size.
func _showing() -> String:
	var parts := PackedStringArray([str(size), str(state.firmware.size())])
	for i: int in content.layers.size():
		parts.append("%d%s%s" % [mini(state.layer_bought[i], MAX_MODULES), "u" if Economy.is_unlocked(state, content.layers[i]) else "", "o" if state.layer_amount[i] > 0.0 else ""])
	return ",".join(parts)


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

	# The link from this row up to the one above (tier 1 links to the register at the top edge).
	if not unlocked or owned <= 0.0:
		return
	var top := y - row_h if i > 0 else 0.0
	draw_line(Vector2(spine_x, y), Vector2(spine_x, top), Color(Palette.CYAN, 0.3), 1.0)


## The fast layer, every frame: pulses running up the spine, and the count of modules past the twelfth.
## Only textured rects and text, which reuse the same buffers frame after frame.
func _draw_pulses() -> void:
	if state == null or content == null or content.layers.is_empty():
		return
	var rows := content.layers.size()
	var row_h := size.y / rows
	var spine_x := RAIL_WIDTH + LABEL_WIDTH - 10.0
	var x0 := spine_x + 14.0
	var spacing := minf((size.x - x0 - 46.0) / MAX_MODULES, row_h * 1.15)
	for i: int in rows:
		var y := row_h * (i + 0.5)
		var bought := state.layer_bought[i]
		if bought > MAX_MODULES:
			_pulses.draw_string(_mono_font, Vector2(x0 + spacing * MAX_MODULES + 4.0, y + 4.0), "+%s" % NumberFormat.amount(bought - MAX_MODULES),
				HORIZONTAL_ALIGNMENT_LEFT, 44.0, 11, Palette.MUTED)
		var owned := state.layer_amount[i]
		if not Economy.is_unlocked(state, content.layers[i]) or owned <= 0.0:
			continue
		var top := y - row_h if i > 0 else 0.0
		var rate := owned * Economy.layer_rate(state, content, i)
		var pulses := clampi(1 + int(log(rate + 1.0) / log(10.0) / 4.0), 1, 4)
		for p: int in pulses:
			var progress := fmod(float(p) / pulses + (0.0 if reduced_motion else _time * 0.6), 1.0)
			var at := Vector2(spine_x, lerpf(y, top, progress))
			_pulses.draw_texture_rect(_dot, Rect2(at - Vector2.ONE * PULSE_RADIUS, Vector2.ONE * PULSE_RADIUS * 2.0), false, Palette.CYAN)


## A soft white dot, tinted when drawn.
static func _make_dot() -> Texture2D:
	var side := 16
	var image := Image.create(side, side, false, Image.FORMAT_RGBA8)
	var center := Vector2(side, side) / 2.0
	for y: int in side:
		for x: int in side:
			var distance := (Vector2(x + 0.5, y + 0.5) - center).length()
			image.set_pixel(x, y, Color(1, 1, 1, clampf(side / 2.0 - distance, 0.0, 1.0)))
	return ImageTexture.create_from_image(image)


func _dashed_polygon(center: Vector2, radius: float, sides: int, color: Color) -> void:
	var points := Shapes.outline(center, radius, sides)
	for k: int in sides:
		draw_dashed_line(points[k], points[k + 1], color, 1.0, 3.0)
