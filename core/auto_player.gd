class_name AutoPlayer
extends RefCounted
## A simple scripted player, used for screenshot captures and the balance simulator.
## Each step it clicks, widens the register when it can, then spends: upgrades, the clock and layers,
## highest layer first, while saving up for the next register width. It Overflows when the run slows down
## (see `should_overflow`) and spends its Carry on Firmware.

## While saving for a wider register, only purchases cheaper than this share of its cost are allowed.
const SPEND_SHARE_WHILE_SAVING := 0.1

## How the scripted player clears a bad bit that holds the Count: pay Count, solve the puzzle at once,
## or wait for it to scrub itself.
enum Fix { REPAIR, SCRUB, WAIT }


## At the default 4 clicks a second the click charge stays empty (Formulas.CHARGE_DRAIN), so pacing checks
## don't depend on it; the simulator plays a faster clicker separately.
static func play(state: GameState, content: Content, seconds: float, step: float = 0.25, clicks_per_second: float = 4.0, fix: Fix = Fix.REPAIR) -> void:
	var elapsed := 0.0
	var clicks := 0.0
	while elapsed < seconds:
		# Several bad bits can sit under the Count at once; clear them lowest first.
		while Economy.is_blocked(state):
			if fix == Fix.REPAIR and Economy.repair(state):
				continue
			if fix == Fix.SCRUB and Economy.scrub(state):
				continue
			break
		clicks += clicks_per_second * step
		while clicks >= 1.0:
			Economy.click(state, content)
			clicks -= 1.0
		while Economy.can_widen(state, content):
			Economy.widen(state, content)
		_spend(state, content)
		Economy.run_autobuyers(state, content)
		Economy.advance(state, content, step)
		Economy.add_time(state, step)
		Achievements.check(state, content)
		Economy.check_ending(state)
		if should_overflow(state, content):
			Economy.overflow(state, content)
			buy_firmware(state, content)
		elapsed += step


## Overflow once the Carry bonus has fully rippled in and the Overflow would at least double the Carry
## earned: after that the run slows down, and a new run gets further. Also Overflow once the register is
## full and Firmware allows no wider one, because then this run can't grow at all.
static func should_overflow(state: GameState, content: Content) -> bool:
	if state.ended or not Economy.can_overflow(state):
		return false
	if state.run_time >= Formulas.CARRY_RIPPLE_SECONDS and Economy.overflow_gain(state, content) >= state.total_carry:
		return true
	if not Economy.is_full(state):
		return false
	var next := Formulas.next_width(state.register_bits)
	return next < 0 or next > Economy.max_bits(state, content)


## Buys Wide bus nodes first (they open the next register width), then nodes that speed up the ×2
## milestones, then the cheapest node it can afford.
static func buy_firmware(state: GameState, content: Content) -> void:
	var priorities: Array = [FirmwareDef.Effect.WIDE_BUS, FirmwareDef.Effect.MILESTONE_STEP, -1]
	var bought := true
	while bought:
		bought = false
		for priority: int in priorities:
			for node: FirmwareDef in content.firmware:
				if priority >= 0 and node.effect != priority:
					continue
				if Economy.buy_firmware(state, content, node):
					bought = true
					break
			if bought:
				break


static func _spend(state: GameState, content: Content) -> void:
	var limit := INF
	var next := Formulas.next_width(state.register_bits)
	if next > 0 and next <= Economy.max_bits(state, content):
		limit = Economy.widen_cost(state) * SPEND_SHARE_WHILE_SAVING

	for upgrade: UpgradeDef in content.upgrades:
		if upgrade.cost <= limit and Economy.can_buy_upgrade(state, upgrade):
			Economy.buy_upgrade(state, upgrade)

	while Economy.clock_cost(state) <= limit and Economy.can_overclock(state):
		Economy.overclock(state)

	for _purchase: int in 200:
		var choice := -1
		for index: int in range(content.layers.size() - 1, -1, -1):
			if Economy.buy_count(state, content, index, Economy.BuyMode.ONE) == 0:
				continue
			if Economy.next_cost(state, content, index) > limit:
				continue
			choice = index
			break
		if choice < 0:
			return
		Economy.buy(state, content, choice, Economy.BuyMode.ONE)
