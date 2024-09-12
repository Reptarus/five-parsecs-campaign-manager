class_name Mission
extends Resource

const LocationClass = preload("res://Scripts/Locations/Location.gd")

enum Type {OPPORTUNITY, PATRON, QUEST, RIVAL}
enum Status {ACTIVE, COMPLETED, FAILED}
enum Objective {MOVE_THROUGH, DELIVER, ACCESS, PATROL, FIGHT_OFF, SEARCH, DEFEND, ACQUIRE, ELIMINATE, SECURE, PROTECT}

@export var title: String
@export var description: String
@export var type: Type
@export var status: Status = Status.ACTIVE
@export var objective: Objective
@export var patron: Patron
@export var rewards: Dictionary
@export var time_limit: int # in campaign turns
@export var difficulty: int # 1-5
@export var location: Location

func _init(p_title: String = "", p_description: String = "", p_type: Type = Type.OPPORTUNITY, 
		   p_objective: Objective = Objective.MOVE_THROUGH, p_location: Location = null, 
		   p_difficulty: int = 1, p_rewards: Dictionary = {}, p_time_limit: int = 3):
	title = p_title
	description = p_description
	type = p_type
	objective = p_objective
	location = p_location
	difficulty = p_difficulty
	rewards = p_rewards
	time_limit = p_time_limit

func complete() -> void:
	status = Status.COMPLETED

func fail() -> void:
	status = Status.FAILED

func is_expired(current_turn: int) -> bool:
	return current_turn >= time_limit

func serialize() -> Dictionary:
	var serialized_data = {
		"title": title,
		"description": description,
		"type": Type.keys()[type],
		"status": Status.keys()[status],
		"objective": Objective.keys()[objective],
		"rewards": rewards,
		"time_limit": time_limit,
		"difficulty": difficulty,
	}
	
	if patron != null:
		serialized_data["patron"] = patron.serialize()
	else:
		serialized_data["patron"] = null
	
	if location:
		serialized_data["location"] = {"data": location.serialize()}
	else:
		serialized_data["location"] = null
	
	return serialized_data

static func deserialize(data: Dictionary) -> Mission:
	var mission = Mission.new(
		data["title"],
		data["description"],
		Type[data["type"]],
		Objective[data["objective"]],
		Location.deserialize(data["location"]) if data["location"] else null,
		data["difficulty"],
		data["rewards"],
		data["time_limit"]
	)
	mission.status = Status[data["status"]]
	mission.patron = Patron.deserialize(data["patron"]) if data["patron"] else null
	mission.difficulty = data["difficulty"]
	mission.location = Location.deserialize(data["location"]) if data["location"] else null
	return mission
