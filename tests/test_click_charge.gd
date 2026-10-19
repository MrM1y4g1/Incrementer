extends TestCase


## Clicks evenly at PER_SECOND for SECONDS, in the game's 20 ticks a second.
func _click_for(s: GameState, content: Content, per_second: float, seconds: float) -> void:
	var clicks := 0.0
	for _tick: int in roundi(seconds * 20.0):
		clicks += per_second / 20.0
		while clicks >= 1.0:
			Economy.click(s, content)
			clicks -= 1.0
		Economy.advance(s, content, 0.05)


func test_the_charge_follows_how_fast_the_player_clicks() -> void:
	var content := Fixtures.content()
	var s := GameState.new()
	_click_for(s, content, 10.0, 30.0)
	check_near(s.charge, 0.5, 0.02, "10 a second holds it half full")
	check_near(s.best_click_rate, 10.0, 1.0, "the fastest click rate")
	check_near(Economy.charge_bonus(s), 2.0 / 3.0, 0.06, "+67% a click")
	var slow := GameState.new()
	_click_for(slow, content, 4.0, 30.0)
	check(slow.charge < Formulas.CHARGE_FROM, "4 a second stays below the bonus: %f" % slow.charge)
	check_eq(Economy.charge_bonus(slow), 0.0)


func test_the_bonus_starts_above_five_a_second() -> void:
	var content := Fixtures.content()
	var s := GameState.new()
	s.charge = Formulas.CHARGE_FROM
	check_eq(Economy.click_value(s, content), 1.0, "no bonus yet")
	s.charge = 0.625
	check_near(Economy.click_value(s, content), 2.0, 1e-9, "halfway to full: +100%")
	s.charge = 0.999
	check_near(Economy.click_value(s, content), 3.0, 0.01, "nearly full: nearly +200%")
	s.charge = 0.625
	check_near(Economy.click(s, content), 2.0, 1e-9, "a click returns what it was worth")
	check_near(s.count, 2.0, 1e-9)


func test_the_charge_fades_when_the_clicking_stops() -> void:
	var content := Fixtures.content()
	var s := GameState.new()
	s.charge = 0.8
	Economy.advance(s, content, Formulas.CHARGE_SECONDS)
	check_near(s.charge, 0.8 / exp(1.0), 1e-9)


func test_a_person_never_flies_too_close() -> void:
	var content := Fixtures.content()
	var s := GameState.new()
	_click_for(s, content, 18.0, 120.0)
	check_eq(s.icarus_falls, 0, "18 a second for two minutes")
	check_near(s.charge, 0.9, 0.03, "nearly full")
	# A slow frame delivers a second of clicks at once, then the ticks catch up.
	var hitch := GameState.new()
	_click_for(hitch, content, 12.0, 30.0)
	for _click: int in 12:
		Economy.click(hitch, content)
	for _tick: int in 20:
		Economy.advance(hitch, content, 0.05)
	check_eq(hitch.icarus_falls, 0, "one burst isn't a macro")


func test_a_macro_flies_too_close_to_the_sun() -> void:
	var content := Fixtures.content()
	var s := GameState.new()
	_click_for(s, content, 30.0, 6.0)
	check_eq(s.icarus_falls, 1, "caught after about 4 seconds")
	check_eq(s.events.filter(func(event: Array) -> bool: return event[1] == "icarus").size(), 1, "and logged")
	check(s.total_clicks < 150, "clicks stop counting once caught: %d" % s.total_clicks)
	check_eq(s.charge, 0.0, "the charge melted")
	check(s.burnout > 0.0, "the Icarus stage")
	var count := s.count
	check_eq(Economy.click_value(s, content), 0.0, "a click is worth nothing")
	check_eq(Economy.click(s, content), 0.0)
	check_eq(s.count, count, "and adds nothing")
	var achievement := Fixtures.achievement(&"icarus", AchievementDef.Condition.ICARUS_FALLS, 1.0)
	check(Achievements.is_met(s, achievement), "the Icarus achievement")
	Economy.advance(s, content, Formulas.ICARUS_SECONDS)
	check_eq(Economy.click(s, content), 1.0, "clicks work again once it's over")


func test_the_records_are_saved_but_the_charge_is_not() -> void:
	var s := GameState.new()
	s.charge = 0.8
	s.click_rate = 9.0
	s.burnout = 3.0
	s.best_click_rate = 13.5
	s.icarus_falls = 2
	var t: GameState = SaveCodec.decode(SaveCodec.encode(s, 1.0))["state"]
	check_eq([t.best_click_rate, t.icarus_falls], [13.5, 2])
	check_eq([t.charge, t.click_rate, t.burnout], [0.0, 0.0, 0.0], "a loaded game starts uncharged")


func test_version_6_saves_load_with_empty_records() -> void:
	var data := GameState.new().to_dict()
	for key: String in ["best_click_rate", "icarus_falls"]:
		data.erase(key)
	data["faults_refreshed"] = 12
	var migrated := SaveCodec.migrate({"version": 6, "state": data.duplicate()}, 6)
	check(not (migrated["state"] as Dictionary).has("faults_refreshed"), "the refreshed count is dropped")
	var loaded := SaveCodec.decode(JSON.stringify({"version": 6, "saved_at": 1.0, "state": data}))
	check(not loaded.is_empty(), "a version 6 save must decode")
	var s: GameState = loaded["state"]
	check_eq([s.best_click_rate, s.icarus_falls], [0.0, 0])


func test_the_autoplayer_clicks_too_slowly_for_a_bonus() -> void:
	var content := Fixtures.content()
	var s := GameState.new()
	AutoPlayer.play(s, content, 600.0)
	check_eq(Economy.charge_bonus(s), 0.0, "4 a second keeps the pacing checks free of the charge")
	check_eq(s.icarus_falls, 0)
