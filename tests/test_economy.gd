extends TestCase
## Uses its own simple layer numbers so balance changes in res://data don't break these tests.


func _layers() -> Array[LayerDef]:
	var unlocks: Array[int] = [8, 8, 16, 32, 32, 64, 64, 128]
	var result: Array[LayerDef] = []
	for i: int in 8:
		var layer := LayerDef.new()
		layer.id = StringName("layer_%d" % (i + 1))
		layer.display_name = "Layer %d" % (i + 1)
		layer.plural_name = "Layer %ds" % (i + 1)
		layer.tier = i + 1
		layer.base_cost = pow(10.0, i + 1)
		layer.cost_growth = 1.15
		layer.base_rate = 1.0
		layer.unlock_bits = unlocks[i]
		result.append(layer)
	return result


func test_click_adds_one() -> void:
	var s := GameState.new()
	Economy.click(s)
	check_eq(s.count, 1.0)
	check_eq(s.total_clicks, 1)


func test_count_stops_at_the_register_cap() -> void:
	var s := GameState.new()
	s.count = 250.0
	Economy.add_count(s, 100.0)
	check_eq(s.count, 255.0)
	check(Economy.is_full(s), "a capped register should report full")


func test_buy_one_spends_the_count() -> void:
	var layers := _layers()
	var s := GameState.new()
	s.count = 100.0
	check_eq(Economy.buy(s, layers, 0, Economy.BuyMode.ONE), 1)
	check_near(s.count, 90.0, 1e-12)
	check_eq(s.layer_bought[0], 1)
	check_eq(s.layer_amount[0], 1.0)


func test_buy_ten_needs_the_full_price() -> void:
	var layers := _layers()
	var s := GameState.new()
	s.register_bits = 16
	s.count = Formulas.cost_of(10.0, 1.15, 0, 10) - 0.01
	check_eq(Economy.buy(s, layers, 0, Economy.BuyMode.TEN), 0)
	s.count += 0.02
	check_eq(Economy.buy(s, layers, 0, Economy.BuyMode.TEN), 10)


func test_buy_max_buys_everything_affordable() -> void:
	var layers := _layers()
	var s := GameState.new()
	s.register_bits = 16
	s.count = Formulas.cost_of(10.0, 1.15, 0, 5)
	check_eq(Economy.buy(s, layers, 0, Economy.BuyMode.MAX), 5)
	check_near(s.count, 0.0, 1e-9)


func test_locked_layers_cannot_be_bought() -> void:
	var layers := _layers()
	var s := GameState.new()
	s.count = 1e6
	check_eq(Economy.buy(s, layers, 2, Economy.BuyMode.ONE), 0)


func test_layer_one_produces_count() -> void:
	var layers := _layers()
	var s := GameState.new()
	s.layer_amount[0] = 2.0
	Economy.advance(s, layers, 10.0)
	check_near(s.count, 20.0, 1e-12)


func test_layers_feed_the_layer_below() -> void:
	var layers := _layers()
	var s := GameState.new()
	s.layer_amount[1] = 1.0
	Economy.advance(s, layers, 5.0)
	check_near(s.layer_amount[0], 5.0, 1e-12)


func test_milestone_doubles_output() -> void:
	var layers := _layers()
	var s := GameState.new()
	s.layer_amount[0] = 10.0
	s.layer_bought[0] = Formulas.MILESTONE_EVERY
	Economy.advance(s, layers, 1.0)
	check_near(s.count, 20.0, 1e-12)


func test_widen_spends_the_count_and_doubles_the_width() -> void:
	var s := GameState.new()
	s.count = 255.0
	check(Economy.widen(s), "widen should succeed with a full 8-bit register")
	check_eq(s.register_bits, 16)
	check_near(s.count, 63.0, 1e-12)


func test_widening_past_64_bits_needs_firmware() -> void:
	var s := GameState.new()
	s.register_bits = 64
	s.count = Formulas.register_cap(64)
	check(not Economy.can_widen(s), "128-bit must wait for Firmware")


func test_offline_catch_up_matches_live_play() -> void:
	var layers := _layers()
	var offline := GameState.new()
	offline.register_bits = 64
	offline.layer_amount[1] = 1.0
	var live := GameState.new()
	live.register_bits = 64
	live.layer_amount[1] = 1.0
	Economy.catch_up(offline, layers, 3600.0)
	for _tick: int in 72000:
		Economy.advance(live, layers, 0.05)
	check_near(offline.count, live.count, 0.001, "one hour offline should match one hour live")


func test_offline_ignores_negative_time() -> void:
	var layers := _layers()
	var s := GameState.new()
	s.layer_amount[0] = 1.0
	check_eq(Economy.catch_up(s, layers, -50.0), 0.0)
	check_eq(s.count, 0.0)


func test_offline_is_capped_at_eight_hours() -> void:
	var layers := _layers()
	var s := GameState.new()
	s.register_bits = 32
	s.layer_amount[0] = 1.0
	Economy.catch_up(s, layers, 100.0 * 3600.0)
	check_near(s.count, 8.0 * 3600.0, 1e-9)
