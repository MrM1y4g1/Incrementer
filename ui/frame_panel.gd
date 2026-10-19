class_name FramePanel
extends PanelContainer
## A panel with thin corner brackets: the frame style from the art direction. The click charge heats it: its
## border and brackets turn red. Drawn with rects only, because during ULTRA it redraws every frame, and in
## the browser every line drawn makes a new WebGL buffer (see SchematicView).

const BRACKET := 12.0
const THICKNESS := 1.5

var bracket_color := Color(Palette.CYAN, 0.55)
## How hot the click charge has made it, 0 to 1.
var heat := 0.0:
	set(value):
		if value != heat:
			heat = value
			queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if heat > 0.0:
		var edge := Color(Palette.HEAT, 0.6 * heat)
		draw_rect(Rect2(0, 0, w, 1), edge)
		draw_rect(Rect2(0, h - 1, w, 1), edge)
		draw_rect(Rect2(0, 1, 1, h - 2), edge)
		draw_rect(Rect2(w - 1, 1, 1, h - 2), edge)
	var color := bracket_color.lerp(Color(Palette.HEAT, 0.95), heat)
	for corner: Vector2 in [Vector2(0, 0), Vector2(w, 0), Vector2(0, h), Vector2(w, h)]:
		var x := 0.0 if corner.x == 0.0 else w - BRACKET
		var y := 0.0 if corner.y == 0.0 else h - THICKNESS
		draw_rect(Rect2(x, y, BRACKET, THICKNESS), color)
		x = 0.0 if corner.x == 0.0 else w - THICKNESS
		y = 0.0 if corner.y == 0.0 else h - BRACKET
		draw_rect(Rect2(x, y, THICKNESS, BRACKET), color)
