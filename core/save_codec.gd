class_name SaveCodec
extends RefCounted
## Turns a GameState into save text and back. Each change to the save format bumps VERSION
## and adds one migration step, so old saves keep loading.
##
## Version history:
##   1  M1: Count, register, layers, clicks, play time
##   2  M2: adds clock level, upgrades, achievements and total Count produced
##   3  M3: adds the run fields, Carry, Firmware, Overflows, run history, autobuyer switches and the ending
##   4  1.1.0: adds the run log (events)
##   5  1.2.0: adds bad bits (run seed, bad bits, blocked time, the switch and the counts)
##   6  1.4.0: adds worn bits (wearing, wear due, wear started, refreshed count, Count lost) and the tutorial

const VERSION := 6


static func encode(state: GameState, saved_at: float) -> String:
	var payload := {"version": VERSION, "saved_at": saved_at, "state": state.to_dict()}
	# Full precision keeps large counts exact across a save and load.
	return JSON.stringify(payload, "\t", true, true)


## Returns {"state": GameState, "saved_at": float}, or an empty Dictionary when the text is not a usable save.
static func decode(text: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {}
	var payload: Dictionary = json.data
	var version := int(payload.get("version", 0))
	if version < 1 or version > VERSION:
		return {}
	payload = migrate(payload, version)
	var state_data: Variant = payload.get("state")
	if typeof(state_data) != TYPE_DICTIONARY:
		return {}
	return {"state": GameState.from_dict(state_data), "saved_at": float(payload.get("saved_at", 0.0))}


## The save format version of some save text, or 0 if it isn't a save.
static func version_of(text: String) -> int:
	var json := JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return 0
	var payload: Dictionary = json.data
	return int(payload.get("version", 0))


## Upgrades a saved payload one version at a time until it matches VERSION.
static func migrate(payload: Dictionary, from_version: int) -> Dictionary:
	var version := from_version
	while version < VERSION:
		if version == 1:
			payload = _v1_to_v2(payload)
		elif version == 2:
			payload = _v2_to_v3(payload)
		elif version == 3:
			payload = _v3_to_v4(payload)
		elif version == 4:
			payload = _v4_to_v5(payload)
		elif version == 5:
			payload = _v5_to_v6(payload)
		version += 1
	payload["version"] = VERSION
	return payload


static func _v1_to_v2(payload: Dictionary) -> Dictionary:
	var state_data: Variant = payload.get("state")
	if typeof(state_data) != TYPE_DICTIONARY:
		return payload
	var state: Dictionary = state_data
	state["clock_level"] = 0
	state["upgrades"] = []
	state["achievements"] = []
	# Version 1 didn't track lifetime production; the peak Count is the best lower bound.
	state["total_produced"] = state.get("peak_count", 0.0)
	payload["state"] = state
	return payload


static func _v2_to_v3(payload: Dictionary) -> Dictionary:
	var state_data: Variant = payload.get("state")
	if typeof(state_data) != TYPE_DICTIONARY:
		return payload
	var state: Dictionary = state_data
	# Before version 3 there was no Overflow, so the whole save was one run.
	state["run_peak"] = state.get("peak_count", 0.0)
	state["run_time"] = state.get("play_time", 0.0)
	state["carry"] = 0.0
	state["total_carry"] = 0.0
	state["overflows"] = 0
	state["firmware"] = []
	state["runs"] = []
	state["ended"] = false
	payload["state"] = state
	return payload


static func _v3_to_v4(payload: Dictionary) -> Dictionary:
	var state_data: Variant = payload.get("state")
	if typeof(state_data) != TYPE_DICTIONARY:
		return payload
	var state: Dictionary = state_data
	# Nothing was logged before version 4, so the log starts empty.
	state["events"] = []
	payload["state"] = state
	return payload


static func _v4_to_v5(payload: Dictionary) -> Dictionary:
	var state_data: Variant = payload.get("state")
	if typeof(state_data) != TYPE_DICTIONARY:
		return payload
	var state: Dictionary = state_data
	# Bad bits are new: the current run has none, and they're on from the next widening.
	state["run_seed"] = 0
	state["bad_bits"] = []
	state["blocked_time"] = 0.0
	state["faults_on"] = true
	state["faults_repaired"] = 0
	state["faults_scrubbed"] = 0
	state["faults_waited"] = 0
	payload["state"] = state
	return payload


static func _v5_to_v6(payload: Dictionary) -> Dictionary:
	var state_data: Variant = payload.get("state")
	if typeof(state_data) != TYPE_DICTIONARY:
		return payload
	var state: Dictionary = state_data
	# Nothing is wearing yet; the first worn bit is scheduled once the game runs.
	state["wearing"] = []
	state["wear_due"] = -1.0
	state["wear_started"] = 0
	state["faults_refreshed"] = 0
	state["count_lost"] = 0.0
	# Someone who has already played knows how to count, buy and upgrade. Worn bits are new to everyone,
	# so their tutorial steps still show.
	var played := int(state.get("total_clicks", 0)) > 0 or float(state.get("total_produced", 0.0)) > 0.0 or int(state.get("overflows", 0)) > 0
	state["tutorial"] = Tutorial.BASICS.duplicate() if played else []
	payload["state"] = state
	return payload
