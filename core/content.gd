class_name Content
extends RefCounted
## All game content loaded from res://data: layers, upgrades and achievements.
## Pass one Content around rather than separate arrays.

var layers: Array[LayerDef] = []
## Sorted by cost, cheapest first.
var upgrades: Array[UpgradeDef] = []
var achievements: Array[AchievementDef] = []
## Sorted by column, then cost.
var firmware: Array[FirmwareDef] = []
var upgrade_by_id := {}
var achievement_by_id := {}
var firmware_by_id := {}


## Loads every definition under `root` (layers/, upgrades/, achievements/).
static func load_from(root: String) -> Content:
	var content := Content.new()
	for res: Resource in _load_dir(root.path_join("layers")):
		if res is LayerDef:
			content.layers.append(res as LayerDef)
	for res: Resource in _load_dir(root.path_join("upgrades")):
		if res is UpgradeDef:
			content.upgrades.append(res as UpgradeDef)
	for res: Resource in _load_dir(root.path_join("achievements")):
		if res is AchievementDef:
			content.achievements.append(res as AchievementDef)
	for res: Resource in _load_dir(root.path_join("firmware")):
		if res is FirmwareDef:
			content.firmware.append(res as FirmwareDef)
	content.layers.sort_custom(func(a: LayerDef, b: LayerDef) -> bool: return a.tier < b.tier)
	content.upgrades.sort_custom(func(a: UpgradeDef, b: UpgradeDef) -> bool: return a.cost < b.cost)
	content.firmware.sort_custom(func(a: FirmwareDef, b: FirmwareDef) -> bool:
		return a.column < b.column or (a.column == b.column and a.cost < b.cost))
	content.index()
	return content


## Rebuilds the id lookups. Call after changing the arrays by hand (tests do this).
func index() -> void:
	upgrade_by_id.clear()
	for upgrade: UpgradeDef in upgrades:
		upgrade_by_id[upgrade.id] = upgrade
	achievement_by_id.clear()
	for achievement: AchievementDef in achievements:
		achievement_by_id[achievement.id] = achievement
	firmware_by_id.clear()
	for node: FirmwareDef in firmware:
		firmware_by_id[node.id] = node


## Returns every problem found. An empty list means the content is consistent.
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var seen := {}
	for i: int in layers.size():
		var layer := layers[i]
		if layer.tier != i + 1:
			errors.append("Layer tiers must run 1 to %d without gaps; found tier %d at position %d" % [layers.size(), layer.tier, i + 1])
		if layer.id == &"" or seen.has(layer.id):
			errors.append("Missing or duplicate layer id: '%s'" % layer.id)
		seen[layer.id] = true

	seen.clear()
	for upgrade: UpgradeDef in upgrades:
		if upgrade.id == &"" or seen.has(upgrade.id):
			errors.append("Missing or duplicate upgrade id: '%s'" % upgrade.id)
		seen[upgrade.id] = true
		if upgrade.effect == UpgradeDef.Effect.LAYER_MULTIPLIER and not _is_tier(upgrade.layer_tier):
			errors.append("Upgrade %s targets layer %d, which doesn't exist" % [upgrade.id, upgrade.layer_tier])
		if upgrade.requires_tier != 0 and not _is_tier(upgrade.requires_tier):
			errors.append("Upgrade %s requires layer %d, which doesn't exist" % [upgrade.id, upgrade.requires_tier])
		if upgrade.cost <= 0.0 or not is_finite(upgrade.cost):
			errors.append("Upgrade %s needs a positive, finite cost" % upgrade.id)
		if upgrade.value <= 0.0:
			errors.append("Upgrade %s needs a positive value" % upgrade.id)
		if not Formulas.REGISTER_WIDTHS.has(upgrade.requires_bits):
			errors.append("Upgrade %s requires %d bits, which isn't a register width" % [upgrade.id, upgrade.requires_bits])

	seen.clear()
	for achievement: AchievementDef in achievements:
		if achievement.id == &"" or seen.has(achievement.id):
			errors.append("Missing or duplicate achievement id: '%s'" % achievement.id)
		seen[achievement.id] = true
		if achievement.condition == AchievementDef.Condition.LAYER_BOUGHT and not _is_tier(achievement.layer_tier):
			errors.append("Achievement %s counts layer %d, which doesn't exist" % [achievement.id, achievement.layer_tier])
		if achievement.display_name == "" or achievement.description == "":
			errors.append("Achievement %s needs a name and a description" % achievement.id)

	seen.clear()
	for node: FirmwareDef in firmware:
		if node.id == &"" or seen.has(node.id):
			errors.append("Missing or duplicate Firmware id: '%s'" % node.id)
		seen[node.id] = true
		for requirement: String in node.requires:
			var required: FirmwareDef = firmware_by_id.get(StringName(requirement))
			if required == null:
				errors.append("Firmware %s requires '%s', which doesn't exist" % [node.id, requirement])
			elif required.column >= node.column:
				errors.append("Firmware %s must sit in a later column than its requirement %s" % [node.id, requirement])
		if node.cost <= 0.0 or not is_finite(node.cost):
			errors.append("Firmware %s needs a positive, finite cost" % node.id)
		var bits_effect := node.effect == FirmwareDef.Effect.WIDE_BUS or node.effect == FirmwareDef.Effect.BOOT_WIDTH
		if bits_effect and not Formulas.REGISTER_WIDTHS.has(int(node.value)):
			errors.append("Firmware %s sets %d bits, which isn't a register width" % [node.id, int(node.value)])
		if node.effect == FirmwareDef.Effect.LAYER_MULTIPLIER and not _is_tier(node.layer_tier):
			errors.append("Firmware %s targets layer %d, which doesn't exist" % [node.id, node.layer_tier])
		if node.effect == FirmwareDef.Effect.RETIRED_OFFLINE_HOURS:
			errors.append("Firmware %s uses the retired offline effect" % node.id)
	return errors


func _is_tier(tier: int) -> bool:
	return tier >= 1 and tier <= layers.size()


## Loads every resource in a folder. Exported builds list resources with a `.remap` suffix.
static func _load_dir(path: String) -> Array[Resource]:
	var result: Array[Resource] = []
	if not DirAccess.dir_exists_absolute(path):
		return result
	for file: String in DirAccess.get_files_at(path):
		var file_name := file.trim_suffix(".remap")
		if not (file_name.ends_with(".tres") or file_name.ends_with(".res")):
			continue
		var res := load(path.path_join(file_name))
		if res == null:
			push_error("Could not load %s" % path.path_join(file_name))
			continue
		result.append(res)
	return result
