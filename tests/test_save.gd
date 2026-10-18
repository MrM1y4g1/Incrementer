extends TestCase

## A real version 1 save, as M1 wrote it.
const V1_SAVE := """{
	"saved_at": 1760770000.0,
	"state": {
		"count": 1200.5,
		"layer_amount": [40.0, 3.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
		"layer_bought": [12, 3, 0, 0, 0, 0, 0, 0],
		"peak_count": 5000.0,
		"play_time": 420.0,
		"register_bits": 16,
		"total_clicks": 310
	},
	"version": 1
}"""


## A version 2 save, as M2 wrote it: a full 64-bit register, so it can Overflow straight away.
const V2_SAVE := """{
	"saved_at": 1760780000.0,
	"state": {
		"achievements": ["kilocount"],
		"clock_level": 6,
		"count": 1.8446744073709552e19,
		"layer_amount": [1.0e15, 2.0e10, 3.0e6, 4000.0, 50.0, 6.0, 0.0, 0.0],
		"layer_bought": [200, 150, 120, 90, 60, 30, 0, 0],
		"peak_count": 1.8446744073709552e19,
		"play_time": 3000.0,
		"register_bits": 64,
		"total_clicks": 12000,
		"total_produced": 4.0e19,
		"upgrades": ["incrementer_10"]
	},
	"version": 2
}"""


func test_version_2_saves_still_load() -> void:
	var loaded := SaveCodec.decode(V2_SAVE)
	check(not loaded.is_empty(), "a version 2 save must decode")
	var s: GameState = loaded["state"]
	check_eq(s.register_bits, 64)
	check_eq(s.clock_level, 6)
	check_eq(s.run_time, 3000.0, "the whole old save counts as one run")
	check(Economy.can_overflow(s), "a full 64-bit register from M2 can Overflow")
	check_eq(s.carry, 0.0)
	check_eq(s.firmware.size(), 0)


func test_run_fields_survive_a_round_trip() -> void:
	var s := GameState.new()
	s.carry = 12.0
	s.total_carry = 40.0
	s.overflows = 3
	s.run_time = 77.5
	s.firmware.append(&"wide_bus_128")
	s.runs.append({"time": 3000.0, "bits": 64.0, "carry": 1.0})
	s.autobuy["clock"] = false
	s.ended = true
	s.ended_time = 23400.0
	var t: GameState = SaveCodec.decode(SaveCodec.encode(s, 1.0))["state"]
	check_eq(t.carry, 12.0)
	check_eq(t.total_carry, 40.0)
	check_eq(t.overflows, 3)
	check_eq(t.run_time, 77.5)
	check_eq(t.firmware, s.firmware)
	check_eq(t.runs.size(), 1)
	check_eq(float(t.runs[0]["carry"]), 1.0)
	check_eq(t.autobuy["clock"], false)
	check(t.ended, "the ending is remembered")
	check_eq(t.ended_time, 23400.0)


func test_round_trip_keeps_every_field() -> void:
	var s := GameState.new()
	s.register_bits = 64
	s.count = 1.8446744073709552e19
	s.peak_count = 1.8446744073709552e19
	s.total_produced = 3.5e19
	s.clock_level = 4
	s.total_clicks = 4321
	s.play_time = 3599.75
	s.layer_amount[0] = 123.456
	s.layer_amount[7] = 0.25
	s.layer_bought[0] = 42
	s.layer_bought[3] = 7
	s.upgrades.append(&"fast_path")
	s.achievements.append(&"kilocount")

	var loaded := SaveCodec.decode(SaveCodec.encode(s, 1760000000.5))
	check(not loaded.is_empty(), "a fresh save must decode")
	var t: GameState = loaded["state"]
	check_eq(t.register_bits, 64)
	check_eq(t.count, s.count)
	check_eq(t.peak_count, s.peak_count)
	check_eq(t.total_produced, s.total_produced)
	check_eq(t.clock_level, 4)
	check_eq(t.total_clicks, 4321)
	check_eq(t.play_time, 3599.75)
	check_eq(t.layer_amount, s.layer_amount)
	check_eq(t.layer_bought, s.layer_bought)
	check_eq(t.upgrades, s.upgrades)
	check_eq(t.achievements, s.achievements)
	check_eq(loaded["saved_at"], 1760000000.5)


func test_version_1_saves_still_load() -> void:
	var loaded := SaveCodec.decode(V1_SAVE)
	check(not loaded.is_empty(), "a version 1 save must decode")
	var s: GameState = loaded["state"]
	check_eq(s.count, 1200.5)
	check_eq(s.register_bits, 16)
	check_eq(s.layer_bought[0], 12)
	check_eq(s.clock_level, 0)
	check_eq(s.upgrades.size(), 0)
	check_eq(s.achievements.size(), 0)
	check_eq(s.total_produced, 5000.0, "lifetime production starts from the peak Count")


func test_garbage_is_rejected() -> void:
	check(SaveCodec.decode("not json").is_empty(), "plain text is not a save")
	check(SaveCodec.decode("[]").is_empty(), "a JSON array is not a save")
	check(SaveCodec.decode("{\"version\": 2}").is_empty(), "a save needs a state")


func test_saves_from_a_newer_version_are_rejected() -> void:
	check(SaveCodec.decode("{\"version\": 99, \"state\": {}}").is_empty(), "unknown future versions must not load")


func test_missing_fields_use_new_game_values() -> void:
	var s := GameState.from_dict({})
	check_eq(s.register_bits, 8)
	check_eq(s.count, 0.0)
	check_eq(s.layer_amount.size(), GameState.LAYER_COUNT)
	check_eq(s.upgrades.size(), 0)


func test_bad_values_are_cleaned_up() -> void:
	var s := GameState.from_dict({"register_bits": 12, "count": 5000.0, "total_clicks": -3, "layer_bought": [-1, 2], "upgrades": ["a", "a", ""]})
	check_eq(s.register_bits, 8)
	check_eq(s.count, 255.0, "count is clamped to the register cap")
	check_eq(s.total_clicks, 0)
	check_eq(s.layer_bought[0], 0)
	check_eq(s.layer_bought[1], 2)
	check_eq(s.upgrades.size(), 1, "duplicate and empty ids are dropped")


func test_an_infinite_lifetime_total_loads_as_the_largest_float() -> void:
	# What 1.0.x wrote once the total passed the largest float.
	var s := GameState.from_dict(JSON.parse_string('{"total_produced": 1e99999}'))
	check_eq(s.total_produced, Formulas.MAX_FLOAT)


func test_the_version_of_save_text() -> void:
	check_eq(SaveCodec.version_of(SaveCodec.encode(GameState.new(), 1.0)), SaveCodec.VERSION)
	check_eq(SaveCodec.version_of('{"version": 99, "state": {}}'), 99, "a save from a newer version")
	check_eq(SaveCodec.version_of("not a save"), 0)
	check(SaveCodec.decode('{"version": 99, "state": {}}').is_empty(), "a newer save can't be loaded")
