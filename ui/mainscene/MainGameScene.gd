# MainGameScene.gd
extends Control

@onready var turn_label = $VBoxContainer/TurnLabel
@onready var credits_label = $VBoxContainer/CreditsLabel
@onready var story_points_label = $VBoxContainer/StoryPointsLabel
@onready var mission_button = $VBoxContainer/MissionButton
@onready var crew_management_button = $VBoxContainer/CrewManagementButton
@onready var ship_management_button = $VBoxContainer/ShipManagementButton

var game_state: GameState

func _ready():
	update_ui()
	
	mission_button.connect("pressed", Callable(self, "_on_mission_button_pressed"))
	crew_management_button.connect("pressed", Callable(self, "_on_crew_management_button_pressed"))
	ship_management_button.connect("pressed", Callable(self, "_on_ship_management_button_pressed"))

func update_ui():
	turn_label.text = "Turn: " + str(game_state.current_turn)
	credits_label.text = "Credits: " + str(game_state.credits)
	story_points_label.text = "Story Points: " + str(game_state.story_points)

func _on_mission_button_pressed():
	# Open mission selection screen
	var mission_selection_scene = load("res://scenes/MissionSelectionScene.tscn").instantiate()
	add_child(mission_selection_scene)

func _on_crew_management_button_pressed():
	# Open crew management screen
	var crew_management_scene = load("res://scenes/CrewManagementScene.tscn").instantiate()
	add_child(crew_management_scene)

func _on_ship_management_button_pressed():
	# Open ship management screen
	var ship_management_scene = load("res://scenes/ShipManagementScene.tscn").instantiate()
	add_child(ship_management_scene)
