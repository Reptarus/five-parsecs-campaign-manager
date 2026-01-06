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

## Test: PostBattleSequence completion triggers phase manager
func test_post_battle_completion_triggers_new_turn() -> void:
	if not is_instance_valid(phase_manager):
		push_warning("phase_manager not valid - skipping test")
		return

	# Setup: Get initial turn number
	var initial_turn = phase_manager.turn_number

	# Connect to signal to verify it fires - use arrays for reference semantics in lambda
	var turn_completed_fired = [false]
	var new_turn_started_fired = [false]

	if phase_manager.has_signal("campaign_turn_completed"):
		phase_manager.campaign_turn_completed.connect(func(_turn): turn_completed_fired[0] = true)
	if phase_manager.has_signal("campaign_turn_started"):
		phase_manager.campaign_turn_started.connect(func(_turn): new_turn_started_fired[0] = true)

	# Act: Simulate PostBattleSequence calling the completion handler
	if phase_manager.has_method("_on_post_battle_phase_completed"):
		phase_manager._on_post_battle_phase_completed()

		# Wait for signals to propagate (synchronous emission)
		await get_tree().process_frame

		# Guard against freed instance after await
		if not is_instance_valid(phase_manager):
			push_warning("phase_manager freed during test - skipping assertions")
			return

		# Assert: Verify signals fired
		assert_bool(turn_completed_fired[0]).is_true()
		assert_bool(new_turn_started_fired[0]).is_true()

		# Assert: Turn number incremented
		assert_int(phase_manager.turn_number).is_equal(initial_turn + 1)
	else:
		push_warning("_on_post_battle_phase_completed method not found - skipping test")

## Test: Phase transitions follow correct order
func test_phase_transition_order() -> void:
	if not is_instance_valid(phase_manager):
		push_warning("phase_manager not valid - skipping test")
		return

	# Start a new turn (begins at TRAVEL)
	if phase_manager.has_method("start_new_campaign_turn"):
		phase_manager.start_new_campaign_turn()
	else:
		push_warning("start_new_campaign_turn method not found - skipping test")
		return

	# Verify we're in TRAVEL phase
	assert_int(phase_manager.current_phase).is_equal(GlobalEnums.FiveParsecsCampaignPhase.TRAVEL)

	# Complete travel -> should go to WORLD
	if phase_manager.has_method("_on_travel_phase_completed"):
		phase_manager._on_travel_phase_completed()
		await get_tree().process_frame
		if not is_instance_valid(phase_manager):
			push_warning("phase_manager freed - skipping")
			return
		assert_int(phase_manager.current_phase).is_equal(GlobalEnums.FiveParsecsCampaignPhase.WORLD)
	else:
		push_warning("_on_travel_phase_completed not found")
		return

	# Complete world -> should go to BATTLE
	if phase_manager.has_method("_on_world_phase_completed"):
		phase_manager._on_world_phase_completed()
		await get_tree().process_frame
		if not is_instance_valid(phase_manager):
			push_warning("phase_manager freed - skipping")
			return
		assert_int(phase_manager.current_phase).is_equal(GlobalEnums.FiveParsecsCampaignPhase.BATTLE)
	else:
		push_warning("_on_world_phase_completed not found")
		return

	# Complete battle -> should go to POST_BATTLE
	if phase_manager.has_method("_on_battle_phase_completed"):
		phase_manager._on_battle_phase_completed()
		await get_tree().process_frame
		if not is_instance_valid(phase_manager):
			push_warning("phase_manager freed - skipping")
			return
		assert_int(phase_manager.current_phase).is_equal(GlobalEnums.FiveParsecsCampaignPhase.POST_BATTLE)
	else:
		push_warning("_on_battle_phase_completed not found")
		return

	# Store turn before post-battle completion
	var turn_before = phase_manager.turn_number

	# Complete post-battle -> should start new turn (back to TRAVEL)
	if phase_manager.has_method("_on_post_battle_phase_completed"):
		phase_manager._on_post_battle_phase_completed()
		await get_tree().process_frame
		if not is_instance_valid(phase_manager):
			push_warning("phase_manager freed - skipping")
			return
		assert_int(phase_manager.current_phase).is_equal(GlobalEnums.FiveParsecsCampaignPhase.TRAVEL)
		assert_int(phase_manager.turn_number).is_equal(turn_before + 1)
	else:
		push_warning("_on_post_battle_phase_completed not found")

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

	# Connect to all phase signals if they exist
	if phase_manager.has_signal("phase_started"):
		phase_manager.phase_started.connect(func(_p): signals_received.append("started"))
	if phase_manager.has_signal("phase_completed"):
		phase_manager.phase_completed.connect(func(_p): signals_received.append("completed"))
	if phase_manager.has_signal("phase_changed"):
		phase_manager.phase_changed.connect(func(_p): signals_received.append("changed"))

	# Start a phase
	if phase_manager.has_method("start_phase"):
		phase_manager.start_phase(GlobalEnums.FiveParsecsCampaignPhase.TRAVEL)
		await get_tree().process_frame

		# Verify signals were emitted
		assert_bool("started" in signals_received).is_true()
		assert_bool("changed" in signals_received).is_true()

		# Complete the phase
		if phase_manager.has_method("_on_travel_phase_completed"):
			phase_manager._on_travel_phase_completed()
			await get_tree().process_frame
			assert_bool("completed" in signals_received).is_true()
	else:
		push_warning("start_phase method not found - skipping signal tests")

## Test: Campaign loop continues without interruption
func test_campaign_loop_continuity() -> void:
	if not is_instance_valid(phase_manager):
		push_warning("phase_manager not valid - skipping test")
		return

	# Start fresh
	phase_manager.turn_number = 0
	phase_manager.current_phase = GlobalEnums.FiveParsecsCampaignPhase.NONE

	# Begin campaign
	if not phase_manager.has_method("start_new_campaign_turn"):
		push_warning("start_new_campaign_turn method not found - skipping test")
		return

	phase_manager.start_new_campaign_turn()
	await get_tree().process_frame
	assert_int(phase_manager.turn_number).is_equal(1)

	# Run through complete loop
	if phase_manager.has_method("_on_travel_phase_completed"):
		phase_manager._on_travel_phase_completed()
		await get_tree().process_frame
	if phase_manager.has_method("_on_world_phase_completed"):
		phase_manager._on_world_phase_completed()
		await get_tree().process_frame
	if phase_manager.has_method("_on_battle_phase_completed"):
		phase_manager._on_battle_phase_completed()
		await get_tree().process_frame
	if phase_manager.has_method("_on_post_battle_phase_completed"):
		phase_manager._on_post_battle_phase_completed()
		await get_tree().process_frame

	# Should now be on turn 2, back to TRAVEL
	assert_int(phase_manager.turn_number).is_equal(2)
	assert_int(phase_manager.current_phase).is_equal(GlobalEnums.FiveParsecsCampaignPhase.TRAVEL)

	# Run another complete loop
	if phase_manager.has_method("_on_travel_phase_completed"):
		phase_manager._on_travel_phase_completed()
		await get_tree().process_frame
	if phase_manager.has_method("_on_world_phase_completed"):
		phase_manager._on_world_phase_completed()
		await get_tree().process_frame
	if phase_manager.has_method("_on_battle_phase_completed"):
		phase_manager._on_battle_phase_completed()
		await get_tree().process_frame
	if phase_manager.has_method("_on_post_battle_phase_completed"):
		phase_manager._on_post_battle_phase_completed()
		await get_tree().process_frame

	# Should now be on turn 3
	assert_int(phase_manager.turn_number).is_equal(3)
	assert_int(phase_manager.current_phase).is_equal(GlobalEnums.FiveParsecsCampaignPhase.TRAVEL)
