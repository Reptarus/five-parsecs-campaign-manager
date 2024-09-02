class_name MissionTemplate
extends Resource

enum MissionType { OPPORTUNITY, PATRON, QUEST, RIVAL }

enum Objective {
	MOVE_THROUGH,
	DELIVER,
	ACCESS,
	PATROL,
	FIGHT_OFF,
	SEARCH,
	DEFEND,
	ACQUIRE,
	ELIMINATE,
	SECURE,
	PROTECT
}

@export var type: MissionType
@export var title_templates: Array[String]
@export var description_templates: Array[String]
@export var objective: Objective
@export var objective_description: String
@export var reward_range: Vector2
@export var difficulty_range: Vector2
@export var required_skills: Array[String]
@export var enemy_types: Array[String]
@export var deployment_condition_chance: float
@export var notable_sight_chance: float
@export var economic_impact: float = 1.0  # New field for economic impact

func _init(
	_type: MissionType = MissionType.OPPORTUNITY,
	_title_templates: Array[String] = [],
	_description_templates: Array[String] = [],
	_objective: Objective = Objective.FIGHT_OFF,
	_objective_description: String = "",
	_reward_range: Vector2 = Vector2(1, 6),
	_difficulty_range: Vector2 = Vector2(1, 5),
	_required_skills: Array[String] = [],
	_enemy_types: Array[String] = [],
	_deployment_condition_chance: float = 0.4,
	_notable_sight_chance: float = 0.2,
	_economic_impact: float = 1.0
):
	type = _type
	title_templates = _title_templates
	description_templates = _description_templates
	objective = _objective
	objective_description = _objective_description
	reward_range = _reward_range
	difficulty_range = _difficulty_range
	required_skills = _required_skills
	enemy_types = _enemy_types
	deployment_condition_chance = _deployment_condition_chance
	notable_sight_chance = _notable_sight_chance
	economic_impact = _economic_impact

func calculate_reward(economy_manager: EconomyManager) -> int:
	var base_reward = randf_range(reward_range.x, reward_range.y)
	return int(base_reward * economy_manager.global_economic_modifier * economic_impact)

func generate_deployment_condition() -> String:
	if randf() < deployment_condition_chance:
		# Implementation of deployment condition generation
		return "Challenging terrain"  # Placeholder
	return "Standard deployment"

func generate_notable_sight() -> String:
	if randf() < notable_sight_chance:
		# Implementation of notable sight generation
		return "Ancient artifact"  # Placeholder
	return ""

func to_dict() -> Dictionary:
	return {
		"type": MissionType.keys()[type],
		"title_templates": title_templates,
		"description_templates": description_templates,
		"objective": Objective.keys()[objective],
		"objective_description": objective_description,
		"reward_range": {"x": reward_range.x, "y": reward_range.y},
		"difficulty_range": {"x": difficulty_range.x, "y": difficulty_range.y},
		"required_skills": required_skills,
		"enemy_types": enemy_types,
		"deployment_condition_chance": deployment_condition_chance,
		"notable_sight_chance": notable_sight_chance,
		"economic_impact": economic_impact
	}

static func from_dict(data: Dictionary) -> MissionTemplate:
	return MissionTemplate.new(
		MissionType[data["type"]],
		data["title_templates"],
		data["description_templates"],
		Objective[data["objective"]],
		data["objective_description"],
		Vector2(data["reward_range"]["x"], data["reward_range"]["y"]),
		Vector2(data["difficulty_range"]["x"], data["difficulty_range"]["y"]),
		data["required_skills"],
		data["enemy_types"],
		data["deployment_condition_chance"],
		data["notable_sight_chance"],
		data["economic_impact"]
	)
