class_name ChargeDisplay
extends Control
## The click charge, over the machine: a message egging the player on, a battery that fills while they click
## faster than Formulas.CHARGE_DRAIN times a second, and what the charge adds to each click. A full battery
## is ULTRA. Caught macro clicking, it says so for as long as the charge can't build. As the charge builds,
## the screen's background and a glow around its edges turn red.
## It never takes the mouse, so the Increment button below it stays free. It draws only rects, one texture
## and text, because it redraws every frame while ULTRA pulses (see RegisterDisplay).

const CELLS := 20
const CELL_SIZE := Vector2(14, 22)
const CELL_GAP := 4.0
## Nothing shows below this charge, so a single click doesn't flash a message. Once showing, it stays until
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
## The screen's background and the glow around its edges, which the charge turns red.
var background: ColorRect
var glow: TextureRect

var _charge := 0.0
var _ultra := false
var _burnout := 0.0
var _shown := ""
var _shown_at := 0.0
var _message: Label
var _battery: Control
var _detail: Label
var _fade: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	_message = _label(Fonts.readout(), 46)
	box.add_child(_message)
	_battery = Control.new()
	_battery.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_battery.custom_minimum_size = Vector2(CELLS * (CELL_SIZE.x + CELL_GAP) + 16.0, CELL_SIZE.y + 10.0)
	_battery.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_battery.draw.connect(_draw_battery)
	box.add_child(_battery)
	_detail = _label(Fonts.mono(), 16)
	_detail.add_theme_color_override("font_color", Palette.ICE)
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
	if state.burnout > 0.0:
		_detail.text = "Too close to the sun: macro clicking detected.\nThe charge is melted for %ds." % ceili(state.burnout)
	elif _shown != "":
		_detail.text = "+%d%% PER CLICK" % roundi(Economy.charge_bonus(state) * 100.0)
	var color := Palette.AMBER.lerp(Palette.HEAT, clampf(_charge * 1.4, 0.0, 1.0))
	if _ultra:
		color = Palette.ICE
	elif _burnout > 0.0:
		color = Palette.HEAT
	_message.add_theme_color_override("font_color", color)
	_message.add_theme_color_override("font_outline_color", Color(Palette.HEAT, 0.6) if _ultra else Color(Palette.VOID, 0.85))
	_tint()
	_battery.queue_redraw()


## A red glow around the edges of the screen, clear in the middle. Stretched over the window, it's an ellipse.
static func make_glow() -> Texture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 0.8, 1.0])
	gradient.colors = PackedColorArray([Color(Palette.HEAT, 0.0), Color(Palette.HEAT, 0.0), Color(Palette.HEAT, 0.4), Color(Palette.HEAT, 1.0)])
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
		_tint()
		_battery.queue_redraw()


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
	_message.add_theme_font_size_override("font_size", 64 if text in [ULTRA, ICARUS] else 46)
	if not reduced_motion:
		_message.pivot_offset = _message.size / 2.0
		_message.scale = Vector2(1.3, 1.3) if text in [ULTRA, ICARUS] else Vector2(1.12, 1.12)
		_message.create_tween().tween_property(_message, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Reddens the background and the edge glow with the charge. ULTRA makes them throb.
func _tint() -> void:
	var pulse := _pulse(1.6)
	if background != null:
		background.color = Palette.VOID.lerp(Palette.HEAT, _charge * (0.2 + 0.08 * pulse))
	if glow != null:
		glow.modulate.a = pow(_charge, 1.5) * (0.5 + 0.3 * pulse)
		glow.visible = glow.modulate.a > 0.0


## 0 to 1 and back `per_second` times a second during ULTRA; 0 otherwise, and with reduced motion.
func _pulse(per_second: float) -> float:
	if not _ultra or reduced_motion:
		return 0.0
	return 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU * per_second)


## A battery: cells that fill from amber to red, a casing and a terminal. Melted, its cells glow dull red.
func _draw_battery() -> void:
	var lit := ceili(_charge * CELLS - 0.001) if _burnout <= 0.0 else 0
	var pulse := _pulse(3.2)
	var origin := Vector2(5.0, 5.0)
	for i: int in CELLS:
		var rect := Rect2(origin + Vector2(i * (CELL_SIZE.x + CELL_GAP), 0.0), CELL_SIZE)
		if i < lit:
			var color := Palette.AMBER.lerp(Palette.HEAT, float(i) / (CELLS - 1))
			if _ultra:
				color = color.lerp(Palette.ICE, 0.4 * pulse)
			_battery.draw_rect(rect.grow(2.0), Color(color, 0.2))
			_battery.draw_rect(rect, color)
		else:
			_battery.draw_rect(rect, Color(Palette.HEAT, 0.3) if _burnout > 0.0 else Color(Palette.LINE, 0.5))
	var casing := Rect2(Vector2.ZERO, Vector2(origin.x * 2.0 + CELLS * (CELL_SIZE.x + CELL_GAP) - CELL_GAP, CELL_SIZE.y + origin.y * 2.0))
	var line := Color(Palette.HEAT, 0.8) if _ultra or _burnout > 0.0 else Palette.LINE
	_battery.draw_rect(Rect2(casing.position, Vector2(casing.size.x, 1.0)), line)
	_battery.draw_rect(Rect2(casing.position.x, casing.end.y - 1.0, casing.size.x, 1.0), line)
	_battery.draw_rect(Rect2(casing.position, Vector2(1.0, casing.size.y)), line)
	_battery.draw_rect(Rect2(casing.end.x - 1.0, casing.position.y, 1.0, casing.size.y), line)
	_battery.draw_rect(Rect2(casing.end.x + 1.0, casing.size.y * 0.3, 5.0, casing.size.y * 0.4), line)


func _label(font: Font, font_size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 10)
	label.add_theme_color_override("font_outline_color", Color(Palette.VOID, 0.85))
	return label
