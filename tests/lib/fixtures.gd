class_name Fixtures
extends RefCounted
## Simple, stable content for tests, so balance changes in res://data don't break them.
## Layer n costs 10^n, grows ×1.15 per unit, makes 1 unit per second and unlocks at the widths below.

const UNLOCK_BITS: Array[int] = [8, 8, 16, 32, 32, 64, 64, 128]


static func content() -> Content:
	var result := Content.new()
	for i: int in 8:
		var layer := LayerDef.new()
		layer.id = StringName("layer_%d" % (i + 1))
		layer.display_name = "Layer %d" % (i + 1)
		layer.plural_name = "Layer %ds" % (i + 1)
		layer.tier = i + 1
		layer.base_cost = pow(10.0, i + 1)
		layer.cost_growth = 1.15
		layer.base_rate = 1.0
		layer.unlock_bits = UNLOCK_BITS[i]
		result.layers.append(layer)
	result.index()
	return result


static func upgrade(id: StringName, effect: UpgradeDef.Effect, value: float, cost: float, layer_tier: int = 0) -> UpgradeDef:
	var def := UpgradeDef.new()
	def.id = id
	def.display_name = String(id)
	def.effect = effect
	def.value = value
	def.cost = cost
	def.layer_tier = layer_tier
	return def


static func achievement(id: StringName, condition: AchievementDef.Condition, threshold: float, layer_tier: int = 0) -> AchievementDef:
	var def := AchievementDef.new()
	def.id = id
	def.display_name = String(id)
	def.description = "Test achievement"
	def.condition = condition
	def.threshold = threshold
	def.layer_tier = layer_tier
	return def
