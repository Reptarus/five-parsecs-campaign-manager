extends GdUnitTestSuite
## Android system Back must navigate, never silently quit (tablet QA T8-01, Aug 8 2026)
##
## On device, Back killed the app from any screen: no prompt, no navigation, process gone
## (`ps -A | grep fiveparsecs` empty afterwards). The cause was not missing code — it was
## `application/config/quit_on_go_back`, which defaults to TRUE and makes SceneTree quit
## before any handler can react. GameState._notification() had been flushing the campaign
## on NOTIFICATION_WM_GO_BACK_REQUEST all along, so nothing was lost; the app just left.
##
## Two things are pinned here, and the first matters most: the setting. Every line of the
## handler is dead while quit_on_go_back is true, so a future edit that drops that one
## line silently restores the bug with all the code still present and passing review.
##
## gdUnit4 v6.0.3 compatible. NOTE: run with -c, never --headless (project rule).

const RouterScript := preload("res://src/ui/screens/SceneRouter.gd")


func test_quit_on_go_back_is_disabled_in_project_settings() -> void:
	## The load-bearing line. Without it the handler never runs.
	assert_bool(ProjectSettings.get_setting("application/config/quit_on_go_back", true)) \
		.override_failure_message(
			"application/config/quit_on_go_back is enabled, so Android Back quits the app "
			+ "before SceneRouter can navigate. Every other assertion in this suite can "
			+ "pass with the bug fully present.")\
		.is_false()


func test_an_open_popup_is_closed_before_anything_else() -> void:
	## Ordering, not preference. Navigating out from under an open modal orphans it — a
	## bug this fix would have INTRODUCED, since previously the app died and the modal
	## never outlived the press.
	assert_str(RouterScript.decide_back_action(true, true, 1000, 900)).is_equal("popup")
	assert_str(RouterScript.decide_back_action(true, false, 1000, 900)).is_equal("popup")


func test_back_navigates_whenever_there_is_history() -> void:
	assert_str(RouterScript.decide_back_action(false, true, 1000, 0)).is_equal("back")
	# Even with a quit already armed: the player moved somewhere, so Back means "go back".
	assert_str(RouterScript.decide_back_action(false, true, 1000, 900)).is_equal("back")


func test_root_screen_requires_two_presses_to_quit() -> void:
	## First press arms and tells the player; a second within the window leaves.
	assert_str(RouterScript.decide_back_action(false, false, 1000, 0)).is_equal("arm_quit")

	var window: int = RouterScript.BACK_TO_QUIT_WINDOW_MS
	# Second press inside the window.
	assert_str(RouterScript.decide_back_action(false, false, 1000 + window - 1, 1000)) \
		.is_equal("quit")
	# ...and exactly at the boundary, which is inclusive.
	assert_str(RouterScript.decide_back_action(false, false, 1000 + window, 1000)) \
		.is_equal("quit")


func test_a_stale_arm_does_not_quit() -> void:
	## The failure that would actually hurt: press Back once, put the tablet down, come
	## back an hour later, press Back to close a menu, and the app exits without warning.
	var window: int = RouterScript.BACK_TO_QUIT_WINDOW_MS
	assert_str(RouterScript.decide_back_action(false, false, 1000 + window + 1, 1000)) \
		.override_failure_message("a press outside the window must re-arm, not quit")\
		.is_equal("arm_quit")


func test_router_subscribes_to_the_notification() -> void:
	## The decision table above is worth nothing if nothing calls it. Guards the wire.
	var f := FileAccess.open("res://src/ui/screens/SceneRouter.gd", FileAccess.READ)
	assert_that(f).is_not_null()
	var src := f.get_as_text()
	assert_str(src).contains("func _notification(what: int) -> void:")
	assert_str(src).contains("NOTIFICATION_WM_GO_BACK_REQUEST")
	assert_str(src).contains("_handle_go_back()")

func test_empty_history_falls_back_to_the_dashboard_mid_campaign() -> void:
	## N2 (Aug 8 device QA): Back from a mid-turn World Phase landed on the MAIN MENU.
	## Re-driven Aug 9 and it did not reproduce through the direct path, so the route
	## that emptied the history is unidentified — but the fallback itself is wrong on
	## its own terms, and history CAN legitimately run dry (clear_history() on
	## new-campaign/return-to-menu, max_history_size trimming, no consecutive dupes).
	## Dropping a player out of a campaign they are mid-turn in is never the right answer.
	var router := get_node_or_null("/root/SceneRouter")
	var gs := get_node_or_null("/root/GameState")
	assert_that(router).is_not_null()
	assert_that(gs).is_not_null()

	var had_campaign: bool = gs.has_active_campaign()
	var saved_scene: String = router.current_scene

	router.current_scene = "campaign_turn_controller"
	if had_campaign:
		assert_str(router.empty_history_fallback()).override_failure_message(
			"A campaign is loaded and Back ran out of history — the campaign's home " +
			"screen is the answer, not the main menu."
		).is_equal("campaign_dashboard")
	else:
		# No campaign loaded in this test environment: the main menu IS correct, and
		# asserting the campaign branch would be asserting the fixture, not the rule.
		assert_str(router.empty_history_fallback()).is_equal("main_menu")

	# Already on the dashboard with no history: do not "go back" to where we are.
	router.current_scene = "campaign_dashboard"
	assert_str(router.empty_history_fallback()).override_failure_message(
		"Back on the dashboard with empty history must not resolve to the dashboard."
	).is_equal("main_menu")

	router.current_scene = saved_scene
