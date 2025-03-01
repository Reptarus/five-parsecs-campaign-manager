@tool
class_name MissionGenerator
extends RefCounted

## Core mission generator for Five Parsecs.
## This class handles the generation of missions based on templates.

const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")
const StoryQuestData := preload("res://src/core/story/StoryQuestData.gd")
const GameState := preload("res://src/core/state/GameState.gd")
const FiveParsecsWorldManager := preload("res://src/core/world/WorldManager.gd")

var game_state: GameState
var world_manager: FiveParsecsWorldManager
var mission_templates: Dictionary = {}
var expanded_missions: Dictionary = {}

func _init(state: GameState, world: FiveParsecsWorldManager) -> void:
	game_state = state
	world_manager = world
	_load_mission_templates()

func _load_mission_templates() -> void:
	var mission_data: Dictionary = load_json_file("res://data/mission_templates.json")
	if mission_data.is_empty():
		push_error("Failed to load mission templates data")
		return
	mission_templates = mission_data
	
	var expanded_data = load_json_file("res://data/expanded_missions.json")
	if expanded_data:
		expanded_missions = expanded_data

func generate_mission(mission_type: int, config: Dictionary = {}) -> Object:
	var mission_instance = StoryQuestData.new()
	var template := _get_mission_template(mission_type)
	
	if not template:
		push_error("No template found for mission type: %d" % mission_type)
		return null
	
	_configure_mission(mission_instance, template, config)
	_apply_difficulty_modifiers(mission_instance, config.get("difficulty", GameEnums.DifficultyLevel.NORMAL))
	_generate_objectives(mission_instance, template)
	_generate_rewards(mission_instance, template)
	_apply_location_effects(mission_instance, config.get("location", null))
	
	return mission_instance

func _get_mission_template(mission_type: int) -> Dictionary:
	var template_key: String = GameEnums.MissionType.keys()[mission_type]
	return mission_templates.get(template_key, {})

func _configure_mission(mission: Object, template: Dictionary, config: Dictionary) -> void:
	if mission:
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
	if mission:
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
	if mission:
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
	if mission:
		var base_rewards = template.get("rewards", {})
		
		mission.reward_credits = base_rewards.get("credits", 0)
		mission.reward_reputation = base_rewards.get("reputation", 0)
		mission.reward_items = base_rewards.get("items", [])
		
		# Add bonus rewards based on risk level
		var bonus_multiplier: float = 1.0 + (mission.risk_level * 0.2)
		mission.reward_credits = int(mission.reward_credits * bonus_multiplier)
		mission.reward_reputation = int(mission.reward_reputation * bonus_multiplier)

func _apply_location_effects(mission: Object, location: Dictionary) -> void:
	if not mission or not location:
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