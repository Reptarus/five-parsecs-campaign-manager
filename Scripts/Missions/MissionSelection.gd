class_name MissionSelection
extends Control

signal mission_selected(mission: Mission)

var game_state: GameState
var available_missions: Array[Mission] = []

@onready var mission_list: ItemList = $MissionList
@onready var mission_details: RichTextLabel = $MissionDetails
@onready var accept_button: Button = $AcceptButton

func _ready() -> void:
	mission_list.item_selected.connect(_on_mission_selected)
	accept_button.pressed.connect(_on_accept_pressed)

func initialize(p_game_state: GameState) -> void:
	game_state = p_game_state
	refresh_mission_list()

func refresh_mission_list() -> void:
	available_missions = game_state.get_available_missions()
	mission_list.clear()
	for mission in available_missions:
		mission_list.add_item(mission.title)

func _on_mission_selected(index: int) -> void:
	var selected_mission = available_missions[index]
	mission_details.text = _format_mission_details(selected_mission)
	accept_button.disabled = false

func _on_accept_pressed() -> void:
	var selected_index = mission_list.get_selected_items()[0]
	emit_signal("mission_selected", available_missions[selected_index])

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
