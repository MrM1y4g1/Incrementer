extends TestCase


func _blocked_at(bit: int, register_bits: int = 16) -> GameState:
	var s := GameState.new()
	s.register_bits = register_bits
	s.bad_bits.append(bit)
	Economy.add_count(s, Formulas.register_cap(register_bits))
	return s


## A register of this width after `seconds` of play in one-second steps, with nobody refreshing.
func _worn(register_bits: int, seconds: float, overflows: int = 0, run_seed: int = 1) -> GameState:
	var s := GameState.new()
	s.register_bits = register_bits
	s.overflows = overflows
	s.run_seed = run_seed
	var content := Fixtures.content()
	for _second: int in int(seconds):
		Economy.advance(s, content, 1.0)
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


func test_wider_registers_get_bigger_puzzles_with_more_flips() -> void:
	check_eq([ParityGrid.size_for(16), ParityGrid.flips_for(16)], [4, 1], "one flip in a small word at first")
	check_eq([ParityGrid.size_for(64), ParityGrid.flips_for(64)], [5, 2])
	check_eq([ParityGrid.size_for(1024), ParityGrid.flips_for(1024)], [7, 4], "four flips in a 7 × 7 word at the end")
	var last_size := 0
	var last_flips := 0
	for bits: int in Formulas.REGISTER_WIDTHS:
		check(ParityGrid.size_for(bits) >= last_size and ParityGrid.flips_for(bits) >= last_flips, "never smaller at %d bits" % bits)
		last_size = ParityGrid.size_for(bits)
		last_flips = ParityGrid.flips_for(bits)


func test_a_puzzle_with_several_flips_needs_them_all() -> void:
	for seed_value: int in 20:
		var grid := ParityGrid.make(7, seed_value, 4)
		var odd_rows: Array[int] = []
		var odd_columns: Array[int] = []
		for i: int in grid.size:
			if not grid.row_even(i):
				odd_rows.append(i)
			if not grid.column_even(i):
				odd_columns.append(i)
		check_eq(odd_rows.size(), 4, "four odd rows")
		check_eq(odd_columns.size(), 4, "four odd columns")
		# Any pairing of odd rows with odd columns fixes every line; one flip short doesn't.
		for k: int in 3:
			grid.flip(odd_rows[k] * grid.size + odd_columns[k])
		check(not grid.solved(), "three flips aren't enough")
		grid.flip(odd_rows[3] * grid.size + odd_columns[3])
		check(grid.solved(), "the fourth solves it")


func test_the_scrub_puzzle_follows_the_register() -> void:
	var s := _blocked_at(10)
	var small := Economy.scrub_puzzle(s)
	s.register_bits = 256
	var big := Economy.scrub_puzzle(s)
	check_eq([small.size, small.flips], [4, 1])
	check_eq([big.size, big.flips], [6, 3])


func test_below_bit_is_the_largest_count_without_that_bit() -> void:
	check_eq(Formulas.below_bit(10), 1023.0)
	check(Formulas.below_bit(60) < pow(2.0, 60), "stays under 2^60 where 2^60 - 1 would round up")
	check_eq(Formulas.below_bit(60) + pow(2.0, 7), pow(2.0, 60))


func test_nothing_wears_in_an_8_bit_register() -> void:
	var s := _worn(8, 3600.0)
	check(s.wearing.is_empty() and s.bad_bits.is_empty(), "an 8-bit register stays clean")
	check_eq(s.wear_started, 0)


func test_widening_adds_no_bad_bits() -> void:
	var content := Fixtures.content()
	var s := GameState.new()
	s.overflows = 8
	s.count = Formulas.register_cap(8)
	Economy.widen(s, content)
	check_eq(s.register_bits, 16)
	check(s.bad_bits.is_empty() and s.wearing.is_empty(), "bits wear over time, not when the register widens")


func test_bits_start_wearing_anywhere_in_the_register() -> void:
	var s := _worn(64, 20000.0)
	check(s.wear_started > 50, "many bits wear over a long run: %d" % s.wear_started)
	var low := 0
	var high := 0
	for event: Array in s.events:
		if event[1] != "bad bit":
			continue
		var detail: Dictionary = event[2]
		var bit := int(detail["bit"])
		check(bit >= 0 and bit < 64, "bit %d is in the register" % bit)
		if bit < 16:
			low += 1
		elif bit >= 48:
			high += 1
	check(low > 0 and high > 0, "from the lowest bits to the highest")


func test_the_same_run_wears_the_same_bits() -> void:
	var first := _worn(32, 2000.0, 2, 999)
	var again := _worn(32, 2000.0, 2, 999)
	check_eq(again.bad_bits, first.bad_bits)
	check_eq(again.wearing, first.wearing)
	var other := _worn(32, 2000.0, 2, 1000)
	check(other.bad_bits != first.bad_bits, "another seed wears other bits")


func test_a_worn_bit_goes_bad_after_wearing_for_its_time() -> void:
	var content := Fixtures.content()
	var s := GameState.new()
	s.register_bits = 16
	s.wear_due = 10000.0
	s.wearing[5] = 0.0
	Economy.advance(s, content, Formulas.WEAR_SECONDS / 2.0)
	check_near(Economy.wear_level(s, 5), 0.5, 1e-9)
	check(s.bad_bits.is_empty(), "still wearing")
	Economy.advance(s, content, Formulas.WEAR_SECONDS / 2.0)
	check(not s.wearing.has(5), "no longer wearing")
	check_eq(s.bad_bits, [5], "it went bad")
	check_eq(s.count_lost, 0.0, "it held a 0, so nothing was lost")


func test_a_bit_that_goes_bad_holding_a_1_takes_its_value() -> void:
	var content := Fixtures.content()
	var s := GameState.new()
	s.register_bits = 16
	s.wear_due = 10000.0
	s.count = 1000.0
	# 1000 is 1111101000 in binary: bit 5 is 1, bit 4 is 0.
	s.wearing[5] = Formulas.WEAR_SECONDS - 1.0
	s.wearing[4] = Formulas.WEAR_SECONDS - 1.0
	Economy.advance(s, content, 1.0)
	check_eq(s.bad_bits, [4, 5])
	check_eq(s.count, 968.0, "bit 5 took its 32 with it")
	check_eq(s.count_lost, 32.0)
	var logged := {}
	for event: Array in s.events:
		if event[1] == "bad bit":
			logged[int(event[2]["bit"])] = float(event[2]["lost"])
	check_eq(logged, {4: 0.0, 5: 32.0}, "the run log says what each bit lost")


func test_losing_the_top_bit_drops_the_count_below_it() -> void:
	var content := Fixtures.content()
	var s := GameState.new()
	s.register_bits = 16
	s.wear_due = 10000.0
	s.count = 1000.0
	s.wearing[9] = Formulas.WEAR_SECONDS
	Economy.advance(s, content, 0.01)
	check_eq(s.count, 488.0, "1000 - 512")
	check(not Economy.is_blocked(s), "below the bad bit, so it can grow again")
	Economy.add_count(s, 1000.0)
	check_eq(s.count, 511.0, "up to just under bit 9")


func test_is_bit_set() -> void:
	check(Economy.is_bit_set(5.0, 0) and not Economy.is_bit_set(5.0, 1) and Economy.is_bit_set(5.0, 2), "5 is 101")
	check(not Economy.is_bit_set(pow(2.0, 80), 3), "bits below a large value's precision read 0")
	check(Economy.is_bit_set(Formulas.MAX_FLOAT, 1023), "the top bit of the largest float")


func test_refreshing_saves_a_worn_bit() -> void:
	var content := Fixtures.content()
	var s := GameState.new()
	s.register_bits = 16
	s.wear_due = 10000.0
	s.wearing[5] = 0.0
	s.wearing[9] = 0.0
	Economy.advance(s, content, Formulas.WEAR_SECONDS - 1.0)
	check(Economy.refresh(s, 5), "refreshed in time")
	check(not Economy.refresh(s, 6), "a healthy bit has nothing to refresh")
	check_eq(Economy.refresh_all(s), 1, "the other worn bit")
	Economy.advance(s, content, 10.0)
	check(s.bad_bits.is_empty() and s.wearing.is_empty(), "nothing went bad")
	check_eq(s.faults_refreshed, 2)


func test_older_machines_wear_faster() -> void:
	check_eq(Formulas.wear_interval(0), Formulas.WEAR_INTERVAL)
	check_eq(Formulas.wear_interval(4), Formulas.WEAR_INTERVAL / 2.0)
	check_eq(Formulas.wear_interval(100), Formulas.WEAR_INTERVAL / Formulas.WEAR_RATE_MAX, "up to a limit")
	check_eq(Formulas.wear_interval(0, 0.5), Formulas.WEAR_INTERVAL * 2.0, "Spare rows halve the rate")
	var young := _worn(32, 6000.0, 0)
	var old := _worn(32, 6000.0, 8)
	check(old.wear_started > young.wear_started * 2, "%d worn on an old machine, %d on a new one" % [old.wear_started, young.wear_started])


func test_a_bad_bit_holds_the_count() -> void:
	var s := _blocked_at(10)
	check_eq(s.count, 1023.0)
	check(Economy.is_blocked(s), "blocked at the bad bit")
	check(not Economy.is_full(s), "blocked isn't full")


func test_a_bad_bit_under_the_count_stops_it_growing() -> void:
	var s := GameState.new()
	s.register_bits = 16
	s.count = 1000.0
	s.bad_bits.append(3)
	check(Economy.is_blocked(s), "held at once")
	check_eq(Economy.add_count(s, 50.0), 0.0, "nothing added")
	check_eq(s.count, 1000.0, "and nothing lost")
	check_eq(Economy.repair_cost(s), 4.0, "a low bit is cheap to repair")
	check(Economy.repair(s), "repaired")
	check_eq(Economy.add_count(s, 50.0), 50.0, "growing again")


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
	s.wear_due = 10000.0
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


func test_bits_keep_wearing_while_a_bad_bit_holds_the_count() -> void:
	var content := Fixtures.content()
	var s := _blocked_at(10)
	s.wear_due = 5.0
	s.wearing[2] = 0.0
	Economy.advance(s, content, 10.0)
	check_eq(s.wear_started, 1, "a new worn bit while held")
	check_eq(s.wearing[2], 10.0, "and the one already wearing carries on")


func test_a_lower_bad_bit_starts_its_own_wait() -> void:
	var content := Fixtures.content()
	var s := _blocked_at(10)
	s.wear_due = 10000.0
	Economy.advance(s, content, 30.0)
	s.wearing[4] = Formulas.WEAR_SECONDS - 1.0
	Economy.advance(s, content, 1.0)
	check_eq(s.bad_bits, [4, 10])
	check_near(Economy.scrub_time_left(s), Formulas.FAULT_SCRUB_SECONDS - 1.0, 1e-9, "a fresh minute for bit 4")


func test_ecc_memory_scrubs_faster() -> void:
	var content := _content_with(_node(FirmwareDef.Effect.SCRUB_SECONDS, 20.0))
	var s := _blocked_at(10)
	s.firmware.append(&"node")
	s.wear_due = 10000.0
	s.layer_amount[0] = 1.0
	Economy.advance(s, content, 20.0)
	check(s.bad_bits.is_empty(), "scrubbed after 20 seconds")


func test_spare_rows_wear_fewer_bits() -> void:
	var content := _content_with(_node(FirmwareDef.Effect.FAULT_RATE, 0.5))
	var counts: Array[int] = []
	for spare: bool in [false, true]:
		var s := GameState.new()
		s.register_bits = 32
		s.run_seed = 5
		if spare:
			s.firmware.append(&"node")
		for _second: int in 6000:
			Economy.advance(s, content, 1.0)
		counts.append(s.wear_started)
	check(counts[1] < counts[0] * 0.7, "%d worn with Spare rows, %d without" % [counts[1], counts[0]])


func test_the_switch_turns_bad_bits_off() -> void:
	var content := Fixtures.content()
	var s := _blocked_at(10)
	s.wearing[3] = 10.0
	Economy.set_faults_on(s, false)
	check(s.bad_bits.is_empty(), "switching off clears this run's bad bits")
	check(s.wearing.is_empty(), "and its worn bits")
	for _second: int in 3000:
		Economy.advance(s, content, 1.0)
	check(s.bad_bits.is_empty() and s.wearing.is_empty(), "and no new ones appear")


func test_an_overflow_clears_bad_bits_and_reseeds() -> void:
	var content := Fixtures.content()
	var s := _blocked_at(70, 128)
	s.count = 0.0
	Economy.add_count(s, Formulas.OVERFLOW_THRESHOLD)
	var seed_before := s.run_seed
	s.wearing[9] = 30.0
	s.wear_started = 12
	Economy.overflow(s, content)
	check(s.bad_bits.is_empty() and s.wearing.is_empty(), "a new run starts clean")
	check_eq(s.wear_started, 0)
	check(s.run_seed != seed_before, "with a new seed")


func test_bad_bits_survive_a_save_and_load() -> void:
	var s := _blocked_at(12)
	s.bad_bits.append(14)
	s.blocked_time = 20.0
	s.faults_on = false
	s.faults_repaired = 3
	s.faults_refreshed = 9
	s.run_seed = 77
	s.wearing[3] = 12.5
	s.wear_due = 12.25
	s.wear_started = 6
	var t: GameState = SaveCodec.decode(SaveCodec.encode(s, 1.0))["state"]
	check_eq(t.bad_bits, [12, 14])
	check_eq(t.blocked_time, 20.0)
	check(not t.faults_on, "the switch is kept")
	check_eq(t.faults_repaired, 3)
	check_eq(t.faults_refreshed, 9)
	check_eq(t.run_seed, 77)
	check_eq(t.wearing, {3: 12.5})
	check_eq(t.wear_due, 12.25)
	check_eq(t.wear_started, 6)


func test_loading_drops_impossible_bad_bits() -> void:
	var t := GameState.from_dict({"register_bits": 16, "count": 2000.0, "bad_bits": [5, 12, 40, 12, -1],
		"wearing": [[2, 10.0], [5, 3.0], [99, 1.0], [7, 1e9], "junk"]})
	check_eq(t.bad_bits, [5, 12], "only bits the register holds, under the Count or above it")
	check_eq(t.wearing, {2: 10.0, 7: Formulas.WEAR_SECONDS}, "worn bits the register holds that haven't gone bad")


func test_version_4_saves_load_with_bad_bits_on() -> void:
	var data := GameState.new().to_dict()
	for key: String in ["run_seed", "bad_bits", "blocked_time", "faults_on", "faults_repaired", "faults_scrubbed", "faults_waited",
			"wearing", "wear_due", "wear_started", "faults_refreshed", "tutorial"]:
		data.erase(key)
	var loaded := SaveCodec.decode(JSON.stringify({"version": 4, "saved_at": 1.0, "state": data}))
	check(not loaded.is_empty(), "a version 4 save must decode")
	var s: GameState = loaded["state"]
	check(s.faults_on, "bad bits start on")
	check(s.bad_bits.is_empty(), "and the current run has none")


func test_version_5_saves_load_with_the_tutorial_basics_shown() -> void:
	var played := GameState.new()
	played.total_clicks = 40
	played.register_bits = 32
	played.bad_bits.append(20)
	var fresh := GameState.new()
	for pair: Array in [[played, Tutorial.BASICS], [fresh, []]]:
		var data: Dictionary = (pair[0] as GameState).to_dict()
		for key: String in ["wearing", "wear_due", "wear_started", "faults_refreshed", "tutorial"]:
			data.erase(key)
		var loaded := SaveCodec.decode(JSON.stringify({"version": 5, "saved_at": 1.0, "state": data}))
		check(not loaded.is_empty(), "a version 5 save must decode")
		var s: GameState = loaded["state"]
		check_eq(s.tutorial, pair[1])
		check(s.wearing.is_empty(), "nothing wearing yet")
		check_eq(s.wear_due, -1.0)
		check_eq(s.bad_bits, (pair[0] as GameState).bad_bits, "bad bits are kept")


func test_nothing_wears_after_the_ending() -> void:
	var content := Fixtures.content()
	var s := GameState.new()
	s.register_bits = 1024
	s.ended = true
	for _second: int in 3000:
		Economy.advance(s, content, 1.0)
	check(s.wearing.is_empty() and s.bad_bits.is_empty(), "the finished machine rests")


func test_the_autoplayer_refreshes_worn_bits() -> void:
	var content := Fixtures.content()
	var s := GameState.new()
	s.register_bits = 32
	AutoPlayer.play(s, content, 3000.0, 1.0, 0.0)
	check(s.faults_refreshed > 5, "refreshed %d" % s.faults_refreshed)
	check(s.bad_bits.is_empty(), "none went bad")
	var idle := GameState.new()
	idle.register_bits = 32
	AutoPlayer.play(idle, content, 3000.0, 1.0, 0.0, AutoPlayer.Fix.WAIT, INF)
	check_eq(idle.faults_refreshed, 0, "an idle player refreshes nothing")
	check(idle.bad_bits.size() + idle.faults_waited > 5, "and lets its worn bits go bad")


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
