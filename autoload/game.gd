extends Node
## Owns the live GameState and runs the simulation at a fixed 20 ticks per second.
## The UI sends requests through the methods below and reads `state` to draw.

const TICK := 0.05
## Longer gaps, such as a minimised window or a background browser tab, are caught up in one go.
const MAX_LIVE_GAP := 1.0
const ACHIEVEMENT_CHECK_SECONDS := 0.25

var state: GameState = GameState.new()
var content: Content
## Simulation speed. Only the debug panel changes it.
var speed := 1.0

var _accumulator := 0.0
var _achievement_timer := 0.0


func _ready() -> void:
	content = ContentDB.content


func _process(delta: float) -> void:
	var dt := delta * speed
	_accumulator += dt
	if _accumulator > MAX_LIVE_GAP:
		Economy.catch_up(state, content, _accumulator)
		state.play_time += _accumulator
		_accumulator = 0.0
	while _accumulator >= TICK:
		_accumulator -= TICK
		Economy.advance(state, content, TICK)
		state.play_time += TICK

	_achievement_timer += delta
	if _achievement_timer >= ACHIEVEMENT_CHECK_SECONDS:
		_achievement_timer = 0.0
		check_achievements()


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
	if not Economy.widen(state):
		return false
	EventBus.register_widened.emit(state.register_bits)
	return true


func check_achievements() -> void:
	for achievement: AchievementDef in Achievements.check(state, content):
		EventBus.achievement_unlocked.emit(achievement.id)


func replace_state(new_state: GameState) -> void:
	state = new_state
	state.effects_dirty = true
