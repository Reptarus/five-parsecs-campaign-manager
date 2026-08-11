extends GdUnitTestSuite
## Out-of-alpha-1 modes are shown as COMING SOON, not hidden (Aug 8 2026)
##
## Co-op and Bug Hunt used to be hidden outright, and Tactics and Planetfall were
## never created at all. To an alpha tester that reads as "this app does not have
## those modes" — when all four are built, tested and shipping later. It also made
## the sprint's Test 8 (other-modes smoke) unrunnable from the menu at all.
##
## The subtle part, and the reason this suite exists: the buttons must stay ENABLED.
## A `disabled` Button emits no `pressed` signal in Godot, so it can never explain
## itself — which is the entire point of the change. Dimming is done with
## `modulate`, which does not touch input.
##
## gdUnit4 v6.0.3 compatible. NOTE: run with -c, never --headless (project rule).

const MENU_SCRIPT := "res://src/ui/screens/mainmenu/MainMenu.gd"
const MenuScene := preload("res://src/ui/screens/mainmenu/MainMenu.tscn")

const GATED := ["coop", "bug_hunt", "tactics", "planetfall"]


func _menu() -> Node:
	var m: Node = auto_free(MenuScene.instantiate())
	add_child(m)
	return m


func _buttons(m: Node) -> Dictionary:
	return {
		"coop": m.coop_campaign_button,
		"bug_hunt": m.bug_hunt_button,
		"tactics": m.tactics_button,
		"planetfall": m.planetfall_button,
	}


func test_every_gated_mode_button_exists() -> void:
	# Tactics and Planetfall are INJECTED, and used to be skipped entirely under
	# A1_BUILD. If injection regresses behind the flag they silently vanish again
	# and every assertion below would pass vacuously on a null.
	var by_key := _buttons(_menu())
	for key: String in GATED:
		assert_that(by_key[key]).override_failure_message(
			"gated mode button missing: %s" % key).is_not_null()


func test_gated_mode_buttons_are_visible() -> void:
	var by_key := _buttons(_menu())
	for key: String in GATED:
		var btn: Button = by_key[key]
		assert_bool(btn.visible).override_failure_message(
			"%s should be shown as coming-soon, not hidden" % key).is_true()


func test_gated_mode_buttons_stay_enabled_so_they_can_explain_themselves() -> void:
	# DETECTION-CRITICAL. Swapping the modulate dim for `disabled = true` looks
	# equivalent and reads better in a diff, but Godot emits no `pressed` on a
	# disabled Button — the tap would do nothing at all, which is a worse version of
	# the bug being fixed.
	var by_key := _buttons(_menu())
	for key: String in GATED:
		assert_bool((by_key[key] as Button).disabled).override_failure_message(
			"%s must stay enabled; a disabled Button emits no pressed signal" % key
		).is_false()


func test_gated_mode_buttons_are_dimmed_so_they_read_as_unavailable() -> void:
	var by_key := _buttons(_menu())
	for key: String in GATED:
		assert_float((by_key[key] as Button).modulate.a).override_failure_message(
			"%s should be visibly dimmed" % key).is_less(1.0)


func test_a_gated_button_does_not_navigate() -> void:
	# The rebind is the fix. If the real handler survived, tapping Bug Hunt under
	# A1_BUILD would route into a mode the alpha does not ship.
	var m := _menu()
	var by_key := _buttons(m)
	var handlers := {
		"coop": m._on_coop_campaign_pressed,
		"bug_hunt": m._on_bug_hunt_pressed,
		"tactics": m._on_tactics_pressed,
		"planetfall": m._on_planetfall_pressed,
	}
	for key: String in GATED:
		assert_bool((by_key[key] as Button).pressed.is_connected(handlers[key])) \
			.override_failure_message(
				"%s still navigates; the coming-soon rebind did not take" % key
			).is_false()


func test_a_gated_button_has_exactly_one_listener() -> void:
	# Neither zero (a dead tap) nor two (the note AND a navigation).
	var by_key := _buttons(_menu())
	for key: String in GATED:
		assert_int((by_key[key] as Button).pressed.get_connections().size()) \
			.override_failure_message("%s has the wrong listener count" % key) \
			.is_equal(1)


func test_every_gated_mode_has_its_own_blurb() -> void:
	# A generic "coming soon" wastes the moment. Each mode says what it IS, so the
	# popup advertises the roadmap instead of only refusing.
	var scr: GDScript = load(MENU_SCRIPT)
	var blurbs: Dictionary = scr.COMING_SOON_BLURBS
	for key: String in GATED:
		assert_bool(blurbs.has(key)).override_failure_message(
			"no coming-soon blurb for %s" % key).is_true()
		assert_int(str(blurbs[key]).length()).is_greater(40)
