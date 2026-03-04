class_name BugHuntCreationStateManager
extends RefCounted

## Manages state for Bug Hunt campaign creation wizard (4 steps).
## Tracks completion of each step and stores intermediate data.

enum Step {
	CONFIG,
	SQUAD_SETUP,
	EQUIPMENT,
	REVIEW
}

const STEP_NAMES := {
	Step.CONFIG: "Campaign Config",
	Step.SQUAD_SETUP: "Squad Setup",
	Step.EQUIPMENT: "Equipment",
	Step.REVIEW: "Review & Launch"
}

var step_complete: Dictionary = {
	Step.CONFIG: false,
	Step.SQUAD_SETUP: false,
	Step.EQUIPMENT: false,
	Step.REVIEW: false
}

## Accumulated creation data
var config_data: Dictionary = {
	"campaign_name": "",
	"regiment_name": "",
	"uniform_color": "",
	"difficulty": "mess_me_up",
	"use_campaign_escalation": false
}

var squad_data: Dictionary = {
	"main_characters": [],
	"total_reputation": 0
}

var equipment_data: Dictionary = {
	"character_loadouts": {}  # character_id -> {mission_weapon, sidearm_swap}
}


func get_step_name(step: Step) -> String:
	return STEP_NAMES.get(step, "Unknown")


func mark_step_complete(step: Step) -> void:
	step_complete[step] = true


func is_step_complete(step: Step) -> bool:
	return step_complete.get(step, false)


func can_advance_from(step: Step) -> bool:
	return is_step_complete(step)


func can_finish() -> bool:
	return step_complete[Step.CONFIG] and step_complete[Step.SQUAD_SETUP] and step_complete[Step.EQUIPMENT]


func update_config(data: Dictionary) -> void:
	for key in data:
		config_data[key] = data[key]
	step_complete[Step.CONFIG] = not config_data.campaign_name.is_empty()


func update_squad(data: Dictionary) -> void:
	for key in data:
		squad_data[key] = data[key]
	step_complete[Step.SQUAD_SETUP] = squad_data.main_characters.size() >= 3


func update_equipment(data: Dictionary) -> void:
	for key in data:
		equipment_data[key] = data[key]
	step_complete[Step.EQUIPMENT] = true


func get_all_data() -> Dictionary:
	return {
		"config": config_data.duplicate(true),
		"squad": squad_data.duplicate(true),
		"equipment": equipment_data.duplicate(true)
	}
