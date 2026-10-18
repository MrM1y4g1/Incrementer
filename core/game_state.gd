class_name GameState
extends RefCounted
## Everything a save file stores: plain data plus conversion to and from a Dictionary.

const LAYER_COUNT := 8

var count := 0.0
var peak_count := 0.0
var register_bits := 8
var total_clicks := 0
var play_time := 0.0
## Units owned per layer, including units produced by the layer above. Fractional while producing.
var layer_amount := PackedFloat64Array()
## Units bought per layer. Costs and the ×2 bonus use this.
var layer_bought := PackedInt64Array()


func _init() -> void:
	layer_amount.resize(LAYER_COUNT)
	layer_amount.fill(0.0)
	layer_bought.resize(LAYER_COUNT)
	layer_bought.fill(0)


func to_dict() -> Dictionary:
	return {
		"count": count,
		"peak_count": peak_count,
		"register_bits": register_bits,
		"total_clicks": total_clicks,
		"play_time": play_time,
		"layer_amount": Array(layer_amount),
		"layer_bought": Array(layer_bought),
	}


## Builds a state from saved data. Missing or invalid fields fall back to new-game values.
static func from_dict(data: Dictionary) -> GameState:
	var s := GameState.new()
	var bits := int(data.get("register_bits", 8))
	s.register_bits = bits if Formulas.REGISTER_WIDTHS.has(bits) else 8
	s.count = clampf(float(data.get("count", 0.0)), 0.0, Formulas.register_cap(s.register_bits))
	s.peak_count = maxf(s.count, float(data.get("peak_count", 0.0)))
	s.total_clicks = maxi(0, int(data.get("total_clicks", 0)))
	s.play_time = maxf(0.0, float(data.get("play_time", 0.0)))

	var amounts: Variant = data.get("layer_amount", [])
	if amounts is Array:
		var list: Array = amounts
		for i: int in mini(list.size(), LAYER_COUNT):
			s.layer_amount[i] = maxf(0.0, float(list[i]))

	var bought: Variant = data.get("layer_bought", [])
	if bought is Array:
		var list: Array = bought
		for i: int in mini(list.size(), LAYER_COUNT):
			s.layer_bought[i] = maxi(0, int(list[i]))
	return s
