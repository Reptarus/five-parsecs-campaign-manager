extends GdUnitTestSuite

## The Planetfall 18-step turn (pp.58-70) ends, resumes where it was left, and charges
## Step 11 Morale once (T1, T11a).
##
## ⚠ Before 2026-10-27 no unit suite touched PlanetfallPhaseManager or the turn
## controller, and three defects lived on that path:
##   - a turn could not END in-session: _complete_turn() left the phase on step 18,
##     the controller starts a turn only from NONE, so "Start Next Turn" re-completed
##     step 18 and turn 2 never began;
##   - a resume ALWAYS jumped to Recovery, replaying steps already applied, and
##     re-emitted campaign_turn_started, whose handler rolls Calamity progress, so an
##     active Calamity advanced again on every relaunch;
##   - Step 11 Morale was applied by the post-battle panel AND by the phase manager.
## Colony Damage's Morale cost moved from Step 11 to the moment the damage is taken
## the same day (p.87), after a first fix had tallied it for Step 11; p.68's Step 11
## charges only the automatic point and the battle casualties.

const CoreScript = preload("res://src/game/campaign/PlanetfallCampaignCore.gd")
const PMScript = preload("res://src/core/campaign/PlanetfallPhaseManager.gd")
const TurnScene = preload("res://src/ui/screens/planetfall/PlanetfallTurnController.tscn")
const PostBattlePanel = preload("res://src/ui/screens/planetfall/panels/PlanetfallPostBattlePanel.gd")
const SaveDirGuard := preload("res://tests/fixtures/helpers/save_dir_guard.gd")
const Phase = PMScript.Phase

var _user_state: Dictionary
var _saved_campaign: Variant


func before_test() -> void:
	_user_state = SaveDirGuard.snapshot()
	var gs := get_tree().root.get_node_or_null("/root/GameState")
	_saved_campaign = gs.current_campaign if gs else null


func after_test() -> void:
	var gs := get_tree().root.get_node_or_null("/root/GameState")
	if gs:
		gs.current_campaign = _saved_campaign
	SaveDirGuard.restore(_user_state)


func _core() -> Resource:
	var core = CoreScript.new()
	core.colony_name = "Probe"
	core.game_phase = "active"
	core.colony_morale = 0
	return core


func _pm(core: Resource) -> Node:
	var pm: Node = PMScript.new()
	add_child(pm)
	auto_free(pm)
	pm.setup(core)
	return pm


## Complete steps until `stop` is the current one. Step 4 reports 2 Colony Damage.
func _advance_to(pm: Node, stop: int) -> void:
	while pm.current_phase != stop:
		var data: Dictionary = {}
		if pm.current_phase == Phase.ENEMY_ACTIVITY:
			data = {"colony_damage": 2}
		elif pm.current_phase == Phase.INJURIES:
			# p.68 Step 11 counts the battle's casualties, which come from the returned
			# battle (one downed figure here), not from anything the Injuries step reports.
			pm.set_battle_result({"won": true, "crew_injuries_data": [{"id": "c1"}],
				"crew_casualties_data": []})
		pm.complete_current_phase(data)


func _round_trip(core: Resource) -> Resource:
	var copy = CoreScript.new()
	copy.from_dictionary(core.to_dictionary())
	return copy


# ── The turn ends ────────────────────────────────────────────────────────────────

func test_a_finished_turn_lets_the_next_one_start() -> void:
	var core := _core()
	var pm := _pm(core)
	var ended: Array = []
	pm.campaign_turn_completed.connect(func(t: int) -> void: ended.append(t))
	pm.start_new_turn()
	assert_int(core.campaign_turn).is_equal(1)
	for i in PMScript.PHASE_COUNT:
		pm.complete_current_phase({})
	assert_array(ended).is_equal([1])
	assert_int(pm.current_phase) \
		.override_failure_message("the controller starts a turn only from NONE") \
		.is_equal(Phase.NONE)
	pm.complete_current_phase({})
	assert_array(ended).override_failure_message("step 18 must not complete twice") \
		.is_equal([1])
	pm.start_new_turn()
	assert_int(core.campaign_turn).is_equal(2)
	assert_int(pm.current_phase).is_equal(Phase.RECOVERY)


# ── The turn resumes where it was left ───────────────────────────────────────────

func test_a_resume_opens_on_the_recorded_step_with_its_turn_state() -> void:
	var core := _core()
	var pm := _pm(core)
	pm.start_new_turn()
	_advance_to(pm, Phase.RESEARCH)
	var pm2 := _pm(_round_trip(core))
	assert_int(pm2.restore_from_campaign()).is_equal(Phase.RESEARCH)
	assert_dict(pm2.get_morale_inputs()) \
		.override_failure_message("p.68/p.89: Morale needs the turn's casualties and damage") \
		.is_equal({"casualties": 1, "colony_damage": 2})


func test_a_resume_inside_the_battle_block_reopens_mission_determination() -> void:
	var core := _core()
	var pm := _pm(core)
	pm.start_new_turn()
	_advance_to(pm, Phase.LOCK_AND_LOAD)
	assert_int(_pm(_round_trip(core)).restore_from_campaign()) \
		.is_equal(Phase.MISSION_DETERMINATION)


func test_a_finished_turn_resumes_between_turns() -> void:
	var core := _core()
	var pm := _pm(core)
	pm.start_new_turn()
	for i in PMScript.PHASE_COUNT:
		pm.complete_current_phase({})
	assert_int(_pm(_round_trip(core)).restore_from_campaign()).is_equal(Phase.NONE)


func test_a_save_older_than_the_record_resumes_at_recovery() -> void:
	var data: Dictionary = _core().to_dictionary()
	(data["progression"] as Dictionary).erase("turn_phase")
	(data["progression"] as Dictionary).erase("turn_state")
	var legacy = CoreScript.new()
	legacy.from_dictionary(data)
	assert_int(_pm(legacy).restore_from_campaign()).is_equal(Phase.RECOVERY)


## The real screen: a relaunch opens on the recorded step and does not run the
## turn-start Calamity effects a second time.
func test_relaunching_mid_turn_opens_the_step_and_leaves_a_calamity_alone() -> void:
	var core := _core()
	core.campaign_turn = 2
	core.record_turn_phase(Phase.RESEARCH, {})
	core.active_calamities = [
		{"id": "enemy_super_weapon", "progress": {"weapon_progress": 3}}]
	var gs := get_tree().root.get_node_or_null("/root/GameState")
	gs.current_campaign = core
	var tc: Control = TurnScene.instantiate()
	add_child(tc)
	auto_free(tc)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_object(tc.phase_manager).override_failure_message(
		"premise: the controller initialised against the pinned campaign").is_not_null()
	assert_int(tc.phase_manager.current_phase).is_equal(Phase.RESEARCH)
	assert_int(int(core.active_calamities[0].progress.weapon_progress)) \
		.override_failure_message("a relaunch advanced the Calamity again").is_equal(3)


# ── Step 11 Morale is charged once ───────────────────────────────────────────────

## p.87: "Any time Integrity drops for any reason, Colony Morale drops by the same
## amount", so the step-4 raid costs 2 when it lands. p.68: Step 11 itself charges -1
## and -1 per battle casualty. The panel's button resolves it through the phase
## manager, and completing the step must not charge it again (T11a).
func test_step_11_charges_morale_once_and_the_panel_shows_the_same_number() -> void:
	var core := _core()
	var pm := _pm(core)
	pm.start_new_turn()
	_advance_to(pm, Phase.MORALE_ADJUSTMENTS)
	assert_int(core.colony_morale) \
		.override_failure_message("p.87: 2 Colony Damage cost 2 Morale when taken") \
		.is_equal(-2)
	var panel: Control = PostBattlePanel.new()
	add_child(panel)
	auto_free(panel)
	panel.set_campaign(core)
	panel.set_phase_manager(pm)
	panel.refresh()
	assert_int(core.colony_morale) \
		.override_failure_message("the preview must not apply").is_equal(-2)
	panel._on_action_pressed()
	assert_int(core.colony_morale) \
		.override_failure_message("p.68: -1 automatic, -1 for the casualty").is_equal(-4)
	pm.complete_current_phase({})
	assert_int(core.colony_morale) \
		.override_failure_message("completing Step 11 charged it a second time") \
		.is_equal(-4)
	var shown := ""
	for n in panel.find_children("*", "RichTextLabel", true, false):
		shown += (n as RichTextLabel).text
	assert_str(shown).contains("Colony Morale will be: -2 -> [b]-4[/b]")
	assert_str(shown).contains("Colony Morale: -2 -> -4.")
