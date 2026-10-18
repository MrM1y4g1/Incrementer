class_name FramePanel
extends PanelContainer
## A panel with thin corner brackets: the frame style from the art direction.

const BRACKET := 12.0

var bracket_color := Color(Palette.CYAN, 0.55)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	for corner: Vector2 in [Vector2(0, 0), Vector2(w, 0), Vector2(0, h), Vector2(w, h)]:
		var dx := BRACKET if corner.x == 0.0 else -BRACKET
		var dy := BRACKET if corner.y == 0.0 else -BRACKET
		draw_line(corner, corner + Vector2(dx, 0), bracket_color, 1.5)
		draw_line(corner, corner + Vector2(0, dy), bracket_color, 1.5)
