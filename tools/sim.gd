extends SceneTree
## Balance check: plays the real content with the AutoPlayer and prints when each milestone is reached,
## next to the pacing targets from plan section 3.
##   godot --headless --path . --script res://tools/sim.gd -- --no-save --minutes=90
##   godot --headless --path . --script res://tools/sim.gd -- --no-save --until=ending --minutes=900
## --until=overflow (the default) stops at the first full 64-bit register; --until=ending plays on
## through Overflows and Firmware to the V1 ending. --log=<csv path> writes the run log, to compare with
## a player's (Save data → Copy run log).

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

## Players who Overflow sooner than the AutoPlayer, on top of its own rule. In 1.0.2 the AutoPlayer took
## 6 h 23 min to the ending, but a player who Overflowed whenever a run slowed down finished in under 2 hours.
## They solve every bad bit's puzzle at once. With --until=ending --check, none of these may reach the ending
## in under 5 hours.
##   ripple:<f>  once the run is f ripples old, if the Overflow would at least double the Carry earned
##   ratio:<r>   whenever the Overflow would pay at least r times the Carry earned
##   stall:<b>   once the peak grows less than b bits in a minute, if the Overflow would double the Carry
const FASTER_PLAYERS: Array[String] = ["ripple:0.5", "ripple:0.75", "ratio:16", "stall:1", "stall:3"]
## The fastest any player may reach the ending, and how long the faster players are followed.
const ENDING_FLOOR := 5.0 * 3600.0
const ENDING_CEILING := 8.0 * 3600.0


func _init() -> void:
	var minutes := 90.0
	var until := "overflow"
	var log_path := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--minutes="):
			minutes = arg.get_slice("=", 1).to_float()
		elif arg.begins_with("--until="):
			until = arg.get_slice("=", 1)
		elif arg.begins_with("--log="):
			log_path = arg.get_slice("=", 1)

	var content := Content.load_from("res://data")
	var state := GameState.new()
	var reached := {}
	var overflows := 0
	var seconds := 0.0
	# Longest stretch in the first hour with nothing bought, widened or overclocked.
	var last_purchase := 0.0
	var longest_wait := 0.0
	var signature := _purchases(state)
	# How long the second run takes to get back to a 64-bit register. Too quick means the Carry bonus
	# skips the early game, which is what playtesting 1.0.0 found.
	var overflow_at := 0.0
	var replay := -1.0

	print("time      milestone                                   target")
	while seconds < minutes * 60.0:
		AutoPlayer.play(state, content, 1.0)
		seconds += 1.0
		if seconds <= 3600.0:
			var now := _purchases(state)
			if now != signature:
				signature = now
				last_purchase = seconds
			longest_wait = maxf(longest_wait, seconds - last_purchase)
		for i: int in content.layers.size():
			_first(reached, seconds, "first %s" % content.layers[i].display_name, state.layer_bought[i] > 0)
		for bits: int in Formulas.REGISTER_WIDTHS:
			_first(reached, seconds, "%d-bit" % bits, state.register_bits >= bits)
		if state.register_bits >= 64 and Economy.is_full(state) and not reached.has("64-bit full (first Overflow)"):
			_first(reached, seconds, "64-bit full (first Overflow)", true)
			if until == "overflow":
				break
		if overflows == 1 and replay < 0.0 and state.overflows == 1 and state.register_bits >= 64:
			replay = seconds - overflow_at
		if state.overflows > overflows:
			overflows = state.overflows
			overflow_at = seconds
			# The AutoPlayer can fill the register and Overflow within the same simulated second.
			_first(reached, seconds, "64-bit full (first Overflow)", true)
			var run: Dictionary = state.runs[-1]
			_report(seconds, "Overflow %d: %.0f bits, +%s Carry, run %s" % [
				overflows, float(run["bits"]), NumberFormat.amount(float(run["carry"])), NumberFormat.duration(float(run["time"]))])
			if until == "overflow":
				break
		if state.ended:
			_first(reached, seconds, "V1 ending", true)
			break

	print("\nlongest wait for a purchase in the first hour: %ds (target 90s or less)" % int(longest_wait))
	if replay >= 0.0:
		print("second run back at 64 bits after %s (target 3 minutes or more)" % NumberFormat.duration(replay))
	print("final: %s Count at %d bits, %s per second, clock level %d" % [
		NumberFormat.amount(state.count), state.register_bits, NumberFormat.rate(Economy.count_per_second(state, content)), state.clock_level])
	print("bad bits cleared: %d repaired, %d scrubbed, %d waited out" % [state.faults_repaired, state.faults_scrubbed, state.faults_waited])
	print("upgrades %d of %d, achievements %d of %d, Firmware %d of %d, Carry %s (%s earned)" % [
		state.upgrades.size(), content.upgrades.size(), state.achievements.size(), content.achievements.size(),
		state.firmware.size(), content.firmware.size(), NumberFormat.amount(state.carry), NumberFormat.amount(state.total_carry)])

	if log_path != "":
		_write_log(state, log_path)

	# With --check, pacing outside the plan's windows fails the run, so CI catches balance regressions.
	var problems := PackedStringArray()
	var first_overflow := float(reached.get("64-bit full (first Overflow)", -1.0))
	if first_overflow < 40.0 * 60.0 or first_overflow > 60.0 * 60.0:
		problems.append("first Overflow at %s, outside 40–60 minutes" % NumberFormat.duration(first_overflow))
	if replay >= 0.0 and replay < 180.0:
		problems.append("the second run is back at 64 bits after %s, under 3 minutes" % NumberFormat.duration(replay))
	if longest_wait > 90.0:
		problems.append("a %ds wait for a purchase in the first hour, over 90s" % int(longest_wait))
	if until == "ending":
		var ending := float(reached.get("V1 ending", -1.0))
		if ending < ENDING_FLOOR or ending > ENDING_CEILING:
			problems.append("V1 ending at %s, outside 5–8 hours" % (NumberFormat.duration(ending) if ending > 0.0 else "never"))
		var patient := _ending_with(content, "none:0", AutoPlayer.Fix.WAIT)
		print("
a player who waits out every bad bit: %s (target 8 hours or less)" % (NumberFormat.duration(patient) if patient > 0.0 else "over %s" % NumberFormat.duration(ENDING_CEILING)))
		if patient < 0.0:
			problems.append("a player who waits out every bad bit takes over 8 hours")
		print("faster players (target 5 hours or more to the ending):")
		for rule: String in FASTER_PLAYERS:
			var seconds_to_end := _ending_with(content, rule)
			print("  %-12s %s" % [rule, NumberFormat.duration(seconds_to_end) if seconds_to_end > 0.0 else "over %s" % NumberFormat.duration(ENDING_CEILING)])
			if seconds_to_end > 0.0 and seconds_to_end < ENDING_FLOOR:
				problems.append("a player using %s reaches the ending at %s, under 5 hours" % [rule, NumberFormat.duration(seconds_to_end)])
	for problem: String in problems:
		printerr("PACING: " + problem)
	var check := OS.get_cmdline_user_args().has("--check")
	quit(1 if check and not problems.is_empty() else 0)


## Plays to the ending like the AutoPlayer, but also Overflows whenever the rule (see FASTER_PLAYERS) says so.
## Returns the seconds it took, or -1 if it takes longer than ENDING_CEILING.
func _ending_with(content: Content, rule: String, fix: AutoPlayer.Fix = AutoPlayer.Fix.SCRUB) -> float:
	var kind := rule.get_slice(":", 0)
	var value := rule.get_slice(":", 1).to_float()
	var state := GameState.new()
	var overflows := 0
	# The run's peak in bits, once a second.
	var peaks := PackedFloat64Array()
	var seconds := 0.0
	while seconds < ENDING_CEILING:
		AutoPlayer.play(state, content, 1.0, 0.25, 4.0, fix)
		seconds += 1.0
		if state.ended:
			return seconds
		if state.overflows != overflows:
			overflows = state.overflows
			peaks.clear()
		var bits := log(maxf(1.0, state.run_peak)) / log(2.0)
		peaks.append(bits)
		if state.overflows == 0 or not Economy.can_overflow(state):
			continue
		var gain := Economy.overflow_gain(state, content)
		var go := false
		match kind:
			"ripple":
				go = state.run_time >= value * Formulas.CARRY_RIPPLE_SECONDS and gain >= state.total_carry
			"ratio":
				go = gain >= value * state.total_carry
			"stall":
				go = peaks.size() > 60 and bits - peaks[peaks.size() - 61] < value and gain >= state.total_carry
		if go:
			Economy.overflow(state, content)
			AutoPlayer.buy_firmware(state, content)
	return -1.0

## Writes the run log as CSV. A relative path is relative to the project folder.
func _write_log(state: GameState, path: String) -> void:
	var full := path
	if full.is_relative_path():
		full = ProjectSettings.globalize_path("res://").path_join(full)
	var file := FileAccess.open(full, FileAccess.WRITE)
	if file == null:
		printerr("Could not write %s: %s" % [full, error_string(FileAccess.get_open_error())])
		return
	file.store_string(RunLog.to_csv(state))
	file.close()
	print("run log: %d events written to %s" % [state.events.size(), full])


## Changes whenever the player buys, widens, overclocks or buys an upgrade.
func _purchases(state: GameState) -> int:
	var total := state.upgrades.size() + state.clock_level + state.register_bits + state.firmware.size()
	for bought: int in state.layer_bought:
		total += bought
	return total


func _first(reached: Dictionary, seconds: float, milestone: String, condition: bool) -> void:
	if condition and not reached.has(milestone):
		reached[milestone] = seconds
		_report(seconds, milestone)


func _report(seconds: float, milestone: String) -> void:
	var target := ""
	if TARGETS.has(milestone):
		target = NumberFormat.duration(TARGETS[milestone])
	print("%-9s %-43s %s" % [NumberFormat.duration(seconds), milestone, target])
