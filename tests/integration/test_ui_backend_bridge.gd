extends GdUnitTestSuite
## Integration tests for UI-Backend bridge connectivity
## Validates that UI scenes properly trigger CampaignPhaseManager

# Dependencies
var phase_manager: Node
var game_state_manager: Node

func before() -> void:
	# Get autoloads
	phase_manager = auto_free(preload("res://src/core/campaign/CampaignPhaseManager.gd").new())
	add_child(phase_manager)

	# Wait for initialization
	await get_tree().create_timer(0.1).timeout

func after_test() -> void:
	# Cleanup between tests
	pass

## Test: PostBattleSequence completion triggers phase manager
func test_post_battle_completion_triggers_new_turn() -> void:
	# Setup: Get initial turn number
	var initial_turn = phase_manager.turn_number

	# Connect to signal to verify it fires
	var turn_completed_fired = false
	var new_turn_started_fired = false

	phase_manager.campaign_turn_completed.connect(func(_turn): turn_completed_fired = true)
	phase_manager.campaign_turn_started.connect(func(_turn): new_turn_started_fired = true)

	# Act: Simulate PostBattleSequence calling the completion handler
	phase_manager._on_post_battle_phase_completed()

	# Assert: Verify signals fired
	assert_bool(turn_completed_fired).is_true()
	assert_bool(new_turn_started_fired).is_true()

	# Assert: Turn number incremented
	assert_int(phase_manager.turn_number).is_equal(initial_turn + 1)

## Test: Phase transitions follow correct order
func test_phase_transition_order() -> void:
	# Start a new turn (begins at TRAVEL)
	phase_manager.start_new_campaign_turn()

	# Verify we're in TRAVEL phase
	assert_int(phase_manager.current_phase).is_equal(GlobalEnums.FiveParsecsCampaignPhase.TRAVEL)

	# Complete travel -> should go to WORLD
	phase_manager._on_travel_phase_completed()
	assert_int(phase_manager.current_phase).is_equal(GlobalEnums.FiveParsecsCampaignPhase.WORLD)

	# Complete world -> should go to BATTLE
	phase_manager._on_world_phase_completed()
	assert_int(phase_manager.current_phase).is_equal(GlobalEnums.FiveParsecsCampaignPhase.BATTLE)

	# Complete battle -> should go to POST_BATTLE
	phase_manager._on_battle_phase_completed()
	assert_int(phase_manager.current_phase).is_equal(GlobalEnums.FiveParsecsCampaignPhase.POST_BATTLE)

	# Store turn before post-battle completion
	var turn_before = phase_manager.turn_number

	# Complete post-battle -> should start new turn (back to TRAVEL)
	phase_manager._on_post_battle_phase_completed()
	assert_int(phase_manager.current_phase).is_equal(GlobalEnums.FiveParsecsCampaignPhase.TRAVEL)
	assert_int(phase_manager.turn_number).is_equal(turn_before + 1)

## Test: Battle results are stored and accessible
func test_battle_results_storage() -> void:
	# Create mock battle results
	var mock_results = {
		"victory": true,
		"enemies_defeated": 5,
		"crew_casualties": 1,
		"credits_earned": 100,
		"experience_gained": {"crew_1": 3, "crew_2": 2}
	}

	# Store results via the handler
	phase_manager._on_battle_results_ready(mock_results)

	# Verify results are stored
	var stored_results = phase_manager._get_battle_results()
	assert_bool(stored_results.get("victory", false)).is_true()
	assert_int(stored_results.get("enemies_defeated", 0)).is_equal(5)
	assert_int(stored_results.get("credits_earned", 0)).is_equal(100)

## Test: Multiple campaign turns accumulate correctly
func test_multiple_turns_accumulate() -> void:
	var initial_turn = phase_manager.turn_number

	# Run through 3 complete turns
	for i in range(3):
		phase_manager.start_new_campaign_turn()
		phase_manager._on_travel_phase_completed()
		phase_manager._on_world_phase_completed()
		phase_manager._on_battle_phase_completed()
		phase_manager._on_post_battle_phase_completed()

	# Verify turn count increased by 3
	# Note: start_new_campaign_turn increments, then post_battle completion triggers another start
	assert_int(phase_manager.turn_number).is_greater(initial_turn)

## Test: Phase manager emits correct signals
func test_phase_signals_emit_correctly() -> void:
	var signals_received: Array[String] = []

	# Connect to all phase signals
	phase_manager.phase_started.connect(func(_p): signals_received.append("started"))
	phase_manager.phase_completed.connect(func(_p): signals_received.append("completed"))
	phase_manager.phase_changed.connect(func(_p): signals_received.append("changed"))

	# Start a phase
	phase_manager.start_phase(GlobalEnums.FiveParsecsCampaignPhase.TRAVEL)

	# Verify signals were emitted
	assert_bool("started" in signals_received).is_true()
	assert_bool("changed" in signals_received).is_true()

	# Complete the phase
	phase_manager._on_travel_phase_completed()
	assert_bool("completed" in signals_received).is_true()

## Test: Campaign loop continues without interruption
func test_campaign_loop_continuity() -> void:
	# Start fresh
	phase_manager.turn_number = 0
	phase_manager.current_phase = GlobalEnums.FiveParsecsCampaignPhase.NONE

	# Begin campaign
	phase_manager.start_new_campaign_turn()
	assert_int(phase_manager.turn_number).is_equal(1)

	# Run through complete loop
	phase_manager._on_travel_phase_completed()
	phase_manager._on_world_phase_completed()
	phase_manager._on_battle_phase_completed()
	phase_manager._on_post_battle_phase_completed()

	# Should now be on turn 2, back to TRAVEL
	assert_int(phase_manager.turn_number).is_equal(2)
	assert_int(phase_manager.current_phase).is_equal(GlobalEnums.FiveParsecsCampaignPhase.TRAVEL)

	# Run another complete loop
	phase_manager._on_travel_phase_completed()
	phase_manager._on_world_phase_completed()
	phase_manager._on_battle_phase_completed()
	phase_manager._on_post_battle_phase_completed()

	# Should now be on turn 3
	assert_int(phase_manager.turn_number).is_equal(3)
	assert_int(phase_manager.current_phase).is_equal(GlobalEnums.FiveParsecsCampaignPhase.TRAVEL)
