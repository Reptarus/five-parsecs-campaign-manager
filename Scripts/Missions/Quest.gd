class_name Quest
extends Resource

@export var quest_type: String
@export var location: Location
@export var objective: String
@export var reward: Dictionary
@export var completed: bool = false
@export var failed: bool = false
@export var current_stage: int = 1
@export var current_requirements: Array = []
@export var faction: Dictionary = {}
@export var loyalty_requirement: int = 0
@export var power_requirement: int = 0

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
		"failed": failed,
		"current_stage": current_stage,
		"current_requirements": current_requirements,
		"faction": faction,
		"loyalty_requirement": loyalty_requirement,
		"power_requirement": power_requirement
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
	quest.current_stage = data["current_stage"]
	quest.current_requirements = data["current_requirements"]
	quest.faction = data["faction"]
	quest.loyalty_requirement = data["loyalty_requirement"]
	quest.power_requirement = data["power_requirement"]
	return quest
