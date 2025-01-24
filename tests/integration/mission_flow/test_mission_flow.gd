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
const GameStateManager = preload("res://src/core/managers/GameStateManager.gd")

var _mission_generator: MissionGenerator
var _game_state: GameStateManager
var _current_mission: Mission

# Test lifecycle methods
func before_each() -> void:
	await super.before_each()
	_game_state = GameStateManager.new()
	_mission_generator = MissionGenerator.new()
	add_child(_game_state)
	add_child(_mission_generator)
	track_test_node(_game_state)
	track_test_node(_mission_generator)

func after_each() -> void:
	await super.after_each()
	_mission_generator = null
	_game_state = null
	_current_mission = null

# Mission Flow Tests
func test_mission_generation_to_completion() -> void:
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
	assert_signal_emitted(_mission_generator, "mission_generated")
	
	# Start mission
	_game_state.start_mission(_current_mission)
	assert_eq(_game_state.current_mission, _current_mission)
	assert_eq(_game_state.current_state, GameEnums.GameState.BATTLE)
	
	# Complete objectives
	for i in range(_current_mission.objectives.size()):
		_current_mission.complete_objective(i)
	assert_true(_current_mission.is_completed)
	
	# End mission and verify rewards
	var initial_credits = _game_state.credits
	_game_state.end_mission(_current_mission)
	assert_gt(_game_state.credits, initial_credits)
	assert_eq(_game_state.current_state, GameEnums.GameState.CAMPAIGN)

func test_mission_failure_handling() -> void:
	# Setup and start mission
	var template = MissionTemplate.new()
	template.set_mission_type(GameEnums.MissionType.DEFENSE)
	track_test_resource(template)
	
	_current_mission = _mission_generator.generate_mission(template)
	track_test_resource(_current_mission)
	_game_state.start_mission(_current_mission)
	
	# Fail mission
	_current_mission.fail_mission()
	assert_true(_current_mission.is_failed)
	
	# Verify game state changes
	var initial_reputation = _game_state.reputation
	_game_state.end_mission(_current_mission)
	assert_lt(_game_state.reputation, initial_reputation)

func test_mission_resource_integration() -> void:
	# Setup mission with resource requirements
	var template = MissionTemplate.new()
	template.set_mission_type(GameEnums.MissionType.RAID)
	template.set_resource_requirements({
		"fuel": 2,
		"supplies": 1
	})
	track_test_resource(template)
	
	_current_mission = _mission_generator.generate_mission(template)
	track_test_resource(_current_mission)
	
	# Verify resource consumption
	var initial_fuel = _game_state.resources["fuel"]
	var initial_supplies = _game_state.resources["supplies"]
	_game_state.start_mission(_current_mission)
	
	assert_eq(_game_state.resources["fuel"], initial_fuel - 2)
	assert_eq(_game_state.resources["supplies"], initial_supplies - 1)

func test_mission_state_persistence() -> void:
	# Generate and start mission
	var template = MissionTemplate.new()
	template.set_mission_type(GameEnums.MissionType.PATROL)
	track_test_resource(template)
	
	_current_mission = _mission_generator.generate_mission(template)
	track_test_resource(_current_mission)
	_game_state.start_mission(_current_mission)
	
	# Complete some objectives
	_current_mission.complete_objective(0)
	
	# Save and load state
	var save_data = _game_state.save_state()
	var new_game_state = GameStateManager.new()
	add_child(new_game_state)
	track_test_node(new_game_state)
	
	new_game_state.load_state(save_data)
	var loaded_mission = new_game_state.current_mission
	
	assert_eq(loaded_mission.get_completion_percentage(),
		_current_mission.get_completion_percentage())

func test_rapid_mission_transitions() -> void:
	var template = MissionTemplate.new()
	template.set_mission_type(GameEnums.MissionType.PATROL)
	track_test_resource(template)
	
	var start_time = Time.get_ticks_msec()
	for i in range(10):
		var mission = _mission_generator.generate_mission(template)
		track_test_resource(mission)
		_game_state.start_mission(mission)
		mission.complete_objective(0)
		_game_state.end_mission(mission)
	
	var duration = Time.get_ticks_msec() - start_time
	assert_lt(duration, 1000, "Should handle rapid mission transitions efficiently")