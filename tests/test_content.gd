extends TestCase


func _real() -> Content:
	return Content.load_from("res://data")


func test_real_content_is_consistent() -> void:
	var errors := _real().validate()
	check(errors.is_empty(), "content problems: %s" % "; ".join(errors))


func test_real_content_has_everything_the_plan_lists() -> void:
	var content := _real()
	check_eq(content.layers.size(), GameState.LAYER_COUNT)
	check(content.upgrades.size() >= 40, "about 40 upgrades, found %d" % content.upgrades.size())
	check(content.achievements.size() >= 30, "about 30 achievements, found %d" % content.achievements.size())
	check(content.firmware.size() >= 20, "about 20 Firmware nodes, found %d" % content.firmware.size())


func test_every_register_width_has_a_wide_bus() -> void:
	var widths := {}
	for node: FirmwareDef in _real().firmware:
		if node.effect == FirmwareDef.Effect.WIDE_BUS:
			widths[int(node.value)] = true
	for bits: int in [128, 256, 512, 1024]:
		check(widths.has(bits), "no Wide bus for %d bits" % bits)


func test_layers_get_steadily_more_expensive() -> void:
	var layers := _real().layers
	for i: int in range(1, layers.size()):
		check(layers[i].base_cost > layers[i - 1].base_cost, "%s should cost more than the tier below" % layers[i].id)
		check(layers[i].unlock_bits >= layers[i - 1].unlock_bits, "%s should not unlock before the tier below" % layers[i].id)
		check(layers[i].plural_name != "", "%s needs a plural name" % layers[i].id)


func test_every_layer_is_affordable_when_it_unlocks() -> void:
	for layer: LayerDef in _real().layers:
		check(layer.base_cost <= Formulas.register_cap(layer.unlock_bits), "%s costs more than a %d-bit register holds" % [layer.id, layer.unlock_bits])


func test_upgrades_are_sorted_and_reachable() -> void:
	var upgrades := _real().upgrades
	for i: int in upgrades.size():
		check(Formulas.width_for(upgrades[i].cost) > 0, "%s costs more than any register holds" % upgrades[i].id)
		if i > 0:
			check(upgrades[i].cost >= upgrades[i - 1].cost, "upgrades are sorted by cost")


func test_validation_catches_mistakes() -> void:
	var content := Fixtures.content()
	content.upgrades = [Fixtures.upgrade(&"dup", UpgradeDef.Effect.ALL_MULTIPLIER, 2.0, 1.0), Fixtures.upgrade(&"dup", UpgradeDef.Effect.LAYER_MULTIPLIER, 2.0, 1.0, 9)]
	content.achievements = [Fixtures.achievement(&"", AchievementDef.Condition.CLICKS, 1.0)]
	content.index()
	check_eq(content.validate().size(), 4, "duplicate id, missing layer, missing id, missing name")


func test_equal_items_keep_a_fixed_order() -> void:
	var content := _real()
	for i: int in content.firmware.size() - 1:
		var a := content.firmware[i]
		var b := content.firmware[i + 1]
		if a.column == b.column and a.cost == b.cost:
			check(String(a.id) < String(b.id), "%s and %s tie, so they sort by id" % [a.id, b.id])
	for i: int in content.upgrades.size() - 1:
		var a := content.upgrades[i]
		var b := content.upgrades[i + 1]
		if a.cost == b.cost:
			check(String(a.id) < String(b.id), "%s and %s tie, so they sort by id" % [a.id, b.id])
