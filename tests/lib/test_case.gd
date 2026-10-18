class_name TestCase
extends RefCounted
## Base class for tests. Methods named `test_*` run in order; failed checks are collected, not thrown.

var failures := PackedStringArray()
var current_test := ""


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append("%s: %s" % [current_test, message])


func check_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		failures.append("%s: expected %s, got %s %s" % [current_test, var_to_str(expected), var_to_str(actual), message])


## Passes when `actual` is within `tolerance` of `expected`, relative to the size of `expected` (minimum 1).
func check_near(actual: float, expected: float, tolerance: float, message: String = "") -> void:
	var allowed := tolerance * maxf(1.0, absf(expected))
	if absf(actual - expected) > allowed:
		failures.append("%s: expected %s ± %s, got %s %s" % [current_test, expected, allowed, actual, message])
