extends Node
## Loads the save at startup, autosaves on the interval set in Settings, and saves on quit or when the window loses focus.
## The game only runs while it's open: a save carries on from where it was saved, however long ago.
## Pass `--no-save` after `--` on the command line to run without reading or writing the save file.

const SAVE_PATH := "user://save.json"
const BACKUP_PATH := "user://save.bak"
const TEMP_PATH := "user://save.tmp"
const START_OVER_PATH := "user://save-before-start-over.json"

var enabled := true
var last_saved_unix := 0.0

var _timer: Timer


func _ready() -> void:
	enabled = not OS.get_cmdline_user_args().has("--no-save")
	if not enabled:
		return
	load_game()
	_timer = Timer.new()
	_timer.wait_time = Settings.autosave_seconds
	_timer.autostart = true
	_timer.timeout.connect(save_game)
	add_child(_timer)
	Settings.changed.connect(func() -> void: _timer.wait_time = Settings.autosave_seconds)


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
	Game.replace_state(loaded["state"])


## The current game as one line of text the player can copy somewhere safe.
func export_text() -> String:
	return Marshalls.utf8_to_base64(SaveCodec.encode(Game.state, Time.get_unix_time_from_system()))


## Loads a game from exported text. Returns "" on success, or why the text couldn't be used.
func import_text(text: String) -> String:
	var cleaned := text.strip_edges()
	if cleaned == "":
		return "Paste an exported save first."
	var loaded := SaveCodec.decode(Marshalls.base64_to_utf8(cleaned))
	if loaded.is_empty():
		return "That text isn't a save from this game. Check that you copied all of it."
	Game.replace_state(loaded["state"])
	if enabled:
		save_game()
	return ""


## Starts a new game for the player. The old game is first written to START_OVER_PATH, which the game
## never reads, so someone who regrets it can rename it to save.json by hand. Settings stay.
func start_over() -> void:
	if enabled:
		var file := FileAccess.open(START_OVER_PATH, FileAccess.WRITE)
		if file != null:
			file.store_string(SaveCodec.encode(Game.state, Time.get_unix_time_from_system()))
			file.close()
	wipe()
	if enabled:
		save_game()


## Deletes the save and its backup and starts a new game. Used by the debug panel and `start_over`.
func wipe() -> void:
	# --no-save promises never to touch the save files.
	if enabled:
		for path: String in [SAVE_PATH, BACKUP_PATH, TEMP_PATH]:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Game.replace_state(GameState.new())
	last_saved_unix = 0.0


## True on the Web when the browser won't keep files between visits (private windows, blocked storage).
func storage_at_risk() -> bool:
	return enabled and OS.has_feature("web") and not OS.is_userfs_persistent()


func status_text() -> String:
	if not enabled:
		return "Saving off (--no-save)"
	if storage_at_risk():
		return "This browser won't keep your save: use Save data to back it up"
	if last_saved_unix <= 0.0:
		return "Autosave every %d s" % int(Settings.autosave_seconds)
	var ago := Time.get_unix_time_from_system() - last_saved_unix
	return "Saved %s ago" % NumberFormat.duration(ago)


func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	return SaveCodec.decode(FileAccess.get_file_as_string(path))
