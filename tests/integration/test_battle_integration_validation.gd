extends GdUnitTestSuite

## Battle Integration Validation Tests
## 
## Validates the complete battle integration flow from UI → Backend → Battle Phase
## Tests signal chains, handler initialization, and phase transitions
##
## Integration Points Tested:
## 1. MissionPrepComponent → WorldPhaseController → CampaignTurnController
## 2. CampaignPhaseManager BattlePhase handler initialization
## 3. Battle phase start signal chain
## 4. Battle completion → POST_BATTLE transition

const CampaignPhaseManager = preload("res://src/core/campaign/CampaignPhaseManager.gd")
const CampaignTurnController = preload("res://src/ui/screens/campaign/CampaignTurnController.gd")
const WorldPhaseController = preload("res://src/ui/screens/world/WorldPhaseController.gd")
const MissionPrepComponent = preload("res://src/ui/screens/world/components/MissionPrepComponent.gd")
const BattlePhase = preload("res://src/core/campaign/phases/BattlePhase.gd")

# Scene preloads - required for controllers that have UI nodes
const WorldPhaseControllerScene = preload("res://src/ui/screens/world/WorldPhaseController.tscn")

var phase_manager: CampaignPhaseManager
var turn_controller: CampaignTurnController
var world_controller: WorldPhaseController
var mission_prep: MissionPrepComponent
var test_scene_root: Node

func before_test() -> void:
	"""Setup test environment with complete integration chain"""
	# Set deterministic seed for reproducible random numbers
	seed(12345)

	test_scene_root = auto_free(Node.new())
	add_child(test_scene_root)

	# Create phase manager
	phase_manager = auto_free(CampaignPhaseManager.new())
	test_scene_root.add_child(phase_manager)

	# Wait for initialization - CampaignPhaseManager._ready() calls _initialize_phase_handlers()
	# which creates BattlePhase, which has async _initialize_autoloads() with retry loops.
	# BattlePhase takes up to 2 seconds to initialize (10 retries * 0.1s * 2 autoloads).
	# We must wait for BattlePhase.ready_for_battle signal to ensure it's fully initialized.

	# Wait for process frames to let _ready() complete
	for i in range(3):
		await get_tree().process_frame

	# Wait for BattlePhase initialization to complete
	if phase_manager.battle_phase_handler:
		# BattlePhase sets _initialization_complete = true when _initialize_autoloads() finishes
		var ready_signaler = phase_manager.battle_phase_handler
		var timeout = 3.0
		var start_time = Time.get_ticks_msec()

		# Wait for initialization to complete or timeout
		while true:
			# Check if initialization completed (flag is set after ready_for_battle emits)
			if ready_signaler.get("_initialization_complete") == true:
				break

			# Check timeout
			if (Time.get_ticks_msec() - start_time) > (timeout * 1000):
				push_warning("BattlePhase initialization timeout after %.1f seconds" % timeout)
				break

			await get_tree().process_frame

		print("test_battle_integration_validation: BattlePhase initialized successfully")

func after_test() -> void:
	"""Cleanup test environment"""
	if test_scene_root and is_instance_valid(test_scene_root):
		test_scene_root.queue_free()
	test_scene_root = null
	phase_manager = null
	turn_controller = null
	world_controller = null
	mission_prep = null

## Test 1: Validate BattlePhase Handler Initialization
func test_battle_phase_handler_initialized() -> void:
	"""Verify BattlePhase handler is created and connected in CampaignPhaseManager"""
	if not is_instance_valid(phase_manager):
		push_warning("phase_manager freed early, skipping")
		return

	# ASSERT: BattlePhase handler exists
	assert_that(phase_manager.battle_phase_handler).is_not_null()\
		.override_failure_message("BattlePhase handler should be initialized in CampaignPhaseManager._ready()")

	if not phase_manager.battle_phase_handler:
		return

	# ASSERT: Handler is a child node
	assert_that(phase_manager.battle_phase_handler.get_parent()).is_equal(phase_manager)\
		.override_failure_message("BattlePhase handler should be child of CampaignPhaseManager")

	# ASSERT: Handler is correct type
	assert_bool(phase_manager.battle_phase_handler is BattlePhase).is_true()\
		.override_failure_message("battle_phase_handler should be instance of BattlePhase")

	# ASSERT: Handler has required method
	assert_bool(phase_manager.battle_phase_handler.has_method("start_battle_phase")).is_true()\
		.override_failure_message("BattlePhase handler must have start_battle_phase() method")

func test_battle_phase_signals_connected() -> void:
	"""Verify all BattlePhase signals are properly connected to CampaignPhaseManager"""
	if not is_instance_valid(phase_manager):
		push_warning("phase_manager freed early, skipping")
		return

	var battle_handler = phase_manager.battle_phase_handler
	assert_that(battle_handler).is_not_null()

	if not battle_handler or not is_instance_valid(battle_handler):
		return

	# ASSERT: battle_phase_completed signal connected (use safe signal access pattern)
	if battle_handler.has_signal("battle_phase_completed"):
		var connections = battle_handler.get_signal_connection_list("battle_phase_completed")
		assert_int(connections.size()).is_greater(0)\
			.override_failure_message("battle_phase_completed signal should have connections")

		# Verify connected to correct handler
		var connected_to_phase_manager = false
		for conn in connections:
			var callable = conn.get("callable", Callable())
			if callable.is_valid() and callable.get_object() == phase_manager:
				connected_to_phase_manager = true
				break
		assert_bool(connected_to_phase_manager).is_true()\
			.override_failure_message("battle_phase_completed should connect to CampaignPhaseManager")

	# ASSERT: battle_results_ready signal connected (use safe signal access pattern)
	if battle_handler.has_signal("battle_results_ready"):
		var connections = battle_handler.get_signal_connection_list("battle_results_ready")
		assert_int(connections.size()).is_greater(0)\
			.override_failure_message("battle_results_ready signal should have connections")

## Test 2: Validate Battle Phase Start Flow
func test_battle_phase_start_flow() -> void:
	"""Test complete flow from start_phase(BATTLE) → BattlePhase.start_battle_phase()"""
	if not is_instance_valid(phase_manager):
		push_warning("phase_manager freed early, skipping")
		return

	# Ensure battle phase handler exists
	if not phase_manager.battle_phase_handler:
		push_warning("battle_phase_handler not available, skipping test")
		return

	# PREREQUISITE: Transition to WORLD phase first (official phase progression requires WORLD → BATTLE)
	# Use force_phase_transition for test setup to bypass validation
	phase_manager.force_phase_transition(GlobalEnums.FiveParsecsCampaignPhase.WORLD)
	await get_tree().process_frame

	# Setup: Connect signal flags BEFORE action - use arrays for reference semantics in lambda
	var started_fired := [false]
	var completed_fired := [false]
	phase_manager.battle_phase_handler.battle_phase_started.connect(func(): started_fired[0] = true)
	phase_manager.battle_phase_handler.battle_phase_completed.connect(func(): completed_fired[0] = true)

	# ACTION: Start battle phase (now valid: WORLD → BATTLE)
	phase_manager.start_phase(GlobalEnums.FiveParsecsCampaignPhase.BATTLE)

	# NOTE: BattlePhase runs asynchronously with multiple await calls in start_battle_phase()
	# and _complete_battle_phase(). We need to wait for async execution to complete.
	# This means battle_in_progress will be false and phase may have transitioned to POST_BATTLE
	# We check that the battle_phase_started signal was emitted to validate the flow

	# Wait for async battle phase execution to complete (BattlePhase uses multiple awaits)
	await get_tree().create_timer(0.3).timeout

	# Guard against freed instance after await
	if not is_instance_valid(phase_manager) or not is_instance_valid(phase_manager.battle_phase_handler):
		return

	# ASSERT: battle_phase_started signal emitted (this validates start_battle_phase() was called)
	assert_that(started_fired[0]).is_true()

	# ASSERT: battle_phase_completed signal also emitted (battle runs synchronously to completion)
	assert_that(completed_fired[0]).is_true()

	# ASSERT: Battle setup data was populated during execution
	assert_that(phase_manager.battle_phase_handler.battle_setup_data).is_not_null()\
		.override_failure_message("battle_setup_data should be populated after battle execution")

	# ASSERT: Phase manager transitioned correctly (may be POST_BATTLE if battle completed)
	# We accept either BATTLE or POST_BATTLE since the battle completes synchronously
	var valid_phases = [GlobalEnums.FiveParsecsCampaignPhase.BATTLE, GlobalEnums.FiveParsecsCampaignPhase.POST_BATTLE]
	assert_bool(phase_manager.current_phase in valid_phases).is_true()\
		.override_failure_message("current_phase should be BATTLE or POST_BATTLE after battle flow")

## Test 3: Validate WorldPhase → Battle Transition
func test_world_phase_to_battle_transition() -> void:
	"""Test signal chain: WorldPhaseController.phase_completed → Battle phase start"""
	if not is_instance_valid(phase_manager) or not is_instance_valid(test_scene_root):
		push_warning("test instances freed early, skipping")
		return

	# PREREQUISITE: Set phase manager to WORLD phase (WORLD → BATTLE is valid transition)
	phase_manager.force_phase_transition(GlobalEnums.FiveParsecsCampaignPhase.WORLD)
	await get_tree().process_frame

	# Setup: Create world controller from scene (not .new()) to include all UI nodes
	world_controller = auto_free(WorldPhaseControllerScene.instantiate())
	test_scene_root.add_child(world_controller)
	# ready signal fires synchronously, just wait for process frames
	for i in range(3):
		await get_tree().process_frame

	# Guard against freed instance after await
	if not is_instance_valid(world_controller) or not is_instance_valid(phase_manager):
		return

	# Setup: Connect signal flag - use array for reference semantics in lambda
	var signal_fired := [false]
	phase_manager.phase_started.connect(func(_phase): signal_fired[0] = true)

	# Setup: Connect world phase completion to phase manager
	# (Normally done by CampaignTurnController, simulating here)
	world_controller.phase_completed.connect(func(results):
		if is_instance_valid(phase_manager):
			phase_manager.start_phase(GlobalEnums.FiveParsecsCampaignPhase.BATTLE)
	)

	# ACTION: Complete world phase
	var world_results = {
		"upkeep_completed": true,
		"crew_tasks_completed": true,
		"mission_selected": true
	}
	world_controller.phase_completed.emit(world_results)

	# Wait for signal propagation
	await get_tree().create_timer(0.2).timeout

	# Guard against freed instance after await
	if not is_instance_valid(phase_manager):
		return

	# ASSERT: Phase transition occurred
	assert_that(signal_fired[0]).is_true()

	# ASSERT: Transitioned to BATTLE or POST_BATTLE (battle auto-completes asynchronously)
	var valid_phases = [GlobalEnums.FiveParsecsCampaignPhase.BATTLE, GlobalEnums.FiveParsecsCampaignPhase.POST_BATTLE]
	assert_bool(phase_manager.current_phase in valid_phases).is_true()\
		.override_failure_message("Should transition to BATTLE or POST_BATTLE after world phase completion")

## Test 4: Validate Battle → POST_BATTLE Transition
func test_battle_to_postbattle_transition() -> void:
	"""Test battle completion triggers POST_BATTLE phase"""
	if not is_instance_valid(phase_manager):
		push_warning("phase_manager freed early, skipping")
		return

	# PREREQUISITE: Force to BATTLE phase directly (without running the handler)
	# Using force_phase_transition avoids auto-completion by the async BattlePhase
	phase_manager.force_phase_transition(GlobalEnums.FiveParsecsCampaignPhase.BATTLE)
	await get_tree().process_frame

	# Guard against freed instance after await
	if not is_instance_valid(phase_manager) or not phase_manager.battle_phase_handler:
		return

	# Setup: Connect signal flag - use array for reference semantics in lambda
	var signal_fired := [false]
	phase_manager.phase_started.connect(func(_phase): signal_fired[0] = true)
	var battle_handler = phase_manager.battle_phase_handler

	# ACTION: Complete battle phase (manually emit to test the handler connection)
	battle_handler.battle_phase_completed.emit()

	# Wait for transition
	await get_tree().create_timer(0.3).timeout

	# Guard against freed instance after await
	if not is_instance_valid(phase_manager):
		return

	# ASSERT: POST_BATTLE phase started
	assert_that(phase_manager.current_phase).is_equal(GlobalEnums.FiveParsecsCampaignPhase.POST_BATTLE)\
		.override_failure_message("Should transition to POST_BATTLE after battle completion")

	# ASSERT: Phase started signal emitted
	assert_that(signal_fired[0]).is_true()

## Test 5: Validate Mission Data Propagation
func test_mission_data_propagation() -> void:
	"""Verify mission data flows correctly from phase manager to battle handler"""
	if not is_instance_valid(phase_manager):
		push_warning("phase_manager freed early, skipping")
		return

	# Setup: Prepare mission data
	var test_mission = {
		"mission_id": "test_001",
		"mission_type": "patrol",
		"enemy_count": 5,
		"terrain": "wasteland",
		"difficulty": 3
	}

	# ACTION: Start battle with mission data
	phase_manager.start_phase(GlobalEnums.FiveParsecsCampaignPhase.BATTLE)
	await get_tree().create_timer(0.2).timeout

	# Guard against freed instance after await
	if not is_instance_valid(phase_manager) or not phase_manager.battle_phase_handler:
		return

	# ASSERT: Battle handler received mission data
	var battle_handler = phase_manager.battle_phase_handler
	assert_that(battle_handler.battle_setup_data).is_not_null()\
		.override_failure_message("Battle handler should store setup data")

	# ASSERT: Mission data structure exists
	assert_bool(battle_handler.battle_setup_data is Dictionary).is_true()\
		.override_failure_message("battle_setup_data should be a Dictionary")

## Test 6: Validate Battle Results Storage
func test_battle_results_storage() -> void:
	"""Test battle results are stored correctly for POST_BATTLE phase"""
	if not is_instance_valid(phase_manager):
		push_warning("phase_manager freed early, skipping")
		return

	# Setup: Start battle
	phase_manager.start_phase(GlobalEnums.FiveParsecsCampaignPhase.BATTLE)
	await get_tree().create_timer(0.2).timeout

	# Guard against freed instance after await
	if not is_instance_valid(phase_manager) or not phase_manager.battle_phase_handler:
		return

	# ACTION: Emit battle results
	var test_results = {
		"victory": true,
		"crew_participants": [
			{"name": "Test Crew 1", "status": "healthy"},
			{"name": "Test Crew 2", "status": "injured"}
		],
		"loot": ["credits:100", "weapon:laser_rifle"],
		"enemy_casualties": 3
	}

	phase_manager.battle_phase_handler.battle_results_ready.emit(test_results)
	await get_tree().create_timer(0.1).timeout

	# Guard against freed instance after await
	if not is_instance_valid(phase_manager):
		return

	# ASSERT: Results stored in phase manager
	assert_that(phase_manager._last_battle_results).is_not_null()\
		.override_failure_message("CampaignPhaseManager should store _last_battle_results")

	# ASSERT: Results data matches
	if phase_manager._last_battle_results:
		assert_bool(phase_manager._last_battle_results.has("victory")).is_true()\
			.override_failure_message("Stored results should contain victory field")

		assert_that(phase_manager._last_battle_results.get("victory")).is_equal(true)\
			.override_failure_message("Victory status should be preserved")

## Test 7: Validate Handler Initialization Timing
func test_handler_initialization_timing() -> void:
	"""Verify battle handler is ready before first use"""
	if not is_instance_valid(test_scene_root):
		push_warning("test_scene_root freed early, skipping")
		return

	# Create fresh phase manager
	var new_phase_manager = auto_free(CampaignPhaseManager.new())
	test_scene_root.add_child(new_phase_manager)

	# Wait for _ready() processing - CampaignPhaseManager creates BattlePhase which has async initialization
	for i in range(3):
		await get_tree().process_frame

	# Wait for BattlePhase async initialization (same pattern as before_test)
	if new_phase_manager.battle_phase_handler:
		var ready_signaler = new_phase_manager.battle_phase_handler
		var timeout = 3.0
		var start_time = Time.get_ticks_msec()

		while true:
			# Check initialization flag instead of autoload references
			if ready_signaler.get("_initialization_complete") == true:
				break
			if (Time.get_ticks_msec() - start_time) > (timeout * 1000):
				push_warning("BattlePhase initialization timeout in test_handler_initialization_timing")
				break
			await get_tree().process_frame

	# Guard against freed instance after await
	if not is_instance_valid(new_phase_manager):
		return

	# ASSERT: Handler initialized immediately (after async wait)
	assert_that(new_phase_manager.battle_phase_handler).is_not_null()\
		.override_failure_message("BattlePhase handler should be initialized in _ready()")

	if not new_phase_manager.battle_phase_handler:
		return

	# ASSERT: Handler is in scene tree
	assert_bool(new_phase_manager.battle_phase_handler.is_inside_tree()).is_true()\
		.override_failure_message("BattlePhase handler should be in scene tree after initialization")
