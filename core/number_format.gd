class_name NumberFormat
extends RefCounted
## Turns big floats into short readable text: 1.23 K, 18.4 Qi, then 1.80e308 past the last suffix.

const SUFFIXES: PackedStringArray = ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]


## Amounts the player owns. Below 1,000 they show as whole numbers, rounded down.
static func amount(value: float) -> String:
	if is_nan(value):
		return "?"
	if is_inf(value):
		return "∞" if value > 0.0 else "-∞"
	if value < 0.0:
		return "-" + amount(-value)
	if value < 1000.0:
		return str(int(floor(value)))
	return _big(value)


## Rates per second. Small rates keep decimals so slow production still shows.
static func rate(value: float) -> String:
	if is_nan(value) or is_inf(value) or value >= 1000.0 or value < 0.0:
		return amount(value)
	if value < 10.0:
		return "%.2f" % value
	if value < 100.0:
		return "%.1f" % value
	return str(int(floor(value)))


## Short durations for the status bar: 42s, 2m 05s, 2h 14m.
static func duration(seconds: float) -> String:
	var total := int(maxf(0.0, seconds))
	var hours := floori(total / 3600.0)
	var minutes := floori((total % 3600) / 60.0)
	var secs := total % 60
	if hours > 0:
		return "%dh %02dm" % [hours, minutes]
	if minutes > 0:
		return "%dm %02ds" % [minutes, secs]
	return "%ds" % secs


static func _big(value: float) -> String:
	var group := floori(_exponent10(value) / 3.0)
	if group >= SUFFIXES.size():
		return _scientific(value)
	var text := _three_digits(value / pow(10.0, group * 3))
	if text == "1000":
		# 999.95 K rounds up to the next suffix.
		group += 1
		if group >= SUFFIXES.size():
			return _scientific(value)
		text = _three_digits(value / pow(10.0, group * 3))
	return "%s %s" % [text, SUFFIXES[group]]


static func _scientific(value: float) -> String:
	var exponent := _exponent10(value)
	var text := "%.2f" % (value / pow(10.0, exponent))
	if text.begins_with("10."):
		exponent += 1
		text = "%.2f" % (value / pow(10.0, exponent))
	return "%se%d" % [text, exponent]


## Three significant digits for a mantissa between 1 and 1000.
static func _three_digits(mantissa: float) -> String:
	if mantissa < 10.0:
		var two := "%.2f" % mantissa
		return two if not two.begins_with("10.") else "%.1f" % mantissa
	if mantissa < 100.0:
		var one := "%.1f" % mantissa
		return one if not one.begins_with("100.") else "%.0f" % mantissa
	return "%.0f" % mantissa


## floor(log10(value)), corrected for float error at exact powers of ten.
static func _exponent10(value: float) -> int:
	var exponent := floori(log(value) / log(10.0))
	if pow(10.0, exponent + 1) <= value:
		exponent += 1
	elif pow(10.0, exponent) > value:
		exponent -= 1
	return exponent
