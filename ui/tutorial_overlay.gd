class_name TutorialOverlay
extends Control
## One tutorial step: dims the screen around the part it explains, frames that part in amber, and shows a
## card with the explanation beside it. The main screen pauses the game while it's open.
## The buttons wait a moment before they work, so a player clicking or pressing Space quickly doesn't
## dismiss the card unread.

signal dismissed
signal skipped

const MARGIN := 16.0
const CARD_WIDTH := 440.0

## Seconds before the buttons work. Screenshot captures set it to 0.
var read_seconds := 0.8

var _target := Rect2()
var _card: PanelContainer
var _title: Label
var _body: Label
var _got_it: Button
var _skip: Button


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	_card = PanelContainer.new()
	_card.theme_type_variation = &"TutorialPanel"
	_card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	add_child(_card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_card.add_child(box)

	var heading := Label.new()
	heading.text = "TUTORIAL  ·  GAME PAUSED"
	heading.add_theme_font_override("font", Fonts.heading())
	heading.add_theme_font_size_override("font_size", 12)
	heading.add_theme_color_override("font_color", Palette.AMBER)
	box.add_child(heading)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 24)
	box.add_child(_title)
	_body = Label.new()
	_body.add_theme_font_size_override("font_size", 16)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# A wrapped label needs its width up front, or it asks for the height of one word per line.
	_body.custom_minimum_size = Vector2(CARD_WIDTH - 40.0, 0)
	box.add_child(_body)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	box.add_child(buttons)
	_got_it = Button.new()
	_got_it.text = "Got it"
	_got_it.theme_type_variation = &"PrimaryButton"
	_got_it.custom_minimum_size = Vector2(130, 40)
	_got_it.pressed.connect(func() -> void: dismissed.emit())
	buttons.add_child(_got_it)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(spacer)
	_skip = Button.new()
	_skip.text = "Skip tutorial"
	_skip.add_theme_font_size_override("font_size", 14)
	_skip.pressed.connect(func() -> void: skipped.emit())
	buttons.add_child(_skip)


## Shows a step. `target` is the part it explains, in this control's coordinates.
func open(title: String, body: String, target: Rect2) -> void:
	_target = target
	_title.text = title
	_body.text = body
	_got_it.disabled = true
	_skip.disabled = true
	visible = true
	queue_redraw()
	_card.reset_size()
	_place_card.call_deferred()
	get_tree().create_timer(maxf(0.01, read_seconds)).timeout.connect(_enable_buttons)


func _enable_buttons() -> void:
	if not visible:
		return
	_got_it.disabled = false
	_skip.disabled = false
	_got_it.grab_focus()


## Below the target if the card fits there, else above it, else beside it.
func _place_card() -> void:
	_card.reset_size()
	var card := _card.size
	var spot := _target.grow(MARGIN)
	var position_now := Vector2(_target.position.x, spot.end.y)
	if spot.end.y + card.y > size.y - MARGIN:
		position_now.y = spot.position.y - card.y
		if position_now.y < MARGIN:
			position_now.y = _target.get_center().y - card.y / 2.0
			position_now.x = spot.end.x if spot.end.x + card.x <= size.x - MARGIN else spot.position.x - card.x
	position_now.x = clampf(position_now.x, MARGIN, size.x - card.x - MARGIN)
	position_now.y = clampf(position_now.y, MARGIN, size.y - card.y - MARGIN)
	_card.position = position_now


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and visible:
		queue_redraw()
		_place_card.call_deferred()


## The shade around the target, and an amber frame on it. Only rects, and only redrawn when a step opens.
func _draw() -> void:
	var shade := Color(Palette.VOID, 0.8)
	var hole := _target.grow(6.0)
	draw_rect(Rect2(0.0, 0.0, size.x, hole.position.y), shade)
	draw_rect(Rect2(0.0, hole.end.y, size.x, size.y - hole.end.y), shade)
	draw_rect(Rect2(0.0, hole.position.y, hole.position.x, hole.size.y), shade)
	draw_rect(Rect2(hole.end.x, hole.position.y, size.x - hole.end.x, hole.size.y), shade)
	TutorialHint.draw_frame(self, hole, Palette.AMBER)
