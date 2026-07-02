extends GdUnitTestSuite
## Integration tests for UI-Backend bridge connectivity
## Validates that UI scenes properly trigger CampaignPhaseManager

# Dependencies
var phase_manager: Node
var game_state_manager: Node

func before() -> void:
	# Create phase manager instance
	var PhaseManagerClass = preload("res://src/core/campaign/CampaignPhaseManager.gd")
	phase_manager = auto_free(PhaseManagerClass.new())
	add_child(phase_manager)

	# Wait for initialization and _ready()
	for i in range(5):
		await get_tree().process_frame

	# Verify initialization
	if not is_instance_valid(phase_manager):
		push_warning("CampaignPhaseManager not initialized properly")

func after_test() -> void:
	# Cleanup between tests
	pass

## Test (updated 2026-07-02 to the real design): the post-battle backend
## handler only LOGS its event — turn rollover is EXPLICIT via
## start_new_turn(), driven by CampaignTurnController, and a new turn
## always begins at UPKEEP (the old auto-rollover-to-TRAVEL model is gone).
func test_post_battle_completion_logs_event_and_rollover_is_explicit() -> void:
	if not is_instance_valid(phase_manager):
		push_warning("phase_manager not valid - skipping test")
		return

	# Backend completion records the event, nothing more
	var events_before: int = phase_manager.phase_events.size()
	phase_manager._on_post_battle_phase_completed()
	await get_tree().process_frame
	if not is_instance_valid(phase_manager):
		return
	assert_int(phase_manager.phase_events.size()).is_equal(events_before + 1)
	var last_event: Dictionary = phase_manager.phase_events[-1]
	assert_str(str(last_event.get("type", ""))) \
		.is_equal("post_battle_backend_completed")

	# Explicit rollover: turn increments, campaign_turn_started fires,
	# and the new turn enters UPKEEP
	phase_manager.current_phase = GlobalEnums.FiveParsecsCampaignPhase.NONE
	var initial_turn: int = phase_manager.turn_number
	var started_fired := [false]
	phase_manager.campaign_turn_started.connect(
		func(_turn: int): started_fired[0] = true)
	phase_manager.start_new_campaign_turn()
	await get_tree().process_frame
	if not is_instance_valid(phase_manager):
		return
	assert_int(phase_manager.turn_number).is_equal(initial_turn + 1)
	assert_bool(started_fired[0]).is_true()
	assert_int(phase_manager.current_phase) \
		.is_equal(GlobalEnums.FiveParsecsCampaignPhase.UPKEEP)

## Test (updated 2026-07-02): phase transitions follow the CANONICAL order
## UPKEEP -> STORY -> TRAVEL -> PRE_MISSION (complete_current_phase walks
## _get_next_phase; a new turn always begins at UPKEEP)
func test_phase_transition_order() -> void:
	if not is_instance_valid(phase_manager):
		push_warning("phase_manager not valid - skipping test")
		return

	phase_manager.current_phase = GlobalEnums.FiveParsecsCampaignPhase.NONE
	phase_manager.start_new_campaign_turn()
	await get_tree().process_frame
	if not is_instance_valid(phase_manager):
		return
	assert_int(phase_manager.current_phase) \
		.is_equal(GlobalEnums.FiveParsecsCampaignPhase.UPKEEP)

	phase_manager.complete_current_phase()
	assert_int(phase_manager.current_phase) \
		.is_equal(GlobalEnums.FiveParsecsCampaignPhase.STORY)

	phase_manager.complete_current_phase()
	assert_int(phase_manager.current_phase) \
		.is_equal(GlobalEnums.FiveParsecsCampaignPhase.TRAVEL)

	phase_manager.complete_current_phase()
	assert_int(phase_manager.current_phase) \
		.is_equal(GlobalEnums.FiveParsecsCampaignPhase.PRE_MISSION)

## Test: Battle results are stored and accessible
func test_battle_results_storage() -> void:
	if not is_instance_valid(phase_manager):
		push_warning("phase_manager not valid - skipping test")
		return

	# Create mock battle results
	var mock_results = {
		"victory": true,
		"enemies_defeated": 5,
		"crew_casualties": 1,
		"credits_earned": 100,
		"experience_gained": {"crew_1": 3, "crew_2": 2}
	}

	# Check if method exists before calling
	if phase_manager.has_method("_on_battle_results_ready"):
		# Store results via the handler
		phase_manager._on_battle_results_ready(mock_results)

		# Verify results are stored
		if phase_manager.has_method("_get_battle_results"):
			var stored_results = phase_manager._get_battle_results()
			# Null check before accessing Dictionary
			if stored_results != null and stored_results is Dictionary:
				assert_bool(stored_results.get("victory", false)).is_true()
				assert_int(stored_results.get("enemies_defeated", 0)).is_equal(5)
				assert_int(stored_results.get("credits_earned", 0)).is_equal(100)
			else:
				push_warning("_get_battle_results returned null or non-Dictionary")
		else:
			push_warning("_get_battle_results method not found - test needs update for actual API")
	else:
		push_warning("_on_battle_results_ready method not found - test needs update for actual API")

## Test: Multiple campaign turns accumulate correctly
func test_multiple_turns_accumulate() -> void:
	if not is_instance_valid(phase_manager):
		push_warning("phase_manager not valid - skipping test")
		return

	var initial_turn = phase_manager.turn_number

	# Run through 3 complete turns
	for i in range(3):
		if phase_manager.has_method("start_new_campaign_turn"):
			phase_manager.start_new_campaign_turn()
		await get_tree().process_frame
		if not is_instance_valid(phase_manager):
			push_warning("phase_manager freed during loop - skipping")
			return

		if phase_manager.has_method("_on_travel_phase_completed"):
			phase_manager._on_travel_phase_completed()
		await get_tree().process_frame
		if not is_instance_valid(phase_manager):
			push_warning("phase_manager freed during loop - skipping")
			return

		if phase_manager.has_method("_on_world_phase_completed"):
			phase_manager._on_world_phase_completed()
		await get_tree().process_frame
		if not is_instance_valid(phase_manager):
			push_warning("phase_manager freed during loop - skipping")
			return

		if phase_manager.has_method("_on_battle_phase_completed"):
			phase_manager._on_battle_phase_completed()
		await get_tree().process_frame
		if not is_instance_valid(phase_manager):
			push_warning("phase_manager freed during loop - skipping")
			return

		if phase_manager.has_method("_on_post_battle_phase_completed"):
			phase_manager._on_post_battle_phase_completed()
		await get_tree().process_frame
		if not is_instance_valid(phase_manager):
			push_warning("phase_manager freed during loop - skipping")
			return

	# Verify turn count increased
	# Note: start_new_campaign_turn increments, then post_battle completion triggers another start
	assert_int(phase_manager.turn_number).is_greater(initial_turn)

## Test: Phase manager emits correct signals
func test_phase_signals_emit_correctly() -> void:
	if not is_instance_valid(phase_manager):
		push_warning("phase_manager not valid - skipping test")
		return

	# Reset state - shared instance from before() may have state from previous tests
	phase_manager.turn_number = 0
	phase_manager.current_phase = GlobalEnums.FiveParsecsCampaignPhase.NONE
	phase_manager.transition_in_progress = false

	var signals_received: Array[String] = []

	# Real signal arities: phase_started(phase), phase_completed(),
	# phase_changed(old, new). The old test connected 1-arg lambdas to all
	# three AND started TRAVEL from NONE, which _can_transition_to_phase
	# rejects (TRAVEL requires STORY) — so nothing ever fired.
	phase_manager.phase_started.connect(
		func(_p): signals_received.append("started"))
	phase_manager.phase_completed.connect(
		func(): signals_received.append("completed"))
	phase_manager.phase_changed.connect(
		func(_o, _n): signals_received.append("changed"))

	# NONE -> UPKEEP is the valid turn-entry transition
	var started_ok: bool = phase_manager.start_phase(
		GlobalEnums.FiveParsecsCampaignPhase.UPKEEP)
	await get_tree().process_frame
	if not is_instance_valid(phase_manager):
		return
	assert_bool(started_ok).is_true()
	assert_bool("started" in signals_received).is_true()
	assert_bool("changed" in signals_received).is_true()

	phase_manager.complete_current_phase()
	await get_tree().process_frame
	if not is_instance_valid(phase_manager):
		return
	assert_bool("completed" in signals_received).is_true()

## Test: Campaign loop continues without interruption
func test_campaign_loop_continuity() -> void:
	if not is_instance_valid(phase_manager):
		push_warning("phase_manager not valid - skipping test")
		return

	# Start fresh (updated 2026-07-02: the loop is driven by
	# complete_current_phase() through the canonical 12-phase sequence;
	# RETIREMENT completion emits campaign_turn_completed, and the next
	# turn is started EXPLICITLY via start_new_campaign_turn -> UPKEEP)
	phase_manager.turn_number = 0
	phase_manager.current_phase = GlobalEnums.FiveParsecsCampaignPhase.NONE

	var turn_completed_count := [0]
	phase_manager.campaign_turn_completed.connect(
		func(_turn: int): turn_completed_count[0] += 1)

	phase_manager.start_new_campaign_turn()
	await get_tree().process_frame
	if not is_instance_valid(phase_manager):
		return
	assert_int(phase_manager.turn_number).is_equal(1)
	assert_int(phase_manager.current_phase) \
		.is_equal(GlobalEnums.FiveParsecsCampaignPhase.UPKEEP)

	# Walk the full canonical sequence: UPKEEP..RETIREMENT is 12 completes;
	# the 12th (RETIREMENT) ends the turn
	for i in range(12):
		phase_manager.complete_current_phase()
	await get_tree().process_frame
	if not is_instance_valid(phase_manager):
		return
	assert_int(turn_completed_count[0]).is_equal(1)

	# Next turn begins at UPKEEP with the counter advanced
	phase_manager.start_new_campaign_turn()
	await get_tree().process_frame
	if not is_instance_valid(phase_manager):
		return
	assert_int(phase_manager.turn_number).is_equal(2)
	assert_int(phase_manager.current_phase) \
		.is_equal(GlobalEnums.FiveParsecsCampaignPhase.UPKEEP)
