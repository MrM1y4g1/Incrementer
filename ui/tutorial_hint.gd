class_name TutorialHint
extends Control
## An amber frame that pulses around what the last tutorial step asked for, until the player has done it.
## It only redraws when it moves or resizes; the pulse is a tween on its transparency.

const PAD := 6.0
const BRACKET := 14.0

var _pulse: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## Frames `target`, a rect in the parent's coordinates, and starts the pulse.
func show_on(target: Rect2) -> void:
	place(target)
	visible = true
	if _pulse != null:
		_pulse.kill()
	modulate.a = 1.0
	if Settings.reduced_motion:
		return
	_pulse = create_tween().set_loops()
	_pulse.tween_property(self, "modulate:a", 0.35, 0.6).set_trans(Tween.TRANS_SINE)
	_pulse.tween_property(self, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)


## Follows the target if the layout moved it.
func place(target: Rect2) -> void:
	var rect := target.grow(PAD)
	if rect.position != position or rect.size != size:
		position = rect.position
		size = rect.size


func stop() -> void:
	visible = false
	if _pulse != null:
		_pulse.kill()
		_pulse = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	draw_frame(self, Rect2(Vector2.ZERO, size), Palette.AMBER)


## A thin frame with heavier corner brackets, from filled rects only.
static func draw_frame(item: CanvasItem, rect: Rect2, color: Color) -> void:
	var thin := Color(color, 0.55)
	item.draw_rect(Rect2(rect.position, Vector2(rect.size.x, 1.0)), thin)
	item.draw_rect(Rect2(rect.position.x, rect.end.y - 1.0, rect.size.x, 1.0), thin)
	item.draw_rect(Rect2(rect.position, Vector2(1.0, rect.size.y)), thin)
	item.draw_rect(Rect2(rect.end.x - 1.0, rect.position.y, 1.0, rect.size.y), thin)
	var arm := minf(BRACKET, minf(rect.size.x, rect.size.y) / 2.0)
	for corner: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), rect.end]:
		var right := corner.x == rect.position.x
		var down := corner.y == rect.position.y
		var x := corner.x if right else corner.x - arm
		var y := corner.y if down else corner.y - arm
		item.draw_rect(Rect2(x, corner.y if down else corner.y - 3.0, arm, 3.0), color)
		item.draw_rect(Rect2(corner.x if right else corner.x - 3.0, y, 3.0, arm), color)
