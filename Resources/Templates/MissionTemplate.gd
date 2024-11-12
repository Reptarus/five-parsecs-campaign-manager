class_name MissionTemplate
extends Resource

@export var type: GlobalEnums.Type
@export var title_templates: Array[String]
@export var description_templates: Array[String]
@export var objective: GlobalEnums.MissionObjective
@export var objective_description: String
@export var reward_range: Vector2
@export var difficulty_range: Vector2
@export var required_skills: Array[GlobalEnums.SkillType]
@export var enemy_types: Array[GlobalEnums.AIType]
@export var deployment_condition_chance: float
@export var notable_sight_chance: float
@export var economic_impact: float = 1.0
@export var faction_type: GlobalEnums.Faction
@export var loyalty_requirement_range: Vector2
@export var power_requirement_range: Vector2
@export var time_limit_range: Vector2
@export var strife_intensity_range: Vector2
@export var environmental_factors: Array[String]
@export var available_resources: Dictionary
@export var deployment_type: GlobalEnums.DeploymentType

func _init(
    _type: GlobalEnums.Type = GlobalEnums.Type.OPPORTUNITY,
    _title_templates: Array[String] = [],
    _description_templates: Array[String] = [],
    _objective: GlobalEnums.MissionObjective = GlobalEnums.MissionObjective.FIGHT_OFF,
    _objective_description: String = "",
    _reward_range: Vector2 = Vector2(1, 6),
    _difficulty_range: Vector2 = Vector2(1, 5),
    _required_skills: Array[GlobalEnums.SkillType] = [],
    _enemy_types: Array[GlobalEnums.AIType] = [],
    _deployment_condition_chance: float = 0.4,
    _notable_sight_chance: float = 0.2,
    _economic_impact: float = 1.0,
    _faction_type: GlobalEnums.Faction = GlobalEnums.Faction.CORPORATE,
    _loyalty_requirement_range: Vector2 = Vector2(1, 3),
    _power_requirement_range: Vector2 = Vector2(1, 5),
    _time_limit_range: Vector2 = Vector2(3, 7),
    _strife_intensity_range: Vector2 = Vector2(1, 5),
    _environmental_factors: Array[String] = [],
    _available_resources: Dictionary = {},
    _deployment_type: GlobalEnums.DeploymentType = GlobalEnums.DeploymentType.LINE
) -> void:
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
    faction_type = _faction_type
    loyalty_requirement_range = _loyalty_requirement_range
    power_requirement_range = _power_requirement_range
    time_limit_range = _time_limit_range
    strife_intensity_range = _strife_intensity_range
    environmental_factors = _environmental_factors
    available_resources = _available_resources
    deployment_type = _deployment_type

func to_dict() -> Dictionary:
    return {
        "type": GlobalEnums.Type.keys()[type],
        "title_templates": title_templates,
        "description_templates": description_templates,
        "objective": GlobalEnums.MissionObjective.keys()[objective],
        "objective_description": objective_description,
        "reward_range": {"x": reward_range.x, "y": reward_range.y},
        "difficulty_range": {"x": difficulty_range.x, "y": difficulty_range.y},
        "required_skills": required_skills.map(func(skill): return GlobalEnums.SkillType.keys()[skill]),
        "enemy_types": enemy_types.map(func(enemy): return GlobalEnums.AIType.keys()[enemy]),
        "deployment_condition_chance": deployment_condition_chance,
        "notable_sight_chance": notable_sight_chance,
        "economic_impact": economic_impact,
        "faction_type": GlobalEnums.Faction.keys()[faction_type],
        "loyalty_requirement_range": {"x": loyalty_requirement_range.x, "y": loyalty_requirement_range.y},
        "power_requirement_range": {"x": power_requirement_range.x, "y": power_requirement_range.y},
        "time_limit_range": {"x": time_limit_range.x, "y": time_limit_range.y},
        "strife_intensity_range": {"x": strife_intensity_range.x, "y": strife_intensity_range.y},
        "environmental_factors": environmental_factors,
        "available_resources": available_resources,
        "deployment_type": GlobalEnums.DeploymentType.keys()[deployment_type]
    }

static func from_dict(data: Dictionary) -> MissionTemplate:
    return MissionTemplate.new(
        GlobalEnums.Type[data["type"]],
        data["title_templates"],
        data["description_templates"],
        GlobalEnums.MissionObjective[data["objective"]],
        data["objective_description"],
        Vector2(data["reward_range"]["x"], data["reward_range"]["y"]),
        Vector2(data["difficulty_range"]["x"], data["difficulty_range"]["y"]),
        data["required_skills"].map(func(skill): return GlobalEnums.SkillType[skill]),
        data["enemy_types"].map(func(enemy): return GlobalEnums.AIType[enemy]),
        data["deployment_condition_chance"],
        data["notable_sight_chance"],
        data["economic_impact"],
        GlobalEnums.Faction[data["faction_type"]],
        Vector2(data["loyalty_requirement_range"]["x"], data["loyalty_requirement_range"]["y"]),
        Vector2(data["power_requirement_range"]["x"], data["power_requirement_range"]["y"]),
        Vector2(data["time_limit_range"]["x"], data["time_limit_range"]["y"]),
        Vector2(data["strife_intensity_range"]["x"], data["strife_intensity_range"]["y"]),
        data["environmental_factors"],
        data["available_resources"],
        GlobalEnums.DeploymentType[data["deployment_type"]]
    )
