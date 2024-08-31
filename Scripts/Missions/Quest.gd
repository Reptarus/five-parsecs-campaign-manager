class_name Quest
extends Resource

@export var quest_type: String
@export var location: Location
@export var objective: String
@export var reward: Dictionary
@export var completed: bool = false
@export var failed: bool = false

func _init(_quest_type: String, _location: Location, _objective: String, _reward: Dictionary):
	quest_type = _quest_type
	location = _location
	objective = _objective
	reward = _reward

func complete():
	completed = true

func fail():
	failed = true

func is_active() -> bool:
	return not completed and not failed

func serialize() -> Dictionary:
	return {
		"quest_type": quest_type,
		"location": location.serialize(),
		"objective": objective,
		"reward": reward,
		"completed": completed,
		"failed": failed
	}

static func deserialize(data: Dictionary) -> Quest:
	var quest = Quest.new(
		data["quest_type"],
		Location.deserialize(data["location"]),
		data["objective"],
		data["reward"]
	)
	quest.completed = data["completed"]
	quest.failed = data["failed"]
	return quest
