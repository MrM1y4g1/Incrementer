extends TestCase
## Every character the UI shows must exist in the fonts that draw it. A missing glyph falls back to a
## system font on Windows and shows as an empty box in the browser, which has no fonts to fall back to.
## That happened to the arrows on the Widen and Overclock buttons until 1.3.1.

## Barlow draws labels and buttons, Oxanium the big readouts, IBM Plex Mono the numbers in lists.
const BODY_FONTS: Array[String] = [
	"res://assets/fonts/BarlowSemiCondensed-Medium.ttf",
	"res://assets/fonts/BarlowSemiCondensed-SemiBold.ttf",
	"res://assets/fonts/Oxanium-Variable.ttf",
]
const MONO_FONT := "res://assets/fonts/IBMPlexMono-Regular.ttf"
## Characters only the mono font has. They may appear only in text drawn with Fonts.mono().
const MONO_ONLY := "→"


## Every non-ASCII character inside string literals in the UI scripts and the content files.
func _ui_characters() -> String:
	var found := {}
	var files: Array[String] = []
	for dir: String in ["res://ui", "res://autoload"]:
		for file: String in DirAccess.get_files_at(dir):
			if file.ends_with(".gd"):
				files.append(dir.path_join(file))
	files.append("res://core/number_format.gd")
	for dir: String in DirAccess.get_directories_at("res://data"):
		for file: String in DirAccess.get_files_at("res://data".path_join(dir)):
			if file.ends_with(".tres"):
				files.append("res://data".path_join(dir).path_join(file))
	var quoted := RegEx.create_from_string("\"([^\"]*)\"")
	for path: String in files:
		for line: String in FileAccess.get_file_as_string(path).split("\n"):
			if line.strip_edges().begins_with("#"):
				continue
			for result: RegExMatch in quoted.search_all(line):
				var text := result.get_string(1)
				for i: int in text.length():
					if text.unicode_at(i) > 127:
						found[text[i]] = true
	return "".join(PackedStringArray(found.keys()))


func test_the_fonts_can_draw_every_character_the_ui_shows() -> void:
	var characters := _ui_characters()
	check(characters.length() > 0, "the scan found the UI text")
	var mono: FontFile = load(MONO_FONT)
	for i: int in characters.length():
		check(mono.has_char(characters.unicode_at(i)), "IBM Plex Mono can't draw %s" % characters[i])
	for path: String in BODY_FONTS:
		var font: FontFile = load(path)
		for i: int in characters.length():
			if not MONO_ONLY.contains(characters[i]):
				check(font.has_char(characters.unicode_at(i)), "%s can't draw %s" % [path.get_file(), characters[i]])


func test_mono_only_characters_stay_in_mono_text() -> void:
	# Each line that uses one must be a label the mono font draws; today that's the parts list.
	for i: int in MONO_ONLY.length():
		for dir: String in ["res://ui"]:
			for file: String in DirAccess.get_files_at(dir):
				if not file.ends_with(".gd"):
					continue
				var source := FileAccess.get_file_as_string(dir.path_join(file))
				for line: String in source.split("\n"):
					if line.strip_edges().begins_with("#") or not line.contains(MONO_ONLY[i]):
						continue
					check(file == "layer_row.gd", "%s uses %s outside the parts list: %s" % [file, MONO_ONLY[i], line.strip_edges()])
