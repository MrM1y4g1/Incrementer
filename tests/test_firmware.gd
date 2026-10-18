extends TestCase


func _node(id: StringName, effect: FirmwareDef.Effect, value: float, cost: float, requires: PackedStringArray = PackedStringArray(), column: int = 0) -> FirmwareDef:
	var node := FirmwareDef.new()
	node.id = id
	node.display_name = String(id)
	node.effect = effect
	node.value = value
	node.cost = cost
	node.requires = requires
	node.column = column
	return node


func _content_with(nodes: Array[FirmwareDef]) -> Content:
	var content := Fixtures.content()
	content.firmware = nodes
	content.index()
	return content


func test_buying_needs_carry_and_prerequisites() -> void:
	var base := _node(&"base", FirmwareDef.Effect.COUNT_MULTIPLIER, 2.0, 1.0)
	var next := _node(&"next", FirmwareDef.Effect.COUNT_MULTIPLIER, 2.0, 5.0, PackedStringArray(["base"]), 1)
	var content := _content_with([base, next])
	var s := GameState.new()
	s.carry = 10.0
	check(not Economy.buy_firmware(s, content, next), "the prerequisite comes first")
	check(Economy.buy_firmware(s, content, base), "base is affordable")
	check(not Economy.buy_firmware(s, content, base), "owned nodes can't be bought twice")
	check(Economy.buy_firmware(s, content, next), "now the second node is available")
	check_eq(s.carry, 4.0)
	s.carry = 0.0
	check(not Economy.can_buy_firmware(s, _node(&"pricey", FirmwareDef.Effect.COUNT_MULTIPLIER, 2.0, 1.0)), "no Carry, no purchase")


func test_wide_bus_raises_the_register_limit() -> void:
	var bus := _node(&"bus", FirmwareDef.Effect.WIDE_BUS, 128.0, 1.0)
	var content := _content_with([bus])
	var s := GameState.new()
	s.register_bits = 64
	s.count = Formulas.register_cap(64)
	check(not Economy.can_widen(s, content), "64 bits is the limit without Firmware")
	s.carry = 1.0
	Economy.buy_firmware(s, content, bus)
	check(Economy.can_widen(s, content), "Wide bus allows 128 bits")
	check(Economy.widen(s, content), "widening works")
	check_eq(s.register_bits, 128)


func test_boot_rom_sets_the_starting_width() -> void:
	var boot := _node(&"boot", FirmwareDef.Effect.BOOT_WIDTH, 32.0, 1.0)
	var content := _content_with([boot])
	var s := GameState.new()
	s.carry = 1.0
	Economy.buy_firmware(s, content, boot)
	check_eq(s.register_bits, 32, "takes effect straight away")
	s.register_bits = 64
	Economy.add_count(s, Formulas.register_cap(64))
	Economy.overflow(s, content)
	check_eq(s.register_bits, 32, "and after every Overflow")


func test_count_multiplier_applies_to_count_per_second_only() -> void:
	var cores := _node(&"cores", FirmwareDef.Effect.COUNT_MULTIPLIER, 4.0, 1.0)
	var content := _content_with([cores])
	var s := GameState.new()
	s.carry = 1.0
	Economy.buy_firmware(s, content, cores)
	# No Carry has been earned in this test, so the Carry bonus is ×1.
	check_near(Economy.layer_rate(s, content, 0), 4.0, 1e-12)
	check_near(Economy.layer_rate(s, content, 1), 1.0, 1e-12)


func test_carry_multiplier() -> void:
	var lookahead := _node(&"lookahead", FirmwareDef.Effect.CARRY_MULTIPLIER, 2.0, 1.0)
	var content := _content_with([lookahead])
	var s := GameState.new()
	s.carry = 1.0
	Economy.buy_firmware(s, content, lookahead)
	s.register_bits = 64
	Economy.add_count(s, Formulas.register_cap(64))
	check_eq(Economy.overflow(s, content), 4.0)


func test_watchdog_extends_offline_progress() -> void:
	var watchdog := _node(&"watchdog", FirmwareDef.Effect.OFFLINE_HOURS, 24.0, 1.0)
	var content := _content_with([watchdog])
	var s := GameState.new()
	s.register_bits = 32
	s.layer_amount[0] = 1.0
	s.carry = 1.0
	Economy.buy_firmware(s, content, watchdog)
	Economy.catch_up(s, content, 30.0 * 3600.0)
	check_near(s.count, 24.0 * 3600.0, 1e-9)


func test_layer_autobuyer_spends_a_small_share_and_respects_its_switch() -> void:
	var scheduler := _node(&"scheduler", FirmwareDef.Effect.AUTOBUY_LOW, 1.0, 1.0)
	var content := _content_with([scheduler])
	var s := GameState.new()
	s.register_bits = 32
	s.count = 1e6
	Economy.run_autobuyers(s, content)
	check_eq(s.layer_bought[0], 0, "nothing without the Firmware")
	s.carry = 1.0
	Economy.buy_firmware(s, content, scheduler)
	s.autobuy["low"] = false
	Economy.run_autobuyers(s, content)
	check_eq(s.layer_bought[0], 0, "switched off")
	s.autobuy["low"] = true
	Economy.run_autobuyers(s, content)
	check(s.layer_bought[0] > 0, "switched on, it buys")
	check(s.count >= 1e6 * (1.0 - Economy.AUTOBUY_SPEND_SHARE * 4.0) - 1.0, "it only spends a small share per layer")


func test_auto_widen() -> void:
	var controller := _node(&"controller", FirmwareDef.Effect.AUTO_WIDEN, 1.0, 1.0)
	var content := _content_with([controller])
	var s := GameState.new()
	s.carry = 1.0
	Economy.buy_firmware(s, content, controller)
	s.count = 255.0
	Economy.run_autobuyers(s, content)
	check_eq(s.register_bits, 16)
