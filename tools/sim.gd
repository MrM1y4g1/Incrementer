extends SceneTree
## Balance check: plays the real content with the AutoPlayer and prints when each milestone is reached,
## next to the pacing targets from plan section 3.
##   godot --headless --path . --script res://tools/sim.gd -- --no-save --minutes=60

const TARGETS := {
	"16-bit": 60.0,
	"32-bit": 360.0,
	"64-bit": 1200.0,
	"64-bit full (first Overflow)": 3000.0,
}


func _init() -> void:
	var minutes := 60.0
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--minutes="):
			minutes = arg.get_slice("=", 1).to_float()

	var layers := ContentLoader.load_layers("res://data/layers")
	var state := GameState.new()
	var bits := state.register_bits
	var owned := PackedByteArray()
	owned.resize(layers.size())
	var seconds := 0.0

	print("time      milestone                         target")
	while seconds < minutes * 60.0:
		AutoPlayer.play(state, layers, 1.0)
		seconds += 1.0
		for i: int in layers.size():
			if owned[i] == 0 and state.layer_bought[i] > 0:
				owned[i] = 1
				_report(seconds, "first %s" % layers[i].display_name)
		if state.register_bits != bits:
			bits = state.register_bits
			_report(seconds, "%d-bit" % bits)
		if bits == Economy.MAX_BITS_WITHOUT_FIRMWARE and Economy.is_full(state):
			_report(seconds, "64-bit full (first Overflow)")
			break

	print("\nfinal: %s Count, %s per second, bought %s" % [
		NumberFormat.amount(state.count),
		NumberFormat.rate(Economy.count_per_second(state, layers)),
		str(Array(state.layer_bought))])
	quit()


func _report(seconds: float, milestone: String) -> void:
	var target := ""
	if TARGETS.has(milestone):
		target = NumberFormat.duration(TARGETS[milestone])
	print("%-9s %-33s %s" % [NumberFormat.duration(seconds), milestone, target])
