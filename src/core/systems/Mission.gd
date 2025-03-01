@tool
extends Resource
class_name Mission

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

signal mission_completed
signal mission_failed
signal mission_updated

@export var mission_id: String = ""
@export var mission_title: String = ""
@export var mission_description: String = ""
@export var mission_type: int = GameEnums.MissionType.NONE
@export var mission_difficulty: int = 1
@export var reward_credits: int = 100
@export var is_completed: bool = false
@export var is_failed: bool = false
@export var turn_offered: int = 0

func _init() -> void:
	pass

func complete(success: bool = true) -> void:
	is_completed = success
	if success:
		mission_completed.emit()

func fail(emit_signal: bool = true) -> void:
	is_failed = true
	if emit_signal:
		mission_failed.emit()

func serialize() -> Dictionary:
	return {
		"mission_id": mission_id,
		"mission_title": mission_title,
		"mission_description": mission_description,
		"mission_type": mission_type,
		"mission_difficulty": mission_difficulty,
		"reward_credits": reward_credits,
		"is_completed": is_completed,
		"is_failed": is_failed,
		"turn_offered": turn_offered
	}

func deserialize(data: Dictionary) -> Mission:
	mission_id = data.get("mission_id", "")
	mission_title = data.get("mission_title", "")
	mission_description = data.get("mission_description", "")
	mission_type = data.get("mission_type", GameEnums.MissionType.NONE)
	mission_difficulty = data.get("mission_difficulty", 1)
	reward_credits = data.get("reward_credits", 100)
	is_completed = data.get("is_completed", false)
	is_failed = data.get("is_failed", false)
	turn_offered = data.get("turn_offered", 0)
	return self