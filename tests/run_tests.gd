extends SceneTree
## Runs every res://tests/test_*.gd file and exits with code 1 if anything fails.
##   godot --headless --path . --script res://tests/run_tests.gd -- --no-save

const TEST_DIR := "res://tests"


func _init() -> void:
	var total := 0
	var failed := 0
	var messages := PackedStringArray()

	for file: String in DirAccess.get_files_at(TEST_DIR):
		if not (file.begins_with("test_") and file.ends_with(".gd")):
			continue
		var script: GDScript = load(TEST_DIR.path_join(file))
		var instance: Variant = script.new()
		if not instance is TestCase:
			push_error("%s does not extend TestCase" % file)
			failed += 1
			continue
		var case: TestCase = instance
		for method: Dictionary in script.get_script_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			case.current_test = "%s::%s" % [file.get_basename(), method_name]
			var before := case.failures.size()
			case.call(method_name)
			total += 1
			if case.failures.size() > before:
				failed += 1
		messages.append_array(case.failures)

	for message: String in messages:
		printerr("FAIL  " + message)
	print("%d tests, %d passed, %d failed" % [total, total - failed, failed])
	quit(1 if failed > 0 else 0)
