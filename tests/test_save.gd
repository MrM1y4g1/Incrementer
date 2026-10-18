extends TestCase


func test_round_trip_keeps_every_field() -> void:
	var s := GameState.new()
	s.register_bits = 64
	s.count = 1.8446744073709552e19
	s.peak_count = 1.8446744073709552e19
	s.total_clicks = 4321
	s.play_time = 3599.75
	s.layer_amount[0] = 123.456
	s.layer_amount[7] = 0.25
	s.layer_bought[0] = 42
	s.layer_bought[3] = 7

	var loaded := SaveCodec.decode(SaveCodec.encode(s, 1760000000.5))
	check(not loaded.is_empty(), "a fresh save must decode")
	var t: GameState = loaded["state"]
	check_eq(t.register_bits, 64)
	check_eq(t.count, s.count)
	check_eq(t.peak_count, s.peak_count)
	check_eq(t.total_clicks, 4321)
	check_eq(t.play_time, 3599.75)
	check_eq(t.layer_amount, s.layer_amount)
	check_eq(t.layer_bought, s.layer_bought)
	check_eq(loaded["saved_at"], 1760000000.5)


func test_garbage_is_rejected() -> void:
	check(SaveCodec.decode("not json").is_empty(), "plain text is not a save")
	check(SaveCodec.decode("[]").is_empty(), "a JSON array is not a save")
	check(SaveCodec.decode("{\"version\": 1}").is_empty(), "a save needs a state")


func test_saves_from_a_newer_version_are_rejected() -> void:
	check(SaveCodec.decode("{\"version\": 99, \"state\": {}}").is_empty(), "unknown future versions must not load")


func test_missing_fields_use_new_game_values() -> void:
	var s := GameState.from_dict({})
	check_eq(s.register_bits, 8)
	check_eq(s.count, 0.0)
	check_eq(s.layer_amount.size(), GameState.LAYER_COUNT)


func test_bad_values_are_cleaned_up() -> void:
	var s := GameState.from_dict({"register_bits": 12, "count": 5000.0, "total_clicks": -3, "layer_bought": [-1, 2]})
	check_eq(s.register_bits, 8)
	check_eq(s.count, 255.0, "count is clamped to the register cap")
	check_eq(s.total_clicks, 0)
	check_eq(s.layer_bought[0], 0)
	check_eq(s.layer_bought[1], 2)
