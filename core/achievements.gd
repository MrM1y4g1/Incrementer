class_name Achievements
extends RefCounted
## Checks achievement conditions against the state. Each unlocked achievement adds
## Formulas.ACHIEVEMENT_BONUS (1%) to all output.


static func is_met(state: GameState, achievement: AchievementDef) -> bool:
	match achievement.condition:
		AchievementDef.Condition.PEAK_COUNT:
			return state.peak_count >= achievement.threshold
		AchievementDef.Condition.REGISTER_BITS:
			return state.register_bits >= int(achievement.threshold)
		AchievementDef.Condition.REGISTER_FULL:
			return Economy.is_full(state)
		AchievementDef.Condition.LAYER_BOUGHT:
			var i := achievement.layer_tier - 1
			return i >= 0 and i < GameState.LAYER_COUNT and state.layer_bought[i] >= int(achievement.threshold)
		AchievementDef.Condition.CLICKS:
			return state.total_clicks >= int(achievement.threshold)
		AchievementDef.Condition.UPGRADES:
			return state.upgrades.size() >= int(achievement.threshold)
		AchievementDef.Condition.CLOCK_LEVEL:
			return state.clock_level >= int(achievement.threshold)
		AchievementDef.Condition.PLAY_TIME:
			return state.play_time >= achievement.threshold
	return false


## Unlocks every achievement whose condition is now met and returns the new ones.
static func check(state: GameState, content: Content) -> Array[AchievementDef]:
	var unlocked: Array[AchievementDef] = []
	for achievement: AchievementDef in content.achievements:
		if state.achievements.has(achievement.id):
			continue
		if is_met(state, achievement):
			state.achievements.append(achievement.id)
			unlocked.append(achievement)
	if not unlocked.is_empty():
		state.effects_dirty = true
	return unlocked
