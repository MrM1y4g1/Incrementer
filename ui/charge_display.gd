class_name ChargeDisplay
extends Control
## The click charge, as a card over the machine. The charge is how fast the player has clicked lately, as a
## share of Formulas.ICARUS_RATE; above Formulas.CHARGE_FROM every click is worth more. The card shows that
## bonus, a message egging the player on, and a battery. Only a macro can fill it: then the card becomes the
## Icarus stage, the emblem of Icarus falling across the sun, while clicks do nothing.
## The charge also heats the screen: the background, a glow behind the panels and the panels' frames turn
## red, while what's inside the panels stays clear.
## It never takes the mouse and sits over the schematic, so the Increment button stays free. Apart from the
## emblem, which draws once, it draws only rects and text.

const CARD_WIDTH := 480.0
const CELLS := 24
const CELL_GAP := 3.0
const METER_HEIGHT := 18.0
const BRACKET := 14.0
const LOGO_SIZE := 136.0
## The card appears at Formulas.CHARGE_FROM, where the bonus starts, and stays until the charge is below
## HIDE_BELOW, so clicking at about that pace doesn't make it blink.
const HIDE_BELOW := 0.2
## A message stays up at least this long, so an uneven click rhythm doesn't make it flicker.
const HOLD_SECONDS := 0.9
const BETTER := "YOU CAN DO BETTER"
const COME_ON := "COME ON, YOU CAN DO IT"
const ALMOST := "YOU'RE ALMOST THERE"
const ICARUS := "ICARUS"

var reduced_motion := false
## What the charge heats: the screen's background, the glow behind the panels, and the panels' frames.
var background: ColorRect
var glow: TextureRect
var frames: Array[FramePanel] = []

var _charge := 0.0
var _burnout := 0.0
var _shown := ""
var _shown_at := 0.0
var _card: MarginContainer
var _charge_box: VBoxContainer
var _bonus: Label
var _message: Label
var _meter: Control
var _icarus_box: HBoxContainer
var _logo: IcarusLogo
var _melted: Label
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
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(stack)

	# Charging: the bonus, the message and the battery.
	_charge_box = VBoxContainer.new()
	_charge_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_charge_box.add_theme_constant_override("separation", 8)
	stack.add_child(_charge_box)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_charge_box.add_child(top)
	var heading := _label(Fonts.heading(), 12, Palette.MUTED)
	heading.text = "CLICK CHARGE"
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(heading)
	_bonus = _label(Fonts.mono(), 14, Palette.AMBER)
	top.add_child(_bonus)
	_message = _label(Fonts.readout(), 34, Palette.AMBER)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_charge_box.add_child(_message)
	_meter = Control.new()
	_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meter.custom_minimum_size = Vector2(0, METER_HEIGHT)
	_meter.draw.connect(_draw_meter)
	_charge_box.add_child(_meter)

	# Caught macro clicking: the emblem, and what it means.
	_icarus_box = HBoxContainer.new()
	_icarus_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icarus_box.add_theme_constant_override("separation", 22)
	_icarus_box.visible = false
	stack.add_child(_icarus_box)
	_logo = IcarusLogo.new()
	_logo.custom_minimum_size = Vector2(LOGO_SIZE, LOGO_SIZE)
	_icarus_box.add_child(_logo)
	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 6)
	_icarus_box.add_child(words)
	var title := _label(Fonts.readout(), 46, Palette.HEAT)
	title.text = ICARUS
	words.add_child(title)
	var story := _label(Fonts.body(), 15, Palette.ICE)
	story.text = "You flew too close to the sun.\nThat's macro clicking, and your wings melted."
	words.add_child(story)
	_melted = _label(Fonts.mono(), 14, Palette.HEAT)
	words.add_child(_melted)


## Follows the state's charge. The screen calls this at its 10 Hz refresh and after every click.
func show_charge(state: GameState) -> void:
	_charge = state.charge
	_burnout = state.burnout
	var text := _message_for(state)
	var now := Time.get_ticks_msec() / 1000.0
	# Icarus, appearing and going quiet happen at once; the egging-on messages wait their turn.
	var urgent := text in [ICARUS, ""] or _shown in [ICARUS, ""]
	if text != _shown and (urgent or now - _shown_at >= HOLD_SECONDS):
		_show_message(text)
		_shown_at = now
	if _burnout > 0.0:
		_melted.text = "CLICKS DO NOTHING FOR %ds" % ceili(_burnout)
	elif _shown != "":
		_bonus.text = "+%d%% PER CLICK" % roundi(Economy.charge_bonus(state) * 100.0)
	var accent := _accent()
	_bonus.add_theme_color_override("font_color", accent)
	_message.add_theme_color_override("font_color", accent)
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


## "" when there's nothing to say.
func _message_for(state: GameState) -> String:
	if state.burnout > 0.0:
		return ICARUS
	if state.charge < (HIDE_BELOW if _shown != "" else Formulas.CHARGE_FROM):
		return ""
	# Slowing down (clicking slower than the charge's pace), or only just started.
	if state.click_rate < state.charge * Formulas.ICARUS_RATE * 0.9 or state.charge < 0.4:
		return BETTER
	return COME_ON if state.charge < 0.65 else ALMOST


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
	# Going quiet keeps the last card while it fades.
	if text == "":
		return
	_icarus_box.visible = text == ICARUS
	_charge_box.visible = text != ICARUS
	var popped: Control = _logo if text == ICARUS else _message
	_message.text = text
	if not reduced_motion:
		popped.pivot_offset = popped.size / 2.0 if popped.size != Vector2.ZERO else popped.custom_minimum_size / 2.0
		popped.scale = Vector2(1.3, 1.3) if text == ICARUS else Vector2(1.08, 1.08)
		popped.create_tween().tween_property(popped, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Amber when the bonus starts, red as the charge nears the sun; red when the wings have melted.
func _accent() -> Color:
	if _burnout > 0.0:
		return Palette.HEAT
	return Palette.AMBER.lerp(Palette.HEAT, clampf((_charge - Formulas.CHARGE_FROM) / (1.0 - Formulas.CHARGE_FROM) * 1.3, 0.0, 1.0))


## Reddens the background, the glow behind the panels and the panels' frames as the charge rises past
## Formulas.CHARGE_FROM, where the bonus starts, so clicking at an easy pace leaves the screen alone.
func _heat() -> void:
	var level := clampf((_charge - Formulas.CHARGE_FROM) / (1.0 - Formulas.CHARGE_FROM), 0.0, 1.0)
	if background != null:
		background.color = Palette.VOID.lerp(Palette.HEAT, level * 0.3)
	if glow != null:
		glow.modulate.a = pow(level, 1.2) * 0.95
		glow.visible = glow.modulate.a > 0.0
	# In steps, so the frames don't redraw for changes nobody can see.
	var heat := snappedf(level, 0.02)
	for frame: FramePanel in frames:
		frame.heat = heat


## The card: a dark panel with a thin border and corner brackets in the charge's colour.
func _draw_card() -> void:
	var rect := Rect2(Vector2.ZERO, _card.size)
	var accent := _accent()
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


## A battery across the card: cells filling from amber to red, and a terminal at the end. The cells below
## Formulas.CHARGE_FROM, which earn no bonus yet, are dimmer.
func _draw_meter() -> void:
	var nub := 5.0
	var width := _meter.size.x - nub - 2.0
	var cell := Vector2((width - CELL_GAP * (CELLS - 1)) / CELLS, METER_HEIGHT)
	var lit := ceili(_charge * CELLS - 0.001)
	for i: int in CELLS:
		var rect := Rect2(Vector2(i * (cell.x + CELL_GAP), 0.0), cell)
		if i < lit:
			var color := Palette.AMBER.lerp(Palette.HEAT, float(i) / (CELLS - 1))
			_meter.draw_rect(rect, Color(color, 0.45) if (i + 1.0) / CELLS <= Formulas.CHARGE_FROM else color)
		else:
			_meter.draw_rect(rect, Color(Palette.LINE, 0.55))
	_meter.draw_rect(Rect2(_meter.size.x - nub, METER_HEIGHT * 0.25, nub, METER_HEIGHT * 0.5), Color(Palette.LINE, 0.9))


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
