extends GdUnitTestSuite

## Campaign Turn Loop E2E Smoke Tests (rewritten 2026-07-02).
##
## The old file drove a never-existed force_phase_transition() API and the
## legacy 4-phase TRAVEL-first model with implicit rollover (and connected a
## 1-arg lambda to the 2-arg phase_changed signal). The canonical loop is
## UPKEEP -> STORY -> TRAVEL -> PRE_MISSION -> MISSION -> BATTLE_SETUP ->
## BATTLE_RESOLUTION -> POST_MISSION -> ADVANCEMENT -> TRADING -> CHARACTER
## -> RETIREMENT, driven by complete_current_phase(), with EXPLICIT turn
## rollover via start_new_campaign_turn() (a new turn enters UPKEEP).

var campaign_phase_manager: Node


func before() -> void:
	campaign_phase_manager = get_tree().root.get_node_or_null("CampaignPhaseManager")
	if not campaign_phase_manager:
		push_error("CampaignPhaseManager autoload not found")


func after() -> void:
	# Reset the shared autoload's phase state
	if campaign_phase_manager:
		campaign_phase_manager.current_phase = GlobalEnums.FiveParsecsCampaignPhase.NONE


func test_complete_turn_loop_execution() -> void:
	"""E2E smoke: full canonical turn cycle ending in campaign_turn_completed"""
	if not campaign_phase_manager:
		push_warning("phase manager unavailable, skipping")
		return

	campaign_phase_manager.current_phase = GlobalEnums.FiveParsecsCampaignPhase.NONE
	var initial_turn: int = campaign_phase_manager.turn_number

	campaign_phase_manager.start_new_campaign_turn()
	assert_that(campaign_phase_manager.turn_number).is_equal(initial_turn + 1)
	assert_that(campaign_phase_manager.current_phase) \
		.is_equal(GlobalEnums.FiveParsecsCampaignPhase.UPKEEP)

	var expected_sequence: Array = [
		GlobalEnums.FiveParsecsCampaignPhase.STORY,
		GlobalEnums.FiveParsecsCampaignPhase.TRAVEL,
		GlobalEnums.FiveParsecsCampaignPhase.PRE_MISSION,
		GlobalEnums.FiveParsecsCampaignPhase.MISSION,
		GlobalEnums.FiveParsecsCampaignPhase.BATTLE_SETUP,
		GlobalEnums.FiveParsecsCampaignPhase.BATTLE_RESOLUTION,
		GlobalEnums.FiveParsecsCampaignPhase.POST_MISSION,
		GlobalEnums.FiveParsecsCampaignPhase.ADVANCEMENT,
		GlobalEnums.FiveParsecsCampaignPhase.TRADING,
		GlobalEnums.FiveParsecsCampaignPhase.CHARACTER,
		GlobalEnums.FiveParsecsCampaignPhase.RETIREMENT,
	]
	for expected_phase in expected_sequence:
		campaign_phase_manager.complete_current_phase()
		assert_that(campaign_phase_manager.current_phase).is_equal(expected_phase)

	# Completing RETIREMENT ends the turn
	var completed := [0]
	var on_completed := func(_turn: int): completed[0] += 1
	campaign_phase_manager.campaign_turn_completed.connect(on_completed)
	campaign_phase_manager.complete_current_phase()
	campaign_phase_manager.campaign_turn_completed.disconnect(on_completed)
	assert_that(completed[0]).is_equal(1)


func test_phase_handlers_execute_during_turn_loop() -> void:
	"""Phase entries fire phase_changed (2-arg signal) for each step"""
	if not campaign_phase_manager:
		push_warning("phase manager unavailable, skipping")
		return

	campaign_phase_manager.current_phase = GlobalEnums.FiveParsecsCampaignPhase.NONE

	var phases_entered: Array = []
	var tracker := func(_old_phase, new_phase): phases_entered.append(new_phase)
	campaign_phase_manager.phase_changed.connect(tracker)

	campaign_phase_manager.start_new_campaign_turn()
	campaign_phase_manager.complete_current_phase()  # UPKEEP -> STORY
	campaign_phase_manager.complete_current_phase()  # STORY -> TRAVEL
	campaign_phase_manager.complete_current_phase()  # TRAVEL -> PRE_MISSION

	campaign_phase_manager.phase_changed.disconnect(tracker)

	for expected in [
			GlobalEnums.FiveParsecsCampaignPhase.UPKEEP,
			GlobalEnums.FiveParsecsCampaignPhase.STORY,
			GlobalEnums.FiveParsecsCampaignPhase.TRAVEL,
			GlobalEnums.FiveParsecsCampaignPhase.PRE_MISSION]:
		assert_bool(expected in phases_entered).is_true()
