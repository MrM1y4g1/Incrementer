class_name SaveCodec
extends RefCounted
## Turns a GameState into save text and back. Each change to the save format bumps VERSION
## and adds one migration step, so old saves keep loading.
##
## Version history:
##   1  M1: Count, register, layers, clicks, play time
##   2  M2: adds clock level, upgrades, achievements and total Count produced

const VERSION := 2


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


## Upgrades a saved payload one version at a time until it matches VERSION.
static func migrate(payload: Dictionary, from_version: int) -> Dictionary:
	var version := from_version
	while version < VERSION:
		if version == 1:
			payload = _v1_to_v2(payload)
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
