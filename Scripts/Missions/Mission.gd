class_name Mission
extends Resource

const LocationClass = preload("res://Scripts/Locations/Location.gd")

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
		"type": Type.keys()[type],
		"status": Status.keys()[status],
		"objective": Objective.keys()[objective],
		"patron": patron.serialize() if patron else null,
		"rewards": rewards,
		"time_limit": time_limit,
		"difficulty": difficulty,
		"location": location.serialize() if location else null
	}

static func deserialize(data: Dictionary) -> Mission:
	var mission = Mission.new(data["title"], data["description"], Type[data["type"]], Objective[data["objective"]])
	mission.status = Status[data["status"]]
	mission.patron = Patron.deserialize(data["patron"]) if data["patron"] else null
	mission.rewards = data["rewards"]
	mission.time_limit = data["time_limit"]
	mission.difficulty = data["difficulty"]
	mission.location = Location.deserialize(data["location"]) if data["location"] else null
	return mission
