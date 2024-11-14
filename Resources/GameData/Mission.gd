class_name Mission
extends Resource

const GlobalEnums = preload("res://Resources/GameData/GlobalEnums.gd")
const Enemy = preload("res://Resources/RivalAndPatrons/Enemy.gd")
const Location = preload("res://Resources/GameData/Location.gd")

@export_group("Mission Details")
var required_crew_size: int = 4
var enemies: Array[Enemy] = []
var unique_individual: Enemy
var status: int = GlobalEnums.MissionStatus.ACTIVE
var benefits: Array[String] = []
var hazards: Array[String] = []
var conditions: Array[String] = []
var patron: Node = null  # Will be typed when Patron class is available
var threat_condition: String = ""
var time_constraint: String = ""

@export var title: String = ""
@export var description: String = ""
@export var mission_type: int = GlobalEnums.MissionType.OPPORTUNITY
@export var objective: int = GlobalEnums.MissionObjective.SURVIVE
@export var terrain_type: int = GlobalEnums.TerrainType.INDUSTRIAL
@export var location: Location
@export var difficulty: int = 1
@export var rewards: Dictionary = {}
@export var time_limit: int = 3
@export var is_expanded: bool = false
@export var faction: Dictionary = {}
@export var deployment_type: int = GlobalEnums.DeploymentType.STANDARD
@export var victory_condition: int = GlobalEnums.VictoryConditionType.TURNS
@export var ai_behavior: int = GlobalEnums.AIBehavior.TACTICAL

func _init(
	p_title: String = "", 
	p_description: String = "", 
	p_type: int = GlobalEnums.MissionType.OPPORTUNITY,
	p_objective: int = GlobalEnums.MissionObjective.SURVIVE, 
	p_location: Location = null,
	p_difficulty: int = 1, 
	p_rewards: Dictionary = {}, 
	p_time_limit: int = 3,
	p_is_expanded: bool = false, 
	p_faction: Dictionary = {}
) -> void:
	title = p_title
	description = p_description
	mission_type = p_type
	objective = p_objective
	location = p_location
	difficulty = p_difficulty
	rewards = p_rewards
	time_limit = p_time_limit
	is_expanded = p_is_expanded
	faction = p_faction

func get_objective_description() -> String:
	match objective:
		GlobalEnums.MissionObjective.MOVE_THROUGH:
			return "Move at least 2 crew members off the opposing battlefield edge."
		GlobalEnums.MissionObjective.RETRIEVE:
			return "Deliver a package to the center of the battlefield."
		GlobalEnums.MissionObjective.EXPLORE:
			return "Access a computer console in the center of the battlefield."
		GlobalEnums.MissionObjective.CONTROL_POINT:
			return "Check 3 randomly selected terrain features."
		GlobalEnums.MissionObjective.SURVIVE:
			return "Drive off all enemy forces."
		GlobalEnums.MissionObjective.RESCUE:
			return "Search terrain features to find a specific item."
		GlobalEnums.MissionObjective.PROTECT:
			return "Defend against enemy forces and hold your position."
		GlobalEnums.MissionObjective.ELIMINATE:
			return "Eliminate a specific target enemy figure."
		GlobalEnums.MissionObjective.NEGOTIATE:
			return "Secure the center of the battlefield for 2 consecutive rounds."
		GlobalEnums.MissionObjective.ESCORT:
			return "Protect a VIP and get them to the center of the battlefield."
		GlobalEnums.MissionObjective.DESTROY:
			return "Destroy a specific target or structure on the battlefield."
		_:
			return "Unknown objective."

func complete() -> void:
	status = GlobalEnums.MissionStatus.COMPLETED

func fail() -> void:
	status = GlobalEnums.MissionStatus.FAILED

func serialize() -> Dictionary:
	return {
		"title": title,
		"description": description,
		"mission_type": GlobalEnums.MissionType.keys()[mission_type],
		"objective": GlobalEnums.MissionObjective.keys()[objective],
		"terrain_type": GlobalEnums.TerrainType.keys()[terrain_type],
		"required_crew_size": required_crew_size,
		"enemies": enemies.map(func(enemy: Enemy) -> Dictionary: return enemy.serialize()),
		"unique_individual": unique_individual.serialize() if unique_individual else null,
		"status": GlobalEnums.MissionStatus.keys()[status],
		"location": location.serialize() if location else {"is_null": true},
		"difficulty": difficulty,
		"rewards": rewards,
		"time_limit": time_limit,
		"is_expanded": is_expanded,
		"faction": faction,
		"deployment_type": GlobalEnums.DeploymentType.keys()[deployment_type],
		"victory_condition": GlobalEnums.VictoryConditionType.keys()[victory_condition],
		"ai_behavior": GlobalEnums.AIBehavior.keys()[ai_behavior]
	}

static func deserialize(data: Dictionary) -> Mission:
	var mission := Mission.new()
	mission.title = data.get("title", "")
	mission.description = data.get("description", "")
	mission.mission_type = GlobalEnums.MissionType[data.get("mission_type", "OPPORTUNITY")]
	mission.objective = GlobalEnums.MissionObjective[data.get("objective", "SURVIVE")]
	mission.terrain_type = GlobalEnums.TerrainType[data.get("terrain_type", "INDUSTRIAL")]
	mission.required_crew_size = data.get("required_crew_size", 4)
	mission.enemies = data.get("enemies", []).map(func(enemy_data: Dictionary) -> Enemy: 
		return Enemy.deserialize(enemy_data)
	)
	if data.get("unique_individual"):
		mission.unique_individual = Enemy.deserialize(data["unique_individual"])
	else:
		mission.unique_individual = null
	mission.status = GlobalEnums.MissionStatus[data.get("status", "ACTIVE")]
	if data.get("location") and not data["location"].get("is_null", false):
		mission.location = Location.deserialize(data["location"])
	else:
		mission.location = null
	mission.difficulty = data.get("difficulty", 1)
	mission.rewards = data.get("rewards", {})
	mission.time_limit = data.get("time_limit", 3)
	mission.is_expanded = data.get("is_expanded", false)
	mission.faction = data.get("faction", {})
	mission.deployment_type = GlobalEnums.DeploymentType[data.get("deployment_type", "LINE")]
	mission.victory_condition = GlobalEnums.VictoryConditionType[data.get("victory_condition", "TURNS")]
	mission.ai_behavior = GlobalEnums.AIBehavior[data.get("ai_behavior", "TACTICAL")]
	return mission
