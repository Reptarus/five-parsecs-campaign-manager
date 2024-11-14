class_name CampaignEventGenerator
extends Resource

var game_state: GameStateManager
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _init(_game_state: GameStateManager):
	game_state = _game_state
	rng.randomize()

func generate_event() -> StoryEvent:
	var event_types = [
		GlobalEnums.GlobalEvent.MARKET_CRASH,
		GlobalEnums.GlobalEvent.ALIEN_INVASION,
		GlobalEnums.GlobalEvent.CORPORATE_WAR,
		GlobalEnums.GlobalEvent.PIRATE_RAIDS,
		GlobalEnums.GlobalEvent.PLAGUE_OUTBREAK
	]
	var event_type = event_types[rng.randi() % event_types.size()]
	
	return create_event(event_type)

func create_event(event_type: GlobalEnums.GlobalEvent) -> StoryEvent:
	var event_data = {
		"event_id": "event_" + str(rng.randi()),
		"description": get_event_description(event_type),
		"campaign_turn_modifications": get_campaign_turn_modifications(event_type),
		"battle_setup": get_battle_setup(event_type),
		"rewards": get_rewards(event_type),
		"next_event_ticks": rng.randi_range(2, 5),
		"event_type": GlobalEnums.GlobalEvent.keys()[event_type]
	}
	return StoryEvent.new(event_data)

func get_event_description(event_type: GlobalEnums.GlobalEvent) -> String:
	match event_type:
		GlobalEnums.GlobalEvent.MARKET_CRASH:
			return "A devastating market crash has thrown the sector's economy into chaos."
		GlobalEnums.GlobalEvent.ALIEN_INVASION:
			return "Unknown alien forces have launched a massive invasion across multiple systems."
		GlobalEnums.GlobalEvent.CORPORATE_WAR:
			return "Mega-corporations have escalated their rivalry into armed conflict."
		GlobalEnums.GlobalEvent.PIRATE_RAIDS:
			return "Coordinated pirate raids have disrupted trade routes across the sector."
		GlobalEnums.GlobalEvent.PLAGUE_OUTBREAK:
			return "A mysterious plague has begun spreading through populated systems."
		_:
			return "An unexpected galactic event has occurred."

func get_campaign_turn_modifications(event_type: GlobalEnums.GlobalEvent) -> Dictionary:
	match event_type:
		GlobalEnums.GlobalEvent.MARKET_CRASH:
			return {"increase_item_prices": 1.5}
		GlobalEnums.GlobalEvent.ALIEN_INVASION:
			return {"set_forced_action": "prepare_defenses"}
		GlobalEnums.GlobalEvent.CORPORATE_WAR:
			return {"modify_credits": -0.1}
		GlobalEnums.GlobalEvent.PIRATE_RAIDS:
			return {"add_rival": "Pirate Lord"}
		GlobalEnums.GlobalEvent.PLAGUE_OUTBREAK:
			return {"modify_crew_health": -0.2}
		_:
			return {}

func get_battle_setup(event_type: GlobalEnums.GlobalEvent) -> Dictionary:
	match event_type:
		GlobalEnums.GlobalEvent.MARKET_CRASH:
			return {"set_enemy_type": "raiders", "set_battlefield_size": Vector2i(24, 24)}
		GlobalEnums.GlobalEvent.ALIEN_INVASION:
			return {"set_enemy_type": "aliens", "set_battlefield_size": Vector2i(36, 36)}
		GlobalEnums.GlobalEvent.CORPORATE_WAR:
			return {"set_enemy_type": "corporate_security", "set_battlefield_size": Vector2i(24, 24)}
		GlobalEnums.GlobalEvent.PIRATE_RAIDS:
			return {"set_enemy_type": "pirates", "set_battlefield_size": Vector2i(30, 30)}
		GlobalEnums.GlobalEvent.PLAGUE_OUTBREAK:
			return {"set_enemy_type": "infected", "set_battlefield_size": Vector2i(24, 24)}
		_:
			return {"set_enemy_type": "generic", "set_battlefield_size": Vector2i(24, 24)}

func get_rewards(event_type: GlobalEnums.GlobalEvent) -> Dictionary:
	match event_type:
		GlobalEnums.GlobalEvent.MARKET_CRASH:
			return {"add_credits": 100, "add_story_points": 1}
		GlobalEnums.GlobalEvent.ALIEN_INVASION:
			return {"add_credits": 200, "add_story_points": 3}
		GlobalEnums.GlobalEvent.CORPORATE_WAR:
			return {"add_credits": 175, "add_story_points": 2}
		GlobalEnums.GlobalEvent.PIRATE_RAIDS:
			return {"add_credits": 150, "add_story_points": 2}
		GlobalEnums.GlobalEvent.PLAGUE_OUTBREAK:
			return {"add_credits": 125, "add_story_points": 2}
		_:
			return {"add_credits": 50, "add_story_points": 1}
