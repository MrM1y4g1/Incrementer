class_name FxLayer
extends Control
## Short effects drawn over the whole screen: floating numbers, flashes and the Overflow shockwave.
## With reduced motion on, numbers fade in place, flashes are softer and there's no shockwave.
## Positions come in as global ones, from get_global_rect(), and are converted to this layer's coordinates,
## so the effects land in the right place wherever the screen sits in the window.

const RING_SECONDS := 1.1

var reduced_motion := false

var _flash: ColorRect
var _rings: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash = ColorRect.new()
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Top level, so a flash covers the whole window and not just the screen's 1280 × 720.
	_flash.top_level = true
	_flash.color = Color(1, 1, 1, 0)
	add_child(_flash)
	set_process(false)


## A number that rises from `at` and fades, like the +1 from a click.
func float_text(at: Vector2, text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", Fonts.readout())
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	label.position = _local(at) - Vector2(label.get_minimum_size().x / 2.0, 0.0)
	var tween := label.create_tween().set_parallel(true)
	if not reduced_motion:
		tween.tween_property(label, "position:y", label.position.y - 46.0, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(label, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)


## Washes the screen with a colour that fades out.
func flash(color: Color, seconds: float = 0.5) -> void:
	var strength := color.a * (0.4 if reduced_motion else 1.0)
	_flash.position = Vector2.ZERO
	_flash.size = get_viewport_rect().size
	_flash.color = Color(color, strength)
	var tween := _flash.create_tween()
	tween.tween_property(_flash, "color:a", 0.0, seconds).set_ease(Tween.EASE_OUT)


## A ring that expands from `center` across the screen.
func shockwave(center: Vector2, color: Color) -> void:
	if reduced_motion:
		return
	_rings.append({"center": _local(center), "age": 0.0, "color": color})
	set_process(true)


func _local(point: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * point


func _process(delta: float) -> void:
	for ring: Dictionary in _rings:
		ring["age"] = float(ring["age"]) + delta
	_rings = _rings.filter(func(ring: Dictionary) -> bool: return float(ring["age"]) < RING_SECONDS)
	if _rings.is_empty():
		set_process(false)
	queue_redraw()


func _draw() -> void:
	var reach := size.length()
	for ring: Dictionary in _rings:
		var progress := float(ring["age"]) / RING_SECONDS
		var radius := ease(progress, 0.4) * reach
		var color: Color = ring["color"]
		draw_arc(ring["center"], radius, 0.0, TAU, 128, Color(color, 1.0 - progress), 3.0, true)
		draw_arc(ring["center"], radius * 0.82, 0.0, TAU, 128, Color(color, (1.0 - progress) * 0.4), 1.5, true)
