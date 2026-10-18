extends TestCase


func test_small_amounts_are_whole_numbers() -> void:
	check_eq(NumberFormat.amount(0.0), "0")
	check_eq(NumberFormat.amount(7.9), "7")
	check_eq(NumberFormat.amount(999.95), "999")


func test_suffixes() -> void:
	check_eq(NumberFormat.amount(1234.0), "1.23 K")
	check_eq(NumberFormat.amount(65535.0), "65.5 K")
	check_eq(NumberFormat.amount(4294967295.0), "4.29 B")
	check_eq(NumberFormat.amount(1e15), "1.00 Qa")
	check_eq(NumberFormat.amount(1.8446744073709552e19), "18.4 Qi")
	check_eq(NumberFormat.amount(1e33), "1.00 Dc")


func test_rounding_rolls_over_to_the_next_suffix() -> void:
	check_eq(NumberFormat.amount(999950.0), "1.00 M")


func test_scientific_past_the_last_suffix() -> void:
	check_eq(NumberFormat.amount(1e36), "1.00e36")
	check_eq(NumberFormat.amount(3.402823669209385e38), "3.40e38")
	check_eq(NumberFormat.amount(1.7976931348623157e308), "1.80e308")


func test_special_values() -> void:
	check_eq(NumberFormat.amount(INF), "∞")
	check_eq(NumberFormat.amount(NAN), "?")
	check_eq(NumberFormat.amount(-1500.0), "-1.50 K")


func test_rates() -> void:
	check_eq(NumberFormat.rate(0.5), "0.50")
	check_eq(NumberFormat.rate(12.34), "12.3")
	check_eq(NumberFormat.rate(250.0), "250")
	check_eq(NumberFormat.rate(1500.0), "1.50 K")


func test_durations() -> void:
	check_eq(NumberFormat.duration(42.0), "42s")
	check_eq(NumberFormat.duration(125.0), "2m 05s")
	check_eq(NumberFormat.duration(8040.0), "2h 14m")
	check_eq(NumberFormat.duration(-5.0), "0s")
