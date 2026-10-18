extends Node
## Owns the live GameState and runs the simulation at a fixed 20 ticks per second.
## The UI sends requests through the methods below and reads `state` to draw.

const TICK := 0.05
## Longer gaps, such as a minimised window or a background browser tab, are caught up in one go.
const MAX_LIVE_GAP := 1.0

var state: GameState = GameState.new()
var layers: Array[LayerDef] = []

var _accumulator := 0.0


func _ready() -> void:
	layers = ContentDB.layers


func _process(delta: float) -> void:
	_accumulator += delta
	if _accumulator > MAX_LIVE_GAP:
		Economy.catch_up(state, layers, _accumulator)
		state.play_time += _accumulator
		_accumulator = 0.0
		return
	while _accumulator >= TICK:
		_accumulator -= TICK
		Economy.advance(state, layers, TICK)
		state.play_time += TICK


func click() -> void:
	Economy.click(state)


func buy(index: int, mode: int) -> int:
	var bought := Economy.buy(state, layers, index, mode)
	if bought > 0:
		EventBus.layer_bought.emit(index, bought)
	return bought


func widen() -> bool:
	if not Economy.widen(state):
		return false
	EventBus.register_widened.emit(state.register_bits)
	return true


func replace_state(new_state: GameState) -> void:
	state = new_state
