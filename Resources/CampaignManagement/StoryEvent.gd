# StoryEvent.gd
class_name StoryEvent
extends Resource

@export var event_id: String
@export var description: String
@export var campaign_turn_modifications: Dictionary
@export var battle_setup: Dictionary
@export var rewards: Dictionary
@export var next_event_ticks: int
@export var event_type: GlobalEnums.MissionType = GlobalEnums.MissionType.STORY

# Story event specific fields based on Core Rules
@export var clock_ticks: int = 0 # For ticking clock events
@export var search_locations: Array[String] = [] # For hidden item searches
@export var spawn_points: Array[Vector2] = [] # For enemy spawn locations
@export var hazards: Array[GlobalEnums.HazardType] = []
@export var victory_condition: GlobalEnums.VictoryConditionType
@export var objective: GlobalEnums.MissionObjective

func _init(data: Dictionary = {}):
	event_id = data.get("event_id", "")
	description = data.get("description", "")
	campaign_turn_modifications = data.get("campaign_turn_modifications", {})
	battle_setup = data.get("battle_setup", {})
	rewards = data.get("rewards", {})
	next_event_ticks = data.get("next_event_ticks", 0)
	event_type = GlobalEnums.MissionType[data.get("event_type", "STORY")]
	
	# Initialize story-specific fields
	clock_ticks = data.get("clock_ticks", 0)
	search_locations = data.get("search_locations", [])
	spawn_points = data.get("spawn_points", [])
	hazards = data.get("hazards", [])
	victory_condition = GlobalEnums.VictoryConditionType[data.get("victory_condition", "SURVIVAL")]
	objective = GlobalEnums.MissionObjective[data.get("objective", "SURVIVE")]

func apply_event_effects(game_state_manager: GameStateManager) -> void:
	var game_state = game_state_manager.game_state
	for key in campaign_turn_modifications:
		if game_state.has_method(key):
			game_state.call(key, campaign_turn_modifications[key])
	
	if game_state_manager.fringe_world_strife_manager:
		game_state_manager.fringe_world_strife_manager.process_mission_event(event_type)

func setup_battle(combat_manager: Node) -> void:
	for key in battle_setup:
		if combat_manager.has_method(key):
			combat_manager.call(key, battle_setup[key])
			
	# Setup story-specific battle elements
	if spawn_points.size() > 0:
		combat_manager.setup_spawn_points(spawn_points)
	if hazards.size() > 0:
		combat_manager.setup_hazards(hazards)
	combat_manager.set_victory_condition(victory_condition)
	combat_manager.set_objective(objective)

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
			"rumors":
				game_state.add_rumors(rewards[key])
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
		"event_type": GlobalEnums.MissionType.keys()[event_type],
		"clock_ticks": clock_ticks,
		"search_locations": search_locations,
		"spawn_points": spawn_points,
		"hazards": hazards,
		"victory_condition": GlobalEnums.VictoryConditionType.keys()[victory_condition],
		"objective": GlobalEnums.MissionObjective.keys()[objective]
	}

static func deserialize(data: Dictionary) -> StoryEvent:
	return StoryEvent.new(data)

func generate_random_event() -> void:
	event_type = GlobalEnums.MissionType.STORY
	victory_condition = GlobalEnums.VictoryConditionType.values()[randi() % GlobalEnums.VictoryConditionType.size()]
	objective = GlobalEnums.MissionObjective.values()[randi() % GlobalEnums.MissionObjective.size()]
	
	# Generate clock ticks based on Core Rules
	clock_ticks = randi() % 6 + 1 # D6 roll for clock ticks
	
	# Setup appropriate hazards and spawn points based on objective
	match objective:
		GlobalEnums.MissionObjective.SURVIVE:
			hazards.append(GlobalEnums.HazardType.values()[randi() % GlobalEnums.HazardType.size()])
		GlobalEnums.MissionObjective.MOVE_THROUGH:
			var spawn_count = randi() % 3 + 1 # 1-3 spawn points
			for i in spawn_count:
				spawn_points.append(Vector2(randi() % 24, randi() % 24)) # Random positions on map