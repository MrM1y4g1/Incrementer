class_name Economy
extends RefCounted
## The only code that changes the numbers. Live play, offline catch-up, the autoplayer and the tests
## all go through these functions, so they can't disagree.

enum BuyMode { ONE = 1, TEN = 10, MAX = -1 }

const CLICK_VALUE := 1.0
## Registers wider than this need a Wide bus Firmware node (milestone M3).
const MAX_BITS_WITHOUT_FIRMWARE := 64
const OFFLINE_CAP_SECONDS := 8.0 * 3600.0


## Runs production for `seconds`. Every layer adds to the layer below it; layer 1 adds to the Count.
## All layers use their amounts from the start of the step.
static func advance(state: GameState, layers: Array[LayerDef], seconds: float) -> void:
	if seconds <= 0.0:
		return
	var start := state.layer_amount.duplicate()
	var layer_count := mini(layers.size(), GameState.LAYER_COUNT)
	for i: int in range(layer_count - 1, 0, -1):
		state.layer_amount[i - 1] += start[i] * layer_rate(state, layers, i) * seconds
	if layer_count > 0:
		add_count(state, start[0] * layer_rate(state, layers, 0) * seconds)


## Runs `seconds` of production in fixed steps, capped at the offline limit. Returns the Count gained.
static func catch_up(state: GameState, layers: Array[LayerDef], seconds: float, step: float = 1.0) -> float:
	var remaining := clampf(seconds, 0.0, OFFLINE_CAP_SECONDS)
	var before := state.count
	while remaining > 0.0:
		var dt := minf(step, remaining)
		advance(state, layers, dt)
		remaining -= dt
	return state.count - before


## Units of the layer below (or Count, for layer 1) that one owned unit makes per second.
static func layer_rate(state: GameState, layers: Array[LayerDef], index: int) -> float:
	return layers[index].base_rate * Formulas.milestone_multiplier(state.layer_bought[index])


static func count_per_second(state: GameState, layers: Array[LayerDef]) -> float:
	if layers.is_empty():
		return 0.0
	return state.layer_amount[0] * layer_rate(state, layers, 0)


## Adds to the Count without passing the register cap.
static func add_count(state: GameState, amount: float) -> void:
	state.count = minf(Formulas.register_cap(state.register_bits), state.count + amount)
	state.peak_count = maxf(state.peak_count, state.count)


static func click(state: GameState) -> void:
	state.total_clicks += 1
	add_count(state, CLICK_VALUE)


static func is_full(state: GameState) -> bool:
	return state.count >= Formulas.register_cap(state.register_bits)


static func is_unlocked(state: GameState, layer: LayerDef) -> bool:
	return state.register_bits >= layer.unlock_bits


static func next_cost(state: GameState, layers: Array[LayerDef], index: int) -> float:
	var layer := layers[index]
	return Formulas.next_cost(layer.base_cost, layer.cost_growth, state.layer_bought[index])


static func cost_of(state: GameState, layers: Array[LayerDef], index: int, n: int) -> float:
	var layer := layers[index]
	return Formulas.cost_of(layer.base_cost, layer.cost_growth, state.layer_bought[index], n)


## Units a purchase in this mode would buy right now: 0 when locked or unaffordable.
## ×1 and ×10 need the full amount; Max buys as many as the Count allows.
static func buy_count(state: GameState, layers: Array[LayerDef], index: int, mode: int) -> int:
	var layer := layers[index]
	if not is_unlocked(state, layer):
		return 0
	if mode == BuyMode.MAX:
		return Formulas.max_affordable(layer.base_cost, layer.cost_growth, state.layer_bought[index], state.count)
	return mode if cost_of(state, layers, index, mode) <= state.count else 0


## Buys units of a layer. Returns how many were bought.
static func buy(state: GameState, layers: Array[LayerDef], index: int, mode: int) -> int:
	var n := buy_count(state, layers, index, mode)
	if n <= 0:
		return 0
	state.count = maxf(0.0, state.count - cost_of(state, layers, index, n))
	state.layer_bought[index] += n
	state.layer_amount[index] += n
	return n


static func widen_cost(state: GameState) -> float:
	return Formulas.widen_cost(state.register_bits)


## True when the next width exists, needs no Firmware yet, and the Count covers the cost.
static func can_widen(state: GameState) -> bool:
	var next := Formulas.next_width(state.register_bits)
	return next > 0 and next <= MAX_BITS_WITHOUT_FIRMWARE and state.count >= widen_cost(state)


static func widen(state: GameState) -> bool:
	if not can_widen(state):
		return false
	state.count -= widen_cost(state)
	state.register_bits = Formulas.next_width(state.register_bits)
	return true
