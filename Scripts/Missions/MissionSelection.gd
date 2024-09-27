class_name MissionSelection
extends Control

## Emitted when a mission is selected. Connected externally.
signal mission_selected(mission)
const Mission = preload("res://Scripts/Missions/Mission.gd")

@onready var mission_list: ItemList = $Panel/MarginContainer/VBoxContainer/HBoxContainer/MissionList
@onready var mission_details: RichTextLabel = $Panel/MarginContainer/VBoxContainer/HBoxContainer/MissionDetails
@onready var accept_button: Button = $Panel/MarginContainer/VBoxContainer/ButtonContainer/AcceptButton
@onready var close_button: Button = $Panel/MarginContainer/VBoxContainer/ButtonContainer/CloseButton
@onready var back_button: Button = $BackButton

var available_missions: Array[Mission] = []

func _ready() -> void:
	mission_list.item_selected.connect(_on_mission_selected)
	accept_button.pressed.connect(_on_accept_pressed)
	close_button.pressed.connect(_on_close_pressed)
	back_button.pressed.connect(_on_back_pressed)

func populate_missions(missions: Array[Mission]) -> void:
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

func _on_back_pressed() -> void:
	# Implement your back functionality here
	queue_free()  # or any other appropriate action

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
		"type": GlobalEnums.Type.keys()[mission.type],
		"objective": GlobalEnums.MissionObjective.keys()[mission.objective],
		"difficulty": mission.difficulty,
		"time_limit": mission.time_limit,
		"rewards": str(mission.rewards),
		"description": mission.description
	})
