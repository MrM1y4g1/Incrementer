extends TestCase


func test_next_cost_grows_geometrically() -> void:
	check_near(Formulas.next_cost(10.0, 1.15, 0), 10.0, 1e-12)
	check_near(Formulas.next_cost(10.0, 1.15, 2), 13.225, 1e-12)


func test_cost_of_matches_the_sum_of_single_costs() -> void:
	var total := 0.0
	for i: int in 10:
		total += Formulas.next_cost(100.0, 1.14, 5 + i)
	check_near(Formulas.cost_of(100.0, 1.14, 5, 10), total, 1e-12)
	check_eq(Formulas.cost_of(100.0, 1.14, 5, 0), 0.0)


func test_max_affordable_with_exactly_enough() -> void:
	var budget := Formulas.cost_of(10.0, 1.13, 3, 7)
	check_eq(Formulas.max_affordable(10.0, 1.13, 3, budget), 7)
	check_eq(Formulas.max_affordable(10.0, 1.13, 3, budget * 0.9999), 6)


func test_max_affordable_when_short() -> void:
	check_eq(Formulas.max_affordable(10.0, 1.13, 0, 9.99), 0)


func test_max_affordable_with_a_huge_budget() -> void:
	var n := Formulas.max_affordable(10.0, 1.13, 0, 1e300)
	check(n > 5000, "expected thousands of units, got %d" % n)
	check(Formulas.cost_of(10.0, 1.13, 0, n) <= 1e300, "must not overspend")


func test_register_caps() -> void:
	check_eq(Formulas.register_cap(8), 255.0)
	check_eq(Formulas.register_cap(16), 65535.0)
	check_eq(Formulas.register_cap(32), 4294967295.0)
	check(is_finite(Formulas.register_cap(1024)), "the 1024-bit cap must stay finite")
	check(Formulas.register_cap(1024) > 1.79e308, "the 1024-bit cap must sit at the float limit")


func test_widen_cost_is_three_quarters_of_a_full_register() -> void:
	check_eq(Formulas.widen_cost(8), 192.0)
	check_eq(Formulas.widen_cost(16), 49152.0)


func test_next_width() -> void:
	check_eq(Formulas.next_width(8), 16)
	check_eq(Formulas.next_width(512), 1024)
	check_eq(Formulas.next_width(1024), -1)
	check_eq(Formulas.next_width(12), -1)


func test_milestone_bonus_doubles_every_step() -> void:
	var step := Formulas.MILESTONE_EVERY
	check_eq(Formulas.milestone_multiplier(0), 1.0)
	check_eq(Formulas.milestone_multiplier(step - 1), 1.0)
	check_eq(Formulas.milestone_multiplier(step), 2.0)
	check_eq(Formulas.milestone_multiplier(step * 2 + 1), 4.0)
