@tool
extends RefCounted
class_name GameStateTestAdapter

# This adapter allows us to use GameState in tests without extensive modifications
# Universal Mock Strategy patterns applied

const GameStateScript: GDScript = preload("res://src/core/state/GameState.gd")
const GameEnumsScript: GDScript = preload("res://src/core/systems/GlobalEnums.gd")

# Test instance creation methods
static func create_test_instance() -> GameState:
	var state = GameStateScript.new()
	return state

static func create_default_test_state() -> GameState:
	var state = create_test_instance()
	
	# Set default test values
	state.current_phase = 2 # Use direct value instead of missing enum
	state.turn_number = 1
	state.story_points = 3
	state.reputation = 50
	state.resources = {
		GameEnumsScript.ResourceType.CREDITS: 1000,
		GameEnumsScript.ResourceType.FUEL: 10,
		GameEnumsScript.ResourceType.TECH_PARTS: 5
	}
	
	return state

# Serialization methods
static func deserialize_from_dict(data: Dictionary) -> GameState:
	var state = create_test_instance()
	# Apply serialized data to state
	return state

static func create_test_serialized_state() -> Dictionary:
	return {
		"current_phase": 2, # Use direct value instead of missing enum
		"turn_number": 1,
		"story_points": 3,
		"reputation": 50,
		"resources": {
			GameEnumsScript.ResourceType.CREDITS: 1000,
			GameEnumsScript.ResourceType.FUEL: 10,
			GameEnumsScript.ResourceType.TECH_PARTS: 5
		},
		"active_quests": [],
		"completed_quests": [],
		"visited_locations": []
	}