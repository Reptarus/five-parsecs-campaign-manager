class_name Quest
extends Resource

signal stage_advanced(new_stage: int)
signal quest_completed
signal quest_failed
signal objective_updated(current: int, total: int)

@export var title: String:
	get:
		return title
	set(value):
		if value.strip_edges().is_empty():
			push_error("Quest title cannot be empty")
			return
		title = value

@export var description: String
@export var current_stage: int = 0
@export var total_stages: int = 1
@export var objectives_completed: int = 0
@export var total_objectives: int = 1
@export var reward: int = 100
@export var quest_type: GlobalEnums.QuestType = GlobalEnums.QuestType.MAIN

var status: GlobalEnums.QuestStatus = GlobalEnums.QuestStatus.ACTIVE

func advance_stage() -> bool:
	if current_stage >= total_stages:
		push_error("Cannot advance beyond final stage")
		return false
		
	current_stage += 1
	stage_advanced.emit(current_stage)
	
	if current_stage == total_stages:
		complete_quest()
	return true

func complete_objective() -> void:
	objectives_completed += 1
	objective_updated.emit(objectives_completed, total_objectives)
	
	if objectives_completed >= total_objectives:
		complete_quest()

func complete_quest() -> void:
	status = GlobalEnums.QuestStatus.COMPLETED
	quest_completed.emit()

func fail_quest() -> void:
	status = GlobalEnums.QuestStatus.FAILED
	quest_failed.emit()
