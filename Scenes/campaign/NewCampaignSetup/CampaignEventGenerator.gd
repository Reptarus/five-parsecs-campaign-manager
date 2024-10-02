class_name CampaignEventGenerator
extends Resource

var game_state: GameStateManager
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _init(_game_state: GameStateManager):
	game_state = _game_state
	rng.randomize()

func generate_event() -> StoryEvent:
	var event_types = [
		GlobalEnums.StrifeType.RESOURCE_CONFLICT,
		GlobalEnums.StrifeType.POLITICAL_UPRISING,
		GlobalEnums.StrifeType.ALIEN_INCURSION,
		GlobalEnums.StrifeType.CORPORATE_WARFARE
	]
	var event_type = event_types[rng.randi() % event_types.size()]
	
	return create_event(event_type)

func create_event(event_type: GlobalEnums.StrifeType) -> StoryEvent:
	var event_data = {
		"event_id": "event_" + str(rng.randi()),
		"description": get_event_description(event_type),
		"campaign_turn_modifications": get_campaign_turn_modifications(event_type),
		"battle_setup": get_battle_setup(event_type),
		"rewards": get_rewards(event_type),
		"next_event_ticks": rng.randi_range(2, 5),
		"event_type": GlobalEnums.StrifeType.keys()[event_type]
	}
	return StoryEvent.new(event_data)

func get_event_description(event_type: GlobalEnums.StrifeType) -> String:
	match event_type:
		GlobalEnums.StrifeType.RESOURCE_CONFLICT:
			return "A critical resource shortage has sparked conflicts across the sector."
		GlobalEnums.StrifeType.POLITICAL_UPRISING:
			return "Political tensions have erupted into open rebellion in several systems."
		GlobalEnums.StrifeType.ALIEN_INCURSION:
			return "An unknown alien force has been detected on the fringes of inhabited space."
		GlobalEnums.StrifeType.CORPORATE_WARFARE:
			return "Mega-corporations have escalated their rivalry into armed conflict."
		_:
			return "An unexpected galactic event has occurred."

func get_campaign_turn_modifications(event_type: GlobalEnums.StrifeType) -> Dictionary:
	match event_type:
		GlobalEnums.StrifeType.RESOURCE_CONFLICT:
			return {"increase_item_prices": 1.5}
		GlobalEnums.StrifeType.POLITICAL_UPRISING:
			return {"add_rival": "Rebel Leader"}
		GlobalEnums.StrifeType.ALIEN_INCURSION:
			return {"set_forced_action": "prepare_defenses"}
		GlobalEnums.StrifeType.CORPORATE_WARFARE:
			return {"modify_credits": -0.1}
		_:
			return {}

func get_battle_setup(event_type: GlobalEnums.StrifeType) -> Dictionary:
	match event_type:
		GlobalEnums.StrifeType.RESOURCE_CONFLICT:
			return {"set_enemy_type": "raiders", "set_battlefield_size": Vector2i(24, 24)}
		GlobalEnums.StrifeType.POLITICAL_UPRISING:
			return {"set_enemy_type": "rebels", "set_battlefield_size": Vector2i(30, 30)}
		GlobalEnums.StrifeType.ALIEN_INCURSION:
			return {"set_enemy_type": "aliens", "set_battlefield_size": Vector2i(36, 36)}
		GlobalEnums.StrifeType.CORPORATE_WARFARE:
			return {"set_enemy_type": "corporate_security", "set_battlefield_size": Vector2i(24, 24)}
		_:
			return {"set_enemy_type": "generic", "set_battlefield_size": Vector2i(24, 24)}

func get_rewards(event_type: GlobalEnums.StrifeType) -> Dictionary:
	match event_type:
		GlobalEnums.StrifeType.RESOURCE_CONFLICT:
			return {"add_credits": 100, "add_story_points": 1}
		GlobalEnums.StrifeType.POLITICAL_UPRISING:
			return {"add_credits": 150, "add_story_points": 2}
		GlobalEnums.StrifeType.ALIEN_INCURSION:
			return {"add_credits": 200, "add_story_points": 3}
		GlobalEnums.StrifeType.CORPORATE_WARFARE:
			return {"add_credits": 175, "add_story_points": 2}
		_:
			return {"add_credits": 50, "add_story_points": 1}
