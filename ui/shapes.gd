class_name Shapes
extends RefCounted
## Geometry shared by the schematic and the tier icons.


## A regular polygon pointing up. Tier n of the Software layers has n + 2 sides.
static func polygon(center: Vector2, radius: float, sides: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for k: int in sides:
		var angle := -PI / 2.0 + TAU * k / sides
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points


## The same polygon with its first point repeated, ready for draw_polyline.
static func outline(center: Vector2, radius: float, sides: int) -> PackedVector2Array:
	var points := polygon(center, radius, sides)
	points.append(points[0])
	return points
