@tool
extends Node

class_name MissionTemplate

## Dependencies
const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")

## Template Properties
@export var type: int = GameEnums.MissionType.NONE
@export var title_templates: Array[String] = []
@export var description_templates: Array[String] = []
@export var objective: String = ""
@export var objective_description: String = ""
@export var reward_range: Vector2 = Vector2(100, 500)
@export var difficulty_range: Vector2 = Vector2(1, 3)
@export var required_skills: Array[String] = []
@export var enemy_types: Array[String] = []
@export var deployment_condition_chance: float = 0.3
@export var notable_sight_chance: float = 0.2
@export var economic_impact: float = 1.0

## Validation method to ensure template is properly configured
func validate() -> bool:
	# Check for required fields
	if type == GameEnums.MissionType.NONE:
		push_error("Mission template must have a valid type")
		return false
	
	if title_templates.is_empty():
		push_error("Mission template must have at least one title template")
		return false
	
	if description_templates.is_empty():
		push_error("Mission template must have at least one description template")
		return false
	
	if objective.is_empty():
		push_error("Mission template must have an objective")
		return false
	
	if objective_description.is_empty():
		push_error("Mission template must have an objective description")
		return false
	
	# Validate ranges
	if reward_range.x < 0 or reward_range.y <= reward_range.x:
		push_error("Invalid reward range")
		return false
	
	if difficulty_range.x < 1 or difficulty_range.y <= difficulty_range.x:
		push_error("Invalid difficulty range")
		return false
	
	# Validate probabilities
	if deployment_condition_chance < 0 or deployment_condition_chance > 1:
		push_error("Invalid deployment condition chance")
		return false
	
	if notable_sight_chance < 0 or notable_sight_chance > 1:
		push_error("Invalid notable sight chance")
		return false
	
	if economic_impact <= 0:
		push_error("Economic impact must be positive")
		return false
	
	return true

## Get a random title template
func get_random_title() -> String:
	return title_templates.pick_random() if not title_templates.is_empty() else "Untitled Mission"

## Get a random description template
func get_random_description() -> String:
	return description_templates.pick_random() if not description_templates.is_empty() else "No description available"

## Get a random enemy type
func get_random_enemy_type() -> String:
	return enemy_types.pick_random() if not enemy_types.is_empty() else "Standard Enemy"

## Get difficulty level based on range
func get_random_difficulty() -> int:
	return randi_range(int(difficulty_range.x), int(difficulty_range.y))

## Get reward amount based on range
func get_random_reward() -> int:
	return randi_range(int(reward_range.x), int(reward_range.y))

## Check if template has a specific required skill
func requires_skill(skill: String) -> bool:
	return required_skills.has(skill)

## Get deployment condition based on chance
func should_have_deployment_condition() -> bool:
	return randf() < deployment_condition_chance

## Get notable sight based on chance
func should_have_notable_sight() -> bool:
	return randf() < notable_sight_chance

## Create a dictionary representation of the template
func to_dictionary() -> Dictionary:
	return {
		"type": type,
		"title_templates": title_templates,
		"description_templates": description_templates,
		"objective": objective,
		"objective_description": objective_description,
		"reward_range": {
			"min": reward_range.x,
			"max": reward_range.y
		},
		"difficulty_range": {
			"min": difficulty_range.x,
			"max": difficulty_range.y
		},
		"required_skills": required_skills,
		"enemy_types": enemy_types,
		"deployment_condition_chance": deployment_condition_chance,
		"notable_sight_chance": notable_sight_chance,
		"economic_impact": economic_impact
	}

## Create a template from a dictionary
static func from_dictionary(data: Dictionary) -> MissionTemplate:
	var template := MissionTemplate.new()
	
	template.type = data.get("type", GameEnums.MissionType.NONE)
	template.title_templates = data.get("title_templates", [])
	template.description_templates = data.get("description_templates", [])
	template.objective = data.get("objective", "")
	template.objective_description = data.get("objective_description", "")
	
	var reward_range_dict = data.get("reward_range", {"min": 100, "max": 500})
	template.reward_range = Vector2(
		reward_range_dict.get("min", 100),
		reward_range_dict.get("max", 500)
	)
	
	var difficulty_range_dict = data.get("difficulty_range", {"min": 1, "max": 3})
	template.difficulty_range = Vector2(
		difficulty_range_dict.get("min", 1),
		difficulty_range_dict.get("max", 3)
	)
	
	template.required_skills = data.get("required_skills", [])
	template.enemy_types = data.get("enemy_types", [])
	template.deployment_condition_chance = data.get("deployment_condition_chance", 0.3)
	template.notable_sight_chance = data.get("notable_sight_chance", 0.2)
	template.economic_impact = data.get("economic_impact", 1.0)
	
	return template
