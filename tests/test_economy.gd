extends TestCase


func test_click_adds_one() -> void:
	var content := Fixtures.content()
	var s := GameState.new()
	Economy.click(s, content)
	check_eq(s.count, 1.0)
	check_eq(s.total_clicks, 1)
	check_eq(s.total_produced, 1.0)


func test_count_stops_at_the_register_cap() -> void:
	var s := GameState.new()
	s.count = 250.0
	check_eq(Economy.add_count(s, 100.0), 5.0, "only what fits is added")
	check_eq(s.count, 255.0)
	check(Economy.is_full(s), "a capped register should report full")


func test_buy_one_spends_the_count() -> void:
	var content := Fixtures.content()
	var s := GameState.new()
	s.count = 100.0
	check_eq(Economy.buy(s, content, 0, Economy.BuyMode.ONE), 1)
	check_near(s.count, 90.0, 1e-12)
	check_eq(s.layer_bought[0], 1)
	check_eq(s.layer_amount[0], 1.0)


func test_buy_ten_needs_the_full_price() -> void:
	var content := Fixtures.content()
	var s := GameState.new()
	s.register_bits = 16
	s.count = Formulas.cost_of(10.0, 1.15, 0, 10) - 0.01
	check_eq(Economy.buy(s, content, 0, Economy.BuyMode.TEN), 0)
	s.count += 0.02
	check_eq(Economy.buy(s, content, 0, Economy.BuyMode.TEN), 10)


func test_buy_max_buys_everything_affordable() -> void:
	var content := Fixtures.content()
	var s := GameState.new()
	s.register_bits = 16
	s.count = Formulas.cost_of(10.0, 1.15, 0, 5)
	check_eq(Economy.buy(s, content, 0, Economy.BuyMode.MAX), 5)
	check_near(s.count, 0.0, 1e-9)


func test_locked_layers_cannot_be_bought() -> void:
	var content := Fixtures.content()
	var s := GameState.new()
	s.count = 1e6
	check_eq(Economy.buy(s, content, 2, Economy.BuyMode.ONE), 0)


func test_layer_one_produces_count() -> void:
	var content := Fixtures.content()
	var s := GameState.new()
	s.layer_amount[0] = 2.0
	Economy.advance(s, content, 10.0)
	check_near(s.count, 20.0, 1e-12)


func test_layers_feed_the_layer_below() -> void:
	var content := Fixtures.content()
	var s := GameState.new()
	s.layer_amount[1] = 1.0
	Economy.advance(s, content, 5.0)
	check_near(s.layer_amount[0], 5.0, 1e-12)


func test_milestone_doubles_output() -> void:
	var content := Fixtures.content()
	var s := GameState.new()
	s.layer_amount[0] = 10.0
	s.layer_bought[0] = Formulas.MILESTONE_EVERY
	Economy.advance(s, content, 1.0)
	check_near(s.count, 20.0, 1e-12)


func test_widen_spends_the_count_and_doubles_the_width() -> void:
	var s := GameState.new()
	s.count = 255.0
	check(Economy.widen(s, Fixtures.content()), "widen should succeed with a full 8-bit register")
	check_eq(s.register_bits, 16)
	check_near(s.count, 63.0, 1e-12)


func test_widening_past_64_bits_needs_firmware() -> void:
	var s := GameState.new()
	s.register_bits = 64
	s.count = Formulas.register_cap(64)
	check(not Economy.can_widen(s, Fixtures.content()), "128-bit must wait for Firmware")


func test_overclock_spends_and_speeds_everything_up() -> void:
	var content := Fixtures.content()
	var s := GameState.new()
	s.register_bits = 16
	s.count = Formulas.CLOCK_BASE_COST
	check(Economy.overclock(s), "overclock should succeed with exactly enough")
	check_eq(s.clock_level, 1)
	check_near(s.count, 0.0, 1e-12)
	check_near(Economy.clock_cost(s), Formulas.CLOCK_BASE_COST * Formulas.CLOCK_COST_GROWTH, 1e-12)
	s.layer_amount[0] = 1.0
	Economy.advance(s, content, 1.0)
	check_near(s.count, Formulas.CLOCK_STEP, 1e-12)


func test_offline_catch_up_matches_live_play() -> void:
	var content := Fixtures.content()
	var offline := GameState.new()
	offline.register_bits = 64
	offline.layer_amount[1] = 1.0
	var live := GameState.new()
	live.register_bits = 64
	live.layer_amount[1] = 1.0
	Economy.catch_up(offline, content, 3600.0)
	for _tick: int in 72000:
		Economy.advance(live, content, 0.05)
	check_near(offline.count, live.count, 0.001, "one hour offline should match one hour live")


func test_offline_eight_hours() -> void:
	var content := Fixtures.content()
	var s := GameState.new()
	s.register_bits = 32
	s.layer_amount[0] = 1.0
	check_near(Economy.catch_up(s, content, 8.0 * 3600.0), 8.0 * 3600.0, 1e-9)


func test_offline_thirty_hours_is_capped_at_eight() -> void:
	var content := Fixtures.content()
	var s := GameState.new()
	s.register_bits = 32
	s.layer_amount[0] = 1.0
	Economy.catch_up(s, content, 30.0 * 3600.0)
	check_near(s.count, 8.0 * 3600.0, 1e-9)


func test_offline_ignores_a_clock_set_backwards() -> void:
	var content := Fixtures.content()
	var s := GameState.new()
	s.layer_amount[0] = 1.0
	check_eq(Economy.catch_up(s, content, -50.0), 0.0)
	check_eq(s.count, 0.0)
