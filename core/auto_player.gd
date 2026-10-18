class_name AutoPlayer
extends RefCounted
## A simple scripted player, used for screenshot captures and the balance simulator.
## Each step it clicks, widens the register when it can, then spends: upgrades, the clock and layers,
## highest layer first, while saving up for the next register width.

## While saving for a wider register, only purchases cheaper than this share of its cost are allowed.
const SPEND_SHARE_WHILE_SAVING := 0.1


static func play(state: GameState, content: Content, seconds: float, step: float = 0.25, clicks_per_second: float = 4.0) -> void:
	var elapsed := 0.0
	var clicks := 0.0
	while elapsed < seconds:
		clicks += clicks_per_second * step
		while clicks >= 1.0:
			Economy.click(state, content)
			clicks -= 1.0
		if Economy.can_widen(state):
			Economy.widen(state)
		_spend(state, content)
		Economy.advance(state, content, step)
		state.play_time += step
		Achievements.check(state, content)
		elapsed += step


static func _spend(state: GameState, content: Content) -> void:
	var limit := INF
	var next := Formulas.next_width(state.register_bits)
	if next > 0 and next <= Economy.MAX_BITS_WITHOUT_FIRMWARE:
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
