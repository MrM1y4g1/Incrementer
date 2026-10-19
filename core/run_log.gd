class_name RunLog
extends RefCounted
## The run log: what the player did and when, kept in the save as GameState.events so a playthrough can
## be studied afterwards. Nothing is sent anywhere. Save data → Copy run log gives the player a CSV they
## can choose to share.
##
## Each event is [play seconds, kind, detail]:
##   session      the game was opened; detail is the game version
##   start over   the player started a new game; detail is the game version
##   import       a save was imported; detail is the game version
##   layer        the first unit of a layer this run; detail is the layer id
##   upgrade      an upgrade; detail is its id
##   widen        the register widened; detail is the new width in bits
##   overflow     an Overflow; detail is {"bits": peak bits, "carry": Carry earned, "run_seconds": run time}
##   firmware     a Firmware node; detail is its id
##   achievement  an achievement; detail is its id
##   autobuy      an autobuyer switch; detail is "<switch> on" or "<switch> off"
##   setting      a switch that changes play; detail is "bad bits on" or "bad bits off"
##   refresh      a worn bit refreshed before it went bad; detail is {"bit": bit, "after": seconds worn}
##   bad bit      a worn bit went bad; detail is {"bit": bit, "lost": Count lost because the bit held a 1}
##   blocked      the lowest bad bit started holding the Count; detail is the bit
##   repair       a bad bit repaired with Count; detail is the bit
##   scrub        a bad bit scrubbed by solving its puzzle; detail is the bit
##   waited       a bad bit scrubbed itself; detail is the bit
##   tutorial     a tutorial step shown; detail is the step, or "skipped"
##   ending       the V1 ending
## Clock levels aren't logged: there are over a hundred a run, and they say little about pacing.

const CSV_HEADER := "play_seconds,play_time,event,detail"


## The whole log as CSV, oldest first. Details never contain commas: an Overflow's fields are written as
## key=value pairs separated by semicolons.
static func to_csv(state: GameState) -> String:
	var lines := PackedStringArray([CSV_HEADER])
	for event: Array in state.events:
		var seconds := float(event[0])
		lines.append("%.1f,%s,%s,%s" % [seconds, NumberFormat.duration(seconds), str(event[1]), _detail(event[2])])
	return "\n".join(lines) + "\n"


static func _detail(detail: Variant) -> String:
	if detail is Dictionary:
		var fields: Dictionary = detail
		var pairs := PackedStringArray()
		for key: Variant in fields:
			pairs.append("%s=%s" % [key, fields[key]])
		return ";".join(pairs)
	return str(detail).replace(",", ";")
