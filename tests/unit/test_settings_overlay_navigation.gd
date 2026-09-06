extends GdUnitTestSuite
## T11-27 — every navigation OUT of the Settings screen must unpause the tree FIRST.
##
## THE DEFECT (device, deploy #19). In-campaign, the gear opens SettingsOverlay, which
## ends _show_settings_overlay() with `get_tree().paused = true`
## (src/autoload/SettingsOverlay.gd:203). The overlay's own controls keep responding
## because the CanvasLayer sets PROCESS_MODE_ALWAYS (:49) — so the four legal buttons
## and "Browse Expansions" looked alive and did nothing at all.
##
## WHY. TransitionManager declares no process_mode, so it INHERITS the pause. Its fade
## uses create_tween(), which "automatically binds it to the current node", and the
## default TWEEN_PAUSE_BOUND makes the tween's pausing "dependent on the bound node"
## (Godot 4.6 docs). A paused-inherit node's tween never advances, so
## `await _tween.finished` (TransitionManager.gd:284) never returns and the
## change_scene_to_file() below it is never reached. The 5s safety timer DOES fire,
## because create_timer's `process_always` defaults to true — which is why the only
## trace on device was a lone "Safety timeout" line, and why it was in LOGCAT rather
## than user://logs/godot.log (push_warning/push_error never reach that file).
##
## WHY PROCESS_MODE_ALWAYS ON TransitionManager IS NOT THE FIX: `paused` is a property
## of the SceneTree, not of current_scene, so it survives change_scene_to_file() — the
## player would land on a frozen destination instead of a dead button.
##
## The screen's author had already diagnosed this exact trap for the DECORATIVE fade
## (SettingsScreen.gd:287-294, "a tree-bound tween does NOT advance while
## get_tree().paused is true") and fixed one call site of two. These cases pin the
## other one.
##
## WHAT IS ASSERTED: the ORDER. `back_requested` (which runs
## _hide_settings_overlay() -> paused = false, SettingsOverlay.gd:212) must be emitted
## BEFORE the route call. Asserting only "it routed" would pass with the defect live.

const SettingsScreenScript = preload("res://src/ui/screens/settings/SettingsScreen.gd")

## Ordered trace of what happened: "back" for back_requested, "route:<key>" for a
## navigation. A set-membership assertion cannot see this defect; the sequence can.
var _log: Array[String] = []
var _routes: Array[Dictionary] = []


## Mirror the PRODUCTION construction path exactly: SettingsOverlay builds the panel
## with .new() and sets overlay_mode BEFORE add_child, because _ready() -> _build_ui()
## branches on it (SettingsScreen.gd:103/:134). Instantiating the .tscn instead would
## also re-enter _enter_tree()'s window.ini restore, which overlay_mode short-circuits.
func _make_screen(overlay: bool) -> SettingsScreen:
	_log = []
	_routes = []
	var screen: SettingsScreen = auto_free(SettingsScreenScript.new())
	screen.overlay_mode = overlay
	screen.route_override = func(key: String, ctx: Dictionary, add_history: bool) -> void:
		_log.append("route:" + key)
		_routes.append({"key": key, "ctx": ctx, "add_history": add_history})
	screen.back_requested.connect(func() -> void: _log.append("back"))
	add_child(screen)
	await await_idle_frame()
	return screen


func _find_button(node: Node, label: String) -> Button:
	if node is Button and (node as Button).text == label:
		return node as Button
	for child in node.get_children():
		var found := _find_button(child, label)
		if found != null:
			return found
	return null


func test_browse_expansions_unpauses_before_it_routes() -> void:
	var screen := await _make_screen(true)
	var btn := _find_button(screen, "Browse Expansions")
	assert_object(btn).override_failure_message(
		"The 'Browse Expansions' button was not built, so this case proves nothing. "
		+ "_build_expansions_section() returns early when /root/DLCManager is absent."
	).is_not_null()
	btn.pressed.emit()
	await await_idle_frame()
	await await_idle_frame()

	assert_array(_log).override_failure_message(
		"Expected back_requested BEFORE the route. Got %s. With the defect live the "
		% [_log] + "route fires while the tree is still paused and the bound fade "
		+ "tween can never finish, so the button is dead."
	).is_equal(["back", "route:store"])


func test_a_legal_document_button_unpauses_before_it_routes() -> void:
	var screen := await _make_screen(true)
	var btn := _find_button(screen, "Privacy Policy")
	assert_object(btn).is_not_null()
	btn.pressed.emit()
	await await_idle_frame()
	await await_idle_frame()

	assert_array(_log).is_equal(["back", "route:legal_viewer"])
	# The context must survive the reorder — this is what the viewer reads.
	assert_str(str(_routes[0]["ctx"].get("file", ""))).is_equal(
		"res://data/legal/privacy_policy.md")
	assert_str(str(_routes[0]["ctx"].get("title", ""))).is_equal("Privacy Policy")


## The delete-all-data path routes to main_menu with add_history FALSE (the EULA must
## re-trigger and Back must not walk into a wiped campaign). Driven directly rather
## than through its ConfirmationDialog: the dialog is a separate Window whose
## confirmation is not the behaviour under test, and this asserts the same helper the
## button's lambda calls.
func test_the_main_menu_route_unpauses_first_and_keeps_add_history_false() -> void:
	var screen := await _make_screen(true)
	screen._navigate_from_settings("main_menu", {}, false)
	await await_idle_frame()
	await await_idle_frame()

	assert_array(_log).is_equal(["back", "route:main_menu"])
	assert_bool(_routes[0]["add_history"]).is_false()


## The standalone (non-overlay) screen must NOT emit back_requested — nothing is
## listening, the tree was never paused, and emitting it would be a behaviour change
## for the MainMenu -> Settings path that already worked.
func test_scene_mode_routes_without_emitting_back_requested() -> void:
	var screen := await _make_screen(false)
	var btn := _find_button(screen, "Browse Expansions")
	assert_object(btn).is_not_null()
	btn.pressed.emit()
	await await_idle_frame()

	assert_array(_log).is_equal(["route:store"])


## The order-independent half of the fix: whatever navigates, the overlay unpauses.
## Set and cleared inside one synchronous call so a failure cannot leave the gdUnit
## tree paused for every suite that follows.
func test_hide_settings_overlay_unpauses_the_tree() -> void:
	var overlay := get_node_or_null("/root/SettingsOverlay")
	assert_object(overlay).override_failure_message(
		"SettingsOverlay autoload missing — the guard cannot be verified."
	).is_not_null()

	var was_paused := get_tree().paused
	get_tree().paused = true
	overlay._hide_settings_overlay()
	var after := get_tree().paused
	get_tree().paused = was_paused

	assert_bool(after).override_failure_message(
		"_hide_settings_overlay() must clear SceneTree.paused; it is the only thing "
		+ "that lets a bound fade tween advance afterwards."
	).is_false()
