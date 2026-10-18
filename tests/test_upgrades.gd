extends TestCase


func _content_with(upgrades: Array[UpgradeDef]) -> Content:
	var content := Fixtures.content()
	content.upgrades = upgrades
	content.index()
	return content


func test_layer_upgrade_doubles_that_layer() -> void:
	var up := Fixtures.upgrade(&"fast", UpgradeDef.Effect.LAYER_MULTIPLIER, 2.0, 50.0, 1)
	var content := _content_with([up])
	var s := GameState.new()
	s.count = 50.0
	s.layer_amount[0] = 1.0
	check(Economy.buy_upgrade(s, up), "affordable upgrade should be bought")
	check_eq(s.count, 0.0)
	Economy.advance(s, content, 1.0)
	check_near(s.count, 2.0, 1e-12)


func test_global_multipliers_apply_to_count_per_second_only() -> void:
	var up := Fixtures.upgrade(&"bus", UpgradeDef.Effect.ALL_MULTIPLIER, 1.5, 1.0)
	var content := _content_with([up])
	var s := GameState.new()
	s.count = 1.0
	Economy.buy_upgrade(s, up)
	check_near(Economy.layer_rate(s, content, 0), 1.5, 1e-12)
	check_near(Economy.layer_rate(s, content, 7), 1.0, 1e-12, "higher layers would compound the bonus")


func test_click_upgrades() -> void:
	var press := Fixtures.upgrade(&"press", UpgradeDef.Effect.CLICK_MULTIPLIER, 3.0, 1.0)
	var macro := Fixtures.upgrade(&"macro", UpgradeDef.Effect.CLICK_FROM_RATE, 0.1, 1.0)
	var content := _content_with([press, macro])
	var s := GameState.new()
	s.register_bits = 16
	s.count = 2.0
	Economy.buy_upgrade(s, press)
	Economy.buy_upgrade(s, macro)
	s.layer_amount[0] = 100.0
	# 3 from the multiplier, plus 10% of 100 per second.
	check_near(Economy.click_value(s, content), 13.0, 1e-12)


func test_an_upgrade_can_only_be_bought_once() -> void:
	var up := Fixtures.upgrade(&"once", UpgradeDef.Effect.ALL_MULTIPLIER, 2.0, 10.0)
	var s := GameState.new()
	s.count = 100.0
	check(Economy.buy_upgrade(s, up), "first purchase")
	check(not Economy.buy_upgrade(s, up), "second purchase must fail")
	check_eq(s.count, 90.0)


func test_requirements_hide_upgrades() -> void:
	var up := Fixtures.upgrade(&"later", UpgradeDef.Effect.LAYER_MULTIPLIER, 2.0, 10.0, 1)
	up.requires_bits = 16
	up.requires_tier = 1
	up.requires_bought = 10
	var s := GameState.new()
	check(not Economy.upgrade_visible(s, up), "hidden at 8-bit")
	s.register_bits = 16
	check(not Economy.upgrade_visible(s, up), "hidden until 10 are bought")
	s.layer_bought[0] = 10
	check(Economy.upgrade_visible(s, up), "visible once both requirements are met")


func test_unknown_upgrade_ids_in_a_save_are_ignored() -> void:
	var content := Fixtures.content()
	var s := GameState.new()
	s.upgrades.append(&"removed_in_a_later_version")
	check_near(Economy.layer_rate(s, content, 0), 1.0, 1e-12)
