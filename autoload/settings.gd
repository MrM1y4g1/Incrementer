extends Node
## Player preferences, kept in user://settings.cfg. They're separate from the save, so wiping or
## importing a save keeps them. Runs with --no-save use the defaults and never write the file.

signal changed

const PATH := "user://settings.cfg"
const AUTOSAVE_CHOICES: Array[float] = [15.0, 30.0, 60.0, 120.0]

var notation: int = NumberFormat.Notation.STANDARD
var music_volume := 0.5
var sfx_volume := 0.8
var reduced_motion := false
var autosave_seconds := 30.0

var _persist := true


func _init() -> void:
	_persist = not OS.get_cmdline_user_args().has("--no-save")
	if _persist:
		_load()
	NumberFormat.notation = notation


## Changes one setting by name, applies it and saves.
func set_value(key: String, value: Variant) -> void:
	set(key, value)
	NumberFormat.notation = notation
	if _persist:
		_save()
	changed.emit()


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	notation = clampi(int(config.get_value("display", "notation", notation)), 0, NumberFormat.Notation.size() - 1)
	reduced_motion = bool(config.get_value("display", "reduced_motion", reduced_motion))
	music_volume = clampf(float(config.get_value("audio", "music_volume", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(config.get_value("audio", "sfx_volume", sfx_volume)), 0.0, 1.0)
	var autosave := float(config.get_value("game", "autosave_seconds", autosave_seconds))
	autosave_seconds = autosave if AUTOSAVE_CHOICES.has(autosave) else 30.0


func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("display", "notation", notation)
	config.set_value("display", "reduced_motion", reduced_motion)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("game", "autosave_seconds", autosave_seconds)
	var err := config.save(PATH)
	if err != OK:
		push_error("Could not save settings: %s" % error_string(err))
