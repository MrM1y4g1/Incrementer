extends TestCase


func _content() -> Content:
	var content := Fixtures.content()
	content.upgrades = [Fixtures.upgrade(&"press", UpgradeDef.Effect.CLICK_MULTIPLIER, 2.0, 50.0)]
	content.index()
	return content


func test_a_new_game_starts_with_counting() -> void:
	var s := GameState.new()
	check_eq(Tutorial.next_step(s, _content()), "count")
	Tutorial.mark_shown(s, "count")
	check_eq(Tutorial.next_step(s, _content()), "", "nothing else is due yet")
	check(not Tutorial.is_done("count", s), "until the first click")
	Economy.click(s, _content())
	check(Tutorial.is_done("count", s), "done")


func test_steps_come_when_what_they_explain_appears() -> void:
	var content := _content()
	var s := GameState.new()
	Tutorial.mark_shown(s, "count")
	s.total_clicks = 10
	s.count = 10.0
	check_eq(Tutorial.next_step(s, content), "incrementer", "the first Incrementer is affordable")
	Tutorial.mark_shown(s, "incrementer")
	Economy.buy(s, content, 0, Economy.BuyMode.ONE)
	check(Tutorial.is_done("incrementer", s), "bought")
	s.count = 50.0
	check_eq(Tutorial.next_step(s, content), "upgrade", "the first upgrade is affordable")
	Tutorial.mark_shown(s, "upgrade")
	s.register_bits = 16
	s.wearing[7] = 0.0
	check_eq(Tutorial.next_step(s, content), "wear")
	Tutorial.mark_shown(s, "wear")
	check(Tutorial.is_done("wear", s), "nothing to do: the card only warns")
	s.wearing.clear()
	s.bad_bits.append(7)
	check_eq(Tutorial.next_step(s, content), "bad bit")
	Tutorial.mark_shown(s, "bad bit")
	check_eq(Tutorial.next_step(s, content), "", "every step shown")


func test_each_step_shows_once() -> void:
	var s := GameState.new()
	Tutorial.mark_shown(s, "count")
	Tutorial.mark_shown(s, "count")
	check_eq(s.tutorial, ["count"])
	check_eq(s.events.size(), 1, "logged once")


func test_skipping_shows_no_more_steps() -> void:
	var s := GameState.new()
	s.wearing[3] = 0.0
	Tutorial.skip(s)
	check_eq(Tutorial.next_step(s, _content()), "")
	check_eq(s.events[-1][1], "tutorial")
	check_eq(s.events[-1][2], "skipped")


func test_the_basics_wait_for_the_first_run_only() -> void:
	var content := _content()
	var s := GameState.new()
	s.overflows = 1
	s.count = 1000.0
	check_eq(Tutorial.next_step(s, content), "", "a player who has Overflowed knows the basics")
	s.register_bits = 16
	s.wearing[2] = 0.0
	check_eq(Tutorial.next_step(s, content), "wear", "worn bits still explain themselves")


func test_the_tutorial_survives_a_save_and_load() -> void:
	var s := GameState.new()
	Tutorial.mark_shown(s, "count")
	Tutorial.mark_shown(s, "wear")
	var t: GameState = SaveCodec.decode(SaveCodec.encode(s, 1.0))["state"]
	check_eq(t.tutorial, ["count", "wear"])
