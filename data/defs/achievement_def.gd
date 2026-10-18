class_name AchievementDef
extends Resource
## A goal that unlocks once and adds a small bonus to all output for the rest of the save.

enum Condition {
	PEAK_COUNT,
	REGISTER_BITS,
	REGISTER_FULL,
	LAYER_BOUGHT,
	CLICKS,
	UPGRADES,
	CLOCK_LEVEL,
	PLAY_TIME,
	OVERFLOWS,
	TOTAL_CARRY,
	ENDED,
	## Bad bits scrubbed with the parity puzzle.
	FAULTS_SCRUBBED,
	## Bad bits cleared in any way.
	FAULTS_CLEARED,
}

@export var id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
@export var condition: Condition = Condition.PEAK_COUNT
## The layer LAYER_BOUGHT counts, 1 to 8.
@export_range(0, 8) var layer_tier: int = 0
## The value the condition must reach: a Count, bits, units, clicks, upgrades, clock level or seconds.
@export var threshold: float = 0.0
