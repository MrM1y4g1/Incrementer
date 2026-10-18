extends SceneTree
## Balance check: plays the real content with the AutoPlayer and prints when each milestone is reached,
## next to the pacing targets from plan section 3.
##   godot --headless --path . --script res://tools/sim.gd -- --no-save --minutes=90
##   godot --headless --path . --script res://tools/sim.gd -- --no-save --until=ending --minutes=900
## --until=overflow (the default) stops at the first full 64-bit register; --until=ending plays on
## through Overflows and Firmware to the V1 ending.

## Targets in seconds of total play, from the plan.
const TARGETS := {
	"16-bit": 60.0,
	"32-bit": 360.0,
	"64-bit": 1200.0,
	"64-bit full (first Overflow)": 3000.0,
	"128-bit": 5400.0,
	"256-bit": 10800.0,
	"512-bit": 16200.0,
	"1024-bit": 21600.0,
	"V1 ending": 23400.0,
}


func _init() -> void:
	var minutes := 90.0
	var until := "overflow"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--minutes="):
			minutes = arg.get_slice("=", 1).to_float()
		elif arg.begins_with("--until="):
			until = arg.get_slice("=", 1)

	var content := Content.load_from("res://data")
	var state := GameState.new()
	var reached := {}
	var overflows := 0
	var seconds := 0.0

	print("time      milestone                                   target")
	while seconds < minutes * 60.0:
		AutoPlayer.play(state, content, 1.0)
		seconds += 1.0
		for i: int in content.layers.size():
			_first(reached, seconds, "first %s" % content.layers[i].display_name, state.layer_bought[i] > 0)
		for bits: int in Formulas.REGISTER_WIDTHS:
			_first(reached, seconds, "%d-bit" % bits, state.register_bits >= bits)
		if state.register_bits >= 64 and Economy.is_full(state) and not reached.has("64-bit full (first Overflow)"):
			_first(reached, seconds, "64-bit full (first Overflow)", true)
			if until == "overflow":
				break
		if state.overflows > overflows:
			overflows = state.overflows
			var run: Dictionary = state.runs[-1]
			_report(seconds, "Overflow %d: %.0f bits, +%s Carry, run %s" % [
				overflows, float(run["bits"]), NumberFormat.amount(float(run["carry"])), NumberFormat.duration(float(run["time"]))])
		if state.ended:
			_first(reached, seconds, "V1 ending", true)
			break

	print("\nfinal: %s Count at %d bits, %s per second, clock level %d" % [
		NumberFormat.amount(state.count), state.register_bits, NumberFormat.rate(Economy.count_per_second(state, content)), state.clock_level])
	print("upgrades %d of %d, achievements %d of %d, Firmware %d of %d, Carry %s (%s earned)" % [
		state.upgrades.size(), content.upgrades.size(), state.achievements.size(), content.achievements.size(),
		state.firmware.size(), content.firmware.size(), NumberFormat.amount(state.carry), NumberFormat.amount(state.total_carry)])
	quit()


func _first(reached: Dictionary, seconds: float, milestone: String, condition: bool) -> void:
	if condition and not reached.has(milestone):
		reached[milestone] = seconds
		_report(seconds, milestone)


func _report(seconds: float, milestone: String) -> void:
	var target := ""
	if TARGETS.has(milestone):
		target = NumberFormat.duration(TARGETS[milestone])
	print("%-9s %-43s %s" % [NumberFormat.duration(seconds), milestone, target])
