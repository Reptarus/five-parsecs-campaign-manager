# StoryEvent.gd
class_name StoryEvent
extends Resource

@export var event_id: String
@export var description: String
@export var campaign_turn_modifications: Dictionary
@export var battle_setup: Dictionary
@export var rewards: Dictionary
@export var next_event_ticks: int
@export var event_type: GlobalEnums.StrifeType = GlobalEnums.StrifeType.RESOURCE_CONFLICT

func _init(data: Dictionary = {}):
	event_id = data.get("event_id", "")
	description = data.get("description", "")
	campaign_turn_modifications = data.get("campaign_turn_modifications", {})
	battle_setup = data.get("battle_setup", {})
	rewards = data.get("rewards", {})
	next_event_ticks = data.get("next_event_ticks", 0)
	event_type = GlobalEnums.StrifeType[data.get("event_type", "RESOURCE_CONFLICT")]

func apply_event_effects(game_state_manager: GameStateManager) -> void:
	var game_state = game_state_manager.game_state
	for key in campaign_turn_modifications:
		if game_state.has_method(key):
			game_state.call(key, campaign_turn_modifications[key])
	
	if game_state_manager.fringe_world_strife_manager:
		game_state_manager.fringe_world_strife_manager.process_strife_event(event_type)

func setup_battle(combat_manager: CombatManager) -> void:
	for key in battle_setup:
		if combat_manager.has_method(key):
			combat_manager.call(key, battle_setup[key])

func apply_rewards(game_state_manager: GameStateManager) -> void:
	var game_state = game_state_manager.game_state
	for key in rewards:
		match key:
			"credits":
				game_state.add_credits(rewards[key])
			"story_points":
				game_state.add_story_points(rewards[key])
			"equipment":
				for item in rewards[key]:
					if game_state_manager.equipment_manager:
						game_state_manager.equipment_manager.add_to_ship_inventory(item)
			_:
				if game_state.has_method(key):
					game_state.call(key, rewards[key])

func serialize() -> Dictionary:
	return {
		"event_id": event_id,
		"description": description,
		"campaign_turn_modifications": campaign_turn_modifications,
		"battle_setup": battle_setup,
		"rewards": rewards,
		"next_event_ticks": next_event_ticks,
		"event_type": GlobalEnums.StrifeType.keys()[event_type]
	}

static func deserialize(data: Dictionary) -> StoryEvent:
	return StoryEvent.new(data)

func generate_random_event() -> void:
	event_type = GlobalEnums.StrifeType.values()[randi() % GlobalEnums.StrifeType.size()]
	# Generate other random event details based on event_type
	# This could include setting up specific campaign_turn_modifications, battle_setup, and rewards
	pass