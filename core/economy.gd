class_name Economy
extends RefCounted
## The only code that changes the numbers. Live play, offline catch-up, the autoplayer, the simulator
## and the tests all go through these functions, so they can't disagree.

enum BuyMode { ONE = 1, TEN = 10, MAX = -1 }

const CLICK_VALUE := 1.0
## Registers wider than this need a Wide bus Firmware node (milestone M3).
const MAX_BITS_WITHOUT_FIRMWARE := 64
const OFFLINE_CAP_SECONDS := 8.0 * 3600.0


# --- Production -----------------------------------------------------------------

## Runs production for `seconds`. Every layer adds to the layer below it; layer 1 adds to the Count.
## All layers use their amounts from the start of the step.
static func advance(state: GameState, content: Content, seconds: float) -> void:
	if seconds <= 0.0:
		return
	var start := state.layer_amount.duplicate()
	var layer_count := mini(content.layers.size(), GameState.LAYER_COUNT)
	for i: int in range(layer_count - 1, 0, -1):
		state.layer_amount[i - 1] += start[i] * layer_rate(state, content, i) * seconds
	if layer_count > 0:
		add_count(state, start[0] * layer_rate(state, content, 0) * seconds)


## Runs `seconds` of production in fixed steps, capped at the offline limit. Returns the Count gained.
static func catch_up(state: GameState, content: Content, seconds: float, step: float = 1.0) -> float:
	var remaining := clampf(seconds, 0.0, OFFLINE_CAP_SECONDS)
	var before := state.count
	while remaining > 0.0:
		var dt := minf(step, remaining)
		advance(state, content, dt)
		remaining -= dt
	return state.count - before


## Units of the layer below (or Count, for layer 1) that one owned unit makes per second.
static func layer_rate(state: GameState, content: Content, index: int) -> float:
	refresh_effects(state, content)
	return content.layers[index].base_rate * Formulas.milestone_multiplier(state.layer_bought[index]) * state.layer_multiplier[index]


static func count_per_second(state: GameState, content: Content) -> float:
	if content.layers.is_empty():
		return 0.0
	return state.layer_amount[0] * layer_rate(state, content, 0)


## Adds to the Count without passing the register cap. Returns what was actually added.
static func add_count(state: GameState, amount: float) -> float:
	var before := state.count
	state.count = minf(Formulas.register_cap(state.register_bits), state.count + amount)
	var added := maxf(0.0, state.count - before)
	state.total_produced += added
	state.peak_count = maxf(state.peak_count, state.count)
	return added


## Rebuilds the multipliers from upgrades, achievements and the clock, if anything changed.
## Global boosts (the clock, achievements, ALL_MULTIPLIER upgrades) multiply layer 1 only, which is
## the Count per second. Applied to every layer they would compound down the chain, so "×2" would
## really mean about ×2 to the power of the number of active layers.
static func refresh_effects(state: GameState, content: Content) -> void:
	if not state.effects_dirty:
		return
	var multipliers := PackedFloat64Array()
	multipliers.resize(GameState.LAYER_COUNT)
	multipliers.fill(1.0)
	var all := Formulas.clock_multiplier(state.clock_level) * (1.0 + Formulas.ACHIEVEMENT_BONUS * state.achievements.size())
	var click_multiplier := 1.0
	var click_share := 0.0
	for id: StringName in state.upgrades:
		var upgrade: UpgradeDef = content.upgrade_by_id.get(id)
		if upgrade == null:
			continue
		match upgrade.effect:
			UpgradeDef.Effect.LAYER_MULTIPLIER:
				var i := upgrade.layer_tier - 1
				if i >= 0 and i < GameState.LAYER_COUNT:
					multipliers[i] *= upgrade.value
			UpgradeDef.Effect.ALL_MULTIPLIER:
				all *= upgrade.value
			UpgradeDef.Effect.CLICK_MULTIPLIER:
				click_multiplier *= upgrade.value
			UpgradeDef.Effect.CLICK_FROM_RATE:
				click_share += upgrade.value
	multipliers[0] *= all
	state.layer_multiplier = multipliers
	state.click_multiplier = click_multiplier
	state.click_rate_share = click_share
	state.effects_dirty = false


# --- Clicking -------------------------------------------------------------------

static func click_value(state: GameState, content: Content) -> float:
	refresh_effects(state, content)
	return CLICK_VALUE * state.click_multiplier + state.click_rate_share * count_per_second(state, content)


static func click(state: GameState, content: Content) -> void:
	state.total_clicks += 1
	add_count(state, click_value(state, content))


# --- Layers ---------------------------------------------------------------------

static func is_unlocked(state: GameState, layer: LayerDef) -> bool:
	return state.register_bits >= layer.unlock_bits


static func next_cost(state: GameState, content: Content, index: int) -> float:
	var layer := content.layers[index]
	return Formulas.next_cost(layer.base_cost, layer.cost_growth, state.layer_bought[index])


static func cost_of(state: GameState, content: Content, index: int, n: int) -> float:
	var layer := content.layers[index]
	return Formulas.cost_of(layer.base_cost, layer.cost_growth, state.layer_bought[index], n)


## Units a purchase in this mode would buy right now: 0 when locked or unaffordable.
## ×1 and ×10 need the full amount; Max buys as many as the Count allows.
static func buy_count(state: GameState, content: Content, index: int, mode: int) -> int:
	var layer := content.layers[index]
	if not is_unlocked(state, layer):
		return 0
	if mode == BuyMode.MAX:
		return Formulas.max_affordable(layer.base_cost, layer.cost_growth, state.layer_bought[index], state.count)
	return mode if cost_of(state, content, index, mode) <= state.count else 0


## Buys units of a layer. Returns how many were bought.
static func buy(state: GameState, content: Content, index: int, mode: int) -> int:
	var n := buy_count(state, content, index, mode)
	if n <= 0:
		return 0
	state.count = maxf(0.0, state.count - cost_of(state, content, index, n))
	state.layer_bought[index] += n
	state.layer_amount[index] += n
	return n


# --- Upgrades -------------------------------------------------------------------

## True when the upgrade's requirements are met and it hasn't been bought yet.
static func upgrade_visible(state: GameState, upgrade: UpgradeDef) -> bool:
	if state.upgrades.has(upgrade.id) or state.register_bits < upgrade.requires_bits:
		return false
	if upgrade.requires_tier > 0 and state.layer_bought[upgrade.requires_tier - 1] < upgrade.requires_bought:
		return false
	return true


static func can_buy_upgrade(state: GameState, upgrade: UpgradeDef) -> bool:
	return upgrade_visible(state, upgrade) and state.count >= upgrade.cost


static func buy_upgrade(state: GameState, upgrade: UpgradeDef) -> bool:
	if not can_buy_upgrade(state, upgrade):
		return false
	state.count -= upgrade.cost
	state.upgrades.append(upgrade.id)
	state.effects_dirty = true
	return true


static func visible_upgrades(state: GameState, content: Content) -> Array[UpgradeDef]:
	var result: Array[UpgradeDef] = []
	for upgrade: UpgradeDef in content.upgrades:
		if upgrade_visible(state, upgrade):
			result.append(upgrade)
	return result


# --- Clock ----------------------------------------------------------------------

static func clock_cost(state: GameState) -> float:
	return Formulas.clock_cost(state.clock_level)


static func can_overclock(state: GameState) -> bool:
	return state.count >= clock_cost(state)


static func overclock(state: GameState) -> bool:
	if not can_overclock(state):
		return false
	state.count -= clock_cost(state)
	state.clock_level += 1
	state.effects_dirty = true
	return true


# --- Register -------------------------------------------------------------------

static func is_full(state: GameState) -> bool:
	return state.count >= Formulas.register_cap(state.register_bits)


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
