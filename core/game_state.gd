class_name GameState
extends RefCounted
## Everything a save file stores, plus a few derived values that Economy rebuilds on demand.

const LAYER_COUNT := 8

var count := 0.0
var peak_count := 0.0
## Count actually added over the whole save, by clicks and production.
var total_produced := 0.0
var register_bits := 8
var clock_level := 0
var total_clicks := 0
var play_time := 0.0
## Units owned per layer, including units produced by the layer above. Fractional while producing.
var layer_amount := PackedFloat64Array()
## Units bought per layer. Costs and the ×2 bonus use this.
var layer_bought := PackedInt64Array()
## Ids of bought upgrades and unlocked achievements.
var upgrades: Array[StringName] = []
var achievements: Array[StringName] = []

# Derived from upgrades, achievements and the clock by Economy.refresh_effects(). Not saved.
var effects_dirty := true
var layer_multiplier := PackedFloat64Array()
var click_multiplier := 1.0
var click_rate_share := 0.0


func _init() -> void:
	layer_amount.resize(LAYER_COUNT)
	layer_amount.fill(0.0)
	layer_bought.resize(LAYER_COUNT)
	layer_bought.fill(0)
	layer_multiplier.resize(LAYER_COUNT)
	layer_multiplier.fill(1.0)


func to_dict() -> Dictionary:
	return {
		"count": count,
		"peak_count": peak_count,
		"total_produced": total_produced,
		"register_bits": register_bits,
		"clock_level": clock_level,
		"total_clicks": total_clicks,
		"play_time": play_time,
		"layer_amount": Array(layer_amount),
		"layer_bought": Array(layer_bought),
		"upgrades": _names(upgrades),
		"achievements": _names(achievements),
	}


## Builds a state from saved data. Missing or invalid fields fall back to new-game values.
static func from_dict(data: Dictionary) -> GameState:
	var s := GameState.new()
	var bits := int(data.get("register_bits", 8))
	s.register_bits = bits if Formulas.REGISTER_WIDTHS.has(bits) else 8
	s.count = clampf(float(data.get("count", 0.0)), 0.0, Formulas.register_cap(s.register_bits))
	s.peak_count = maxf(s.count, float(data.get("peak_count", 0.0)))
	s.total_produced = maxf(0.0, float(data.get("total_produced", 0.0)))
	s.clock_level = maxi(0, int(data.get("clock_level", 0)))
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

	s.upgrades = _ids(data.get("upgrades", []))
	s.achievements = _ids(data.get("achievements", []))
	return s


static func _names(ids: Array[StringName]) -> Array:
	var names: Array = []
	for id: StringName in ids:
		names.append(String(id))
	return names


static func _ids(value: Variant) -> Array[StringName]:
	var ids: Array[StringName] = []
	if not value is Array:
		return ids
	var list: Array = value
	for item: Variant in list:
		var id := StringName(str(item))
		if id != &"" and not ids.has(id):
			ids.append(id)
	return ids
