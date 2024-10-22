class_name Mission
extends Resource

@export_group("Mission Details")
var required_crew_size: int = 4
var enemies: Array[Enemy] = []
var unique_individual: Enemy
var status: GlobalEnums.MissionStatus = GlobalEnums.MissionStatus.ACTIVE

@export var title: String = ""
@export var description: String = ""
@export var mission_type: GlobalEnums.Type = GlobalEnums.Type.OPPORTUNITY
@export var objective: GlobalEnums.MissionObjective = GlobalEnums.MissionObjective.FIGHT_OFF
@export var terrain_type: GlobalEnums.TerrainGenerationType = GlobalEnums.TerrainGenerationType.INDUSTRIAL
@export var location: Location
@export var difficulty: int = 1
@export var rewards: Dictionary = {}
@export var time_limit: int = 3
@export var is_expanded: bool = false
@export var faction: Dictionary = {}
@export var deployment_type: GlobalEnums.DeploymentType = GlobalEnums.DeploymentType.LINE
@export var victory_condition: GlobalEnums.VictoryConditionType = GlobalEnums.VictoryConditionType.TURNS
@export var ai_behavior: GlobalEnums.AIBehavior = GlobalEnums.AIBehavior.TACTICAL

func _init(p_title: String = "", p_description: String = "", p_type: GlobalEnums.Type = GlobalEnums.Type.OPPORTUNITY, 
		   p_objective: GlobalEnums.MissionObjective = GlobalEnums.MissionObjective.FIGHT_OFF, p_location: Location = null, 
		   p_difficulty: int = 1, p_rewards: Dictionary = {}, p_time_limit: int = 3,
		   p_is_expanded: bool = false, p_faction: Dictionary = {}) -> void:
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

func set_enemies(p_enemies: Array[Enemy]) -> void:
	enemies = p_enemies

func add_enemy(enemy: Enemy) -> void:
	enemies.append(enemy)

func set_unique_individual(p_unique_individual: Enemy) -> void:
	unique_individual = p_unique_individual

func get_enemy_count() -> int:
	return enemies.size()

func get_total_enemy_count() -> int:
	return get_enemy_count() + (1 if unique_individual else 0)

func get_objective_description() -> String:
	match objective:
		GlobalEnums.MissionObjective.MOVE_THROUGH:
			return "Move at least 2 crew members off the opposing battlefield edge."
		GlobalEnums.MissionObjective.DELIVER:
			return "Deliver a package to the center of the battlefield."
		GlobalEnums.MissionObjective.EXPLORE:
			return "Access a computer console in the center of the battlefield."
		GlobalEnums.MissionObjective.DEFEND:
			return "Check 3 randomly selected terrain features."
		GlobalEnums.MissionObjective.FIGHT_OFF:
			return "Drive off all enemy forces."
		GlobalEnums.MissionObjective.ACQUIRE:
			return "Search terrain features to find a specific item."
		GlobalEnums.MissionObjective.PROTECT:
			return "Defend against enemy forces and hold your position."
		GlobalEnums.MissionObjective.SABOTAGE:
			return "Acquire an item from the center of the battlefield and extract it."
		GlobalEnums.MissionObjective.ELIMINATE:
			return "Eliminate a specific target enemy figure."
		GlobalEnums.MissionObjective.INFILTRATION:
			return "Secure the center of the battlefield for 2 consecutive rounds."
		GlobalEnums.MissionObjective.RESCUE:
			return "Protect a VIP and get them to the center of the battlefield."
		GlobalEnums.MissionObjective.DESTROY:
			return "Destroy a specific target or structure on the battlefield."
		_:
			return "Unknown objective."

func serialize() -> Dictionary:
	return {
		"title": title,
		"description": description,
		"mission_type": GlobalEnums.Type.keys()[mission_type],
		"objective": GlobalEnums.MissionObjective.keys()[objective],
		"terrain_type": GlobalEnums.TerrainGenerationType.keys()[terrain_type],
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
	mission.mission_type = GlobalEnums.Type[data.get("mission_type", "OPPORTUNITY")]
	mission.objective = GlobalEnums.MissionObjective[data.get("objective", "FIGHT_OFF")]
	mission.terrain_type = GlobalEnums.TerrainGenerationType[data.get("terrain_type", "INDUSTRIAL")]
	mission.required_crew_size = data.get("required_crew_size", 4)
	mission.enemies = data.get("enemies", []).map(func(enemy_data: Dictionary) -> Enemy: return Enemy.new(enemy_data.get("name", ""), enemy_data.get("enemy_type", "")).deserialize(enemy_data))
	mission.unique_individual = Enemy.new("Unique", "").deserialize(data["unique_individual"]) if data.get("unique_individual") else null
	mission.status = GlobalEnums.MissionStatus[data.get("status", "ACTIVE")]
	mission.location = Location.deserialize(data["location"]) if data.get("location") else null
	mission.difficulty = data.get("difficulty", 1)
	mission.rewards = data.get("rewards", {})
	mission.time_limit = data.get("time_limit", 3)
	mission.is_expanded = data.get("is_expanded", false)
	mission.faction = data.get("faction", {})
	mission.deployment_type = GlobalEnums.DeploymentType[data.get("deployment_type", "LINE")]
	mission.victory_condition = GlobalEnums.VictoryConditionType[data.get("victory_condition", "TURNS")]
	mission.ai_behavior = GlobalEnums.AIBehavior[data.get("ai_behavior", "TACTICAL")]
	return mission
