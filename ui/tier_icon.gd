class_name TierIcon
extends Control
## A small tier polygon for the parts list: tier n has n + 2 sides.

var sides := 3
var color := Palette.CYAN
var filled := true


func _init(tier: int) -> void:
	sides = tier + 2
	custom_minimum_size = Vector2(26, 26)


func set_style(new_color: Color, new_filled: bool) -> void:
	if new_color == color and new_filled == filled:
		return
	color = new_color
	filled = new_filled
	queue_redraw()


func _draw() -> void:
	var center := size / 2.0
	var radius := minf(size.x, size.y) * 0.4
	if filled:
		draw_colored_polygon(Shapes.polygon(center, radius, sides), Color(color, 0.15))
	draw_polyline(Shapes.outline(center, radius, sides), color, 1.5, true)
