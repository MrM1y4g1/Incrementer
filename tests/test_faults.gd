extends TestCase


func _blocked_at(bit: int, register_bits: int = 16) -> GameState:
	var s := GameState.new()
	s.register_bits = register_bits
	s.bad_bits.append(bit)
	Economy.add_count(s, Formulas.register_cap(register_bits))
	return s


func _node(effect: FirmwareDef.Effect, value: float) -> FirmwareDef:
	var node := FirmwareDef.new()
	node.id = &"node"
	node.effect = effect
	node.value = value
	return node


func _content_with(node: FirmwareDef) -> Content:
	var content := Fixtures.content()
	content.firmware = [node]
	content.index()
	return content


func test_the_puzzle_has_one_flipped_bit() -> void:
	for seed_value: int in 20:
		var grid := ParityGrid.make(5, seed_value)
		var odd_rows: Array[int] = []
		var odd_columns: Array[int] = []
		for i: int in grid.size:
			if not grid.row_even(i):
				odd_rows.append(i)
			if not grid.column_even(i):
				odd_columns.append(i)
		check_eq(odd_rows.size(), 1, "one odd row")
		check_eq(odd_columns.size(), 1, "one odd column")
		check(not grid.solved(), "not solved yet")
		grid.flip(odd_rows[0] * grid.size + odd_columns[0])
		check(grid.solved(), "flipping the bit where they cross solves it")


func test_a_wrong_flip_does_not_solve_the_puzzle() -> void:
	var grid := ParityGrid.make(4, 7)
	# A bit on the odd row but in an even column: flipping it fixes the row and breaks that column.
	var done := false
	for row: int in grid.size:
		for column: int in grid.size:
			if not done and not grid.row_even(row) and grid.column_even(column):
				grid.flip(row * grid.size + column)
				done = true
	check(done, "found a bit off the crossing")
	check(not grid.solved(), "a bit off the crossing doesn't solve it")


func test_bigger_puzzles_for_higher_bits() -> void:
	check_eq(ParityGrid.size_for(40), 4)
	check_eq(ParityGrid.size_for(300), 5)
	check_eq(ParityGrid.size_for(900), 6)


func test_below_bit_is_the_largest_count_without_that_bit() -> void:
	check_eq(Formulas.below_bit(10), 1023.0)
	check(Formulas.below_bit(60) < pow(2.0, 60), "stays under 2^60 where 2^60 - 1 would round up")
	check_eq(Formulas.below_bit(60) + pow(2.0, 7), pow(2.0, 60))


func test_no_bad_bits_in_the_first_run() -> void:
	var content := Fixtures.content()
	var s := GameState.new()
	s.count = Formulas.register_cap(8)
	Economy.widen(s, content)
	check_eq(s.register_bits, 16)
	check(s.bad_bits.is_empty(), "the first run is clean")


func test_widening_maps_in_bad_bits_among_the_new_bits() -> void:
	var content := Fixtures.content()
	var s := GameState.new()
	s.overflows = 8
	s.run_seed = 12345
	s.count = Formulas.register_cap(8)
	Economy.widen(s, content)
	check(not s.bad_bits.is_empty(), "an old machine has bad bits")
	check(s.bad_bits.size() <= int(Formulas.FAULT_RATE_MAX), "at most the top rate per widening")
	for bit: int in s.bad_bits:
		check(bit >= 8 and bit < 16, "bad bit %d is among the new bits" % bit)


func test_the_same_run_meets_the_same_bad_bits() -> void:
	var content := Fixtures.content()
	var first: Array[int] = []
	for attempt: int in 2:
		var s := GameState.new()
		s.overflows = 6
		s.run_seed = 999
		s.count = Formulas.register_cap(8)
		Economy.widen(s, content)
		if attempt == 0:
			first = s.bad_bits.duplicate()
		else:
			check_eq(s.bad_bits, first)


func test_a_bad_bit_holds_the_count() -> void:
	var s := _blocked_at(10)
	check_eq(s.count, 1023.0)
	check(Economy.is_blocked(s), "blocked at the bad bit")
	check(not Economy.is_full(s), "blocked isn't full")


func test_repair_costs_half_the_bit() -> void:
	var s := _blocked_at(10)
	check_eq(Economy.repair_cost(s), 512.0)
	check(Economy.repair(s), "affordable once blocked")
	check_eq(s.count, 511.0)
	check(s.bad_bits.is_empty(), "the bit is cleared")
	check_eq(s.faults_repaired, 1)
	Economy.add_count(s, 1e9)
	check_eq(s.count, Formulas.register_cap(16), "the Count runs on to the register cap")


func test_scrubbing_is_free() -> void:
	var s := _blocked_at(10)
	check(Economy.scrub(s), "scrubbed")
	check_eq(s.count, 1023.0)
	check_eq(s.faults_scrubbed, 1)


func test_a_bad_bit_scrubs_itself_after_a_minute_of_blocking() -> void:
	var content := Fixtures.content()
	var s := _blocked_at(10)
	s.layer_amount[0] = 1.0
	Economy.advance(s, content, Formulas.FAULT_SCRUB_SECONDS - 1.0)
	check(Economy.is_blocked(s), "still waiting")
	check_near(Economy.scrub_time_left(s), 1.0, 1e-9)
	Economy.advance(s, content, 1.0)
	check(s.bad_bits.is_empty(), "scrubbed itself")
	check_eq(s.faults_waited, 1)
	var kinds: Array = []
	for event: Array in s.events:
		kinds.append(event[1])
	check_eq(kinds, ["blocked", "waited"])


func test_ecc_memory_scrubs_faster() -> void:
	var content := _content_with(_node(FirmwareDef.Effect.SCRUB_SECONDS, 20.0))
	var s := _blocked_at(10)
	s.firmware.append(&"node")
	s.layer_amount[0] = 1.0
	Economy.advance(s, content, 20.0)
	check(s.bad_bits.is_empty(), "scrubbed after 20 seconds")


func test_spare_rows_map_in_fewer_bad_bits() -> void:
	var content := _content_with(_node(FirmwareDef.Effect.FAULT_RATE, 0.5))
	var s := GameState.new()
	s.firmware.append(&"node")
	# Four Overflows make two bad bits per widening; Spare rows halve that to exactly one.
	s.overflows = 4
	s.count = Formulas.register_cap(8)
	Economy.widen(s, content)
	check_eq(s.bad_bits.size(), 1, "half of two")


func test_the_switch_turns_bad_bits_off() -> void:
	var content := Fixtures.content()
	var s := _blocked_at(10)
	Economy.set_faults_on(s, false)
	check(s.bad_bits.is_empty(), "switching off clears this run's bad bits")
	s.overflows = 8
	s.register_bits = 8
	s.count = Formulas.register_cap(8)
	Economy.widen(s, content)
	check(s.bad_bits.is_empty(), "and no new ones appear")


func test_an_overflow_clears_bad_bits_and_reseeds() -> void:
	var content := Fixtures.content()
	var s := _blocked_at(70, 128)
	s.count = 0.0
	Economy.add_count(s, Formulas.OVERFLOW_THRESHOLD)
	var seed_before := s.run_seed
	Economy.overflow(s, content)
	check(s.bad_bits.is_empty(), "a new run starts clean")
	check(s.run_seed != seed_before, "with a new seed")


func test_bad_bits_survive_a_save_and_load() -> void:
	var s := _blocked_at(12)
	s.bad_bits.append(14)
	s.blocked_time = 20.0
	s.faults_on = false
	s.faults_repaired = 3
	s.run_seed = 77
	var t: GameState = SaveCodec.decode(SaveCodec.encode(s, 1.0))["state"]
	check_eq(t.bad_bits, [12, 14])
	check_eq(t.blocked_time, 20.0)
	check(not t.faults_on, "the switch is kept")
	check_eq(t.faults_repaired, 3)
	check_eq(t.run_seed, 77)


func test_loading_drops_impossible_bad_bits() -> void:
	var t := GameState.from_dict({"register_bits": 16, "count": 2000.0, "bad_bits": [5, 12, 40, 12, -1]})
	check_eq(t.bad_bits, [12], "only bits the register holds and the Count hasn't passed")


func test_version_4_saves_load_with_bad_bits_on() -> void:
	var data := GameState.new().to_dict()
	for key: String in ["run_seed", "bad_bits", "blocked_time", "faults_on", "faults_repaired", "faults_scrubbed", "faults_waited"]:
		data.erase(key)
	var loaded := SaveCodec.decode(JSON.stringify({"version": 4, "saved_at": 1.0, "state": data}))
	check(not loaded.is_empty(), "a version 4 save must decode")
	var s: GameState = loaded["state"]
	check(s.faults_on, "bad bits start on")
	check(s.bad_bits.is_empty(), "and the current run has none")


func test_the_autoplayer_repairs_a_bad_bit() -> void:
	var content := Fixtures.content()
	var s := _blocked_at(10)
	AutoPlayer.play(s, content, 0.25)
	check_eq(s.faults_repaired, 1)


func test_bad_bit_achievements() -> void:
	var s := GameState.new()
	var scrubbed := Fixtures.achievement(&"scrub", AchievementDef.Condition.FAULTS_SCRUBBED, 1.0)
	var cleared := Fixtures.achievement(&"clear", AchievementDef.Condition.FAULTS_CLEARED, 3.0)
	s.faults_repaired = 2
	check(not Achievements.is_met(s, scrubbed), "nothing scrubbed yet")
	check(not Achievements.is_met(s, cleared), "two of three cleared")
	s.faults_scrubbed = 1
	check(Achievements.is_met(s, scrubbed), "one scrubbed")
	check(Achievements.is_met(s, cleared), "three cleared in all")
