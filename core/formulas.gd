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
## Count per second × (1 + Carry earned)^CARRY_BONUS_POWER. Carry doubles every 16 bits a run reaches, so
## the bonus adds 7 bits of Count per second for every 16 bits of peak. Count pays for every layer, which
## roughly triples that, so a run that lets the bonus ripple in ends about a third wider than the last.
## At 12.5 (1.0.2) runs reached twice the bits of the run before and the game ended in under 2 hours.
const CARRY_BONUS_POWER := 7.0
## The Carry bonus ripples in: it is ×1 when a run starts and reaches full strength after this many seconds.
## A flat bonus made a new run's first Incrementer worth millions per second, and because Count pays for
## every layer, any flat bonus snowballs through the old widths in seconds. Time can't snowball, so each
## run replays the old widths, then meets new ground as the bonus completes. Runs that make progress last
## about this long, so it sets the pace of everything after the first Overflow.
const CARRY_RIPPLE_SECONDS := 2400.0
## Multipliers stay below this so they never become INF, because INF × 0 would be NaN.
const MAX_MULTIPLIER := 1e300
## Worn bits: the machine's storage wearing out. Once the register reaches WEAR_FROM_BITS, a random bit
## anywhere in it starts to wear about every WEAR_INTERVAL seconds. An older machine wears faster: each
## Overflow so far adds WEAR_PER_OVERFLOW to the rate, up to WEAR_RATE_MAX times the first run's.
## A worn bit goes bad WEAR_SECONDS after it starts, and nothing stops it: the amber and red are a warning.
## Until 1.3.3, bad bits only appeared among the new bits of a widening, from the second run on. In 1.4.0 a
## worn bit took 20 seconds and the player could refresh it in time; the repo owner took that out in 1.5.0.
const WEAR_FROM_BITS := 16
const WEAR_INTERVAL := 150.0
const WEAR_PER_OVERFLOW := 0.25
const WEAR_RATE_MAX := 3.0
const WEAR_SECONDS := 5.0
## A bad bit holding the Count scrubs itself after this many seconds, unless Firmware is faster.
const FAULT_SCRUB_SECONDS := 60.0
## Repairing a bad bit costs this share of the bit's value: the Count drops by about one bit.
const FAULT_REPAIR_SHARE := 0.5
## The click charge: how fast the player has clicked lately, as a share of ICARUS_RATE. Each click adds
## 1 / (ICARUS_RATE × CHARGE_SECONDS) and the charge decays with a CHARGE_SECONDS time constant, so it settles
## at clicks a second ÷ ICARUS_RATE: half full at 10 a second. Above CHARGE_FROM (5 a second) every click
## is worth more, rising towards CHARGE_BONUS_MAX more as the charge nears full.
## Full takes ICARUS_RATE clicks a second or more for several seconds (about 4 at 30 a second, 6 at 25, never
## at 20 or less), which takes a macro. Then the player flies too close to the sun: for ICARUS_SECONDS
## clicks do nothing and the charge can't build. A full charge was a reward (ULTRA) in the first 1.5.0 test
## build; the repo owner made it this punishment instead.
const ICARUS_RATE := 20.0
const CHARGE_SECONDS := 4.0
const CHARGE_FROM := 0.25
const CHARGE_BONUS_MAX := 2.0
const ICARUS_SECONDS := 15.0
## The click rate in stats, and the one that tells speeding up from slowing down, is averaged over this long.
const CLICK_RATE_SECONDS := 1.0


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


## The Carry bonus `run_seconds` into a run. Its exponent grows evenly, so the bonus gains the same number
## of bits every second until it is complete.
static func carry_bonus_at(total_carry: float, run_seconds: float) -> float:
	return pow(carry_bonus(total_carry), clampf(run_seconds / CARRY_RIPPLE_SECONDS, 0.0, 1.0))


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


## The average seconds between bits starting to wear, after `overflows` Overflows. `rate_multiplier` comes
## from Firmware: 0.5 wears half as often.
static func wear_interval(overflows: int, rate_multiplier: float = 1.0) -> float:
	var rate := minf(WEAR_RATE_MAX, 1.0 + WEAR_PER_OVERFLOW * overflows) * maxf(0.01, rate_multiplier)
	return WEAR_INTERVAL / rate


## The largest Count that leaves `bit` unset: 2^bit − 1, or from 53 bits on, where 2^bit − 1 would round
## up to 2^bit, the largest float below 2^bit.
static func below_bit(bit: int) -> float:
	return pow(2.0, bit) - pow(2.0, maxi(0, bit - 53))
