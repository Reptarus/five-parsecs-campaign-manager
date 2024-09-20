# MissionSelection.gd
extends Control

## Emitted when a mission is selected. Connected externally.
signal mission_selected(mission)

@onready var mission_list: ItemList = $Panel/VBoxContainer/MissionList
@onready var mission_details: RichTextLabel = $Panel/VBoxContainer/MissionDetails
@onready var accept_button: Button = $Panel/VBoxContainer/AcceptButton
@onready var close_button: Button = $Panel/VBoxContainer/CloseButton

var available_missions: Array = []

func _ready() -> void:
	mission_list.item_selected.connect(_on_mission_selected)
	accept_button.pressed.connect(_on_accept_pressed)
	close_button.pressed.connect(_on_close_pressed)

func populate_missions(missions: Array) -> void:
	available_missions = missions
	mission_list.clear()
	for mission in available_missions:
		mission_list.add_item(mission.title)

func _on_mission_selected(index: int) -> void:
	var selected_mission = available_missions[index]
	mission_details.text = _format_mission_details(selected_mission)
	accept_button.disabled = false

func _on_accept_pressed() -> void:
	var selected_index = mission_list.get_selected_items()[0]
	var chosen_mission = available_missions[selected_index]
	emit_signal("mission_selected", chosen_mission)
	queue_free()

func _on_close_pressed() -> void:
	queue_free()

func _format_mission_details(mission: Mission) -> String:
	return """
	Title: {title}
	Type: {type}
	Objective: {objective}
	Difficulty: {difficulty}
	Time Limit: {time_limit} turns
	Rewards: {rewards}
	Description: {description}
	""".format({
		"title": mission.title,
		"type": Mission.Type.keys()[mission.type],
		"objective": Mission.Objective.keys()[mission.objective],
		"difficulty": mission.difficulty,
		"time_limit": mission.time_limit,
		"rewards": str(mission.rewards),
		"description": mission.description
	})
