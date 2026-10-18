class_name AutoPlayer
extends RefCounted
## A simple scripted player, used for screenshot captures now and the balance simulator later (M2, M4).
## Each step it clicks, widens the register when it can, and buys the highest layer it can afford
## while saving up for the next register width.

## Purchases cheaper than this share of the next widen cost are allowed while saving.
const SPEND_SHARE_WHILE_SAVING := 0.1


static func play(state: GameState, layers: Array[LayerDef], seconds: float, step: float = 0.25, clicks_per_second: float = 4.0) -> void:
	var elapsed := 0.0
	var clicks := 0.0
	while elapsed < seconds:
		clicks += clicks_per_second * step
		while clicks >= 1.0:
			Economy.click(state)
			clicks -= 1.0
		if Economy.can_widen(state):
			Economy.widen(state)
		_buy_layers(state, layers)
		Economy.advance(state, layers, step)
		state.play_time += step
		elapsed += step


static func _buy_layers(state: GameState, layers: Array[LayerDef]) -> void:
	var limit := INF
	var next := Formulas.next_width(state.register_bits)
	if next > 0 and next <= Economy.MAX_BITS_WITHOUT_FIRMWARE:
		limit = Economy.widen_cost(state) * SPEND_SHARE_WHILE_SAVING
	for _purchase: int in 200:
		var choice := -1
		for index: int in range(layers.size() - 1, -1, -1):
			if Economy.buy_count(state, layers, index, Economy.BuyMode.ONE) == 0:
				continue
			if Economy.next_cost(state, layers, index) > limit:
				continue
			choice = index
			break
		if choice < 0:
			return
		Economy.buy(state, layers, choice, Economy.BuyMode.ONE)
