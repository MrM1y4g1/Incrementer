class_name GameState
extends RefCounted
## Everything a save file stores, plus a few derived values that Economy rebuilds on demand.
## "Run" fields reset on every Overflow; everything else lasts the whole save.

const LAYER_COUNT := 8
## How many finished runs the history keeps.
const RUN_HISTORY_LIMIT := 20

# --- This run (reset by an Overflow) ---
var count := 0.0
var run_peak := 0.0
var run_time := 0.0
var register_bits := 8
var clock_level := 0
## Units owned per layer, including units produced by the layer above. Fractional while producing.
var layer_amount := PackedFloat64Array()
## Units bought per layer. Costs and the ×2 bonus use this.
var layer_bought := PackedInt64Array()
## Ids of upgrades bought this run.
var upgrades: Array[StringName] = []

# --- The whole save ---
var peak_count := 0.0
## Count actually added over the whole save, by clicks and production.
var total_produced := 0.0
var total_clicks := 0
var play_time := 0.0
var carry := 0.0
var total_carry := 0.0
var overflows := 0
var firmware: Array[StringName] = []
var achievements: Array[StringName] = []
## Finished runs, newest last: {"time": seconds, "bits": peak bits, "carry": Carry earned}.
var runs: Array[Dictionary] = []
## Player switches for the autobuyers that Firmware unlocks.
var autobuy := {"low": true, "high": true, "clock": true, "widen": true}
var ended := false
var ended_time := 0.0

# --- Derived by Economy.refresh_effects(). Not saved. ---
var effects_dirty := true
var layer_multiplier := PackedFloat64Array()
var click_multiplier := 1.0
var click_rate_share := 0.0
var max_bits := 64
var milestone_step := Formulas.MILESTONE_EVERY
var boot_bits := 8
var carry_multiplier := 1.0
## Firmware effects the player owns, as FirmwareDef.Effect values.
var firmware_effects := {}


func _init() -> void:
	layer_amount.resize(LAYER_COUNT)
	layer_amount.fill(0.0)
	layer_bought.resize(LAYER_COUNT)
	layer_bought.fill(0)
	layer_multiplier.resize(LAYER_COUNT)
	layer_multiplier.fill(1.0)


func has_firmware_effect(effect: FirmwareDef.Effect) -> bool:
	return firmware_effects.has(effect)


func to_dict() -> Dictionary:
	return {
		"count": count,
		"run_peak": run_peak,
		"run_time": run_time,
		"register_bits": register_bits,
		"clock_level": clock_level,
		"layer_amount": Array(layer_amount),
		"layer_bought": Array(layer_bought),
		"upgrades": _names(upgrades),
		"peak_count": peak_count,
		"total_produced": total_produced,
		"total_clicks": total_clicks,
		"play_time": play_time,
		"carry": carry,
		"total_carry": total_carry,
		"overflows": overflows,
		"firmware": _names(firmware),
		"achievements": _names(achievements),
		"runs": runs.duplicate(true),
		"autobuy": autobuy.duplicate(),
		"ended": ended,
		"ended_time": ended_time,
	}


## Builds a state from saved data. Missing or invalid fields fall back to new-game values.
static func from_dict(data: Dictionary) -> GameState:
	var s := GameState.new()
	var bits := int(data.get("register_bits", 8))
	s.register_bits = bits if Formulas.REGISTER_WIDTHS.has(bits) else 8
	s.count = clampf(float(data.get("count", 0.0)), 0.0, Formulas.register_cap(s.register_bits))
	s.run_peak = maxf(s.count, float(data.get("run_peak", 0.0)))
	s.run_time = maxf(0.0, float(data.get("run_time", 0.0)))
	s.clock_level = maxi(0, int(data.get("clock_level", 0)))
	s.peak_count = maxf(s.run_peak, float(data.get("peak_count", 0.0)))
	s.total_produced = maxf(0.0, float(data.get("total_produced", 0.0)))
	s.total_clicks = maxi(0, int(data.get("total_clicks", 0)))
	s.play_time = maxf(0.0, float(data.get("play_time", 0.0)))
	s.carry = maxf(0.0, float(data.get("carry", 0.0)))
	s.total_carry = maxf(s.carry, float(data.get("total_carry", 0.0)))
	s.overflows = maxi(0, int(data.get("overflows", 0)))
	s.ended = bool(data.get("ended", false))
	s.ended_time = maxf(0.0, float(data.get("ended_time", 0.0)))

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
	s.firmware = _ids(data.get("firmware", []))
	s.achievements = _ids(data.get("achievements", []))

	var saved_runs: Variant = data.get("runs", [])
	if saved_runs is Array:
		var list: Array = saved_runs
		for item: Variant in list:
			if item is Dictionary:
				var run: Dictionary = item
				s.runs.append({"time": float(run.get("time", 0.0)), "bits": float(run.get("bits", 0.0)), "carry": float(run.get("carry", 0.0))})
		while s.runs.size() > RUN_HISTORY_LIMIT:
			s.runs.pop_front()

	var switches: Variant = data.get("autobuy", {})
	if switches is Dictionary:
		var saved: Dictionary = switches
		for key: String in s.autobuy:
			s.autobuy[key] = bool(saved.get(key, true))
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
