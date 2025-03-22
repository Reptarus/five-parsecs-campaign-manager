@tool
extends RefCounted
# REMOVED: class_name GameStateTestAdapter
# Using explicit file reference instead to avoid class name conflicts

# No Self reference to avoid circular reference
# const Self = preload("res://tests/fixtures/helpers/game_state_test_adapter.gd")

# This adapter allows us to use GameState in tests without extensive modifications
# to the source file, working around linter errors

# Game state dependencies with explicit paths
const GameStateScript = preload("res://src/core/state/GameState.gd")
const GameEnumsScript = preload("res://src/core/systems/GlobalEnums.gd")

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

# Wrapper for deserialization - use a method that exists in GameStateScript
static func deserialize_from_dict(data: Dictionary) -> Node:
	var state = create_test_instance()
	state.deserialize(data) # Use deserialize instead of deserialize_new
	return state

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