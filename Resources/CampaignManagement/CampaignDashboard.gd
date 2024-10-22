class_name CampaignDashboard
extends Control

const GlobalEnums = preload("res://Resources/GameData/GlobalEnums.gd")
const MockGameState = preload("res://Resources/MockGameState.gd")

@onready var phase_label: Label = $MarginContainer/VBoxContainer/HeaderPanel/HBoxContainer/PhaseLabel
@onready var credits_label: Label = $MarginContainer/VBoxContainer/HeaderPanel/HBoxContainer/CreditsLabel
@onready var story_points_label: Label = $MarginContainer/VBoxContainer/HeaderPanel/HBoxContainer/StoryPointsLabel
@onready var crew_list: ItemList = $MarginContainer/VBoxContainer/MainContent/LeftPanel/CrewPanel/VBoxContainer/CrewList
@onready var ship_info: Label = $MarginContainer/VBoxContainer/MainContent/LeftPanel/ShipPanel/VBoxContainer/ShipInfo
@onready var quest_info: Label = $MarginContainer/VBoxContainer/MainContent/RightPanel/QuestPanel/VBoxContainer/QuestInfo
@onready var world_info: Label = $MarginContainer/VBoxContainer/MainContent/RightPanel/WorldPanel/VBoxContainer/WorldInfo
@onready var patron_list: ItemList = $MarginContainer/VBoxContainer/MainContent/RightPanel/PatronPanel/VBoxContainer/PatronList
@onready var action_button: Button = $MarginContainer/VBoxContainer/ButtonContainer/ActionButton
@onready var manage_crew_button: Button = $MarginContainer/VBoxContainer/ButtonContainer/ManageCrewButton
@onready var save_button: Button = $MarginContainer/VBoxContainer/ButtonContainer/SaveButton
@onready var load_button: Button = $MarginContainer/VBoxContainer/ButtonContainer/LoadButton
@onready var quit_button: Button = $MarginContainer/VBoxContainer/ButtonContainer/QuitButton

var game_state: MockGameState

func _ready() -> void:
	game_state = MockGameState.new()
	
	action_button.pressed.connect(_on_action_button_pressed)
	manage_crew_button.pressed.connect(_on_manage_crew_button_pressed)
	save_button.pressed.connect(_on_save_button_pressed)
	load_button.pressed.connect(_on_load_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)
	
	update_display()

func update_display() -> void:
	phase_label.text = GlobalEnums.CampaignPhase.keys()[game_state.current_state].capitalize().replace("_", " ")
	credits_label.text = "Credits: %d" % game_state.credits
	story_points_label.text = "Story Points: %d" % game_state.story_points
	
	update_crew_list()
	update_ship_info()
	update_quest_info()
	update_world_info()
	update_patron_list()
	update_action_button()

func update_crew_list() -> void:
	crew_list.clear()
	for character in game_state.crew.get_characters():
		crew_list.add_item("%s - %s" % [character.name, GlobalEnums.Class.keys()[character.class]])

func update_ship_info() -> void:
	var ship = game_state.current_ship
	if ship:
		ship_info.text = "Ship: %s\nHull: %d/%d" % [ship.name, ship.current_hull, ship.max_hull]
	else:
		ship_info.text = "No ship information available"

func update_quest_info() -> void:
	var current_mission = game_state.current_mission
	if current_mission:
		quest_info.text = "Mission: %s\nType: %s\nStatus: %s" % [
			current_mission.title,
			GlobalEnums.MissionType.keys()[current_mission.mission_type],
			GlobalEnums.MissionStatus.keys()[current_mission.status]
		]
	else:
		quest_info.text = "No active mission"

func update_world_info() -> void:
	var current_world = game_state.current_location
	if current_world:
		world_info.text = "World: %s\nType: %s\nFaction: %s\nInstability: %s" % [
			current_world.name,
			GlobalEnums.TerrainType.keys()[current_world.type],
			GlobalEnums.FactionType.keys()[current_world.faction],
			GlobalEnums.StrifeType.keys()[current_world.instability]
		]
	else:
		world_info.text = "No current world information"

func update_patron_list() -> void:
	patron_list.clear()
	for patron in game_state.patrons:
		patron_list.add_item(patron.name)

func update_action_button() -> void:
	match game_state.current_state:
		GlobalEnums.CampaignPhase.UPKEEP:
			action_button.text = "Start Upkeep"
		GlobalEnums.CampaignPhase.STORY_POINT:
			action_button.text = "Use Story Point"
		GlobalEnums.CampaignPhase.TRAVEL:
			action_button.text = "Travel"
		GlobalEnums.CampaignPhase.PATRONS:
			action_button.text = "Find Patrons"
		GlobalEnums.CampaignPhase.MISSION:
			action_button.text = "Start Mission"
		_:
			action_button.text = "Continue"

func _on_action_button_pressed() -> void:
	# For now, just cycle through phases
	var current_phase = game_state.current_state
	var next_phase = (current_phase + 1) % GlobalEnums.CampaignPhase.size()
	game_state.current_state = next_phase
	update_display()

func _on_manage_crew_button_pressed() -> void:
	print("Manage Crew button pressed")
	# Implement crew management functionality

func _on_save_button_pressed() -> void:
	print("Save button pressed")
	# Implement save game functionality

func _on_load_button_pressed() -> void:
	print("Load button pressed")
	# Implement load game functionality

func _on_quit_button_pressed() -> void:
	get_tree().quit()
