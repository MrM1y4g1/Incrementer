extends Node
## Plays the sound effects and the music loop, and keeps the Music and SFX buses at the volumes
## set in Settings. The sounds are synthesised by tools/make_sounds.gd.
## Runs with --mute or --capture, and headless runs, stay silent.

const SOUND_NAMES: PackedStringArray = ["click", "buy", "upgrade", "overclock", "widen", "achievement", "overflow"]
## The same sound won't restart faster than this, so rapid purchases don't turn into a buzz.
const MIN_GAP_SECONDS := 0.045
const PLAYER_COUNT := 8

var _sounds := {}
var _last_played := {}
var _players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _muted := false


func _ready() -> void:
	# Headless runs (tests, the simulator, CI) have no audio output and quit quickly.
	_muted = DisplayServer.get_name() == "headless"
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--mute" or arg.begins_with("--capture="):
			_muted = true
	_ensure_bus("Music")
	_ensure_bus("SFX")
	for sound_name: String in SOUND_NAMES:
		_sounds[sound_name] = load("res://assets/audio/%s.wav" % sound_name)
	for i: int in PLAYER_COUNT:
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		add_child(player)
		_players.append(player)

	_music = AudioStreamPlayer.new()
	_music.bus = &"Music"
	var track: AudioStreamWAV = load("res://assets/audio/music.wav")
	if track != null:
		track.loop_mode = AudioStreamWAV.LOOP_FORWARD
		track.loop_begin = 0
		track.loop_end = track.data.size() / 2
		_music.stream = track
	add_child(_music)

	EventBus.layer_bought.connect(func(_index: int, _count: int) -> void: play("buy"))
	EventBus.upgrade_bought.connect(func(_id: StringName) -> void: play("upgrade"))
	EventBus.firmware_bought.connect(func(_id: StringName) -> void: play("upgrade"))
	EventBus.clock_raised.connect(func(_level: int) -> void: play("overclock"))
	EventBus.register_widened.connect(func(_bits: int) -> void: play("widen"))
	EventBus.overflowed.connect(func(_carry: float) -> void: play("overflow", 0.0))
	EventBus.achievement_unlocked.connect(func(_id: StringName) -> void: play("achievement", 0.0))
	Settings.changed.connect(_apply_volumes)
	_apply_volumes()
	if not _muted and _music.stream != null:
		_music.play()


## Plays a sound effect, with a little random pitch so repeats don't sound mechanical.
func play(sound_name: String, pitch_jitter: float = 0.05) -> void:
	if _muted or not _sounds.has(sound_name):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_played.get(sound_name, -1.0)) < MIN_GAP_SECONDS:
		return
	_last_played[sound_name] = now
	var player := _free_player()
	player.stream = _sounds[sound_name]
	player.pitch_scale = randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
	player.play()


func _free_player() -> AudioStreamPlayer:
	for player: AudioStreamPlayer in _players:
		if not player.playing:
			return player
	return _players[0]


func _apply_volumes() -> void:
	_set_bus_volume("Music", Settings.music_volume)
	_set_bus_volume("SFX", Settings.sfx_volume)


func _set_bus_volume(bus_name: String, volume: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_mute(index, volume <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.001)))


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, &"Master")
