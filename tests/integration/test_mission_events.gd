@tool
extends "res://tests/fixtures/game_test.gd"

const Mission := preload("res://src/core/systems/Mission.gd")
const TerrainSystem := preload("res://src/core/terrain/TerrainSystem.gd")
const RivalSystem := preload("res://src/core/rivals/RivalSystem.gd")
const PositionValidator := preload("res://src/core/systems/PositionValidator.gd")
const EventManager := preload("res://src/core/managers/EventManager.gd")
const MissionGenerator := preload("res://src/core/systems/MissionGenerator.gd")
const ResourceSystem := preload("res://src/core/systems/ResourceSystem.gd")

var mission: Mission = null
var game_state: GameState = null
var _received_signals := []

func before_all() -> void:
	super.before_all()

func after_all() -> void:
	super.after_all()

func before_each() -> void:
	await super.before_each()
	
	# Initialize game state first
	game_state = create_test_game_state()
	add_child_autofree(game_state)
	track_test_node(game_state)
	
	# Initialize mission as a resource
	mission = Mission.new()
	track_test_resource(mission)
	
	# Setup default mission state
	mission.mission_name = "Test Mission"
	mission.mission_type = GameEnums.MissionType.PATROL
	mission.difficulty = GameEnums.DifficultyLevel.NORMAL
	
	# Watch signals
	watch_signals(mission)
	watch_signals(game_state)
	
	await stabilize_engine()

func after_each() -> void:
	# Let parent handle cleanup first to ensure proper order
	await super.after_each()
	
	# Clean up game state node if still valid
	if is_instance_valid(game_state):
		if game_state.get_parent():
			remove_child(game_state)
		game_state.queue_free()
	
	# Wait for nodes to be freed
	await get_tree().process_frame
	
	# Clear references
	mission = null
	game_state = null
	_received_signals.clear()
	
	# Clear tracked resources
	_tracked_resources.clear()

# Test mission event handling
func test_mission_event_handling() -> void:
	# Trigger mission events
	mission.change_phase("preparation")
	assert_signal_emitted(mission, "phase_changed")
	
	mission.is_completed = true
	assert_signal_emitted(mission, "mission_completed")
	assert_true(mission.is_completed)

# Test mission state transitions
func test_mission_state_transitions() -> void:
	assert_eq(mission.current_phase, "preparation")
	
	mission.change_phase("combat")
	assert_eq(mission.current_phase, "combat")
	
	mission.is_completed = true
	assert_true(mission.is_completed)

# Test mission rewards
func test_mission_rewards() -> void:
	mission.rewards = {
		"credits": 100,
		"experience": 50,
		"items": ["medkit", "ammo"]
	}
	
	mission.change_phase("combat")
	mission.is_completed = true
	
	var rewards = mission.calculate_final_rewards()
	assert_eq(rewards.credits, 100)
	assert_eq(rewards.experience, 50)
	assert_eq(rewards.items.size(), 2)

# Test mission failure handling
func test_mission_failure() -> void:
	mission.change_phase("combat")
	mission.fail_mission()
	
	assert_true(mission.is_failed)
	assert_false(mission.is_completed)
	assert_eq(mission.get_summary().status, "failed")

# Test mission cleanup
func test_mission_cleanup() -> void:
	mission.change_phase("combat")
	mission.is_completed = true
	
	mission.change_phase("preparation")
	mission.is_completed = false
	mission.is_failed = false
	
	assert_eq(mission.current_phase, "preparation")
	assert_false(mission.is_completed)
	assert_false(mission.is_failed)
