class_name ChargeDisplay
extends Control
## The click charge, as a card over the machine: what the charge adds to each click, a message egging the
## player on, and a battery that fills while they click faster than Formulas.CHARGE_DRAIN times a second.
## A full battery is ULTRA. Caught macro clicking, the card says so for as long as the charge can't build.
## The charge also heats the screen: the background, a glow behind the panels and the panels' frames turn
## red, while what's inside the panels stays clear.
## It never takes the mouse and sits over the schematic, so the Increment button stays free. It draws only
## rects and text, because it redraws every frame while ULTRA pulses (see RegisterDisplay).

const CARD_WIDTH := 480.0
const CELLS := 24
const CELL_GAP := 3.0
const METER_HEIGHT := 18.0
const BRACKET := 14.0
## Nothing shows below this charge, so a single click doesn't flash the card. Once showing, it stays until
## the charge is below HIDE_BELOW, so clicking at about the drain rate doesn't make it blink.
const SHOW_FROM := 0.04
const HIDE_BELOW := 0.01
## A message stays up at least this long, so an uneven click rhythm doesn't make it flicker.
const HOLD_SECONDS := 0.9
const BETTER := "YOU CAN DO BETTER"
const COME_ON := "COME ON, YOU CAN DO IT"
const ALMOST := "YOU'RE ALMOST THERE"
const ULTRA := "ULTRA"
const ICARUS := "ICARUS"

var reduced_motion := false
## What the charge heats: the screen's background, the glow behind the panels, and the panels' frames.
var background: ColorRect
var glow: TextureRect
var frames: Array[FramePanel] = []

var _charge := 0.0
var _ultra := false
var _burnout := 0.0
var _shown := ""
var _shown_at := 0.0
var _card: MarginContainer
var _heading: Label
var _bonus: Label
var _message: Label
var _meter: Control
var _detail: Label
var _fade: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_card = MarginContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	for side: String in ["margin_left", "margin_right"]:
		_card.add_theme_constant_override(side, 22)
	for side: String in ["margin_top", "margin_bottom"]:
		_card.add_theme_constant_override(side, 16)
	_card.draw.connect(_draw_card)
	center.add_child(_card)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 8)
	_card.add_child(box)

	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(top)
	_heading = _label(Fonts.heading(), 12, Palette.MUTED)
	_heading.text = "CLICK CHARGE"
	_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_heading)
	_bonus = _label(Fonts.mono(), 14, Palette.AMBER)
	top.add_child(_bonus)

	_message = _label(Fonts.readout(), 34, Palette.AMBER)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_message)

	_meter = Control.new()
	_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meter.custom_minimum_size = Vector2(0, METER_HEIGHT)
	_meter.draw.connect(_draw_meter)
	box.add_child(_meter)

	_detail = _label(Fonts.body(), 14, Palette.ICE)
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.text = "Too close to the sun: that's macro clicking."
	_detail.visible = false
	box.add_child(_detail)


## Follows the state's charge. The screen calls this at its 10 Hz refresh and after every click.
func show_charge(state: GameState) -> void:
	_charge = state.charge
	_ultra = state.ultra
	_burnout = state.burnout
	var text := _message_for(state)
	var now := Time.get_ticks_msec() / 1000.0
	# ULTRA, Icarus, appearing and going quiet happen at once; the egging-on messages wait their turn.
	var urgent := text in [ULTRA, ICARUS, ""] or _shown in [ULTRA, ICARUS, ""]
	if text != _shown and (urgent or now - _shown_at >= HOLD_SECONDS):
		_show_message(text)
		_shown_at = now
	if _burnout > 0.0:
		_bonus.text = "MELTED  %ds" % ceili(_burnout)
	elif _shown != "":
		_bonus.text = "+%d%% PER CLICK" % roundi(Economy.charge_bonus(state) * 100.0)
	_detail.visible = _burnout > 0.0
	var accent := _accent()
	_bonus.add_theme_color_override("font_color", accent)
	_message.add_theme_color_override("font_color", Palette.ICE if _ultra else accent)
	_heat()
	_card.queue_redraw()
	_meter.queue_redraw()


## A red glow around the edges of the screen, clear in the middle. Stretched over the window, it's an ellipse.
static func make_glow() -> Texture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.35, 0.75, 1.0])
	gradient.colors = PackedColorArray([Color(Palette.HEAT, 0.0), Color(Palette.HEAT, 0.0), Color(Palette.HEAT, 0.45), Color(Palette.HEAT, 1.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 256
	texture.height = 256
	return texture


func _process(_delta: float) -> void:
	# Only ULTRA moves between refreshes.
	if _ultra and not reduced_motion:
		_heat()
		_card.queue_redraw()
		_meter.queue_redraw()


## "" when there's nothing to say.
func _message_for(state: GameState) -> String:
	if state.burnout > 0.0:
		return ICARUS
	if state.ultra:
		return ULTRA
	if state.charge < (HIDE_BELOW if _shown != "" else SHOW_FROM):
		return ""
	# Slowing down, or barely started.
	if state.click_rate < Formulas.CHARGE_DRAIN or state.charge < 0.3:
		return BETTER
	return COME_ON if state.charge < 0.7 else ALMOST


func _show_message(text: String) -> void:
	_shown = text
	if _fade != null:
		_fade.kill()
	var target := 0.0 if text == "" else 1.0
	if reduced_motion:
		modulate.a = target
	else:
		_fade = create_tween()
		_fade.tween_property(self, "modulate:a", target, 0.15 if target > 0.0 else 0.4)
	# Going quiet keeps the last message while it fades.
	if text == "":
		return
	_message.text = text
	_message.add_theme_font_size_override("font_size", 46 if text in [ULTRA, ICARUS] else 34)
	if not reduced_motion:
		_message.pivot_offset = _message.size / 2.0
		_message.scale = Vector2(1.25, 1.25) if text in [ULTRA, ICARUS] else Vector2(1.08, 1.08)
		_message.create_tween().tween_property(_message, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Amber when the charge starts, red as it fills; red when melted.
func _accent() -> Color:
	if _burnout > 0.0:
		return Palette.HEAT
	return Palette.AMBER.lerp(Palette.HEAT, clampf(_charge * 1.25, 0.0, 1.0))


## Reddens the background, the glow behind the panels and the panels' frames with the charge. ULTRA throbs.
func _heat() -> void:
	var pulse := _pulse(1.6)
	if background != null:
		background.color = Palette.VOID.lerp(Palette.HEAT, _charge * (0.22 + 0.08 * pulse))
	if glow != null:
		glow.modulate.a = pow(_charge, 1.3) * (0.7 + 0.3 * pulse)
		glow.visible = glow.modulate.a > 0.0
	# In steps, so the frames don't redraw for changes nobody can see.
	var heat := snappedf(_charge * (0.75 + 0.25 * pulse), 0.02)
	for frame: FramePanel in frames:
		frame.heat = heat


## 0 to 1 and back `per_second` times a second during ULTRA; 0 otherwise, and with reduced motion.
func _pulse(per_second: float) -> float:
	if not _ultra or reduced_motion:
		return 0.0
	return 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU * per_second)


## The card: a dark panel with a thin border and corner brackets in the charge's colour. ULTRA adds a halo.
func _draw_card() -> void:
	var rect := Rect2(Vector2.ZERO, _card.size)
	var accent := _accent()
	if _ultra:
		_card.draw_rect(rect.grow(8.0), Color(Palette.HEAT, 0.08 + 0.1 * _pulse(1.6)))
		_card.draw_rect(rect.grow(3.0), Color(Palette.HEAT, 0.14 + 0.14 * _pulse(1.6)))
	_card.draw_rect(rect, Color(Palette.PANEL, 0.97))
	_outline(_card, rect, Color(accent, 0.45), 1.0)
	var thickness := 2.0
	for corner: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), rect.end]:
		var x := corner.x if corner.x == rect.position.x else corner.x - BRACKET
		var y := corner.y if corner.y == rect.position.y else corner.y - thickness
		_card.draw_rect(Rect2(x, y, BRACKET, thickness), accent)
		x = corner.x if corner.x == rect.position.x else corner.x - thickness
		y = corner.y if corner.y == rect.position.y else corner.y - BRACKET
		_card.draw_rect(Rect2(x, y, thickness, BRACKET), accent)


## A battery across the card: cells filling from amber to red, and a terminal at the end. Melted, the cells
## glow a dull red.
func _draw_meter() -> void:
	var nub := 5.0
	var width := _meter.size.x - nub - 2.0
	var cell := Vector2((width - CELL_GAP * (CELLS - 1)) / CELLS, METER_HEIGHT)
	var lit := ceili(_charge * CELLS - 0.001) if _burnout <= 0.0 else 0
	var pulse := _pulse(3.2)
	for i: int in CELLS:
		var rect := Rect2(Vector2(i * (cell.x + CELL_GAP), 0.0), cell)
		if i < lit:
			var color := Palette.AMBER.lerp(Palette.HEAT, float(i) / (CELLS - 1))
			if _ultra:
				color = color.lerp(Palette.ICE, 0.35 * pulse)
			_meter.draw_rect(rect, color)
		else:
			_meter.draw_rect(rect, Color(Palette.HEAT, 0.22) if _burnout > 0.0 else Color(Palette.LINE, 0.55))
	var lit_end := lit >= CELLS
	_meter.draw_rect(Rect2(_meter.size.x - nub, METER_HEIGHT * 0.25, nub, METER_HEIGHT * 0.5), Palette.HEAT if lit_end else Color(Palette.LINE, 0.9))


## A rectangle's border as four thin filled rects.
static func _outline(canvas: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x, width)), color)
	canvas.draw_rect(Rect2(rect.position.x, rect.end.y - width, rect.size.x, width), color)
	canvas.draw_rect(Rect2(rect.position.x, rect.position.y + width, width, rect.size.y - width * 2.0), color)
	canvas.draw_rect(Rect2(rect.end.x - width, rect.position.y + width, width, rect.size.y - width * 2.0), color)


func _label(font: Font, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
