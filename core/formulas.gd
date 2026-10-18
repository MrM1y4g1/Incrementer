class_name Formulas
extends RefCounted
## Pure maths for costs, caps and bonuses. No nodes, no autoloads, so tests and tools can call it headless.

## The largest finite 64-bit float. A full 1024-bit register sits exactly at this limit.
const MAX_FLOAT := 1.7976931348623157e308
const REGISTER_WIDTHS: Array[int] = [8, 16, 32, 64, 128, 256, 512, 1024]
## Widening the register costs this share of a full register.
const WIDEN_COST_SHARE := 0.75
## Each layer's output doubles every time this many units of it have been bought.
const MILESTONE_EVERY := 40
## Every unlocked achievement adds this share to all output.
const ACHIEVEMENT_BONUS := 0.01
## The clock: each level multiplies all output by CLOCK_STEP and costs CLOCK_COST_GROWTH times the last.
const CLOCK_BASE_COST := 1000.0
const CLOCK_COST_GROWTH := 100.0
const CLOCK_STEP := 1.125
## The Count a run must reach before the player can Overflow: a full 64-bit register.
const OVERFLOW_THRESHOLD := 18446744073709551616.0
## Carry = 2^((peak bits - CARRY_BASE_BITS) / 16).
const CARRY_BASE_BITS := 48.0
## Count per second × (1 + Carry earned)^CARRY_BONUS_POWER. Carry grows exponentially with the bits a run
## reaches, so this power law adds about 32 bits per doubling of Carry: enough for each run to reach
## roughly twice the bits of the run before.
const CARRY_BONUS_POWER := 12.5
## Multipliers stay below this so they never become INF, because INF × 0 would be NaN.
const MAX_MULTIPLIER := 1e300


## Price of the next single unit.
static func next_cost(base: float, growth: float, bought: int) -> float:
	return base * pow(growth, bought)


## Price of buying `n` units in a row, starting after `bought` units.
static func cost_of(base: float, growth: float, bought: int, n: int) -> float:
	if n <= 0:
		return 0.0
	return next_cost(base, growth, bought) * (pow(growth, n) - 1.0) / (growth - 1.0)


## How many units `budget` can buy in a row.
static func max_affordable(base: float, growth: float, bought: int, budget: float) -> int:
	var first := next_cost(base, growth, bought)
	if first <= 0.0 or budget < first:
		return 0
	var n := int(floor(log(1.0 + budget * (growth - 1.0) / first) / log(growth)))
	# Float rounding can land one off in either direction; settle on the exact answer.
	while n > 0 and cost_of(base, growth, bought, n) > budget:
		n -= 1
	while cost_of(base, growth, bought, n + 1) <= budget:
		n += 1
	return n


## The largest Count a register of this width can hold.
static func register_cap(bits: int) -> float:
	if bits >= 1024:
		return MAX_FLOAT
	return pow(2.0, bits) - 1.0


static func widen_cost(bits: int) -> float:
	return floor(WIDEN_COST_SHARE * (register_cap(bits) + 1.0))


## Carry for an Overflow: 2^((bits - CARRY_BASE_BITS) / 16), so 2 for a full 64-bit register,
## doubling for every 16 bits beyond it.
## Returns 0 below 2^64, before the multiplier from Firmware.
static func carry_for_peak(peak: float) -> float:
	if peak < OVERFLOW_THRESHOLD:
		return 0.0
	var bits := log(peak) / log(2.0)
	# The small nudge keeps a peak of exactly 2^64 from rounding down to 0.
	return maxf(1.0, floor(pow(2.0, (bits - CARRY_BASE_BITS) / 16.0) + 1e-9))


## The Count-per-second bonus from all the Carry ever earned (spending Carry doesn't reduce it).
static func carry_bonus(total_carry: float) -> float:
	return minf(MAX_MULTIPLIER, pow(1.0 + maxf(0.0, total_carry), CARRY_BONUS_POWER))


## The narrowest register that can hold `amount`, or -1 if none can.
static func width_for(amount: float) -> int:
	for bits: int in REGISTER_WIDTHS:
		if register_cap(bits) >= amount:
			return bits
	return -1


static func clock_cost(level: int) -> float:
	return CLOCK_BASE_COST * pow(CLOCK_COST_GROWTH, level)


## Output multiplier from the clock. Shown to the player as a clock speed in hertz.
static func clock_multiplier(level: int) -> float:
	return pow(CLOCK_STEP, level)


## The next register width, or -1 at the top of the ladder.
static func next_width(bits: int) -> int:
	var i := REGISTER_WIDTHS.find(bits)
	if i < 0 or i == REGISTER_WIDTHS.size() - 1:
		return -1
	return REGISTER_WIDTHS[i + 1]


## Output doubles for every `step` units bought (MILESTONE_EVERY unless Firmware lowers it).
static func milestone_multiplier(bought: int, step: int = MILESTONE_EVERY) -> float:
	return pow(2.0, floor(float(bought) / maxi(1, step)))
