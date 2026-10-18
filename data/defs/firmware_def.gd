class_name FirmwareDef
extends Resource
## A permanent upgrade bought with Carry. Firmware survives every Overflow.

enum Effect {
	## Allows registers up to `value` bits.
	WIDE_BUS,
	## Every run starts with a `value`-bit register.
	BOOT_WIDTH,
	## Count per second ×value.
	COUNT_MULTIPLIER,
	## One layer's output ×value.
	LAYER_MULTIPLIER,
	## Carry earned by an Overflow ×value.
	CARRY_MULTIPLIER,
	## Unused since 1.1.0, when the game stopped running while closed. Kept so the effects after it keep
	## their numbers in the .tres files; Content.validate rejects it.
	RETIRED_OFFLINE_HOURS,
	## Buys layers 1 to 4 automatically.
	AUTOBUY_LOW,
	## Buys layers 5 to 8 automatically.
	AUTOBUY_HIGH,
	## Overclocks automatically.
	AUTO_CLOCK,
	## Widens the register automatically.
	AUTO_WIDEN,
	## The ×2 output milestone comes every `value` units bought instead of every 40.
	MILESTONE_STEP,
}

@export var id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
@export var effect: Effect = Effect.COUNT_MULTIPLIER
@export var value: float = 1.0
## The layer LAYER_MULTIPLIER affects, 1 to 8.
@export_range(0, 8) var layer_tier: int = 0
## Price in Carry.
@export var cost: float = 1.0
## Ids of the nodes that must be owned first.
@export var requires: PackedStringArray = PackedStringArray()
## Column in the Firmware screen, 0 = leftmost.
@export_range(0, 6) var column: int = 0
