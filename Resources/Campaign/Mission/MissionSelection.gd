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
		var item_text = _format_mission_list_item(mission)
		mission_list.add_item(item_text)

func _format_mission_list_item(mission: Mission) -> String:
	var type_str = GlobalEnums.Type.keys()[mission.type]
	return "%s (%s) - Difficulty: %d" % [mission.title, type_str, mission.difficulty]

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
	var details = """
	[b]Title:[/b] {title}
	[b]Type:[/b] {type}
	[b]Objective:[/b] {objective}
	[b]Difficulty:[/b] {difficulty}
	[b]Time Limit:[/b] {time_limit} turns
	[b]Required Crew:[/b] {required_crew}
	[b]Deployment:[/b] {deployment}
	[b]Victory Condition:[/b] {victory}
	
	[b]Rewards:[/b]
	{rewards}
	
	[b]Description:[/b]
	{description}
	
	[b]Objective Details:[/b]
	{objective_desc}
	""".format({
		"title": mission.title,
		"type": GlobalEnums.Type.keys()[mission.type],
		"objective": GlobalEnums.MissionObjective.keys()[mission.objective],
		"difficulty": mission.difficulty,
		"time_limit": mission.time_limit,
		"required_crew": mission.required_crew_size,
		"deployment": GlobalEnums.DeploymentType.keys()[mission.deployment_type],
		"victory": GlobalEnums.VictoryConditionType.keys()[mission.victory_condition],
		"rewards": _format_rewards(mission.rewards),
		"description": mission.description,
		"objective_desc": mission.get_objective_description()
	})
	
	if mission.hazards.size() > 0:
		details += "\n[b]Hazards:[/b]\n" + "\n".join(mission.hazards)
	
	if mission.benefits.size() > 0:
		details += "\n[b]Benefits:[/b]\n" + "\n".join(mission.benefits)
	
	return details

func _format_rewards(rewards: Dictionary) -> String:
	var reward_lines: Array[String] = []
	
	if rewards.has("credits"):
		reward_lines.append("Credits: %d" % rewards.credits)
	if rewards.has("reputation"):
		reward_lines.append("Reputation: %d" % rewards.reputation)
	if rewards.get("item", false):
		reward_lines.append("Special Item")
	if rewards.has("story_points"):
		reward_lines.append("Story Points: %d" % rewards.story_points)
	
	return "\n".join(reward_lines)
