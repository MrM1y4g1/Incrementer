class_name UpgradeDef
extends Resource
## A one-time purchase that changes a multiplier. It appears once its requirements are met.

enum Effect {
	## Multiplies one layer's output by `value`.
	LAYER_MULTIPLIER,
	## Multiplies the Count per second by `value`.
	ALL_MULTIPLIER,
	## Multiplies the Count each click adds by `value`.
	CLICK_MULTIPLIER,
	## Each click also adds `value` × Count per second (0.05 means 5%).
	CLICK_FROM_RATE,
}

@export var id: StringName = &""
@export var display_name: String = ""
@export var effect: Effect = Effect.LAYER_MULTIPLIER
## The layer LAYER_MULTIPLIER affects, 1 to 8.
@export_range(0, 8) var layer_tier: int = 0
@export var value: float = 2.0
@export var cost: float = 100.0

@export_group("Requirements")
## Register width needed before the upgrade appears.
@export var requires_bits: int = 8
## Layer (1 to 8) whose units bought must reach `requires_bought`. 0 means no layer requirement.
@export_range(0, 8) var requires_tier: int = 0
@export var requires_bought: int = 0
