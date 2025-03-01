@tool
class_name CampaignMissionGenerator
extends MissionGenerator

## Campaign-specific mission generator for Five Parsecs.
## This class handles the generation of campaign missions, including
## story quests, random encounters, and special events.
##
## This implementation extends the core MissionGenerator with campaign-specific functionality.

const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")
const _StoryQuestScript := preload("res://src/core/story/StoryQuestData.gd")
const GameState := preload("res://src/core/state/GameState.gd")
const FiveParsecsWorldManager := preload("res://src/core/world/WorldManager.gd")

var game_state: GameState
var world_manager: FiveParsecsWorldManager
var mission_templates: Dictionary = {}
var expanded_missions: Dictionary = {}

# Campaign-specific constants and variables
var campaign_mission_types: Array[int] = []
var last_generated_mission: StoryQuestData = null

func _init(state: GameState, world: FiveParsecsWorldManager) -> void:
	super(state, world)
	game_state = state
	world_manager = world
	_load_mission_templates()
	_load_campaign_missions()

func _load_mission_templates() -> void:
	var mission_data: Dictionary = load_json_file("res://data/mission_templates.json")
	if mission_data.is_empty():
		push_error("Failed to load mission templates data")
		return
	mission_templates = mission_data
	
	var expanded_data = load_json_file("res://data/expanded_missions.json")
	if expanded_data:
		expanded_missions = expanded_data

## Load campaign-specific missions
func _load_campaign_missions() -> void:
	var campaign_data: Dictionary = load_json_file("res://data/campaign_missions.json")
	if not campaign_data.is_empty():
		for mission_key in campaign_data:
			if not mission_templates.has(mission_key):
				mission_templates[mission_key] = campaign_data[mission_key]
	
	# Initialize the campaign mission types list
	_update_available_mission_types()

## Get available mission types for the current campaign state
func get_available_mission_types() -> Array[int]:
	return campaign_mission_types

## Update the list of available mission types based on campaign state
func _update_available_mission_types() -> void:
	campaign_mission_types.clear()
	
	# Add all mission types that meet the requirements
	for mission_type in GameEnums.MissionType.values():
		if _check_mission_requirements(mission_type):
			campaign_mission_types.append(mission_type)

## Check if mission requirements are met in the current campaign state
func _check_mission_requirements(mission_type: int) -> bool:
	var template := _get_mission_template(mission_type)
	if template.is_empty():
		return false
	
	# Check reputation requirement
	var required_rep = template.get("required_reputation", 0)
	if required_rep > game_state.get_crew_reputation():
		return false
	
	# Check location requirement
	var required_location = template.get("required_location_type", -1)
	if required_location != -1 and required_location != world_manager.get_current_location_type():
		return false
	
	# Check story progression requirement
	var required_story_progress = template.get("required_story_progress", -1)
	if required_story_progress != -1 and required_story_progress > game_state.get_story_progress():
		return false
	
	return true

## Generate a random campaign mission
func generate_random_mission() -> StoryQuestData:
	if campaign_mission_types.is_empty():
		_update_available_mission_types()
	
	if campaign_mission_types.is_empty():
		push_error("No available mission types for current campaign state")
		return null
	
	var random_index := randi() % campaign_mission_types.size()
	var random_mission_type: int = campaign_mission_types[random_index]
	
	last_generated_mission = generate_mission(random_mission_type)
	return last_generated_mission

## Generate a specific campaign mission with additional campaign-specific configuration
func generate_campaign_mission(mission_type: int, campaign_config: Dictionary = {}) -> StoryQuestData:
	var mission := super.generate_mission(mission_type, campaign_config)
	
	# Apply campaign-specific modifications
	if mission and campaign_config.has("campaign_faction"):
		_apply_faction_effects(mission, campaign_config.get("campaign_faction"))
	
	last_generated_mission = mission
	return mission

## Apply faction-specific effects to a mission
func _apply_faction_effects(mission: StoryQuestData, faction_id: String) -> void:
	var faction_data = game_state.get_faction_data(faction_id)
	if not faction_data:
		return
	
	# Apply faction-specific modifiers
	var relation_level = game_state.get_faction_relation(faction_id)
	
	match relation_level:
		0: # HOSTILE
			mission.enemy_count += 2
			mission.risk_level += 1
		1: # UNFRIENDLY
			mission.enemy_count += 1
		2: # FRIENDLY
			mission.reward_credits *= 1.1
		3: # ALLIED
			mission.reward_credits *= 1.2
			mission.reward_reputation += 1

## Override the parent method to ensure proper return type
func generate_mission(mission_type: int, config: Dictionary = {}) -> StoryQuestData:
	return super.generate_mission(mission_type, config)

func _get_mission_template(mission_type: int) -> Dictionary:
	var template_key: String = GameEnums.MissionType.keys()[mission_type]
	return mission_templates.get(template_key, {})

func _configure_mission(mission: Object, template: Dictionary, config: Dictionary) -> void:
	mission.mission_type = config.get("type", GameEnums.MissionType.NONE)
	mission.name = template.get("name", "Unknown Mission")
	mission.description = template.get("description", "")
	mission.turn_limit = template.get("turn_limit", -1)
	mission.required_reputation = template.get("required_reputation", 0)
	mission.risk_level = template.get("risk_level", 1)
	
	# Apply configuration overrides
	for key in config:
		if mission.has_method("set_" + key):
			mission.call("set_" + key, config[key])

func _apply_difficulty_modifiers(mission: Object, difficulty: int) -> void:
	var modifiers := _get_difficulty_modifiers(difficulty)
	
	mission.enemy_count *= modifiers.get("enemy_multiplier", 1.0)
	mission.reward_credits *= modifiers.get("reward_multiplier", 1.0)
	mission.risk_level = mini(5, mission.risk_level + modifiers.get("risk_modifier", 0))

func _get_difficulty_modifiers(difficulty: int) -> Dictionary:
	match difficulty:
		GameEnums.DifficultyLevel.EASY:
			return {
				"enemy_multiplier": 0.8,
				"reward_multiplier": 0.9,
				"risk_modifier": - 1
			}
		GameEnums.DifficultyLevel.NORMAL:
			return {
				"enemy_multiplier": 1.0,
				"reward_multiplier": 1.0,
				"risk_modifier": 0
			}
		GameEnums.DifficultyLevel.HARD:
			return {
				"enemy_multiplier": 1.2,
				"reward_multiplier": 1.2,
				"risk_modifier": 1
			}
		GameEnums.DifficultyLevel.HARDCORE:
			return {
				"enemy_multiplier": 1.4,
				"reward_multiplier": 1.5,
				"risk_modifier": 2
			}
		_:
			return {
				"enemy_multiplier": 1.0,
				"reward_multiplier": 1.0,
				"risk_modifier": 0
			}

func _generate_objectives(mission: Object, template: Dictionary) -> void:
	var objectives = template.get("objectives", [])
	
	for obj in objectives:
		var objective := {
			"type": obj.get("type", GameEnums.MissionObjective.NONE),
			"description": obj.get("description", ""),
			"required": obj.get("required", true),
			"completed": false,
			"progress": 0,
			"target": obj.get("target", 1)
		}
		
		mission.objectives.append(objective)

func _generate_rewards(mission: Object, template: Dictionary) -> void:
	var base_rewards = template.get("rewards", {})
	
	mission.reward_credits = base_rewards.get("credits", 0)
	mission.reward_reputation = base_rewards.get("reputation", 0)
	mission.reward_items = base_rewards.get("items", [])
	
	# Add bonus rewards based on risk level
	var bonus_multiplier: float = 1.0 + (mission.risk_level * 0.2)
	mission.reward_credits = int(mission.reward_credits * bonus_multiplier)
	mission.reward_reputation = int(mission.reward_reputation * bonus_multiplier)

func _apply_location_effects(mission: Object, location: Dictionary) -> void:
	if not location:
		return
	
	var location_type = location.get("type", GameEnums.LocationType.NONE)
	
	match location_type:
		GameEnums.LocationType.INDUSTRIAL_HUB:
			mission.reward_credits *= 1.2
		GameEnums.LocationType.FRONTIER_WORLD:
			mission.risk_level += 1
		GameEnums.LocationType.TRADE_CENTER:
			mission.reward_items.append_array(_generate_bonus_trade_items())
		GameEnums.LocationType.PIRATE_HAVEN:
			mission.enemy_count += 2
		_:
			pass

func _generate_bonus_trade_items() -> Array:
	# Implementation will be added when item system is complete
	return []

func load_json_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("File not found: %s" % path)
		return {}
	
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Could not open file: %s" % path)
		return {}
	
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	if error != OK:
		push_error("JSON Parse Error: %s at line %d" % [json.get_error_message(), json.get_error_line()])
		return {}
	
	return json.get_data()