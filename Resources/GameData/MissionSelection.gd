class_name MissionSelection
extends Control

## Emitted when a mission is selected. Connected externally.
signal mission_selected(mission: Mission)

@onready var mission_list: ItemList = $Panel/MarginContainer/VBoxContainer/HBoxContainer/MissionList
@onready var mission_details: RichTextLabel = $Panel/MarginContainer/VBoxContainer/HBoxContainer/MissionDetails
@onready var accept_button: Button = $Panel/MarginContainer/VBoxContainer/ButtonContainer/AcceptButton
@onready var close_button: Button = $Panel/MarginContainer/VBoxContainer/ButtonContainer/CloseButton
@onready var back_button: Button = $BackButton

var available_missions: Array[Mission] = []

func _ready() -> void:
	if mission_list:
		mission_list.item_selected.connect(_on_mission_selected)
	if accept_button:
		accept_button.pressed.connect(_on_accept_pressed)
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	else:
		push_error("One or more required nodes are missing in MissionSelection scene")

func populate_missions(missions: Array[Mission]) -> void:
	available_missions = missions
	mission_list.clear()
	for mission in available_missions:
		mission_list.add_item(mission.title)

func _on_mission_selected(index: int) -> void:
	var selected_mission: Mission = available_missions[index]
	mission_details.text = _format_mission_details(selected_mission)
	accept_button.disabled = false

func _on_accept_pressed() -> void:
	var selected_index: int = mission_list.get_selected_items()[0]
	var chosen_mission: Mission = available_missions[selected_index]
	mission_selected.emit(chosen_mission)
	queue_free()

func _on_close_pressed() -> void:
	queue_free()

func _on_back_pressed() -> void:
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
		"type": GlobalEnums.Type.keys()[mission.type],
		"objective": GlobalEnums.MissionObjective.keys()[mission.objective],
		"difficulty": mission.difficulty,
		"time_limit": mission.time_limit,
		"rewards": str(mission.rewards),
		"description": mission.description
	})
