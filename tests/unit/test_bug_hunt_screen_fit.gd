extends GdUnitTestSuite
## Bug Hunt screens on a phone and a tablet (Sprint U screen pass, 2026-10-28).
##
## Captured with capture_modes.gd -- mode=bug_hunt at 2560x1600 and 393x851. Every
## creation step, all three turn stages and the Battle Card scrolled SIDEWAYS on a phone:
## seven panel scrolls left the horizontal axis on AUTO while holding unwrapped titles, a
## 420 px CheckButton and rows of fixed text. verify_layout cannot see that shape (content
## inside a scroll is allowed to overflow it), so these cases assert the render truth: no
## scroll shows a horizontal bar, and nothing ends past the screen edge.
##
## Each screen is filled by its own handlers (the wizard's panels, the Mission panel's
## Generate, the battle return through BugHuntTurnController._resume_after_battle with
## TacticalBattleUI's own result vocabulary), never a hand-built dictionary.

const CREATION_SCENE := "res://src/ui/screens/bug_hunt/BugHuntCreationUI.tscn"
const DASHBOARD_SCENE := "res://src/ui/screens/bug_hunt/BugHuntDashboard.tscn"
const TURN_SCENE := "res://src/ui/screens/bug_hunt/BugHuntTurnController.tscn"
const Populator := preload("res://tests/tools/screen_populator.gd")
const SaveDirGuard := preload("res://tests/fixtures/helpers/save_dir_guard.gd")

## Below the 338 px phone the sweeps use, so a fit here has margin.
const SMALL_PHONE := Vector2i(310, 551)
const EPS := 0.5

var _user_state: Dictionary
var _saved_campaign: Variant = null


func before_test() -> void:
	_user_state = SaveDirGuard.snapshot()
	var gs := get_tree().root.get_node_or_null("/root/GameState")
	_saved_campaign = gs.current_campaign if gs else null


func after_test() -> void:
	var gsm := get_tree().root.get_node_or_null("/root/GameStateManager")
	if gsm:
		gsm.set_temp_data("bug_hunt_battle_result", null)
		gsm.set_temp_data("bug_hunt_battle_context", null)
	var gs := get_tree().root.get_node_or_null("/root/GameState")
	if gs:
		gs.current_campaign = _saved_campaign
	SaveDirGuard.restore(_user_state)


func _settle() -> void:
	await get_tree().create_timer(0.3).timeout
	for _i in range(3):
		await get_tree().process_frame


## Every visible button and label with text must lie inside the screen's width.
func _offenders(root: Node, width: float) -> PackedStringArray:
	var bad := PackedStringArray()
	for kind in ["Button", "Label"]:
		for n in root.find_children("*", kind, true, false):
			var c := n as Control
			if not c.is_visible_in_tree() or str(c.get("text")).is_empty():
				continue
			var r: Rect2 = c.get_global_rect()
			if r.end.x > width + EPS or r.position.x < -EPS:
				bad.append("'%s' x=%.0f..%.0f" % [str(c.get("text")).left(40), r.position.x,
					r.end.x])
	return bad


## Scrolls showing a horizontal bar, i.e. a page that moves sideways under a finger.
func _sideways(root: Node, exempt: Array = []) -> PackedStringArray:
	var bad := PackedStringArray()
	for n in root.find_children("*", "ScrollContainer", true, false):
		var s := n as ScrollContainer
		if s in exempt or not s.is_visible_in_tree():
			continue
		if s.get_h_scroll_bar().visible:
			bad.append("scrolls sideways: %s" % str(root.get_path_to(s)))
	return bad


func _measure(into: PackedStringArray, where: String, root: Node, exempt: Array = [],
		width: int = SMALL_PHONE.x) -> void:
	for o in _offenders(root, float(width)):
		into.append("%s: %s" % [where, o])
	for s in _sideways(root, exempt):
		into.append("%s: %s" % [where, s])


func _in_viewport(size: Vector2i, scene: String) -> Node:
	var sv := SubViewport.new()
	sv.size = size
	add_child(sv)
	auto_free(sv)
	var inst: Node = (load(scene) as PackedScene).instantiate()
	sv.add_child(inst)
	await _settle()
	return inst


func test_every_creation_step_fits_a_small_phone() -> void:
	var ui: Node = await _in_viewport(SMALL_PHONE, CREATION_SCENE)
	var bad := PackedStringArray()
	for step in range(4):
		ui.coordinator.go_to_step(step)
		var panel: Node = ui.panels[step]
		match step:
			0:
				panel._name_edit.text = "Sweep fixture"
				panel._on_name_changed("Sweep fixture")
				panel._on_generate_regiment()
			1:
				panel._on_generate_squad()
			3:
				panel.refresh()
		await _settle()
		_measure(bad, "step %d" % (step + 1), ui)
	assert_array(bad).override_failure_message(
		"past a %d px phone:\n%s" % [SMALL_PHONE.x, "\n".join(bad)]).is_empty()


## The three stages as a turn reaches them: Special Assignments, the Mission once
## generated, and Post-Battle after the battle returns and the debrief is processed.
func test_every_turn_stage_fits_a_small_phone() -> void:
	Populator.new(get_tree().root)._pre_bug_hunt()
	var tc: Node = await _in_viewport(SMALL_PHONE, TURN_SCENE)
	for _i in range(8):
		await get_tree().process_frame
	# No exemptions: the phase strip used to be a sideways scroll that hid the stage on a
	# phone, and it now wraps like everything else.
	var ex: Array = []
	var bad := PackedStringArray()
	_measure(bad, "Special Assignments", tc, ex)
	# The rolled results now stay on screen with the footer (they used to be skipped
	# past straight into the Mission), so that page is measured too.
	tc.panels[0]._on_roll_all()
	await _settle()
	_measure(bad, "Special Assignments rolled", tc, ex)
	tc.panels[0].complete()
	await _settle()
	var mp: Node = tc.panels[1]
	mp._generate_mission()
	await _settle()
	_measure(bad, "Mission", tc, ex)
	mp._mission_context["participant_ids"] = mp._participant_ids.duplicate()
	mp._persist_stamped_mission()
	tc._resume_after_battle(_battle_result(tc.campaign))
	await _settle()
	_measure(bad, "Post-Battle", tc, ex)
	tc.panels[2]._process_post_battle()
	await _settle()
	_measure(bad, "Post-Battle receipt", tc, ex)
	assert_array(bad).override_failure_message(
		"past a %d px phone:\n%s" % [SMALL_PHONE.x, "\n".join(bad)]).is_empty()


## TacticalBattleUI's own vocabulary for a played battle (its result_dict), with the
## first main character down, so the normalizer derives the casualty itself.
func _battle_result(campaign: Resource) -> Dictionary:
	var first: Dictionary = {}
	for mc in campaign.main_characters:
		if mc is Dictionary:
			first = mc
			break
	return {
		"victory": true, "won": true, "held_field": true, "rounds_fought": 5,
		"crew_casualties": 1,
		"crew_casualties_data": [{"id": str(first.get("id", "")),
			"name": str(first.get("name", ""))}],
		"crew_injuries": 0, "crew_injuries_data": [],
		"enemies_defeated_count": 4, "auto_resolved": false}


## The battle screen's opening modal in Bug Hunt mode: the Battle Card, the deployment
## card and the checklist, reached the way a launch reaches it (the Mission panel's own
## Launch, then the companion-level chooser). It scrolled sideways on a phone, and the
## card's rules text was cut mid-word at the screen edge.
func test_the_bug_hunt_battle_card_fits_a_small_phone() -> void:
	Populator.new(get_tree().root)._pre_bug_hunt()
	var tc: Node = await _in_viewport(SMALL_PHONE, TURN_SCENE)
	for _i in range(8):
		await get_tree().process_frame
	tc.panels[0].complete()
	await _settle()
	tc.panels[1]._generate_mission()
	await _settle()
	# The Launch button's own path, with SceneRouter held out so it stamps the mission
	# and leaves the battle context in temp data without changing scene.
	var root := get_tree().root
	var held: Array = []
	for n in ["SceneRouter", "NotificationManager"]:
		var node: Node = root.get_node_or_null(n)
		if node:
			root.remove_child(node)
			held.append(node)
	tc.panels[1]._launch_mission()
	for node in held:
		root.add_child(node)
	var gsm := root.get_node("/root/GameStateManager")
	var ctx: Variant = gsm.get_temp_data("bug_hunt_battle_context")
	assert_bool(ctx is Dictionary and not (ctx as Dictionary).is_empty()).override_failure_message(
		"the launch left no battle context, so there is no Bug Hunt battle to measure").is_true()
	var tb: Node = await _in_viewport(SMALL_PHONE,
		"res://src/ui/screens/battle/TacticalBattleUI.tscn")
	tb._on_tier_selected(1)
	await _settle()
	var card_title: Label = null
	for n in tb.find_children("*", "Label", true, false):
		if (n as Label).text == "BUG HUNT BATTLE CARD" and (n as Label).is_visible_in_tree():
			card_title = n
	assert_object(card_title).override_failure_message(
		"no Bug Hunt Battle Card on screen").is_not_null()
	var scroll: Node = card_title
	while scroll != null and not (scroll is ScrollContainer):
		scroll = scroll.get_parent()
	var modal: Node = scroll.get_parent() if scroll else null
	var bad := PackedStringArray()
	_measure(bad, "battle modal", modal)
	# The spine starts INSIDE the scroll: a scroll that may move sideways does not pass
	# its child's minimum up, so from the modal it would stop at the footer button.
	assert_array(bad).override_failure_message("past a %d px phone:\n%s\nspine: %s" % [
		SMALL_PHONE.x, "\n".join(bad), _spine(scroll)]).is_empty()


## The widest-minimum chain under a node: what is actually holding a page wide.
func _spine(from: Node) -> String:
	var parts := PackedStringArray()
	var n: Node = from
	while n is Control and n.get_child_count() > 0:
		var widest: Control = null
		for c in n.get_children():
			if c is Control and (c as Control).visible and (widest == null
					or (c as Control).get_combined_minimum_size().x
					> widest.get_combined_minimum_size().x):
				widest = c
		if widest == null:
			break
		parts.append("%s(%s %.0f '%s')" % [widest.name, widest.get_class(),
			widest.get_combined_minimum_size().x, str(widest.get("text")).left(30)])
		n = widest
	return " > ".join(parts)


func test_the_dashboard_clears_the_settings_band_on_a_phone() -> void:
	Populator.new(get_tree().root)._pre_bug_hunt()
	var so := get_tree().root.get_node("/root/SettingsOverlay")
	var band: float = so.get_reserved_bottom()
	assert_float(band).override_failure_message(
		"no Settings band is showing, so clearing it proves nothing").is_greater(0.0)
	var dash: Node = await _in_viewport(Vector2i(393, 851), DASHBOARD_SCENE)
	var title: Label = null
	for n in dash.find_children("*", "Label", true, false):
		if (n as Label).text == "Sweep fixture":
			title = n
	assert_object(title).is_not_null()
	assert_float(title.get_global_rect().position.y).override_failure_message(
		"the title starts at y=%.0f, under the %.0f px Settings band"
		% [title.get_global_rect().position.y, band]).is_greater_equal(band - EPS)
	var bad := PackedStringArray()
	_measure(bad, "dashboard", dash, [], 393)
	assert_array(bad).is_empty()
