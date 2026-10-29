extends GdUnitTestSuite

## A Tactics campaign could never reach turn 2 (Sprint U, 2026-10-28).
##
## TacticsTurnController started a turn only while campaign_turn was 0 and resumed every
## later entry at Operational Orders. Nothing recorded that a turn had ENDED, so after
## turn 1 completed and saved, "Continue Campaign" replayed turn 1, and the operational
## map, the PBP caps and the turn counter never moved on. A turn left mid-way resumed at
## Orders too, so a battle already recorded could be recorded again.
##
## The fix is the Planetfall T1 shape: TacticsCampaignCore records the phase in progress
## (Phase.NONE once a turn ends) with the per-turn tallies the p.96 caps read, and
## TacticsPhaseManager.enter_campaign() starts, resumes or (for a save older than the
## record) keeps the old answer. These cases pin the decision, the tallies, the save
## round trip and the two screen call sites: the controller's entry and its turn-end card.

const PhaseManagerScript := preload("res://src/core/campaign/TacticsPhaseManager.gd")
const CoreScript := preload("res://src/game/campaign/TacticsCampaignCore.gd")
const Populator := preload("res://tests/tools/screen_populator.gd")
const SaveDirGuard := preload("res://tests/fixtures/helpers/save_dir_guard.gd")
const TURN_SCENE := "res://src/ui/screens/tactics/TacticsTurnController.tscn"

var _user_state: Dictionary
var _saved_campaign: Variant = null


func before_test() -> void:
	_user_state = SaveDirGuard.snapshot()
	var gs := get_tree().root.get_node_or_null("/root/GameState")
	_saved_campaign = gs.current_campaign if gs else null


func after_test() -> void:
	var gs := get_tree().root.get_node_or_null("/root/GameState")
	if gs:
		gs.current_campaign = _saved_campaign
	SaveDirGuard.restore(_user_state)


## The sweeps' own fixture: a legal army raised through the wizard, turn 1 at Orders.
func _fixture_core() -> Resource:
	Populator.new(get_tree().root)._pre_tactics()
	var core: Resource = get_tree().root.get_node("/root/GameState").current_campaign
	assert_object(core).override_failure_message("the Tactics fixture built no campaign") \
		.is_not_null()
	return core


func _manager(core: Resource) -> Node:
	var pm: Node = PhaseManagerScript.new()
	add_child(pm)
	auto_free(pm)
	pm.setup(core)
	return pm


## Every phase of one turn, the way the controller completes them.
func _play_turn(pm: Node) -> void:
	var guard := 0
	while guard < 9:
		guard += 1
		var phase: int = pm.current_phase
		var data: Dictionary = {}
		if phase == PhaseManagerScript.Phase.BATTLE:
			data = {"battle_result": {"won": true, "draw": false, "victory_points": 0},
				"play_another": false}
		pm.complete_current_phase(data)
		if phase == PhaseManagerScript.Phase.STRATEGIC:
			return


func test_a_completed_turn_records_that_it_ended() -> void:
	var core := _fixture_core()
	var pm := _manager(core)
	pm.enter_campaign()
	assert_int(pm.current_phase).is_equal(PhaseManagerScript.Phase.ORDERS)
	_play_turn(pm)
	assert_int(int(core.turn_phase)).override_failure_message(
		"turn_phase is %d after the last phase: nothing says the turn ENDED" % core.turn_phase) \
		.is_equal(PhaseManagerScript.Phase.NONE)


## A quit mid-turn resumes where it left off only because EVERY phase change is
## recorded, not just the turn's end.
func test_each_phase_change_is_recorded() -> void:
	var core := _fixture_core()
	var pm := _manager(core)
	pm.enter_campaign()
	pm.complete_current_phase({})
	assert_int(int(core.turn_phase)).override_failure_message(
		"Recon opened but the save still says phase %d" % core.turn_phase) \
		.is_equal(PhaseManagerScript.Phase.RECON)


func test_the_next_entry_after_a_completed_turn_starts_turn_two() -> void:
	var core := _fixture_core()
	var pm := _manager(core)
	pm.enter_campaign()
	_play_turn(pm)
	var turn_before: int = int(core.campaign_turn)
	var next := _manager(core)
	next.enter_campaign()
	assert_int(int(core.campaign_turn)).override_failure_message(
		"campaign_turn stayed %d: the completed turn was resumed, not followed" % turn_before) \
		.is_equal(turn_before + 1)
	assert_int(next.turn_number).is_equal(turn_before + 1)
	assert_int(next.current_phase).is_equal(PhaseManagerScript.Phase.ORDERS)


func test_a_turn_left_midway_resumes_on_its_phase_with_its_tallies() -> void:
	var core := _fixture_core()
	core.record_turn_phase(PhaseManagerScript.Phase.POST_BATTLE,
		{"battles": 1, "wins": 1, "losses": 0, "pbp_at_start": 0})
	var pm := _manager(core)
	pm.enter_campaign()
	assert_int(pm.current_phase).override_failure_message(
		"resumed on phase %d, not Post-Battle: a recorded battle could be recorded again"
		% pm.current_phase).is_equal(PhaseManagerScript.Phase.POST_BATTLE)
	assert_int(pm.turn_number).is_equal(1)
	assert_int(int(core.campaign_turn)).is_equal(1)
	assert_int(pm.battles_this_turn).is_equal(1)
	assert_int(pm.battle_wins_this_turn).is_equal(1)
	for p in range(PhaseManagerScript.Phase.POST_BATTLE):
		assert_bool(pm.is_phase_complete(p)).is_true()


func test_a_save_older_than_the_record_resumes_at_orders_as_it_did() -> void:
	var core := _fixture_core()
	core.turn_phase = CoreScript.PHASE_UNRECORDED
	core.turn_state = {}
	var pm := _manager(core)
	pm.enter_campaign()
	assert_int(pm.current_phase).is_equal(PhaseManagerScript.Phase.ORDERS)
	assert_int(int(core.campaign_turn)).override_failure_message(
		"a legacy save started a NEW turn and skipped whatever was left of the saved one") \
		.is_equal(1)


func test_the_record_survives_a_save_and_an_older_save_loads_unrecorded() -> void:
	var core := _fixture_core()
	core.record_turn_phase(PhaseManagerScript.Phase.BATTLE,
		{"battles": 2, "wins": 1, "losses": 1, "pbp_at_start": 1})
	var data: Dictionary = core.to_dictionary()
	var copy: Resource = CoreScript.new()
	copy.from_dictionary(JSON.parse_string(JSON.stringify(data)))
	assert_int(int(copy.turn_phase)).is_equal(PhaseManagerScript.Phase.BATTLE)
	assert_int(int(copy.turn_state.get("losses", -1))).is_equal(1)
	(data["state"] as Dictionary).erase("turn_phase")
	(data["state"] as Dictionary).erase("turn_state")
	var legacy: Resource = CoreScript.new()
	legacy.from_dictionary(data)
	assert_bool(legacy.has_recorded_turn_phase()).is_false()


## The CALL SITE. Every case above would pass with the controller still deciding for
## itself from campaign_turn alone.
func test_the_turn_screen_starts_the_next_turn_after_one_ended() -> void:
	var core := _fixture_core()
	core.record_turn_phase(PhaseManagerScript.Phase.NONE, {})
	var tc: Node = (load(TURN_SCENE) as PackedScene).instantiate()
	add_child(tc)
	auto_free(tc)
	for _i in range(8):
		await get_tree().process_frame
	assert_object(tc.phase_manager).is_not_null()
	assert_int(tc.phase_manager.turn_number).override_failure_message(
		"the turn screen reopened turn %d after it had ended" % tc.phase_manager.turn_number) \
		.is_equal(2)


## The end of a turn says what comes next, and its button starts that turn.
func test_the_turn_end_card_offers_the_next_turn() -> void:
	var core := _fixture_core()
	core.record_turn_phase(PhaseManagerScript.Phase.STRATEGIC, {})
	var tc: Node = (load(TURN_SCENE) as PackedScene).instantiate()
	add_child(tc)
	auto_free(tc)
	for _i in range(8):
		await get_tree().process_frame
	tc.phase_manager.complete_current_phase({})
	await get_tree().process_frame
	var btn: Button = tc.find_child("StartNextTurn", true, false) as Button
	assert_object(btn).override_failure_message(
		"nothing on screen starts the next turn once this one ends").is_not_null()
	assert_str(btn.text).is_equal("Start Turn 2")
	btn.pressed.emit()
	await get_tree().process_frame
	assert_int(tc.phase_manager.turn_number).is_equal(2)
	assert_int(tc.phase_manager.current_phase).is_equal(PhaseManagerScript.Phase.ORDERS)
