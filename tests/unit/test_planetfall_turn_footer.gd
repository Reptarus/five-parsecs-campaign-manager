extends GdUnitTestSuite

## The Planetfall turn screen's pinned footer is each step's one completion control.
##
## ⚠ Until 2026-10-28 the footer read "Complete Phase" and was DISABLED on every step:
## it took its state from the phase manager's can_forward, which is true only for a
## phase already completed, and a completed phase has already been advanced past. Each
## step carried its own Continue button at the bottom of its scroll instead, so the
## screen showed a dead button pinned in reach and the live one below the fold.

const CoreScript = preload("res://src/game/campaign/PlanetfallCampaignCore.gd")
const PMScript = preload("res://src/core/campaign/PlanetfallPhaseManager.gd")
const MapScript = preload("res://src/core/systems/PlanetfallMap.gd")
const ScoutPanel = preload("res://src/ui/screens/planetfall/panels/PlanetfallScoutReportsPanel.gd")
const SectorGrid = preload("res://src/ui/screens/planetfall/panels/PlanetfallSectorGrid.gd")
const TurnScene = preload("res://src/ui/screens/planetfall/PlanetfallTurnController.tscn")
const PANELS := "res://src/ui/screens/planetfall/panels/"
const ColonyEventsPanel = preload(PANELS + "PlanetfallColonyEventsPanel.gd")
const MissionPanelScript = preload(PANELS + "PlanetfallMissionPanel.gd")
const LockAndLoadScript = preload(PANELS + "PlanetfallLockAndLoadPanel.gd")
const ResearchPanelScript = preload(PANELS + "PlanetfallResearchPanel.gd")
const BuildingPanelScript = preload(PANELS + "PlanetfallBuildingPanel.gd")
const PostBattlePanelScript = preload(PANELS + "PlanetfallPostBattlePanel.gd")
const SaveDirGuard := preload("res://tests/fixtures/helpers/save_dir_guard.gd")
const Phase = PMScript.Phase

var _user_state: Dictionary
var _saved_campaign: Variant
var _dm: Node


func before_test() -> void:
	_user_state = SaveDirGuard.snapshot()
	var gs := get_tree().root.get_node_or_null("/root/GameState")
	_saved_campaign = gs.current_campaign if gs else null
	_dm = get_tree().root.get_node_or_null("/root/DiceManager")


func after_test() -> void:
	if _dm != null:
		_dm.clear_forced_results()
	var gs := get_tree().root.get_node_or_null("/root/GameState")
	if gs:
		gs.current_campaign = _saved_campaign
	SaveDirGuard.restore(_user_state)


## A colony mid-turn on `phase`, with a fixed 6 x 6 map and one scout.
func _core(phase: int) -> Resource:
	var core = CoreScript.new()
	core.colony_name = "Probe"
	core.game_phase = "active"
	core.campaign_turn = 1
	core.roster = [{"id": "s1", "name": "Vex", "class": "scout", "xp": 0}]
	MapScript.generate(core, 6, 6, [2, 2], 0)
	core.record_turn_phase(phase, {})
	return core


func _screen(core: Resource) -> Control:
	var gs := get_tree().root.get_node_or_null("/root/GameState")
	gs.current_campaign = core
	var tc: Control = TurnScene.instantiate()
	add_child(tc)
	auto_free(tc)
	await get_tree().process_frame
	await get_tree().process_frame
	return tc


func _force_explore() -> void:
	for pair in [[MapScript.EXPLORE_RESOURCE_DIE, [3, 5]], [MapScript.EXPLORE_HAZARD_DIE, [4, 2]]]:
		for v in pair[1]:
			_dm.queue_forced_result(str(pair[0]), int(v))


## The footer waits on Step 3, says which part is left, then finishes the step.
func test_the_footer_follows_the_scout_step_and_finishes_it() -> void:
	var tc: Control = await _screen(_core(Phase.SCOUT_REPORTS))
	assert_int(tc.phase_manager.current_phase).override_failure_message(
		"premise: the screen resumed on Step 3").is_equal(Phase.SCOUT_REPORTS)
	var footer: Button = tc._advance_button
	assert_bool(footer.visible and footer.disabled).override_failure_message(
		"the footer is shown, and disabled until the step is done").is_true()
	assert_str(tc._footer_reason.text).contains("Explore a sector")
	assert_bool(tc._footer_reason.visible).is_true()

	var panel: Control = tc.current_panel
	_force_explore()
	panel._pending_sector = MapScript.key(0, 0)
	panel._on_explore_pressed()
	assert_str(tc._footer_reason.text).contains("Process Enemy Information")
	panel._on_intel_pressed()
	assert_bool(footer.disabled).override_failure_message(
		"Enemy Information is in, so the footer may continue").is_false()
	assert_str(footer.text).is_equal("Continue to Step 4")
	assert_bool(tc._footer_reason.visible).is_false()

	footer.pressed.emit()
	assert_int(tc.phase_manager.current_phase).override_failure_message(
		"pressing the footer completed Step 3").is_equal(Phase.ENEMY_ACTIVITY)
	assert_bool(footer.visible and footer.disabled).override_failure_message(
		"Step 4 waits for its own roll").is_true()
	assert_str(tc._footer_reason.text).contains("above first")


## A relaunch onto a step that is already done opens with the footer ready. The phase
## manager emits navigation_updated AFTER phase_changed, so a handler that disabled the
## footer from can_forward ran last and locked a finished step.
func test_a_resumed_finished_step_opens_with_the_footer_ready() -> void:
	var core := _core(Phase.SCOUT_REPORTS)
	var pm: Node = PMScript.new()
	add_child(pm)
	auto_free(pm)
	pm.setup(core)
	# restore_from_campaign() names the step; go_to_phase() makes it current, so the
	# receipt below is recorded against Step 3.
	pm.go_to_phase(pm.restore_from_campaign())
	_force_explore()
	pm.scout_explore(MapScript.key(0, 0))
	pm.scout_enemy_information()
	var tc: Control = await _screen(core)
	assert_int(tc.phase_manager.current_phase).override_failure_message(
		"premise: the screen resumed on Step 3").is_equal(Phase.SCOUT_REPORTS)
	assert_bool(tc.current_panel.step_status().ready).override_failure_message(
		"premise: the resumed receipt has Enemy Information").is_true()
	assert_bool(tc._advance_button.disabled).override_failure_message(
		"a finished step opened with its footer disabled").is_false()


## p.59: with no damage and the bot working, Repairs has nothing to decide, so its footer
## is live as built; damage still waits for "Apply Repairs".
func test_repairs_with_nothing_to_repair_is_ready_at_once() -> void:
	var tc: Control = await _screen(_core(Phase.REPAIRS))
	assert_int(tc.phase_manager.current_phase).override_failure_message(
		"premise: the screen resumed on Step 2").is_equal(Phase.REPAIRS)
	assert_bool(tc._advance_button.disabled).override_failure_message(
		"nothing to repair, and the footer still waited for a press").is_false()
	var damaged := _core(Phase.REPAIRS)
	damaged.colony_integrity = -2
	var tc2: Control = await _screen(damaged)
	assert_bool(tc2._advance_button.disabled).override_failure_message(
		"damage must wait for Apply Repairs").is_true()


func _mount(script: GDScript, core: Resource) -> Control:
	var panel: Control = script.new()
	add_child(panel)
	auto_free(panel)
	panel.set_campaign(core)
	return panel


## Step 5 waits for its roll; an event a Milestone still owes (p.156) is named in the
## footer, and the next turn's roll is not labelled a Milestone event.
func test_colony_events_report_their_roll_and_an_owed_event() -> void:
	var core := _core(Phase.COLONY_EVENTS)
	core.queue_extra_roll("colony_event")
	var panel := _mount(ColonyEventsPanel, core)
	panel.refresh()
	assert_bool(panel.step_status().ready).is_false()
	assert_str(str(panel.step_status().reason)).contains("Roll Colony Event")
	_dm.queue_forced_result("Planetfall Colony Event", 43)
	panel._on_roll_pressed()
	assert_bool(panel.step_status().ready).is_true()
	assert_str(str(panel.step_status().get("label", ""))) \
		.is_equal("Next: Milestone Colony Event 1 of 1")
	panel._on_continue_pressed()
	panel.refresh()
	assert_str(panel._roll_btn.text).is_equal("Roll Colony Event (D100)")


## Step 6 confirms the mission picked, from the footer.
func test_mission_determination_waits_for_a_pick() -> void:
	var panel := _mount(MissionPanelScript, _core(Phase.MISSION_DETERMINATION))
	panel.refresh()
	assert_str(str(panel.step_status().reason)).contains("Pick a mission")
	var picked: Button = null
	for b in panel._list_container.find_children("*", "Button", true, false):
		if not (b as Button).disabled:
			picked = b
			break
	assert_object(picked).override_failure_message("premise: a mission is offered").is_not_null()
	# The footer is refreshed by the signal, not by polling; a status that changes
	# without it leaves the footer disabled over a valid pick.
	var fired: Array[int] = [0]
	panel.step_status_changed.connect(func() -> void: fired[0] += 1)
	picked.pressed.emit()
	assert_int(fired[0]).override_failure_message("the pick never told the footer").is_greater(0)
	assert_bool(panel.step_status().ready).is_true()
	assert_str(str(panel.step_status().label)).is_equal("Confirm %s" % picked.text)


## Step 7 needs someone on the table before the battle.
func test_lock_and_load_needs_someone_deployed() -> void:
	var panel := _mount(LockAndLoadScript, _core(Phase.LOCK_AND_LOAD))
	panel.set_mission_context({})
	panel.refresh()
	assert_bool(panel.step_status().ready).override_failure_message(
		"deploying nobody was accepted").is_false()
	var vex: CheckBox = null
	for c in panel.find_children("*", "CheckBox", true, false):
		if (c as CheckBox).text.begins_with("Vex"):
			vex = c
	assert_object(vex).override_failure_message("premise: Vex can deploy").is_not_null()
	var fired: Array[int] = [0]
	panel.step_status_changed.connect(func() -> void: fired[0] += 1)
	vex.button_pressed = true
	assert_int(fired[0]).override_failure_message("deploying never told the footer").is_greater(0)
	assert_bool(panel.step_status().ready).is_true()


## Research and Building are optional spends: always finishable, and the panel no longer
## carries a second "Done" button below the fold.
func test_research_and_building_are_always_finishable() -> void:
	for script in [ResearchPanelScript, BuildingPanelScript]:
		var panel := _mount(script, _core(Phase.RESEARCH))
		panel.refresh()
		assert_bool(panel.step_status().ready).is_true()
		for b in panel.find_children("*", "Button", true, false):
			assert_str((b as Button).text).not_contains("Done ")


## Step 12's two parts follow Morale in one panel, so the footer names them rather than
## calling the next press "Step 13".
func test_post_battle_names_step_12s_parts() -> void:
	var panel := _mount(PostBattlePanelScript, _core(Phase.MORALE_ADJUSTMENTS))
	panel._current_sub_step = panel.SubStep.MORALE
	panel._set_can_continue(false)
	assert_str(str(panel.step_status().reason)).contains("above first")
	panel._set_can_continue(true)
	assert_str(str(panel.step_status().label)).is_equal("Continue to Post-Mission Finds")
	panel._current_sub_step = panel.SubStep.POST_MISSION_FINDS
	assert_str(str(panel.step_status().label)).is_equal("Continue to Enemy Information")


## A step that reports no status finishes from its own panel, so the footer hides
## instead of showing a disabled "Complete Phase".
func test_a_step_without_a_status_hides_the_footer() -> void:
	var tc: Control = await _screen(_core(Phase.SCOUT_REPORTS))
	var bare := Control.new()
	tc.add_child(bare)
	tc.current_panel = bare
	tc._refresh_footer()
	assert_bool(tc._advance_button.visible).is_false()
	assert_bool(tc._footer_reason.visible).is_false()


func test_the_footer_names_the_next_step_the_player_will_see() -> void:
	var tc: Control = await _screen(_core(Phase.SCOUT_REPORTS))
	assert_str(tc._next_step_label(Phase.SCOUT_REPORTS)).is_equal("Continue to Step 4")
	assert_str(tc._next_step_label(Phase.MORALE_ADJUSTMENTS)) \
		.override_failure_message("Step 12 is folded into the post-battle panel") \
		.is_equal("Continue to Step 13")
	assert_str(tc._next_step_label(Phase.UPDATE_TRACKING)).starts_with("End Turn")


## p.60: a turn with nothing to explore (every sector enemy-held or Exploited) must still
## be finishable; the Enemy Information part does not need an Explore.
func test_with_nothing_to_explore_the_step_can_still_finish() -> void:
	var core := _core(Phase.SCOUT_REPORTS)
	for k in MapScript.all_keys(core.map_data):
		MapScript._sector_for_write(core, str(k))["exploited"] = true
	assert_bool(MapScript.explore_targets(core).is_empty()).override_failure_message(
		"premise: no sector may be explored").is_true()
	var pm: Node = PMScript.new()
	add_child(pm)
	auto_free(pm)
	pm.setup(core)
	pm.restore_from_campaign()
	var panel: Control = ScoutPanel.new()
	add_child(panel)
	auto_free(panel)
	panel.set_campaign(core)
	panel.set_phase_manager(pm)
	panel.refresh()
	assert_bool(panel._intel_btn.disabled).override_failure_message(
		"Enemy Information was locked behind an Explore that cannot happen").is_false()
	assert_bool(panel._discovery_btn.visible).override_failure_message(
		"p.60: Discovery follows an Explore, so it is not offered").is_false()
	assert_str(panel._map_hint.text).contains("nothing to explore")
	panel._on_intel_pressed()
	assert_bool(panel.step_status().ready).is_true()


## At turn 1 every sector may be explored, and the pick highlight used to paint over the
## colony's border, so the map no longer showed where the colony was.
func test_the_colony_keeps_its_border_while_pickable() -> void:
	var core := _core(Phase.SCOUT_REPORTS)
	var grid: Control = SectorGrid.new()
	add_child(grid)
	auto_free(grid)
	var home: String = MapScript.home_key(core.map_data)
	grid.configure(core, MapScript.explore_targets(core), "")
	assert_bool(MapScript.explore_targets(core).has(home)).override_failure_message(
		"premise: the colony's sector is pickable").is_true()
	var style: StyleBoxFlat = grid._cells[home].get_theme_stylebox("normal")
	assert_that(style.border_color).is_equal(UIColors.COLOR_EMERALD)


## A disabled button names what it is waiting for (a phone has no hover).
func test_disabled_scout_buttons_say_why() -> void:
	var core := _core(Phase.SCOUT_REPORTS)
	var pm: Node = PMScript.new()
	add_child(pm)
	auto_free(pm)
	pm.setup(core)
	pm.restore_from_campaign()
	var panel: Control = ScoutPanel.new()
	add_child(panel)
	auto_free(panel)
	panel.set_campaign(core)
	panel.set_phase_manager(pm)
	panel.refresh()
	assert_bool(panel._discovery_btn.disabled).is_true()
	assert_bool(panel._discovery_why.visible).is_true()
	assert_str(panel._discovery_why.text).contains("Explore a sector first")
	assert_bool(panel._intel_why.visible).is_true()
	_force_explore()
	panel._pending_sector = MapScript.key(0, 0)
	panel._on_explore_pressed()
	assert_bool(panel._discovery_why.visible or panel._intel_why.visible) \
		.override_failure_message("a reason stays up once the button is enabled").is_false()
