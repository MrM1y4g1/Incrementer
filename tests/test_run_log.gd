extends TestCase

## A version 3 save, as 1.0.3 wrote it: one Overflow, no run log.
const V3_SAVE := """{
	"saved_at": 1760790000.0,
	"state": {
		"count": 500.0,
		"register_bits": 16,
		"play_time": 3100.0,
		"run_time": 100.0,
		"carry": 2.0,
		"total_carry": 2.0,
		"overflows": 1,
		"firmware": [],
		"runs": [{"time": 3000.0, "bits": 64.0, "carry": 2.0}],
		"ended": false
	},
	"version": 3
}"""


func _kinds(state: GameState) -> Array:
	var kinds: Array = []
	for event: Array in state.events:
		kinds.append(event[1])
	return kinds


func test_the_first_unit_of_a_layer_is_logged_once_a_run() -> void:
	var content := Fixtures.content()
	var s := GameState.new()
	s.count = 1000.0
	s.play_time = 12.5
	Economy.buy(s, content, 0, Economy.BuyMode.ONE)
	Economy.buy(s, content, 0, Economy.BuyMode.ONE)
	check_eq(s.events, [[12.5, "layer", "layer_1"]])


func test_purchases_widening_and_the_overflow_are_logged() -> void:
	var content := Fixtures.content()
	var s := GameState.new()
	s.count = Formulas.register_cap(8)
	Economy.widen(s, content)
	var upgrade := Fixtures.upgrade(&"faster", UpgradeDef.Effect.ALL_MULTIPLIER, 2.0, 1.0)
	s.count = 10.0
	Economy.buy_upgrade(s, upgrade)
	s.register_bits = 64
	s.run_time = 2966.0
	Economy.add_count(s, Formulas.register_cap(64))
	Economy.overflow(s, content)
	check_eq(_kinds(s), ["widen", "upgrade", "overflow"])
	check_eq(s.events[0][2], 16)
	check_eq(s.events[1][2], "faster")
	var overflow: Dictionary = s.events[2][2]
	check_eq(overflow["bits"], 64.0)
	check_eq(overflow["carry"], 2.0)
	check_eq(overflow["run_seconds"], 2966.0)


func test_the_log_keeps_the_newest_events() -> void:
	var s := GameState.new()
	for i: int in GameState.EVENT_LIMIT + 5:
		s.record("widen", i)
	check_eq(s.events.size(), GameState.EVENT_LIMIT)
	check_eq(s.events[0][2], 5, "the oldest events drop off first")


func test_the_log_survives_a_save_and_load() -> void:
	var s := GameState.new()
	s.play_time = 61.25
	s.record("session", "1.1.0")
	s.record("overflow", {"bits": 64.0, "carry": 2.0, "run_seconds": 3000.0})
	var t: GameState = SaveCodec.decode(SaveCodec.encode(s, 1.0))["state"]
	check_eq(t.events.size(), 2)
	check_eq(t.events[0], [61.3, "session", "1.1.0"], "times are kept to a tenth of a second")
	check_eq((t.events[1][2] as Dictionary)["carry"], 2.0)


func test_broken_events_are_dropped_on_load() -> void:
	var t := GameState.from_dict({"events": [[1.0, "widen", 16], "nonsense", [2.0, 5, 3], [3.0, "upgrade"]]})
	check_eq(t.events, [[1.0, "widen", 16]])


func test_version_3_saves_load_with_an_empty_log() -> void:
	var loaded := SaveCodec.decode(V3_SAVE)
	check(not loaded.is_empty(), "a version 3 save must decode")
	var s: GameState = loaded["state"]
	check_eq(s.overflows, 1)
	check_eq(s.events, [])


func test_csv_has_a_header_and_one_line_per_event() -> void:
	var s := GameState.new()
	s.play_time = 3725.0
	s.record("widen", 32)
	s.record("overflow", {"bits": 64.0, "carry": 2.0})
	var lines := RunLog.to_csv(s).strip_edges().split("\n")
	check_eq(lines.size(), 3)
	check_eq(lines[0], RunLog.CSV_HEADER)
	check(lines[1].begins_with("3725.0,") and lines[1].ends_with(",widen,32"), "a widen line: %s" % lines[1])
	check(lines[2].ends_with(",overflow,bits=64.0;carry=2.0"), "an Overflow's fields can't break the columns: %s" % lines[2])
