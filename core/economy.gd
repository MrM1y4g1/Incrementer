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
## All layers use their amounts from the start of the step. Bits wear out as the time passes, and a bad
## bit holding the Count scrubs itself.
static func advance(state: GameState, content: Content, seconds: float) -> void:
	if seconds <= 0.0:
		return
	var start := state.layer_amount.duplicate()
	var layer_count := mini(content.layers.size(), GameState.LAYER_COUNT)
	for i: int in range(layer_count - 1, 0, -1):
		state.layer_amount[i - 1] = minf(Formulas.MAX_FLOAT, state.layer_amount[i - 1] + start[i] * layer_rate(state, content, i) * seconds)
	if layer_count > 0:
		add_count(state, start[0] * layer_rate(state, content, 0) * seconds)
	_wear(state, content, seconds)
	_wait_out_fault(state, seconds)


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


## Adds to the Count without passing the register cap or a bad bit. A Count already above a bad bit
## stays where it is. Returns what was actually added.
static func add_count(state: GameState, amount: float) -> float:
	var before := state.count
	state.count = maxf(before, minf(capacity(state), state.count + amount))
	var added := maxf(0.0, state.count - before)
	# After the ending a full register adds the largest float every tick, which would overflow to INF.
	state.total_produced = minf(Formulas.MAX_FLOAT, state.total_produced + added)
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
	var scrub_seconds := Formulas.FAULT_SCRUB_SECONDS
	var fault_rate_multiplier := 1.0
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
			FirmwareDef.Effect.SCRUB_SECONDS:
				scrub_seconds = minf(scrub_seconds, node.value)
			FirmwareDef.Effect.FAULT_RATE:
				fault_rate_multiplier *= node.value

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
	state.scrub_seconds = scrub_seconds
	state.fault_rate_multiplier = fault_rate_multiplier
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
	_clear_wear(state)
	# Different every run, but the same for the same game, so the simulator replays exactly.
	state.run_seed = hash([state.overflows, state.play_time, state.total_carry])
	state.effects_dirty = true
	refresh_effects(state, content)
	state.register_bits = state.boot_bits
	return gain


# --- Bad bits -------------------------------------------------------------------

## The most the Count can grow to right now: the register's cap, or just under the lowest bad bit.
static func capacity(state: GameState) -> float:
	var cap := Formulas.register_cap(state.register_bits)
	if not state.bad_bits.is_empty():
		cap = minf(cap, Formulas.below_bit(state.bad_bits[0]))
	return cap


## The lowest bad bit, or -1 if there is none. It's the one that holds the Count, and the one Repair,
## Scrub and waiting clear.
static func next_fault(state: GameState) -> int:
	return state.bad_bits[0] if not state.bad_bits.is_empty() else -1


## True when the Count has reached the lowest bad bit, or was already past it when it went bad, and can't
## grow until it's cleared.
static func is_blocked(state: GameState) -> bool:
	return not state.bad_bits.is_empty() and state.count >= Formulas.below_bit(state.bad_bits[0])


static func repair_cost(state: GameState) -> float:
	var bit := next_fault(state)
	return Formulas.FAULT_REPAIR_SHARE * pow(2.0, bit) if bit >= 0 else 0.0


static func can_repair(state: GameState) -> bool:
	return next_fault(state) >= 0 and state.count >= repair_cost(state)


## Clears the lowest bad bit for Count.
static func repair(state: GameState) -> bool:
	if not can_repair(state):
		return false
	state.count -= repair_cost(state)
	_clear_fault(state, "repair")
	return true


## Clears the lowest bad bit for free. The UI calls this once the player has solved its parity puzzle.
static func scrub(state: GameState) -> bool:
	if next_fault(state) < 0:
		return false
	_clear_fault(state, "scrub")
	return true


## The puzzle for the lowest bad bit, sized for the register. The same bit in the same run, at the same
## width, always gets the same puzzle.
static func scrub_puzzle(state: GameState) -> ParityGrid:
	var bit := maxi(0, next_fault(state))
	var bits := state.register_bits
	return ParityGrid.make(ParityGrid.size_for(bits), hash([state.run_seed, bit]), ParityGrid.flips_for(bits))


## Seconds until the bad bit holding the Count scrubs itself.
static func scrub_time_left(state: GameState) -> float:
	return maxf(0.0, state.scrub_seconds - state.blocked_time)


## The Settings switch. Switching off clears this run's worn and bad bits too.
static func set_faults_on(state: GameState, on: bool) -> void:
	if state.faults_on == on:
		return
	state.faults_on = on
	if not on:
		_clear_wear(state)
	state.record("setting", "bad bits %s" % ("on" if on else "off"))


# --- Worn bits ------------------------------------------------------------------

## How far a worn bit has gone, from 0 when it starts to wear to 1 when it goes bad. 0 for a healthy bit.
static func wear_level(state: GameState, bit: int) -> float:
	var seconds: float = state.wearing.get(bit, 0.0)
	return clampf(seconds / Formulas.WEAR_SECONDS, 0.0, 1.0)


## Rewrites a worn bit before it goes bad. Free: it only takes noticing.
static func refresh(state: GameState, bit: int) -> bool:
	if not state.wearing.has(bit):
		return false
	state.record("refresh", {"bit": bit, "after": snappedf(state.wearing[bit], 0.1)})
	state.wearing.erase(bit)
	state.faults_refreshed += 1
	return true


## Refreshes every worn bit. Returns how many there were.
static func refresh_all(state: GameState) -> int:
	var refreshed := 0
	for bit: int in state.wearing.keys():
		if refresh(state, bit):
			refreshed += 1
	return refreshed


## Ages the worn bits, turns those that have worn for WEAR_SECONDS into bad bits, and starts new ones on
## schedule. Nothing wears in a register narrower than WEAR_FROM_BITS, after the ending, or with the switch off.
## Bits keep wearing while a bad bit holds the Count, so a player who looks away comes back to a pile of bad
## bits. That is intended (the repo owner's call in 1.4.0): bad bits are the game's enemy.
static func _wear(state: GameState, content: Content, seconds: float) -> void:
	if not state.faults_on or state.ended or state.register_bits < Formulas.WEAR_FROM_BITS:
		return
	refresh_effects(state, content)
	for bit: int in state.wearing.keys():
		state.wearing[bit] += seconds
		if state.wearing[bit] >= Formulas.WEAR_SECONDS:
			state.wearing.erase(bit)
			_go_bad(state, bit)
	if state.wear_due < 0.0:
		state.wear_due = _wear_gap(state)
	state.wear_due -= seconds
	while state.wear_due <= 0.0:
		_start_wearing(state)
		state.wear_due += _wear_gap(state)


## Picks a healthy bit anywhere in the register and starts it wearing. The seed and the number of bits worn
## so far this run decide which, so a run always wears the same bits in the same order.
static func _start_wearing(state: GameState) -> void:
	var rng := _wear_rng(state, "bit")
	state.wear_started += 1
	# A few tries, in case the pick is already worn or bad.
	for _try: int in 8:
		var bit := rng.randi_range(0, state.register_bits - 1)
		if not state.wearing.has(bit) and not state.bad_bits.has(bit):
			state.wearing[bit] = 0.0
			return


## Seconds until the next bit starts to wear: between half and one and a half times the average interval.
static func _wear_gap(state: GameState) -> float:
	var rng := _wear_rng(state, "gap")
	return Formulas.wear_interval(state.overflows, state.fault_rate_multiplier) * (0.5 + rng.randf())


static func _wear_rng(state: GameState, purpose: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([state.run_seed, state.wear_started, purpose])
	return rng


## A worn bit goes bad. If it held a 1 in the Count, the Count loses that bit's value: the storage that held
## it is gone. A new lowest bad bit starts its own wait to scrub itself.
static func _go_bad(state: GameState, bit: int) -> void:
	var lost := 0.0
	if is_bit_set(state.count, bit):
		lost = pow(2.0, bit)
		state.count = maxf(0.0, state.count - lost)
		state.count_lost = minf(Formulas.MAX_FLOAT, state.count_lost + lost)
	if state.bad_bits.is_empty() or bit < state.bad_bits[0]:
		state.blocked_time = 0.0
	state.bad_bits.append(bit)
	state.bad_bits.sort()
	state.record("bad bit", {"bit": bit, "lost": lost})


## True when `bit` is 1 in `value`. Bits below a large value's float precision always read 0.
static func is_bit_set(value: float, bit: int) -> bool:
	if value < 1.0:
		return false
	return fmod(floor(value / pow(2.0, bit)), 2.0) >= 1.0


static func _clear_wear(state: GameState) -> void:
	state.bad_bits.clear()
	state.blocked_time = 0.0
	state.wearing.clear()
	state.wear_due = -1.0
	state.wear_started = 0


## A bad bit holding the Count scrubs itself after scrub_seconds of holding it.
static func _wait_out_fault(state: GameState, seconds: float) -> void:
	if not is_blocked(state):
		return
	if state.blocked_time == 0.0:
		state.record("blocked", state.bad_bits[0])
	state.blocked_time += seconds
	if state.blocked_time >= state.scrub_seconds:
		_clear_fault(state, "waited")


static func _clear_fault(state: GameState, how: String) -> void:
	var bit: int = state.bad_bits.pop_front()
	state.blocked_time = 0.0
	match how:
		"repair":
			state.faults_repaired += 1
		"scrub":
			state.faults_scrubbed += 1
		_:
			state.faults_waited += 1
	state.record(how, bit)


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
