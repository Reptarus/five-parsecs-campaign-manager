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

func apply_event_effects(game_state: GameState) -> void:
	for key in campaign_turn_modifications:
		if game_state.has_method(key):
			game_state.call(key, campaign_turn_modifications[key])
	
	game_state.galactic_war_manager.process_strife_event(event_type)

func setup_battle(battle: Battle) -> void:
	for key in battle_setup:
		if battle.has_method(key):
			battle.call(key, battle_setup[key])

func apply_rewards(game_state: GameState) -> void:
	for key in rewards:
		match key:
			"credits":
				game_state.add_credits(rewards[key])
			"experience":
				game_state.current_crew.gain_experience(rewards[key])
			"equipment":
				for item in rewards[key]:
					game_state.add_to_ship_stash(item)
			"reputation":
				game_state.change_reputation(rewards[key])
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