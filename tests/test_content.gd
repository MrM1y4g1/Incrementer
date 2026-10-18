extends TestCase


func test_layers_load_in_tier_order() -> void:
	var layers := ContentLoader.load_layers("res://data/layers")
	check_eq(layers.size(), GameState.LAYER_COUNT)
	var ids := {}
	for i: int in layers.size():
		var layer := layers[i]
		check_eq(layer.tier, i + 1)
		check(not ids.has(layer.id), "duplicate id %s" % layer.id)
		ids[layer.id] = true
		check(layer.plural_name != "", "%s needs a plural name" % layer.id)
		check(layer.cost_growth > 1.0, "%s must get more expensive" % layer.id)
		check(Formulas.REGISTER_WIDTHS.has(layer.unlock_bits), "%s unlocks at a real register width" % layer.id)
		if i > 0:
			check(layer.base_cost > layers[i - 1].base_cost, "%s should cost more than the tier below" % layer.id)
			check(layer.unlock_bits >= layers[i - 1].unlock_bits, "%s should not unlock before the tier below" % layer.id)


func test_every_layer_is_affordable_when_it_unlocks() -> void:
	for layer: LayerDef in ContentLoader.load_layers("res://data/layers"):
		check(layer.base_cost <= Formulas.register_cap(layer.unlock_bits), "%s costs more than a %d-bit register holds" % [layer.id, layer.unlock_bits])
