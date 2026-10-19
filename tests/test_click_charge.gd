extends TestCase


## Clicks evenly at `per_second` for `seconds`, in the game's 20 ticks a second.
func _click_for(s: GameState, content: Content, per_second: float, seconds: float) -> void:
	var clicks := 0.0
	for _tick: int in roundi(seconds * 20.0):
		clicks += per_second / 20.0
		while clicks >= 1.0:
			Economy.click(s, content)
			clicks -= 1.0
		Economy.advance(s, content, 0.05)


func _logged(s: GameState, kind: String) -> int:
	return s.events.filter(func(event: Array) -> bool: return event[1] == kind).size()


func test_clicking_faster_than_the_drain_charges_the_battery() -> void:
	var content := Fixtures.content()
	var s := GameState.new()
	_click_for(s, content, 10.0, 5.0)
	check_near(s.charge, 0.5, 0.03, "10 a second fills half in 5 seconds")
	check_near(s.best_click_rate, 10.0, 1.0, "the fastest click rate")
	var slow := GameState.new()
	_click_for(slow, content, 3.0, 20.0)
	check(slow.charge < 0.02, "3 a second never builds: %f" % slow.charge)


func test_the_charge_adds_to_every_click() -> void:
	var content := Fixtures.content()
	var s := GameState.new()
	check_eq(Economy.click_value(s, content), 1.0)
	s.charge = 0.5
	check_eq(Economy.click_value(s, content), 2.0, "half charged: +100%")
	s.charge = 1.0
	check_eq(Economy.charge_bonus(s), Formulas.CHARGE_BONUS_MAX)
	check_eq(Economy.click_value(s, content), 3.0, "full: +200%")
	check_eq(Economy.click(s, content), 3.0, "a click returns what it was worth")
	check_eq(s.count, 3.0)


func test_the_charge_drains_when_the_clicking_stops() -> void:
	var content := Fixtures.content()
	var s := GameState.new()
	s.charge = 1.0
	Economy.advance(s, content, 7.5)
	check_near(s.charge, 0.5, 1e-9, "half gone in 7.5 seconds")
	Economy.advance(s, content, 10.0)
	check_eq(s.charge, 0.0)


func test_a_full_charge_is_ultra_until_it_drops() -> void:
	var content := Fixtures.content()
	var s := GameState.new()
	_click_for(s, content, 12.0, 8.0)
	check(s.ultra, "full after 8 seconds at 12 a second")
	check_eq(s.ultras, 1)
	_click_for(s, content, 12.0, 5.0)
	check_eq(s.ultras, 1, "staying full is one ULTRA")
	Economy.advance(s, content, 0.5)
	check(s.ultra, "a short pause doesn't end it")
	Economy.advance(s, content, 2.0)
	check(not s.ultra, "a longer one does")
	_click_for(s, content, 12.0, 3.0)
	check_eq(s.ultras, 2, "filling it again is another")
	check_eq(_logged(s, "ultra"), 2, "and both are in the run log")


func test_clicking_like_a_macro_flies_too_close_to_the_sun() -> void:
	var content := Fixtures.content()
	var s := GameState.new()
	_click_for(s, content, 30.0, 4.0)
	check_eq(s.icarus_falls, 1, "caught")
	check_eq(_logged(s, "icarus"), 1, "and logged")
	check_eq(s.total_clicks, 120, "every click still counted")
	check_eq(s.charge, 0.0, "the charge melted and can't build")
	check(not s.ultra, "no ULTRA")
	check(s.burnout > 0.0, "for a while")
	var achievement := Fixtures.achievement(&"icarus", AchievementDef.Condition.ICARUS_FALLS, 1.0)
	check(Achievements.is_met(s, achievement), "the Icarus achievement")
	Economy.advance(s, content, Formulas.ICARUS_SECONDS)
	_click_for(s, content, 10.0, 2.0)
	check(s.charge > 0.15, "it builds again once the burnout is over: %f" % s.charge)


func test_a_fast_person_is_never_taken_for_a_macro() -> void:
	var content := Fixtures.content()
	var s := GameState.new()
	_click_for(s, content, 15.0, 120.0)
	check_eq(s.icarus_falls, 0, "15 a second for two minutes")
	# A slow frame delivers a second's worth of clicks at once, then the ticks catch up.
	for _click: int in 25:
		Economy.click(s, content)
	for _tick: int in 20:
		Economy.advance(s, content, 0.05)
	check_eq(s.icarus_falls, 0, "one burst isn't a macro")


func test_the_records_are_saved_but_the_charge_is_not() -> void:
	var s := GameState.new()
	s.charge = 0.8
	s.click_rate = 9.0
	s.ultra = true
	s.burnout = 3.0
	s.best_click_rate = 13.5
	s.ultras = 4
	s.icarus_falls = 2
	var t: GameState = SaveCodec.decode(SaveCodec.encode(s, 1.0))["state"]
	check_eq([t.best_click_rate, t.ultras, t.icarus_falls], [13.5, 4, 2])
	check_eq([t.charge, t.click_rate, t.ultra, t.burnout], [0.0, 0.0, false, 0.0], "a loaded game starts uncharged")


func test_version_6_saves_load_with_empty_records() -> void:
	var data := GameState.new().to_dict()
	for key: String in ["best_click_rate", "ultras", "icarus_falls"]:
		data.erase(key)
	data["faults_refreshed"] = 12
	var migrated := SaveCodec.migrate({"version": 6, "state": data.duplicate()}, 6)
	check(not (migrated["state"] as Dictionary).has("faults_refreshed"), "the refreshed count is dropped")
	var loaded := SaveCodec.decode(JSON.stringify({"version": 6, "saved_at": 1.0, "state": data}))
	check(not loaded.is_empty(), "a version 6 save must decode")
	var s: GameState = loaded["state"]
	check_eq([s.best_click_rate, s.ultras, s.icarus_falls], [0.0, 0, 0])


func test_the_autoplayer_clicks_too_slowly_to_charge() -> void:
	var content := Fixtures.content()
	var s := GameState.new()
	AutoPlayer.play(s, content, 600.0)
	check(s.charge < 0.05, "4 a second keeps the pacing checks free of the charge: %f" % s.charge)
	check_eq(s.ultras, 0)
