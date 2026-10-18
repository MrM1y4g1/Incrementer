extends Node
## Loads the save at startup, autosaves every 30 seconds, and saves on quit or when the window loses focus.
## Pass `--no-save` after `--` on the command line to run without reading or writing the save file.

const SAVE_PATH := "user://save.json"
const BACKUP_PATH := "user://save.bak"
const TEMP_PATH := "user://save.tmp"
const AUTOSAVE_SECONDS := 30.0

var enabled := true
## Filled in when a save is loaded, so the UI can show a "While you were away" report.
var offline_seconds := 0.0
var offline_gain := 0.0
var last_saved_unix := 0.0


func _ready() -> void:
	enabled = not OS.get_cmdline_user_args().has("--no-save")
	if not enabled:
		return
	load_game()
	var timer := Timer.new()
	timer.wait_time = AUTOSAVE_SECONDS
	timer.autostart = true
	timer.timeout.connect(save_game)
	add_child(timer)


func _notification(what: int) -> void:
	if not enabled:
		return
	# Browsers can close a tab without a quit event, so focus loss is the safer moment to save.
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		save_game()


func save_game() -> bool:
	var now := Time.get_unix_time_from_system()
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s: %s" % [TEMP_PATH, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(SaveCodec.encode(Game.state, now))
	file.close()

	var dir := DirAccess.open("user://")
	if dir == null:
		push_error("Could not open user://")
		return false
	var save_name := SAVE_PATH.get_file()
	var backup_name := BACKUP_PATH.get_file()
	if dir.file_exists(save_name):
		if dir.file_exists(backup_name):
			dir.remove(backup_name)
		dir.rename(save_name, backup_name)
	var err := dir.rename(TEMP_PATH.get_file(), save_name)
	if err != OK:
		push_error("Could not replace the save file: %s" % error_string(err))
		return false
	last_saved_unix = now
	return true


func load_game() -> void:
	var loaded := _read(SAVE_PATH)
	if loaded.is_empty():
		loaded = _read(BACKUP_PATH)
	if loaded.is_empty():
		return
	var state: GameState = loaded["state"]
	var elapsed := Time.get_unix_time_from_system() - float(loaded["saved_at"])
	offline_seconds = clampf(elapsed, 0.0, Economy.OFFLINE_CAP_SECONDS)
	offline_gain = Economy.catch_up(state, ContentDB.content, elapsed)
	Game.replace_state(state)


## Deletes the save and its backup and starts a new game. Used by the debug panel.
func wipe() -> void:
	for path: String in [SAVE_PATH, BACKUP_PATH, TEMP_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Game.replace_state(GameState.new())
	offline_seconds = 0.0
	offline_gain = 0.0
	last_saved_unix = 0.0


func status_text() -> String:
	if not enabled:
		return "Saving off (--no-save)"
	if last_saved_unix <= 0.0:
		return "Autosave every %d s" % int(AUTOSAVE_SECONDS)
	var ago := Time.get_unix_time_from_system() - last_saved_unix
	return "Saved %s ago" % NumberFormat.duration(ago)


func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	return SaveCodec.decode(FileAccess.get_file_as_string(path))
