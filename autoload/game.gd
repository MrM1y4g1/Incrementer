extends Node
## Owns the live GameState and runs the simulation at a fixed 20 ticks per second.
## The UI sends requests through the methods below and reads `state` to draw.

const TICK := 0.05
## Longer gaps, such as a minimised window or a background browser tab, are caught up in one go.
const MAX_LIVE_GAP := 1.0
const CHECK_SECONDS := 0.25

var state: GameState = GameState.new()
var content: Content
## Simulation speed. Only the debug panel changes it.
var speed := 1.0
## True while the tutorial explains something: nothing is produced, nothing wears and play time stands still.
var paused := false

var _accumulator := 0.0
var _check_timer := 0.0


func _ready() -> void:
	content = ContentDB.content
	_seed_new_game()


func _process(delta: float) -> void:
	if paused:
		_accumulator = 0.0
		return
	var dt := delta * speed
	_accumulator += dt
	if _accumulator > MAX_LIVE_GAP:
		Economy.catch_up(state, content, _accumulator)
		Economy.add_play_time(state, _accumulator)
		_accumulator = 0.0
	while _accumulator >= TICK:
		_accumulator -= TICK
		Economy.run_autobuyers(state, content)
		Economy.advance(state, content, TICK)
		Economy.add_time(state, TICK)

	_check_timer += delta
	if _check_timer >= CHECK_SECONDS:
		_check_timer = 0.0
		check_achievements()
		if Economy.check_ending(state):
			EventBus.game_ended.emit()


func click() -> void:
	Economy.click(state, content)


func buy(index: int, mode: int) -> int:
	var bought := Economy.buy(state, content, index, mode)
	if bought > 0:
		EventBus.layer_bought.emit(index, bought)
	return bought


func buy_upgrade(id: StringName) -> bool:
	var upgrade: UpgradeDef = content.upgrade_by_id.get(id)
	if upgrade == null or not Economy.buy_upgrade(state, upgrade):
		return false
	EventBus.upgrade_bought.emit(id)
	return true


func overclock() -> bool:
	if not Economy.overclock(state):
		return false
	EventBus.clock_raised.emit(state.clock_level)
	return true


func widen() -> bool:
	if not Economy.widen(state, content):
		return false
	EventBus.register_widened.emit(state.register_bits)
	return true


func overflow() -> float:
	var gain := Economy.overflow(state, content)
	if gain > 0.0:
		EventBus.overflowed.emit(gain)
		check_achievements()
	return gain


func buy_firmware(id: StringName) -> bool:
	var node: FirmwareDef = content.firmware_by_id.get(id)
	if node == null or not Economy.buy_firmware(state, content, node):
		return false
	EventBus.firmware_bought.emit(id)
	return true


## Refreshes one worn bit before it goes bad.
func refresh_bit(bit: int) -> bool:
	return Economy.refresh(state, bit)


## Refreshes every worn bit. Returns how many there were.
func refresh_all() -> int:
	return Economy.refresh_all(state)


func repair_fault() -> bool:
	return Economy.repair(state)


## Clears the lowest bad bit for free, once the player has solved its parity puzzle.
func scrub_fault() -> bool:
	return Economy.scrub(state)


func set_faults_on(on: bool) -> void:
	Economy.set_faults_on(state, on)


func set_autobuy(switch: String, on: bool) -> void:
	if bool(state.autobuy.get(switch, true)) != on:
		state.record("autobuy", "%s %s" % [switch, "on" if on else "off"])
	state.autobuy[switch] = on


func check_achievements() -> void:
	for achievement: AchievementDef in Achievements.check(state, content):
		EventBus.achievement_unlocked.emit(achievement.id)


func replace_state(new_state: GameState) -> void:
	state = new_state
	state.effects_dirty = true
	_seed_new_game()


## A new game's first run gets a random seed, so every player's first run wears different bits. Later runs
## are seeded by the Overflow, and tests and the simulator use GameState directly, with seed 0.
func _seed_new_game() -> void:
	if state.run_seed == 0 and state.overflows == 0:
		state.run_seed = randi()
