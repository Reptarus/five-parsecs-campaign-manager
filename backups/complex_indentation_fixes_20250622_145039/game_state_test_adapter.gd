@tool
extends RefCounted
class_name GameStateTestAdapter

# This adapter allows us to use GameState in tests without extensive modifications
#

const GameStateScript: GDScript = preload("res://src/core/state/GameState.gd")
const GameEnumsScript: GDScript = preload("res://src/core/systems/GlobalEnums.gd")

#
static func create_test_instance() -> GameState:

		pass
static func create_default_test_state() -> GameState:
		pass
	
	#
	state.current_phase = GameEnumsScript.FiveParcsecsCampaignPhase.CAMPAIGN
	state.turn_number = 1
	state.story_points = 3
	state.reputation = 50
	state.resources = {
		GameEnumsScript.ResourceType.CREDITS: 1000,
		GameEnumsScript.ResourceType.FUEL: 10,
		GameEnumsScript.ResourceType.TECH_PARTS: 5

#
static func deserialize_from_dict(data: Dictionary) -> GameState:

		pass
static func create_test_serialized_state() -> Dictionary:
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
		"visited_locations": [],