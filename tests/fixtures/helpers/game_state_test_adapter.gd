@tool
extends RefCounted
# Use explicit preloads instead of global class names
const GameStateTestAdapterScript = preload("res://tests/fixtures/helpers/game_state_test_adapter.gd")

# This adapter allows us to use GameState in tests without extensive modifications
# to the source file, working around linter errors

const GameStateScript: GDScript = preload("res://src/core/state/GameState.gd")
const GameEnumsScript: GDScript = preload("res://src/core/systems/GlobalEnums.gd")

# Create a new GameState instance for testing
static func create_test_instance() -> Node:
	return GameStateScript.new() as Node

# Helper to create a GameState with default test values
static func create_default_test_state() -> Node:
	var state := create_test_instance()
	
	# Initialize with sensible defaults for testing
	state.current_phase = GameEnumsScript.FiveParcsecsCampaignPhase.CAMPAIGN
	state.turn_number = 1
	state.story_points = 3
	state.reputation = 50
	state.resources = {
		GameEnumsScript.ResourceType.CREDITS: 1000,
		GameEnumsScript.ResourceType.FUEL: 10,
		GameEnumsScript.ResourceType.TECH_PARTS: 5
	}
	
	return state

# Wrapper for the static deserialization to avoid type issues
static func deserialize_from_dict(data: Dictionary) -> Node:
	return GameStateScript.deserialize_new(data)

# Helper to create a serialized state for testing
static func create_test_serialized_state() -> Dictionary:
	return {
		"current_phase": GameEnumsScript.FiveParcsecsCampaignPhase.CAMPAIGN,
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