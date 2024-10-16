class_name Mission
extends Resource

enum Type { OPPORTUNITY, PATRON, QUEST, RIVAL }
enum Status { ACTIVE, COMPLETED, FAILED }
enum Objective { MOVE_THROUGH, DELIVER, ACCESS, PATROL, FIGHT_OFF, SEARCH, DEFEND, ACQUIRE, ELIMINATE, SECURE, PROTECT }

@export var title: String
@export var description: String
@export var type: Type
@export var status: Status = Status.ACTIVE
@export var objective: Objective
@export var patron: Patron
@export var rewards: Dictionary
@export var time_limit: int  # in campaign turns
@export var difficulty: int  # 1-5
@export var location: Location

func _init(p_title: String = "", p_description: String = "", p_type: Type = Type.OPPORTUNITY, p_objective: Objective = Objective.FIGHT_OFF) -> void:
	title = p_title
	description = p_description
	type = p_type
	objective = p_objective

func complete() -> void:
	status = Status.COMPLETED

func fail() -> void:
	status = Status.FAILED

func is_expired(current_turn: int) -> bool:
	return current_turn >= time_limit

func serialize() -> Dictionary:
	return {
		"title": title,
		"description": description,
<<<<<<< HEAD
		"type": type,
		"status": status,
		"objective": objective,
		"patron": patron.serialize() if patron else null,
=======
		"mission_type": GlobalEnums.Type.keys()[mission_type],
		"objective": GlobalEnums.MissionObjective.keys()[objective],
		"terrain_type": GlobalEnums.TerrainGenerationType.keys()[terrain_type],
		"required_crew_size": required_crew_size,
		"enemies": enemies.map(func(enemy: Enemy) -> Dictionary: return enemy.serialize()),
		"unique_individual": unique_individual.serialize() if unique_individual else null,
		"status": GlobalEnums.MissionStatus.keys()[status],
		"location": location.serialize() if location else {"is_null": true},
		"difficulty": difficulty,
>>>>>>> parent of 1efa334 (worldphase functionality)
		"rewards": rewards,
		"time_limit": time_limit,
		"difficulty": difficulty,
		"location": location.serialize() if location else null
	}

static func deserialize(data: Dictionary) -> Mission:
<<<<<<< HEAD
	var mission = Mission.new(data["title"], data["description"], data["type"], data["objective"])
	mission.status = data["status"]
	mission.patron = Patron.deserialize(data["patron"]) if data["patron"] else null
	mission.rewards = data["rewards"]
	mission.time_limit = data["time_limit"]
	mission.difficulty = data["difficulty"]
	mission.location = Location.deserialize(data["location"]) if data["location"] else null
=======
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
>>>>>>> parent of 1efa334 (worldphase functionality)
	return mission
