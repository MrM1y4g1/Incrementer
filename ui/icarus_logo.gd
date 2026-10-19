class_name IcarusLogo
extends Control
## The Icarus emblem, in one colour: a winged figure tumbling across the sun, shedding feathers. Where the
## figure crosses the sun it's cut out of it (drawn in `cut_color`, the colour of what's behind); where it
## reaches past the sun it's drawn in the logo's colour, so the figure reads on both.
## It draws once and only redraws when it's resized, because in the browser every polygon drawn makes a new
## WebGL buffer (see SchematicView).

## In the figure's units the sun's radius is 1, and the longest rays reach RAY_LONG.
const RAY_LONG := 1.42
const RAY_SHORT := 1.28
const RAY_FROM := 1.1
const RAYS := 12
## Radians the figure is turned by: it's falling.
const TILT := -0.22

var color := Palette.HEAT
var cut_color := Palette.PANEL


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var radius := minf(size.x, size.y) / 2.0 / RAY_LONG
	var to_screen := Transform2D(0.0, Vector2(radius, radius), 0.0, size / 2.0)
	for i: int in RAYS:
		var angle := TAU * i / RAYS
		var reach := RAY_LONG if i % 2 == 0 else RAY_SHORT
		var half := 0.1 if i % 2 == 0 else 0.075
		var ray := PackedVector2Array([Vector2.from_angle(angle - half) * RAY_FROM, Vector2.from_angle(angle) * reach, Vector2.from_angle(angle + half) * RAY_FROM])
		draw_colored_polygon(to_screen * ray, color)
	var sun := _circle(Vector2.ZERO, 1.0, 72)
	draw_colored_polygon(to_screen * sun, color)
	for part: PackedVector2Array in figure():
		for piece: PackedVector2Array in Geometry2D.intersect_polygons(part, sun):
			draw_colored_polygon(to_screen * piece, cut_color)
		# A part minus the sun has no holes: the sun never fits inside a part.
		for piece: PackedVector2Array in Geometry2D.clip_polygons(part, sun):
			draw_colored_polygon(to_screen * piece, color)


## The figure and its loose feathers, as polygons in the sun's units. It stays inside the sun, so it's all
## cut out of it.
static func figure() -> Array[PackedVector2Array]:
	var parts: Array[PackedVector2Array] = []
	parts.append(_circle(Vector2(0.0, -0.115), 0.11, 24))
	parts.append(PackedVector2Array([Vector2(-0.13, 0.0), Vector2(0.13, 0.0), Vector2(0.09, 0.36), Vector2(-0.09, 0.36)]))
	parts.append(PackedVector2Array([Vector2(-0.09, 0.32), Vector2(-0.01, 0.32), Vector2(-0.06, 0.72), Vector2(-0.14, 0.7)]))
	parts.append(PackedVector2Array([Vector2(0.01, 0.32), Vector2(0.09, 0.32), Vector2(0.17, 0.68), Vector2(0.09, 0.71)]))
	# A wing raised from each shoulder: the arm along its top, feather tips down its outer edge.
	var wing := PackedVector2Array([Vector2(0.11, -0.02), Vector2(0.36, -0.4), Vector2(0.56, -0.7), Vector2(0.8, -0.56),
		Vector2(0.66, -0.48), Vector2(0.84, -0.34), Vector2(0.64, -0.28), Vector2(0.8, -0.12), Vector2(0.56, -0.1),
		Vector2(0.66, 0.06), Vector2(0.42, 0.04), Vector2(0.44, 0.18), Vector2(0.16, 0.12)])
	parts.append(wing)
	parts.append(Transform2D.FLIP_X * wing)
	var turn := Transform2D(TILT, Vector2(0.95, 0.95), 0.0, Vector2(-0.03, 0.0))
	for i: int in parts.size():
		parts[i] = turn * parts[i]
	# Feathers it has lost, drifting down.
	parts.append(_feather(Vector2(0.5, 0.42), Vector2(0.35, 0.94), 0.17, 0.075))
	parts.append(_feather(Vector2(0.64, 0.2), Vector2(0.6, 0.8), 0.14, 0.065))
	parts.append(_feather(Vector2(0.4, 0.66), Vector2(0.1, 1.0), 0.13, 0.06))
	return parts


## A feather: a leaf shape from `base`, `length` long in `direction`, `width` wide.
static func _feather(base: Vector2, direction: Vector2, length: float, width: float) -> PackedVector2Array:
	var d := direction.normalized()
	var p := Vector2(-d.y, d.x)
	return PackedVector2Array([base + p * width * 0.5, base + d * length * 0.65 + p * width * 0.45, base + d * length,
		base + d * length * 0.65 - p * width * 0.45, base - p * width * 0.5])


static func _circle(center: Vector2, radius: float, points: int) -> PackedVector2Array:
	var circle := PackedVector2Array()
	for i: int in points:
		circle.append(center + Vector2.from_angle(TAU * i / points) * radius)
	return circle
