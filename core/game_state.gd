class_name GameState
extends RefCounted
## Everything a save file stores, plus a few derived values that Economy rebuilds on demand.
## "Run" fields reset on every Overflow; everything else lasts the whole save.

const LAYER_COUNT := 8
## How many finished runs the history keeps.
const RUN_HISTORY_LIMIT := 20
## How many run log events the save keeps. A playthrough to the ending makes about 600; the oldest drop off.
const EVENT_LIMIT := 3000

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
## Seeds this run's worn bits and the bad bits' puzzles, so a run always meets the same ones.
var run_seed := 0
## Bits that have gone bad this run, anywhere in the register, lowest first. The Count can't grow past the
## lowest one: it stops below it, or stops growing at all if it's already higher.
var bad_bits: Array[int] = []
## Seconds the Count has been held by the lowest bad bit. At scrub_seconds the bit scrubs itself.
var blocked_time := 0.0
## Bits wearing out this run: bit → seconds it has been wearing. At Formulas.WEAR_SECONDS it goes bad.
var wearing: Dictionary[int, float] = {}
## Seconds until the next bit starts to wear, or -1 before the first is scheduled.
var wear_due := -1.0
## Bits that have started to wear this run. Each one's bit and timing come from the seed and this number.
var wear_started := 0

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
## Whether bits wear out and go bad. A switch in Settings.
var faults_on := true
## Bad bits cleared over the whole save: repaired with Count, scrubbed with the puzzle, or waited out.
var faults_repaired := 0
var faults_scrubbed := 0
var faults_waited := 0
## Count lost over the whole save to bits that went bad while they held a 1.
var count_lost := 0.0
## The click charge's records: the fastest click rate, how many times the charge filled (ULTRA), and how
## many times the player was caught clicking faster than a person can (Icarus).
var best_click_rate := 0.0
var ultras := 0
var icarus_falls := 0
## Tutorial steps already shown (see Tutorial).
var tutorial: Array[String] = []
## The run log, oldest first: [play seconds, kind, detail]. See RunLog for the kinds.
var events: Array = []

# --- The click charge (see Formulas.CHARGE_CLICKS). Not saved: it drains in seconds. ---
## How full the charge is, 0 to 1.
var charge := 0.0
## Clicks a second, averaged over about Formulas.CLICK_RATE_SECONDS.
var click_rate := 0.0
## True from the moment the charge is full until it drops below Formulas.ULTRA_EXIT.
var ultra := false
## Seconds the click rate has stayed at Formulas.ICARUS_RATE or more.
var icarus_time := 0.0
## Seconds before the charge can build again, after the player was caught macro clicking.
var burnout := 0.0

# --- Derived by Economy.refresh_effects(). Not saved. ---
var effects_dirty := true
var layer_multiplier := PackedFloat64Array()
var click_multiplier := 1.0
var click_rate_share := 0.0
var max_bits := 64
var milestone_step := Formulas.MILESTONE_EVERY
var boot_bits := 8
var carry_multiplier := 1.0
var scrub_seconds := Formulas.FAULT_SCRUB_SECONDS
var fault_rate_multiplier := 1.0
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


## Adds an event to the run log at the current play time.
func record(kind: String, detail: Variant = "") -> void:
	events.append([snappedf(play_time, 0.1), kind, detail])
	while events.size() > EVENT_LIMIT:
		events.pop_front()


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
		"run_seed": run_seed,
		"bad_bits": bad_bits.duplicate(),
		"blocked_time": blocked_time,
		"wearing": _wearing_pairs(),
		"wear_due": wear_due,
		"wear_started": wear_started,
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
		"faults_on": faults_on,
		"faults_repaired": faults_repaired,
		"faults_scrubbed": faults_scrubbed,
		"faults_waited": faults_waited,
		"count_lost": count_lost,
		"best_click_rate": best_click_rate,
		"ultras": ultras,
		"icarus_falls": icarus_falls,
		"tutorial": tutorial.duplicate(),
		"events": events.duplicate(true),
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
	# Before 1.1.0 this total could pass the largest float; JSON writes that INF as 1e99999.
	s.total_produced = clampf(float(data.get("total_produced", 0.0)), 0.0, Formulas.MAX_FLOAT)
	s.total_clicks = maxi(0, int(data.get("total_clicks", 0)))
	s.play_time = maxf(0.0, float(data.get("play_time", 0.0)))
	s.carry = maxf(0.0, float(data.get("carry", 0.0)))
	s.total_carry = maxf(s.carry, float(data.get("total_carry", 0.0)))
	s.overflows = maxi(0, int(data.get("overflows", 0)))
	s.ended = bool(data.get("ended", false))
	s.ended_time = maxf(0.0, float(data.get("ended_time", 0.0)))
	s.run_seed = int(data.get("run_seed", 0))
	s.blocked_time = maxf(0.0, float(data.get("blocked_time", 0.0)))
	s.faults_on = bool(data.get("faults_on", true))
	s.faults_repaired = maxi(0, int(data.get("faults_repaired", 0)))
	s.faults_scrubbed = maxi(0, int(data.get("faults_scrubbed", 0)))
	s.faults_waited = maxi(0, int(data.get("faults_waited", 0)))
	s.count_lost = clampf(float(data.get("count_lost", 0.0)), 0.0, Formulas.MAX_FLOAT)
	s.best_click_rate = maxf(0.0, float(data.get("best_click_rate", 0.0)))
	s.ultras = maxi(0, int(data.get("ultras", 0)))
	s.icarus_falls = maxi(0, int(data.get("icarus_falls", 0)))
	s.wear_due = maxf(-1.0, float(data.get("wear_due", -1.0)))
	s.wear_started = maxi(0, int(data.get("wear_started", 0)))
	var saved_bad_bits: Variant = data.get("bad_bits", [])
	if saved_bad_bits is Array:
		var list: Array = saved_bad_bits
		for item: Variant in list:
			# Only bits the register holds.
			var bit := int(item)
			if bit >= 0 and bit < s.register_bits and not s.bad_bits.has(bit):
				s.bad_bits.append(bit)
		s.bad_bits.sort()
	var saved_wearing: Variant = data.get("wearing", [])
	if saved_wearing is Array:
		var list: Array = saved_wearing
		for item: Variant in list:
			# [bit, seconds worn], for bits the register holds that haven't gone bad.
			if item is Array and (item as Array).size() == 2:
				var bit := int(item[0])
				if bit >= 0 and bit < s.register_bits and not s.bad_bits.has(bit):
					s.wearing[bit] = clampf(float(item[1]), 0.0, Formulas.WEAR_SECONDS)
	var saved_tutorial: Variant = data.get("tutorial", [])
	if saved_tutorial is Array:
		var list: Array = saved_tutorial
		for item: Variant in list:
			if not s.tutorial.has(str(item)):
				s.tutorial.append(str(item))

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

	var saved_events: Variant = data.get("events", [])
	if saved_events is Array:
		var list: Array = saved_events
		for item: Variant in list:
			# Keep only well-formed events: [seconds, kind, detail].
			if item is Array and (item as Array).size() == 3 and typeof(item[0]) in [TYPE_FLOAT, TYPE_INT] and item[1] is String:
				s.events.append([maxf(0.0, float(item[0])), item[1], item[2]])
		while s.events.size() > EVENT_LIMIT:
			s.events.pop_front()

	var switches: Variant = data.get("autobuy", {})
	if switches is Dictionary:
		var saved: Dictionary = switches
		for key: String in s.autobuy:
			s.autobuy[key] = bool(saved.get(key, true))
	return s


## The worn bits as [bit, seconds] pairs, lowest bit first. JSON would turn a Dictionary's keys into text.
func _wearing_pairs() -> Array:
	var pairs: Array = []
	var bits := wearing.keys()
	bits.sort()
	for bit: int in bits:
		pairs.append([bit, wearing[bit]])
	return pairs


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
