extends TestCase


func _content_with(achievements: Array[AchievementDef]) -> Content:
	var content := Fixtures.content()
	content.achievements = achievements
	content.index()
	return content


func test_unlocks_once_when_the_condition_is_met() -> void:
	var kilo := Fixtures.achievement(&"kilo", AchievementDef.Condition.PEAK_COUNT, 1000.0)
	var content := _content_with([kilo])
	var s := GameState.new()
	s.register_bits = 16
	check_eq(Achievements.check(s, content).size(), 0)
	s.peak_count = 1000.0
	check_eq(Achievements.check(s, content).size(), 1)
	check_eq(Achievements.check(s, content).size(), 0, "a second check must not unlock it again")
	check(s.achievements.has(&"kilo"), "the id is stored in the state")


func test_each_achievement_adds_one_percent() -> void:
	var a := Fixtures.achievement(&"a", AchievementDef.Condition.CLICKS, 1.0)
	var b := Fixtures.achievement(&"b", AchievementDef.Condition.CLICKS, 2.0)
	var content := _content_with([a, b])
	var s := GameState.new()
	s.total_clicks = 2
	Achievements.check(s, content)
	check_near(Economy.layer_rate(s, content, 0), 1.0 + 2.0 * Formulas.ACHIEVEMENT_BONUS, 1e-12)


func test_conditions() -> void:
	var s := GameState.new()
	s.register_bits = 32
	s.layer_bought[2] = 5
	s.clock_level = 3
	s.play_time = 3600.0
	s.upgrades.append(&"x")
	check(Achievements.is_met(s, Fixtures.achievement(&"bits", AchievementDef.Condition.REGISTER_BITS, 32.0)), "register width")
	check(not Achievements.is_met(s, Fixtures.achievement(&"bits64", AchievementDef.Condition.REGISTER_BITS, 64.0)), "register width too low")
	check(Achievements.is_met(s, Fixtures.achievement(&"layer", AchievementDef.Condition.LAYER_BOUGHT, 5.0, 3)), "layer bought")
	check(Achievements.is_met(s, Fixtures.achievement(&"clock", AchievementDef.Condition.CLOCK_LEVEL, 3.0)), "clock level")
	check(Achievements.is_met(s, Fixtures.achievement(&"time", AchievementDef.Condition.PLAY_TIME, 3600.0)), "play time")
	check(Achievements.is_met(s, Fixtures.achievement(&"ups", AchievementDef.Condition.UPGRADES, 1.0)), "upgrades")
	check(not Achievements.is_met(s, Fixtures.achievement(&"full", AchievementDef.Condition.REGISTER_FULL, 0.0)), "register not full")
	s.count = Formulas.register_cap(32)
	check(Achievements.is_met(s, Fixtures.achievement(&"full", AchievementDef.Condition.REGISTER_FULL, 0.0)), "register full")
