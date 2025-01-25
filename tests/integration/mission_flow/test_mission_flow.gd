@tool
extends "res://tests/fixtures/game_test.gd"

## Integration tests for mission flow
##
## Tests the interaction between different mission components:
## - Mission generation and template system
## - Mission state and objective tracking
## - Mission rewards and resource system
## - Mission completion and campaign integration

const Mission = preload("res://src/core/systems/Mission.gd")
const MissionGenerator = preload("res://src/core/systems/MissionGenerator.gd")
const MissionTemplate = preload("res://src/core/templates/MissionTemplate.gd")

var _mission_generator: MissionGenerator
var _current_mission: Mission

# Test lifecycle methods
func before_each() -> void:
	await super.before_each()
	
	# Initialize mission generator
	_mission_generator = MissionGenerator.new()
	add_child_autofree(_mission_generator)
	track_test_node(_mission_generator)
	
	# Set up campaign system
	_campaign_system = setup_campaign_system()
	watch_signals(_campaign_system)
	
	# Wait for everything to initialize
	await stabilize_engine()

func after_each() -> void:
	_mission_generator = null
	_current_mission = null
	await super.after_each()

# Mission Flow Tests
func test_mission_generation_to_completion() -> void:
	# Setup campaign first
	var campaign = create_test_campaign()
	watch_signals(campaign)
	watch_signals(_game_state)
	
	# Set campaign and wait for signals
	_game_state.current_campaign = campaign
	await assert_async_signal(_game_state, "campaign_loaded", SIGNAL_TIMEOUT)
	
	# Start campaign and wait for signals
	campaign.start_campaign()
	await assert_async_signal(campaign, "campaign_started", SIGNAL_TIMEOUT)
	
	# Setup template
	var template = MissionTemplate.new()
	template.set_mission_type(GameEnums.MissionType.PATROL)
	template.set_difficulty_range(1, 3)
	template.set_reward_range(100, 300)
	track_test_resource(template)
	
	# Generate mission
	watch_signals(_mission_generator)
	_current_mission = _mission_generator.generate_mission(template)
	track_test_resource(_current_mission)
	await assert_async_signal(_mission_generator, "mission_generated", SIGNAL_TIMEOUT)
	
	# Start mission
	watch_signals(_current_mission) # Watch mission signals before starting
	_game_state.start_mission(_current_mission)
	await assert_async_signal(_game_state, "mission_started", SIGNAL_TIMEOUT)
	
	assert_eq(_game_state.current_mission, _current_mission, "Current mission should be set")
	assert_eq(_game_state.current_state, GameEnums.GameState.BATTLE, "Game state should be BATTLE")
	
	# Complete objectives
	for i in range(_current_mission.objectives.size()):
		_current_mission.complete_objective(i)
		await assert_async_signal(_current_mission, "objective_completed", SIGNAL_TIMEOUT)
	
	assert_true(_current_mission.is_completed, "Mission should be completed")
	
	# End mission and verify rewards
	var initial_credits = _game_state.credits
	_game_state.end_mission(_current_mission)
	await assert_async_signal(_game_state, "mission_ended", SIGNAL_TIMEOUT)
	
	assert_gt(_game_state.credits, initial_credits, "Credits should increase after mission")
	assert_eq(_game_state.current_state, GameEnums.GameState.CAMPAIGN, "Game state should return to CAMPAIGN")

func test_mission_failure_handling() -> void:
	# Setup campaign first
	var campaign = create_test_campaign()
	watch_signals(campaign)
	watch_signals(_game_state)
	
	# Set campaign and wait for signals
	_game_state.current_campaign = campaign
	await assert_async_signal(_game_state, "campaign_loaded", SIGNAL_TIMEOUT)
	
	# Start campaign and wait for signals
	campaign.start_campaign()
	await assert_async_signal(campaign, "campaign_started", SIGNAL_TIMEOUT)
	
	# Setup and start mission
	var template = MissionTemplate.new()
	template.set_mission_type(GameEnums.MissionType.DEFENSE)
	track_test_resource(template)
	
	watch_signals(_mission_generator)
	_current_mission = _mission_generator.generate_mission(template)
	track_test_resource(_current_mission)
	await assert_async_signal(_mission_generator, "mission_generated", SIGNAL_TIMEOUT)
	
	# Start mission
	watch_signals(_current_mission)
	_game_state.start_mission(_current_mission)
	await assert_async_signal(_game_state, "mission_started", SIGNAL_TIMEOUT)
	
	# Fail mission
	_current_mission.fail_mission()
	await assert_async_signal(_current_mission, "mission_failed", SIGNAL_TIMEOUT)
	assert_true(_current_mission.is_failed)
	
	# Verify game state changes
	var initial_reputation = _game_state.reputation
	_game_state.end_mission(_current_mission)
	await assert_async_signal(_game_state, "mission_ended", SIGNAL_TIMEOUT)
	assert_lt(_game_state.reputation, initial_reputation)

func test_mission_resource_integration() -> void:
	# Setup campaign first
	var campaign = create_test_campaign()
	watch_signals(campaign)
	watch_signals(_game_state)
	
	# Set campaign and wait for signals
	_game_state.current_campaign = campaign
	await assert_async_signal(_game_state, "campaign_loaded", SIGNAL_TIMEOUT)
	
	# Start campaign and wait for signals
	campaign.start_campaign()
	await assert_async_signal(campaign, "campaign_started", SIGNAL_TIMEOUT)
	
	# Setup mission with resource requirements
	var template = MissionTemplate.new()
	template.set_mission_type(GameEnums.MissionType.RAID)
	template.set_resource_requirements({
		"fuel": 2,
		"supplies": 1
	})
	track_test_resource(template)
	
	watch_signals(_mission_generator)
	_current_mission = _mission_generator.generate_mission(template)
	track_test_resource(_current_mission)
	await assert_async_signal(_mission_generator, "mission_generated", SIGNAL_TIMEOUT)
	
	# Verify resource consumption
	var initial_fuel = _game_state.resources["fuel"]
	var initial_supplies = _game_state.resources["supplies"]
	
	watch_signals(_current_mission)
	_game_state.start_mission(_current_mission)
	await assert_async_signal(_game_state, "mission_started", SIGNAL_TIMEOUT)
	
	assert_eq(_game_state.resources["fuel"], initial_fuel - 2)
	assert_eq(_game_state.resources["supplies"], initial_supplies - 1)

func test_mission_state_persistence() -> void:
	# Setup campaign first
	var campaign = create_test_campaign()
	watch_signals(campaign)
	watch_signals(_game_state)
	
	# Set campaign and wait for signals
	_game_state.current_campaign = campaign
	await assert_async_signal(_game_state, "campaign_loaded", SIGNAL_TIMEOUT)
	
	# Start campaign and wait for signals
	campaign.start_campaign()
	await assert_async_signal(campaign, "campaign_started", SIGNAL_TIMEOUT)
	
	# Generate and start mission
	var template = MissionTemplate.new()
	template.set_mission_type(GameEnums.MissionType.PATROL)
	track_test_resource(template)
	
	watch_signals(_mission_generator)
	_current_mission = _mission_generator.generate_mission(template)
	track_test_resource(_current_mission)
	await assert_async_signal(_mission_generator, "mission_generated", SIGNAL_TIMEOUT)
	
	watch_signals(_current_mission)
	_game_state.start_mission(_current_mission)
	await assert_async_signal(_game_state, "mission_started", SIGNAL_TIMEOUT)
	
	# Complete some objectives
	_current_mission.complete_objective(0)
	await assert_async_signal(_current_mission, "objective_completed", SIGNAL_TIMEOUT)
	
	# Save and load state
	var save_data = _game_state.save_state()
	var new_game_state = GameStateManager.new()
	add_child_autofree(new_game_state)
	track_test_node(new_game_state)
	
	new_game_state.load_state(save_data)
	var loaded_mission = new_game_state.current_mission
	
	assert_eq(loaded_mission.get_completion_percentage(),
		_current_mission.get_completion_percentage())

func test_rapid_mission_transitions() -> void:
	# Setup campaign first
	var campaign = create_test_campaign()
	watch_signals(campaign)
	watch_signals(_game_state)
	
	# Set campaign and wait for signals
	_game_state.current_campaign = campaign
	await assert_async_signal(_game_state, "campaign_loaded", SIGNAL_TIMEOUT)
	
	# Start campaign and wait for signals
	campaign.start_campaign()
	await assert_async_signal(campaign, "campaign_started", SIGNAL_TIMEOUT)
	
	var template = MissionTemplate.new()
	template.set_mission_type(GameEnums.MissionType.PATROL)
	track_test_resource(template)
	
	watch_signals(_mission_generator)
	var start_time = Time.get_ticks_msec()
	for i in range(10):
		var mission = _mission_generator.generate_mission(template)
		track_test_resource(mission)
		await assert_async_signal(_mission_generator, "mission_generated", SIGNAL_TIMEOUT)
		
		watch_signals(mission)
		_game_state.start_mission(mission)
		await assert_async_signal(_game_state, "mission_started", SIGNAL_TIMEOUT)
		
		mission.complete_objective(0)
		await assert_async_signal(mission, "objective_completed", SIGNAL_TIMEOUT)
		
		_game_state.end_mission(mission)
		await assert_async_signal(_game_state, "mission_ended", SIGNAL_TIMEOUT)
	
	var duration = Time.get_ticks_msec() - start_time
	assert_lt(duration, 1000, "Should handle rapid mission transitions efficiently")
