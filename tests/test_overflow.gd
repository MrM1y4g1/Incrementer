extends TestCase


func test_carry_formula() -> void:
	check_eq(Formulas.carry_for_peak(Formulas.OVERFLOW_THRESHOLD * 0.5), 0.0, "nothing below a full 64-bit register")
	check_eq(Formulas.carry_for_peak(Formulas.OVERFLOW_THRESHOLD), 2.0)
	check_eq(Formulas.carry_for_peak(pow(2.0, 80)), 4.0)
	check_eq(Formulas.carry_for_peak(pow(2.0, 128)), 32.0)
	check_eq(Formulas.carry_for_peak(Formulas.MAX_FLOAT), pow(2.0, 61))


func test_overflow_needs_a_full_64_bit_register() -> void:
	var content := Fixtures.content()
	var s := GameState.new()
	s.register_bits = 64
	s.count = Formulas.register_cap(32)
	check(not Economy.can_overflow(s), "not yet")
	check_eq(Economy.overflow(s, content), 0.0)
	Economy.add_count(s, Formulas.register_cap(64))
	check(Economy.can_overflow(s), "a full 64-bit register allows an Overflow")


func test_overflow_resets_the_run_and_keeps_the_rest() -> void:
	var content := Fixtures.content()
	var s := GameState.new()
	s.register_bits = 64
	s.clock_level = 3
	s.layer_amount[0] = 50.0
	s.layer_bought[0] = 12
	s.upgrades.append(&"some_upgrade")
	s.achievements.append(&"some_achievement")
	s.total_clicks = 99
	s.run_time = 3000.0
	Economy.add_count(s, Formulas.register_cap(64))

	check_eq(Economy.overflow(s, content), 2.0)
	check_eq(s.count, 0.0)
	check_eq(s.run_peak, 0.0)
	check_eq(s.run_time, 0.0)
	check_eq(s.register_bits, 8)
	check_eq(s.clock_level, 0)
	check_eq(s.layer_amount[0], 0.0)
	check_eq(s.layer_bought[0], 0)
	check_eq(s.upgrades.size(), 0)
	check_eq(s.achievements.size(), 1, "achievements stay")
	check_eq(s.total_clicks, 99, "stats stay")
	check_eq(s.carry, 2.0)
	check_eq(s.overflows, 1)
	check_eq(s.runs.size(), 1)
	check_near(float(s.runs[0]["bits"]), 64.0, 1e-9)
	check_eq(float(s.runs[0]["time"]), 3000.0)


func test_run_history_is_capped() -> void:
	var content := Fixtures.content()
	var s := GameState.new()
	for _run: int in GameState.RUN_HISTORY_LIMIT + 5:
		s.register_bits = 64
		Economy.add_count(s, Formulas.register_cap(64))
		Economy.overflow(s, content)
	check_eq(s.runs.size(), GameState.RUN_HISTORY_LIMIT)
	check_eq(s.overflows, GameState.RUN_HISTORY_LIMIT + 5)


func test_ending_happens_once_at_a_full_1024_bit_register() -> void:
	var s := GameState.new()
	s.register_bits = 512
	s.count = Formulas.register_cap(512)
	check(not Economy.check_ending(s), "512 bits is not the end")
	s.register_bits = 1024
	s.count = Formulas.register_cap(1024)
	s.play_time = 23400.0
	check(Economy.check_ending(s), "a full 1024-bit register ends V1")
	check(s.ended, "the state remembers it")
	check_eq(s.ended_time, 23400.0)
	check(not Economy.check_ending(s), "it only happens once")


func test_carry_bonus_boosts_count_per_second_and_stays_finite() -> void:
	check_eq(Formulas.carry_bonus(0.0), 1.0)
	check_near(Formulas.carry_bonus(1.0), pow(2.0, Formulas.CARRY_BONUS_POWER), 1e-12)
	check(is_finite(Formulas.carry_bonus(1e300)), "a huge Carry total must not give an infinite bonus")
	var content := Fixtures.content()
	var s := GameState.new()
	s.total_carry = 1.0
	s.run_time = Formulas.CARRY_RIPPLE_SECONDS
	check_near(Economy.layer_rate(s, content, 0), pow(2.0, Formulas.CARRY_BONUS_POWER), 1e-12)
	check_near(Economy.layer_rate(s, content, 1), 1.0, 1e-12)


func test_the_carry_bonus_ripples_in_over_a_run() -> void:
	var full := Formulas.carry_bonus(2.0)
	check_eq(Formulas.carry_bonus_at(2.0, 0.0), 1.0)
	check_near(Formulas.carry_bonus_at(2.0, Formulas.CARRY_RIPPLE_SECONDS / 2.0), sqrt(full), 1e-6)
	check_near(Formulas.carry_bonus_at(2.0, Formulas.CARRY_RIPPLE_SECONDS), full, 1e-3)
	check_near(Formulas.carry_bonus_at(2.0, 10.0 * Formulas.CARRY_RIPPLE_SECONDS), full, 1e-3)
	check(is_finite(Formulas.carry_bonus_at(1e300, 1e9)), "a huge bonus stays finite")
	# Right after an Overflow the first Incrementer makes what it did in the first run.
	var content := Fixtures.content()
	var s := GameState.new()
	s.total_carry = 2.0
	check_near(Economy.layer_rate(s, content, 0), 1.0, 1e-12)
	Economy.add_time(s, Formulas.CARRY_RIPPLE_SECONDS)
	check_near(Economy.layer_rate(s, content, 0), full, 1e-3)


func test_the_ripple_goes_on_while_away() -> void:
	var content := Fixtures.content()
	var s := GameState.new()
	s.total_carry = 2.0
	s.play_time = 100.0
	Economy.catch_up(s, content, 2.0 * Formulas.CARRY_RIPPLE_SECONDS)
	check_eq(s.run_time, 2.0 * Formulas.CARRY_RIPPLE_SECONDS)
	check_eq(s.play_time, 100.0, "time away isn't play time")
	check_near(Economy.carry_bonus_now(s), Formulas.carry_bonus(2.0), 1e-3)


func test_huge_multipliers_never_produce_nan() -> void:
	var content := Fixtures.content()
	var s := GameState.new()
	s.register_bits = 1024
	s.total_carry = 1e300
	s.run_time = Formulas.CARRY_RIPPLE_SECONDS
	s.layer_amount[7] = 1e300
	for _step: int in 20:
		Economy.advance(s, content, 1.0)
	check(not is_nan(s.count) and is_finite(s.count), "the Count stays a real number")
	for i: int in GameState.LAYER_COUNT:
		check(not is_nan(s.layer_amount[i]), "layer %d stays a real number" % (i + 1))


func test_rates_stay_finite_at_the_end() -> void:
	var content := Fixtures.content()
	var s := GameState.new()
	s.register_bits = 1024
	s.total_carry = 1e300
	s.run_time = Formulas.CARRY_RIPPLE_SECONDS
	s.layer_amount[0] = Formulas.MAX_FLOAT
	check(is_finite(Economy.count_per_second(s, content)), "Count per second stays finite")
	check(is_finite(Economy.click_value(s, content)), "a click stays finite")
