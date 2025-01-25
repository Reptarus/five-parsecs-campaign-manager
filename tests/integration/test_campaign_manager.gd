@tool
extends "res://tests/fixtures/game_test.gd"

const StoryQuestData := preload("res://src/core/story/StoryQuestData.gd")
const CampaignManager := preload("res://src/core/managers/CampaignManager.gd")

var game_state: GameState = null
var campaign_manager: CampaignManager = null

func before_all() -> void:
	super.before_all()

func after_all() -> void:
	super.after_all()

func before_each() -> void:
	await super.before_each()
	
	# Initialize game state
	game_state = create_test_game_state()
	add_child_autofree(game_state)
	track_test_node(game_state)
	
	# Initialize campaign manager
	campaign_manager = CampaignManager.new(game_state)
	track_test_resource(campaign_manager)
	
	# Set up required resources
	game_state.add_resource(GameEnums.ResourceType.SUPPLIES, 100)
	game_state.add_resource(GameEnums.ResourceType.FUEL, 100)
	game_state.add_resource(GameEnums.ResourceType.MEDICAL_SUPPLIES, 100)
	
	await stabilize_engine()

func after_each() -> void:
	# Clean up nodes first
	if is_instance_valid(game_state):
		remove_child(game_state)
		game_state.queue_free()
	
	# Wait for nodes to be freed
	await get_tree().process_frame
	
	# Clear references
	campaign_manager = null
	game_state = null
	
	# Let parent handle remaining cleanup
	await super.after_each()
	
	# Clear any tracked resources
	_tracked_resources.clear()

# Test campaign initialization
func test_campaign_initialization() -> void:
	assert_not_null(campaign_manager, "Campaign manager should be initialized")
	assert_not_null(campaign_manager.game_state, "Game state should be set")
	assert_eq(campaign_manager.get_current_phase(), GameEnums.FiveParcsecsCampaignPhase.NONE, "Should start in NONE phase")

# Test phase transitions
func test_phase_transitions() -> void:
	watch_signals(campaign_manager)
	
	campaign_manager.start_campaign()
	assert_eq(campaign_manager.get_current_phase(), GameEnums.FiveParcsecsCampaignPhase.SETUP)
	assert_signal_emitted(campaign_manager, "phase_changed")
	
	campaign_manager.advance_phase()
	assert_eq(campaign_manager.get_current_phase(), GameEnums.FiveParcsecsCampaignPhase.CAMPAIGN)
	assert_signal_emitted(campaign_manager, "phase_changed")

# Test resource management
func test_resource_management() -> void:
	watch_signals(game_state)
	
	campaign_manager.add_resources({
		GameEnums.ResourceType.CREDITS: 100,
		GameEnums.ResourceType.SUPPLIES: 50
	})
	
	assert_eq(game_state.get_resource(GameEnums.ResourceType.CREDITS), 100)
	assert_eq(game_state.get_resource(GameEnums.ResourceType.SUPPLIES), 150)
	assert_signal_emitted(game_state, "resources_changed")

# Test story quest handling
func test_story_quest_handling() -> void:
	watch_signals(campaign_manager)
	
	var quest_data = {
		"id": "test_quest",
		"title": "Test Quest",
		"description": "A test quest",
		"objectives": [],
		"rewards": {
			"credits": 100,
			"reputation": 1
		}
	}
	
	campaign_manager.add_story_quest(quest_data)
	assert_true(campaign_manager.has_active_quest("test_quest"))
	assert_signal_emitted(campaign_manager, "quest_added")
	
	campaign_manager.complete_quest("test_quest")
	assert_false(campaign_manager.has_active_quest("test_quest"))
	assert_signal_emitted(campaign_manager, "quest_completed")

# Test campaign cleanup
func test_campaign_cleanup() -> void:
	campaign_manager.start_campaign()
	campaign_manager.add_resources({
		GameEnums.ResourceType.CREDITS: 100
	})
	
	campaign_manager.cleanup()
	
	assert_eq(campaign_manager.get_current_phase(), GameEnums.FiveParcsecsCampaignPhase.NONE)
	assert_eq(game_state.get_resource(GameEnums.ResourceType.CREDITS), 0)

func test_initial_state() -> void:
	# Null checks
	assert_not_null(game_state, "Game state should be initialized")
	assert_not_null(campaign_manager, "Campaign manager should be initialized")
	
	# Boolean checks
	assert_false(game_state.has_active_campaign(), "Game state should start with no active campaign")
	
	# Collection size checks
	assert_eq(campaign_manager.get_available_missions().size(), 0, "Should start with no available missions")
	assert_eq(campaign_manager.get_active_missions().size(), 0, "Should start with no active missions")
	assert_eq(campaign_manager.get_completed_missions().size(), 0, "Should start with no completed missions")
	
	# Instance type checks
	assert_is_instance(campaign_manager, "CampaignManager", "Should be a CampaignManager instance")

func test_mission_management() -> void:
	load_test_campaign(game_state)
	watch_signals(campaign_manager)
	
	# Create and configure mission
	var mission = StoryQuestData.create_mission(GameEnums.MissionType.PATROL, {
		"difficulty": GameEnums.DifficultyLevel.NORMAL,
		"risk_level": 1
	})
	mission.configure(GameEnums.MissionType.PATROL)
	
	# Set up mission requirements
	mission.required_crew_size = 1 # Minimum crew size
	var equipment: Array[String] = []
	mission.required_equipment = equipment # No special equipment needed
	mission.required_resources = {
		GameEnums.ResourceType.SUPPLIES: 10, # Basic supply requirement
		GameEnums.ResourceType.FUEL: 5 # Basic fuel requirement
	}
	
	# Add objective
	mission.add_objective(GameEnums.MissionObjective.PATROL, "Patrol the designated area", true)
	
	# Validate mission before adding
	var mission_validation = mission.validate()
	assert_true(mission_validation.is_valid, "Mission should be valid: " + str(mission_validation.get("errors", [])))
	
	# Add to available missions
	campaign_manager.available_missions.append(mission)
	campaign_manager.mission_available.emit(mission)
	
	# Validate campaign state
	var campaign_validation = campaign_manager.validate_campaign_state()
	assert_true(campaign_validation.is_valid, "Campaign should be valid: " + str(campaign_validation.get("errors", [])))
	
	# Verify mission was added
	assert_eq(campaign_manager.available_missions.size(), 1, "Should add to available missions")
	
	# Start mission
	assert_true(campaign_manager.start_mission(mission), "Should start mission")
	var mission_started = await assert_async_signal(campaign_manager, "mission_started")
	assert_true(mission_started, "Mission started signal should be emitted")
	assert_eq(campaign_manager.available_missions.size(), 0, "Should remove from available missions")
	assert_eq(campaign_manager.active_missions.size(), 1, "Should add to active missions")

func test_mission_completion() -> void:
	load_test_campaign(game_state)
	watch_signals(campaign_manager)
	
	# Set up initial resources
	var initial_credits = game_state.credits
	var initial_reputation = game_state.reputation
	var initial_supplies = 100
	game_state.set_resource(GameEnums.ResourceType.SUPPLIES, initial_supplies)
	
	# Create and configure mission
	var mission = campaign_manager.create_mission(GameEnums.MissionType.PATROL, {
		"difficulty": GameEnums.DifficultyLevel.NORMAL,
		"risk_level": 1
	})
	
	# Configure mission requirements and rewards
	mission.configure(GameEnums.MissionType.PATROL)
	mission.add_objective(GameEnums.MissionObjective.PATROL, "Patrol the designated area", true)
	var equipment: Array[String] = []
	mission.required_equipment = equipment
	mission.required_resources = {
		GameEnums.ResourceType.SUPPLIES: 10
	}
	mission.reward_credits = 500
	mission.reward_reputation = 5
	
	var validation = mission.validate()
	assert_true(validation.is_valid, "Mission should be valid: " + str(validation.get("errors", [])))
	
	# Ensure mission is in available missions
	if not mission in campaign_manager.available_missions:
		campaign_manager.available_missions.append(mission)
	
	# Start mission and complete objectives
	assert_true(campaign_manager.start_mission(mission), "Should successfully start mission")
	var mission_started = await assert_async_signal(campaign_manager, "mission_started")
	assert_true(mission_started, "Mission started signal should be emitted")
	assert_true(mission in campaign_manager.get_active_missions(), "Mission should be in active missions")
	mission.complete_objective(GameEnums.MissionObjective.PATROL)
	
	# Complete mission
	campaign_manager.complete_mission(mission)
	var mission_completed = await assert_async_signal(campaign_manager, "mission_completed")
	assert_true(mission_completed, "Mission completed signal should be emitted")
	
	# Verify mission state changes
	assert_eq(campaign_manager.get_active_missions().size(), 0, "Should remove from active missions")
	assert_eq(campaign_manager.get_completed_missions().size(), 1, "Should add to completed missions")
	
	# Verify resource consumption
	var final_supplies = game_state.get_resource(GameEnums.ResourceType.SUPPLIES)
	assert_eq(final_supplies, initial_supplies - 10, "Should consume required supplies")
	
	# Verify rewards
	assert_eq(game_state.credits, initial_credits + 500, "Should award mission credits")
	assert_eq(game_state.reputation, initial_reputation + 5, "Should award mission reputation")
	
	# Verify mission history
	var history = campaign_manager.get_mission_history()
	assert_eq(history.size(), 1, "Should add mission to history")
	var history_entry = history[0]
	
	# Check history entry details
	assert_has(history_entry, "rewards", "History should include rewards")
	assert_eq(history_entry.rewards.credits, 500, "History should record correct reward credits")
	assert_eq(history_entry.rewards.reputation, 5, "History should record correct reward reputation")
	assert_has(history_entry, "resources_consumed", "History should include consumed resources")
	assert_eq(history_entry.resources_consumed[GameEnums.ResourceType.SUPPLIES], 10, "History should record correct resource consumption")
	assert_true(history_entry.is_completed, "Should be marked as completed in history")
	assert_false(history_entry.is_failed, "Should not be marked as failed in history")

func test_mission_failure() -> void:
	load_test_campaign(game_state)
	watch_signals(campaign_manager)
	
	# Set up initial resources
	var initial_credits = game_state.credits
	var initial_reputation = game_state.reputation
	var initial_supplies = 100
	game_state.set_resource(GameEnums.ResourceType.SUPPLIES, initial_supplies)
	
	# Create and configure mission
	var mission = campaign_manager.create_mission(GameEnums.MissionType.PATROL, {
		"difficulty": GameEnums.DifficultyLevel.NORMAL,
		"risk_level": 1
	})
	
	# Configure mission requirements and rewards
	mission.configure(GameEnums.MissionType.PATROL)
	mission.add_objective(GameEnums.MissionObjective.PATROL, "Patrol the designated area", true)
	var equipment: Array[String] = []
	mission.required_equipment = equipment
	mission.required_resources = {
		GameEnums.ResourceType.SUPPLIES: 10
	}
	mission.reward_credits = 500
	mission.reward_reputation = 5
	
	var validation = mission.validate()
	assert_true(validation.is_valid, "Mission should be valid: " + str(validation.get("errors", [])))
	
	# Ensure mission is in available missions
	if not mission in campaign_manager.available_missions:
		campaign_manager.available_missions.append(mission)
	
	# Start mission
	assert_true(campaign_manager.start_mission(mission), "Should successfully start mission")
	var mission_started = await assert_async_signal(campaign_manager, "mission_started")
	assert_true(mission_started, "Mission started signal should be emitted")
	assert_true(mission in campaign_manager.get_active_missions(), "Mission should be in active missions")
	
	# Fail mission
	campaign_manager.fail_mission(mission)
	var mission_failed = await assert_async_signal(campaign_manager, "mission_failed")
	assert_true(mission_failed, "Mission failed signal should be emitted")
	
	# Verify mission state changes
	assert_eq(campaign_manager.get_active_missions().size(), 0, "Should remove from active missions")
	assert_eq(campaign_manager.get_completed_missions().size(), 0, "Should not add to completed missions")
	assert_true(mission.is_failed, "Mission should be marked as failed")
	assert_false(mission.is_active, "Mission should not be active")
	
	# Verify resource consumption still happens
	var final_supplies = game_state.get_resource(GameEnums.ResourceType.SUPPLIES)
	assert_eq(final_supplies, initial_supplies - 10, "Should still consume required supplies")
	
	# Verify no rewards given
	assert_eq(game_state.credits, initial_credits, "Should not award mission credits")
	assert_eq(game_state.reputation, initial_reputation, "Should not award mission reputation")
	
	# Verify mission history
	var history = campaign_manager.get_mission_history()
	assert_eq(history.size(), 1, "Should add mission to history")
	var history_entry = history[0]
	
	# Check history entry details
	assert_has(history_entry, "resources_consumed", "History should include consumed resources")
	assert_eq(history_entry.resources_consumed[GameEnums.ResourceType.SUPPLIES], 10, "History should record correct resource consumption")
	assert_false(history_entry.is_completed, "Mission should not be marked as completed in history")
	assert_true(history_entry.is_failed, "Mission should be marked as failed in history")
	assert_has(history_entry, "rewards", "History should include rewards field even if empty")
	assert_eq(history_entry.rewards.credits, 0, "History should record no reward credits")
	assert_eq(history_entry.rewards.reputation, 0, "History should record no reward reputation")

func test_campaign_validation() -> void:
	load_test_campaign(game_state)
	watch_signals(campaign_manager)
	
	# Initial validation
	var validation = campaign_manager.validate_campaign_state()
	assert_true(validation.is_valid, "Campaign should be valid initially: " + str(validation.get("errors", [])))
	assert_eq(validation.get("errors", []).size(), 0, "Should have no validation errors")
	assert_has(validation, "warnings", "Validation result should include warnings field")
	
	# Test resource validation
	var initial_supplies = game_state.get_resource(GameEnums.ResourceType.SUPPLIES)
	assert_gt(initial_supplies, 0, "Should start with positive supplies")
	
	# Remove a required resource to trigger validation error
	game_state.set_resource(GameEnums.ResourceType.SUPPLIES, 0)
	validation = campaign_manager.validate_campaign_state()
	assert_false(validation.is_valid, "Campaign should be invalid with missing resources")
	assert_gt(validation.get("errors", []).size(), 0, "Should have validation errors")
	var validation_failed = await assert_async_signal(campaign_manager, "validation_failed")
	assert_true(validation_failed, "Validation failed signal should be emitted")
	
	# Test mission count validation
	for i in range(campaign_manager.MAX_ACTIVE_MISSIONS + 1):
		var mission = campaign_manager.create_mission(GameEnums.MissionType.PATROL)
		campaign_manager.available_missions.append(mission)
	
	validation = campaign_manager.validate_campaign_state()
	assert_false(validation.is_valid, "Campaign should be invalid with too many missions")
	assert_gt(validation.get("errors", []).size(), 0, "Should have validation errors")
	validation_failed = await assert_async_signal(campaign_manager, "validation_failed")
	assert_true(validation_failed, "Validation failed signal should be emitted")

func test_mission_requirements() -> void:
	load_test_campaign(game_state)
	watch_signals(campaign_manager)
	
	var mission = campaign_manager.create_mission(GameEnums.MissionType.PATROL)
	
	# Test crew size requirements
	var initial_crew_size = game_state.get_crew_size()
	assert_ge(initial_crew_size, 1, "Should start with at least one crew member")
	
	mission.required_crew_size = initial_crew_size + 1
	var requirement_errors = campaign_manager._validate_mission_requirements(mission)
	assert_gt(requirement_errors.size(), 0, "Should have errors with insufficient crew")
	
	# Test resource requirements
	var initial_supplies = game_state.get_resource(GameEnums.ResourceType.SUPPLIES)
	mission.required_resources = {
		GameEnums.ResourceType.SUPPLIES: initial_supplies + 1
	}
	requirement_errors = campaign_manager._validate_mission_requirements(mission)
	assert_gt(requirement_errors.size(), 0, "Should have errors with insufficient resources")
	
	# Test equipment requirements
	var test_equipment = "test_equipment"
	mission.required_equipment = [test_equipment]
	requirement_errors = campaign_manager._validate_mission_requirements(mission)
	assert_does_not_have(game_state.get_equipment(), test_equipment, "Should not have required equipment")
	assert_gt(requirement_errors.size(), 0, "Should have errors with missing equipment")

func test_mission_history_management() -> void:
	load_test_campaign(game_state)
	watch_signals(campaign_manager)
	
	# Test history entry creation
	var mission = campaign_manager.create_mission(GameEnums.MissionType.PATROL)
	var history_entry = campaign_manager._create_mission_history_entry(mission)
	
	# Check required fields
	var required_fields = ["mission_id", "mission_type", "name", "completion_percentage",
						  "is_completed", "is_failed", "objectives_completed", "total_objectives",
						  "resources_consumed", "crew_involved", "timestamp"]
	
	for field in required_fields:
		assert_has(history_entry, field, "History entry should have %s field" % field)
	
	# Test history size limits
	for i in range(campaign_manager.MAX_MISSION_HISTORY + 1):
		var test_mission = campaign_manager.create_mission(GameEnums.MissionType.PATROL)
		campaign_manager.mission_history.append(campaign_manager._create_mission_history_entry(test_mission))
	
	campaign_manager.cleanup_campaign_state()
	assert_le(campaign_manager.mission_history.size(), campaign_manager.MAX_MISSION_HISTORY,
			 "Should not exceed maximum history size")

func test_mission_state_transitions() -> void:
	load_test_campaign(game_state)
	watch_signals(campaign_manager)
	
	# Create test missions
	var mission1 = campaign_manager.create_mission(GameEnums.MissionType.PATROL)
	var mission2 = campaign_manager.create_mission(GameEnums.MissionType.RESCUE)
	
	# Test initial state
	assert_false(mission1.is_active, "Mission should not start active")
	assert_false(mission1.is_completed, "Mission should not start completed")
	assert_false(mission1.is_failed, "Mission should not start failed")
	
	# Test invalid transitions
	campaign_manager.complete_mission(mission1)
	assert_false(mission1.is_completed, "Should not complete non-active mission")
	
	campaign_manager.fail_mission(mission2)
	assert_false(mission2.is_failed, "Should not fail non-active mission")
	
	# Test valid transitions
	campaign_manager.start_mission(mission1)
	assert_true(mission1.is_active, "Mission should be active after start")
	assert_has(campaign_manager.get_active_missions(), mission1, "Mission should be in active missions")
	
	mission1.complete_objective(GameEnums.MissionObjective.PATROL)
	campaign_manager.complete_mission(mission1)
	assert_true(mission1.is_completed, "Mission should be completed")
	assert_has(campaign_manager.get_completed_missions(), mission1, "Mission should be in completed missions")
	assert_does_not_have(campaign_manager.get_active_missions(), mission1, "Mission should not be in active missions")

func test_mission_generation() -> void:
	load_test_campaign(game_state)
	watch_signals(campaign_manager)
	
	campaign_manager.generate_available_missions()
	var available = campaign_manager.get_available_missions()
	
	assert_true(available.size() > 0, "Should generate available missions")
	assert_signal_emitted(campaign_manager, "mission_available")
	
	for mission in available:
		assert_true(mission is StoryQuestData, "Generated missions should be StoryQuestData")
		var validation = mission.validate()
		assert_true(validation.is_valid, "Generated mission should be valid: " + str(validation.get("errors", [])))

func test_mission_rewards() -> void:
	load_test_campaign(game_state)
	watch_signals(campaign_manager)
	
	var mission = campaign_manager.create_mission(GameEnums.MissionType.PATROL, {
		"difficulty": GameEnums.DifficultyLevel.NORMAL,
		"risk_level": 1
	})
	
	# Configure and validate mission before starting
	mission.configure(GameEnums.MissionType.PATROL)
	mission.add_objective(GameEnums.MissionObjective.PATROL, "Patrol the designated area", true)
	var equipment: Array[String] = []
	mission.required_equipment = equipment
	var validation = mission.validate()
	assert_true(validation.is_valid, "Mission should be valid: " + str(validation.get("errors", [])))
	
	campaign_manager.start_mission(mission)
	campaign_manager.complete_mission(mission)
	
	# Verify mission history contains reward info
	var history = campaign_manager.get_mission_history()
	assert_eq(history.size(), 1, "Should add mission to history")
	assert_has(history[0], "rewards", "History should include rewards")

func test_mission_generation_limits() -> void:
	load_test_campaign(game_state)
	watch_signals(campaign_manager)
	
	# Set high reputation to enable patron missions
	game_state.reputation = campaign_manager.MIN_REPUTATION_FOR_PATRONS + 10
	
	# Generate first batch of missions
	campaign_manager.generate_available_missions()
	var first_batch = campaign_manager.get_available_missions()
	assert_true(first_batch.size() > 0, "Should generate first batch of missions")
	
	# Try to generate more missions when at max
	campaign_manager.generate_available_missions()
	var second_batch = campaign_manager.get_available_missions()
	assert_eq(second_batch.size(), first_batch.size(), "Should not exceed maximum mission count")
	
	# Verify patron missions are included with high reputation
	var has_patron_mission = false
	for mission in second_batch:
		if mission.mission_type == GameEnums.MissionType.PATRON:
			has_patron_mission = true
			break
	assert_true(has_patron_mission, "Should include patron missions with high reputation")

func test_multiple_resource_consumption() -> void:
	load_test_campaign(game_state)
	watch_signals(campaign_manager)
	
	# Set up initial resources
	var initial_supplies = 50
	var initial_fuel = 30
	var initial_medical = 20
	game_state.set_resource(GameEnums.ResourceType.SUPPLIES, initial_supplies)
	game_state.set_resource(GameEnums.ResourceType.FUEL, initial_fuel)
	game_state.set_resource(GameEnums.ResourceType.MEDICAL_SUPPLIES, initial_medical)
	
	# Create mission with multiple resource requirements
	var mission = campaign_manager.create_mission(GameEnums.MissionType.PATROL, {
		"difficulty": GameEnums.DifficultyLevel.NORMAL,
		"risk_level": 1
	})
	
	mission.configure(GameEnums.MissionType.PATROL)
	mission.required_resources = {
		GameEnums.ResourceType.SUPPLIES: 10,
		GameEnums.ResourceType.FUEL: 5,
		GameEnums.ResourceType.MEDICAL_SUPPLIES: 2
	}
	
	# Start and complete mission
	campaign_manager.start_mission(mission)
	campaign_manager.complete_mission(mission)
	
	# Verify all resources were consumed
	assert_eq(game_state.get_resource(GameEnums.ResourceType.SUPPLIES), initial_supplies - 10)
	assert_eq(game_state.get_resource(GameEnums.ResourceType.FUEL), initial_fuel - 5)
	assert_eq(game_state.get_resource(GameEnums.ResourceType.MEDICAL_SUPPLIES), initial_medical - 2)
	
	# Verify history tracks all consumed resources
	var history = campaign_manager.get_mission_history()
	var history_entry = history[0]
	assert_eq(history_entry.resources_consumed[GameEnums.ResourceType.SUPPLIES], 10)
	assert_eq(history_entry.resources_consumed[GameEnums.ResourceType.FUEL], 5)
	assert_eq(history_entry.resources_consumed[GameEnums.ResourceType.MEDICAL_SUPPLIES], 2)

func test_force_complete_mission() -> void:
	load_test_campaign(game_state)
	watch_signals(campaign_manager)
	
	var mission = campaign_manager.create_mission(GameEnums.MissionType.PATROL, {"difficulty": GameEnums.DifficultyLevel.NORMAL})
	mission.configure(GameEnums.MissionType.PATROL)
	mission.add_objective(GameEnums.MissionObjective.PATROL, "Patrol the area", true)
	
	campaign_manager.start_mission(mission)
	
	# Try normal completion without meeting objectives
	campaign_manager.complete_mission(mission)
	assert_false(mission.is_completed, "Should not complete without meeting objectives")
	
	# Force complete
	campaign_manager.complete_mission(mission, true)
	assert_true(mission.is_completed, "Should force complete regardless of objectives")
	assert_true(mission in campaign_manager.get_completed_missions(), "Should be in completed missions")

func test_resource_edge_cases() -> void:
	load_test_campaign(game_state)
	watch_signals(campaign_manager)
	
	var mission = campaign_manager.create_mission(GameEnums.MissionType.PATROL, {"difficulty": GameEnums.DifficultyLevel.NORMAL})
	mission.configure(GameEnums.MissionType.PATROL)
	
	# Test with exact resource amount
	game_state.set_resource(GameEnums.ResourceType.SUPPLIES, 10)
	mission.required_resources = {
		GameEnums.ResourceType.SUPPLIES: 10
	}
	
	assert_true(campaign_manager.start_mission(mission), "Should start with exact resources")
	campaign_manager.complete_mission(mission)
	assert_eq(game_state.get_resource(GameEnums.ResourceType.SUPPLIES), 0, "Should consume to zero")
	
	# Test with insufficient resources
	var mission2 = campaign_manager.create_mission(GameEnums.MissionType.RESCUE, {"difficulty": GameEnums.DifficultyLevel.NORMAL})
	mission2.configure(GameEnums.MissionType.RESCUE)
	mission2.required_resources = {
		GameEnums.ResourceType.SUPPLIES: 1
	}
	
	assert_false(campaign_manager.start_mission(mission2), "Should not start with insufficient resources")
