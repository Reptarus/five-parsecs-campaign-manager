# MissionSelection.gd
extends Control

var game_state: GameState

@onready var mission_list: ItemList = $Panel/VBoxContainer/MissionList
@onready var mission_details: RichTextLabel = $Panel/VBoxContainer/MissionDetails
@onready var accept_button: Button = $Panel/VBoxContainer/AcceptButton
@onready var close_button: Button = $Panel/VBoxContainer/CloseButton

func _ready() -> void:
	mission_list.connect("item_selected", Callable(self, "_on_mission_selected"))
	accept_button.connect("pressed", Callable(self, "_on_accept_pressed"))
	close_button.connect("pressed", Callable(self, "_on_close_pressed"))

func set_game_state(state: GameState) -> void:
	game_state = state
	populate_mission_list()

func populate_mission_list() -> void:
	mission_list.clear()
	for mission in game_state.available_missions:
		mission_list.add_item(mission.title)

func _on_mission_selected(index: int) -> void:
	var selected_mission = game_state.available_missions[index]
	mission_details.text = _format_mission_details(selected_mission)
	accept_button.disabled = false

func _on_accept_pressed() -> void:
	var selected_index = mission_list.get_selected_items()[0]
	game_state.current_mission = game_state.available_missions[selected_index]
	game_state.remove_mission(game_state.current_mission)
	get_tree().root.get_node("Main").goto_scene("res://scenes/PreBattle.tscn")

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
