class_name ContentLoader
extends RefCounted
## Loads content definitions from `res://data`. Works headless and in exported builds,
## where resource files are listed with a `.remap` suffix.


static func load_layers(dir_path: String) -> Array[LayerDef]:
	var result: Array[LayerDef] = []
	for file: String in DirAccess.get_files_at(dir_path):
		var file_name := file.trim_suffix(".remap")
		if not (file_name.ends_with(".tres") or file_name.ends_with(".res")):
			continue
		var res := load(dir_path.path_join(file_name))
		if res is LayerDef:
			result.append(res as LayerDef)
		else:
			push_error("%s is not a LayerDef" % file_name)
	result.sort_custom(func(a: LayerDef, b: LayerDef) -> bool: return a.tier < b.tier)

	var seen := {}
	for i: int in result.size():
		var layer := result[i]
		if layer.tier != i + 1:
			push_error("Layer tiers must run 1 to %d without gaps; found tier %d at position %d" % [result.size(), layer.tier, i + 1])
		if seen.has(layer.id):
			push_error("Duplicate layer id: %s" % layer.id)
		seen[layer.id] = true
	return result
