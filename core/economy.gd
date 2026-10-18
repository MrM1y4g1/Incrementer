class_name Economy
extends RefCounted
## The only code that changes the numbers. Live play, catch-up after a long frame, the autoplayer, the
## simulator and the tests all go through these functions, so they can't disagree.

enum BuyMode { ONE = 1, TEN = 10, MAX = -1 }

const CLICK_VALUE := 1.0
## Without a Wide bus Firmware node the register stops at this width.
const BASE_MAX_BITS := 64
## The longest gap `catch_up` fills, such as a computer that slept with the game open.
const MAX_CATCH_UP_SECONDS := 8.0 * 3600.0
## Autobuyers only buy units costing at most this share of the Count, so the player can still save up.
const AUTOBUY_SPEND_SHARE := 0.1


# --- Production -----------------------------------------------------------------

## Runs production for `seconds`. Every layer adds to the layer below it; layer 1 adds to the Count.
## All layers use their amounts from the start of the step.
static func advance(state: GameState, content: Content, seconds: float) -> void:
	if seconds <= 0.0:
		return
	var start := state.layer_amount.duplicate()
	var layer_count := mini(content.layers.size(), GameState.LAYER_COUNT)
	for i: int in range(layer_count - 1, 0, -1):
		state.layer_amount[i - 1] = minf(Formulas.MAX_FLOAT, state.layer_amount[i - 1] + start[i] * layer_rate(state, content, i) * seconds)
	if layer_count > 0:
		add_count(state, start[0] * layer_rate(state, content, 0) * seconds)


## Runs `seconds` of production in fixed steps, with autobuyers, up to MAX_CATCH_UP_SECONDS. For long gaps
## while the game is open, such as a minimised window or a background browser tab. The game doesn't run
## while it's closed, so nothing calls this on load. The run's time moves on with it, so the Carry bonus
## keeps rippling in. Returns the Count gained.
static func catch_up(state: GameState, content: Content, seconds: float, step: float = 1.0) -> float:
	refresh_effects(state, content)
	var remaining := clampf(seconds, 0.0, MAX_CATCH_UP_SECONDS)
	var before := state.count
	while remaining > 0.0:
		var dt := minf(step, remaining)
		run_autobuyers(state, content)
		advance(state, content, dt)
		state.run_time += dt
		remaining -= dt
	return state.count - before


## Time the player spends in the game, for the run and the whole save.
static func add_time(state: GameState, seconds: float) -> void:
	add_play_time(state, seconds)
	state.run_time += seconds


## For time already caught up with `catch_up`, which moved the run's time on itself.
static func add_play_time(state: GameState, seconds: float) -> void:
	state.play_time += seconds


## Units of the layer below (or Count, for layer 1) that one owned unit makes per second.
static func layer_rate(state: GameState, content: Content, index: int) -> float:
	refresh_effects(state, content)
	var multiplier := state.layer_multiplier[index]
	if index == 0:
		# Applied here, not in refresh_effects, because it changes every tick while it ripples in.
		multiplier = minf(Formulas.MAX_MULTIPLIER, multiplier * carry_bonus_now(state))
	return content.layers[index].base_rate * Formulas.milestone_multiplier(state.layer_bought[index], state.milestone_step) * multiplier


## The Carry bonus on Count per second at this point in the run.
static func carry_bonus_now(state: GameState) -> float:
	return Formulas.carry_bonus_at(state.total_carry, state.run_time)


static func count_per_second(state: GameState, content: Content) -> float:
	if content.layers.is_empty():
		return 0.0
	# Late in the game this product can pass the largest float; keep it finite for display and clicks.
	return minf(Formulas.MAX_FLOAT, state.layer_amount[0] * layer_rate(state, content, 0))


## Adds to the Count without passing the register cap. Returns what was actually added.
static func add_count(state: GameState, amount: float) -> float:
	var before := state.count
	state.count = minf(Formulas.register_cap(state.register_bits), state.count + amount)
	var added := maxf(0.0, state.count - before)
	state.total_produced += added
	state.run_peak = maxf(state.run_peak, state.count)
	state.peak_count = maxf(state.peak_count, state.count)
	return added


## Rebuilds every derived value from upgrades, Firmware, achievements and the clock, if anything changed.
## The Carry bonus is left out: `layer_rate` applies it, because it ripples in over the run.
## Global boosts (the clock, achievements, Count multipliers) multiply layer 1 only, which is the Count
## per second. Applied to every layer they would compound down the chain, so "×2" would really mean
## about ×2 to the power of the number of active layers.
static func refresh_effects(state: GameState, content: Content) -> void:
	if not state.effects_dirty:
		return
	var multipliers := PackedFloat64Array()
	multipliers.resize(GameState.LAYER_COUNT)
	multipliers.fill(1.0)
	var count_multiplier := Formulas.clock_multiplier(state.clock_level) * (1.0 + Formulas.ACHIEVEMENT_BONUS * state.achievements.size())
	var click_multiplier := 1.0
	var click_share := 0.0

	for id: StringName in state.upgrades:
		var upgrade: UpgradeDef = content.upgrade_by_id.get(id)
		if upgrade == null:
			continue
		match upgrade.effect:
			UpgradeDef.Effect.LAYER_MULTIPLIER:
				_multiply(multipliers, upgrade.layer_tier, upgrade.value)
			UpgradeDef.Effect.ALL_MULTIPLIER:
				count_multiplier *= upgrade.value
			UpgradeDef.Effect.CLICK_MULTIPLIER:
				click_multiplier *= upgrade.value
			UpgradeDef.Effect.CLICK_FROM_RATE:
				click_share += upgrade.value

	var max_bits := BASE_MAX_BITS
	var boot_bits := 8
	var carry_multiplier := 1.0
	var milestone_step := Formulas.MILESTONE_EVERY
	var effects := {}
	for id: StringName in state.firmware:
		var node: FirmwareDef = content.firmware_by_id.get(id)
		if node == null:
			continue
		effects[node.effect] = true
		match node.effect:
			FirmwareDef.Effect.WIDE_BUS:
				max_bits = maxi(max_bits, int(node.value))
			FirmwareDef.Effect.BOOT_WIDTH:
				boot_bits = maxi(boot_bits, int(node.value))
			FirmwareDef.Effect.COUNT_MULTIPLIER:
				count_multiplier *= node.value
			FirmwareDef.Effect.LAYER_MULTIPLIER:
				_multiply(multipliers, node.layer_tier, node.value)
			FirmwareDef.Effect.CARRY_MULTIPLIER:
				carry_multiplier *= node.value
			FirmwareDef.Effect.MILESTONE_STEP:
				milestone_step = mini(milestone_step, int(node.value))

	multipliers[0] *= count_multiplier
	for i: int in GameState.LAYER_COUNT:
		multipliers[i] = minf(multipliers[i], Formulas.MAX_MULTIPLIER)
	state.layer_multiplier = multipliers
	state.click_multiplier = click_multiplier
	state.click_rate_share = click_share
	state.max_bits = max_bits
	state.boot_bits = mini(boot_bits, max_bits)
	state.carry_multiplier = carry_multiplier
	state.milestone_step = milestone_step
	state.firmware_effects = effects
	state.effects_dirty = false


static func _multiply(multipliers: PackedFloat64Array, tier: int, value: float) -> void:
	var i := tier - 1
	if i >= 0 and i < GameState.LAYER_COUNT:
		multipliers[i] *= value


# --- Clicking -------------------------------------------------------------------

static func click_value(state: GameState, content: Content) -> float:
	refresh_effects(state, content)
	return minf(Formulas.MAX_FLOAT, CLICK_VALUE * state.click_multiplier + state.click_rate_share * count_per_second(state, content))


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
	_add_bought(state, content, index, n)
	return n


## Adds bought units to a layer, and logs the run's first unit of it.
static func _add_bought(state: GameState, content: Content, index: int, n: int) -> void:
	if state.layer_bought[index] == 0:
		state.record("layer", String(content.layers[index].id))
	state.layer_bought[index] += n
	state.layer_amount[index] += n


# --- Upgrades -------------------------------------------------------------------

## True when the upgrade's requirements are met and it hasn't been bought this run.
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
	state.record("upgrade", String(upgrade.id))
	return true


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


## The widest register the player's Firmware allows.
static func max_bits(state: GameState, content: Content) -> int:
	refresh_effects(state, content)
	return state.max_bits


## True when the next width exists, Firmware allows it, and the Count covers the cost.
static func can_widen(state: GameState, content: Content) -> bool:
	var next := Formulas.next_width(state.register_bits)
	return next > 0 and next <= max_bits(state, content) and state.count >= widen_cost(state)


static func widen(state: GameState, content: Content) -> bool:
	if not can_widen(state, content):
		return false
	state.count -= widen_cost(state)
	state.register_bits = Formulas.next_width(state.register_bits)
	state.record("widen", state.register_bits)
	return true


# --- Overflow -------------------------------------------------------------------

static func can_overflow(state: GameState) -> bool:
	return state.run_peak >= Formulas.OVERFLOW_THRESHOLD


## Carry an Overflow would pay right now.
static func overflow_gain(state: GameState, content: Content) -> float:
	refresh_effects(state, content)
	return floor(Formulas.carry_for_peak(state.run_peak) * state.carry_multiplier)


## Ends the run: pays Carry, records the run, and resets the Count, layers, register, clock and upgrades.
## Firmware, achievements, stats and Carry stay. Returns the Carry earned, or 0 if not allowed yet.
static func overflow(state: GameState, content: Content) -> float:
	if not can_overflow(state):
		return 0.0
	var gain := overflow_gain(state, content)
	state.carry += gain
	state.total_carry += gain
	state.overflows += 1
	var bits := log(state.run_peak) / log(2.0)
	state.runs.append({"time": state.run_time, "bits": bits, "carry": gain})
	state.record("overflow", {"bits": snappedf(bits, 0.1), "carry": gain, "run_seconds": snappedf(state.run_time, 0.1)})
	while state.runs.size() > GameState.RUN_HISTORY_LIMIT:
		state.runs.pop_front()

	state.count = 0.0
	state.run_peak = 0.0
	state.run_time = 0.0
	state.clock_level = 0
	# Packed arrays are copied on read, so assign fresh ones rather than filling in place.
	var fresh := GameState.new()
	state.layer_amount = fresh.layer_amount
	state.layer_bought = fresh.layer_bought
	state.upgrades.clear()
	state.effects_dirty = true
	refresh_effects(state, content)
	state.register_bits = state.boot_bits
	return gain


# --- Firmware -------------------------------------------------------------------

static func owns_firmware(state: GameState, id: StringName) -> bool:
	return state.firmware.has(id)


## True when every prerequisite is owned.
static func firmware_available(state: GameState, node: FirmwareDef) -> bool:
	for requirement: String in node.requires:
		if not state.firmware.has(StringName(requirement)):
			return false
	return true


static func can_buy_firmware(state: GameState, node: FirmwareDef) -> bool:
	return not owns_firmware(state, node.id) and firmware_available(state, node) and state.carry >= node.cost


static func buy_firmware(state: GameState, content: Content, node: FirmwareDef) -> bool:
	if not can_buy_firmware(state, node):
		return false
	state.carry -= node.cost
	state.firmware.append(node.id)
	state.record("firmware", String(node.id))
	state.effects_dirty = true
	refresh_effects(state, content)
	# A Boot ROM takes effect immediately if the register is narrower than it.
	if state.register_bits < state.boot_bits:
		state.register_bits = state.boot_bits
	return true


# --- Automation -----------------------------------------------------------------

## True when Firmware has unlocked this autobuyer and the player hasn't switched it off.
static func autobuyer_active(state: GameState, content: Content, effect: FirmwareDef.Effect, switch: String) -> bool:
	refresh_effects(state, content)
	return state.has_firmware_effect(effect) and bool(state.autobuy.get(switch, true))


## Runs every active autobuyer once. Layer autobuyers only buy units that cost at most
## AUTOBUY_SPEND_SHARE of the Count, so saving for a wider register still works.
static func run_autobuyers(state: GameState, content: Content) -> void:
	if autobuyer_active(state, content, FirmwareDef.Effect.AUTO_WIDEN, "widen"):
		while can_widen(state, content):
			widen(state, content)
	if autobuyer_active(state, content, FirmwareDef.Effect.AUTO_CLOCK, "clock"):
		while clock_cost(state) <= state.count * AUTOBUY_SPEND_SHARE and can_overclock(state):
			overclock(state)
	var low := autobuyer_active(state, content, FirmwareDef.Effect.AUTOBUY_LOW, "low")
	var high := autobuyer_active(state, content, FirmwareDef.Effect.AUTOBUY_HIGH, "high")
	if not low and not high:
		return
	for index: int in range(content.layers.size() - 1, -1, -1):
		if (index < 4 and not low) or (index >= 4 and not high):
			continue
		var layer := content.layers[index]
		if not is_unlocked(state, layer):
			continue
		var n := Formulas.max_affordable(layer.base_cost, layer.cost_growth, state.layer_bought[index], state.count * AUTOBUY_SPEND_SHARE)
		if n > 0:
			state.count = maxf(0.0, state.count - cost_of(state, content, index, n))
			_add_bought(state, content, index, n)


# --- The ending -----------------------------------------------------------------

## Marks the V1 ending once the 1024-bit register is full. Returns true the moment it happens.
static func check_ending(state: GameState) -> bool:
	if state.ended or state.register_bits < 1024 or not is_full(state):
		return false
	state.ended = true
	state.ended_time = state.play_time
	state.record("ending")
	return true
