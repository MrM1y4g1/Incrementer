class_name LayerDef
extends Resource
## One Software layer. Layer 1 adds to the Count; every other layer adds to the layer below it.

@export var id: StringName = &""
@export var display_name: String = ""
## Used in text such as "+12 Loops/s".
@export var plural_name: String = ""
## 1 = Incrementer up to 8 = Hypervisor. Tier n is drawn as a polygon with n + 2 sides.
@export_range(1, 8) var tier: int = 1
@export var base_cost: float = 10.0
## Price multiplier applied for every unit bought.
@export var cost_growth: float = 1.15
## Units of the layer below (or Count, for tier 1) that each owned unit makes per second.
@export var base_rate: float = 1.0
## Register width needed before this layer can be bought.
@export var unlock_bits: int = 8
