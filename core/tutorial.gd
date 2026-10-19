class_name Tutorial
extends RefCounted
## The tutorial: a short explanation the first time each of these happens, while the game is paused.
##   count        a new game: press Increment
##   incrementer  the first Incrementer is affordable
##   upgrade      the first upgrade is affordable
##   wear         the first bit starts to wear out (nothing to do: it warns what's coming)
##   bad bit      the first bit goes bad
## Each step shows once per save; GameState.tutorial lists the steps already shown. The UI decides when it
## can show one (not over another screen) and pauses the game while it's open.

const STEPS: PackedStringArray = ["count", "incrementer", "upgrade", "wear", "bad bit"]
## The steps for things every player who has played before already knows.
const BASICS: Array[String] = ["count", "incrementer", "upgrade"]


## The first step that is due and hasn't been shown, or "" if there is none.
static func next_step(state: GameState, content: Content) -> String:
	for step: String in STEPS:
		if not state.tutorial.has(step) and is_due(step, state, content):
			return step
	return ""


## True when what the step explains is in front of the player right now.
static func is_due(step: String, state: GameState, content: Content) -> bool:
	match step:
		"count":
			return state.overflows == 0 and state.total_clicks == 0 and state.total_produced == 0.0
		"incrementer":
			return state.overflows == 0 and not content.layers.is_empty() and state.layer_bought[0] == 0 \
				and Economy.buy_count(state, content, 0, Economy.BuyMode.ONE) > 0
		"upgrade":
			if state.overflows > 0 or not state.upgrades.is_empty():
				return false
			for upgrade: UpgradeDef in content.upgrades:
				if Economy.can_buy_upgrade(state, upgrade):
					return true
			return false
		"wear":
			return not state.wearing.is_empty()
		"bad bit":
			return not state.bad_bits.is_empty()
	return false


## True once the player has done what the step asks, so its hint can go.
static func is_done(step: String, state: GameState) -> bool:
	match step:
		"count":
			return state.total_clicks > 0 or state.layer_bought[0] > 0 or state.overflows > 0
		"incrementer":
			return state.layer_bought[0] > 0 or state.overflows > 0
		"upgrade":
			return not state.upgrades.is_empty() or state.overflows > 0
		"bad bit":
			return state.bad_bits.is_empty()
	return true


## Marks a step as shown, and logs it.
static func mark_shown(state: GameState, step: String) -> void:
	if state.tutorial.has(step):
		return
	state.tutorial.append(step)
	state.record("tutorial", step)


## Marks every step as shown, so no more appear in this save.
static func skip(state: GameState) -> void:
	for step: String in STEPS:
		if not state.tutorial.has(step):
			state.tutorial.append(step)
	state.record("tutorial", "skipped")
