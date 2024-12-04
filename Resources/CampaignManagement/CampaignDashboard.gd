extends Control

const GlobalEnums = preload("res://Resources/GameData/GlobalEnums.gd")
const GameState = preload("res://Resources/GameData/GameState.gd")

@onready var phase_label = $MarginContainer/VBoxContainer/HeaderPanel/HBoxContainer/PhaseLabel
@onready var credits_label = $MarginContainer/VBoxContainer/HeaderPanel/HBoxContainer/CreditsLabel
@onready var story_points_label = $MarginContainer/VBoxContainer/HeaderPanel/HBoxContainer/StoryPointsLabel
@onready var crew_list = $MarginContainer/VBoxContainer/MainContent/LeftPanel/CrewPanel/VBoxContainer/CrewList
@onready var ship_info = $MarginContainer/VBoxContainer/MainContent/LeftPanel/ShipPanel/VBoxContainer/ShipInfo
@onready var quest_info = $MarginContainer/VBoxContainer/MainContent/RightPanel/QuestPanel/VBoxContainer/QuestInfo
@onready var world_info = $MarginContainer/VBoxContainer/MainContent/RightPanel/WorldPanel/VBoxContainer/WorldInfo
@onready var patron_list = $MarginContainer/VBoxContainer/MainContent/RightPanel/PatronPanel/VBoxContainer/PatronList

@onready var action_button = $MarginContainer/VBoxContainer/ButtonContainer/ActionButton
@onready var manage_crew_button = $MarginContainer/VBoxContainer/ButtonContainer/ManageCrewButton
@onready var save_button = $MarginContainer/VBoxContainer/ButtonContainer/SaveButton
@onready var load_button = $MarginContainer/VBoxContainer/ButtonContainer/LoadButton
@onready var quit_button = $MarginContainer/VBoxContainer/ButtonContainer/QuitButton

var game_state: GameState

func _ready() -> void:
	_connect_signals()
	_initialize_ui()
	if not game_state:
		_populate_test_data()

func setup(state: GameState) -> void:
	game_state = state
	if game_state:
		_update_display()
	else:
		_initialize_ui()
		_populate_test_data()

func _connect_signals() -> void:
	action_button.pressed.connect(_on_action_pressed)
	manage_crew_button.pressed.connect(_on_manage_crew_pressed)
	save_button.pressed.connect(_on_save_pressed)
	load_button.pressed.connect(_on_load_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _initialize_ui() -> void:
	phase_label.text = "Current Phase: Campaign Setup"
	credits_label.text = "Credits: 0"
	story_points_label.text = "Story Points: 0"
	ship_info.text = "No Ship Data"
	quest_info.text = "No Active Quest"
	world_info.text = "No World Data"
	
	crew_list.clear()
	patron_list.clear()
	
	_update_button_states(true)

func _populate_test_data() -> void:
	phase_label.text = "Current Phase: Exploration"
	credits_label.text = "Credits: 2500"
	story_points_label.text = "Story Points: 3"
	
	crew_list.clear()
	var test_crew = [
		"Captain Sarah 'Starblade' Chen - Veteran",
		"Marcus 'Doc' Rodriguez - Medic",
		"Zara 'Ghost' Al-Rashid - Scout",
		"Viktor 'Tank' Petrov - Heavy",
		"Luna 'Tech' Martinez - Engineer"
	]
	for crew_member in test_crew:
		crew_list.add_item(crew_member)
	
	ship_info.text = """Ship: SSV Nomad
Class: Corvette
Hull: 75/100
Fuel: 80%
Cargo: 12/20
Special Systems: 
- Advanced Sensors
- Medical Bay
- Stealth Drive"""
	
	quest_info.text = """Active Mission: The Lost Archive
Type: Recovery
Difficulty: Hard
Reward: 1500 Credits
Objective: Recover ancient data cores from abandoned research facility
Location: Sector 7, Nebula Zone
Warning: Heavy enemy presence reported"""
	
	world_info.text = """Current Location: New Haven
Type: Frontier World
Population: Medium
Security Level: Low
Available Services:
- Trading Post
- Medical Facility
- Ship Repairs
Local Threats:
- Pirate Activity
- Hostile Wildlife"""
	
	patron_list.clear()
	var test_patrons = [
		"Merchant's Guild - Trade Mission Available",
		"Research Institute - Exploration Contract",
		"Local Militia - Defense Contract",
		"Mining Consortium - Resource Gathering",
		"Smuggler's Alliance - High Risk/Reward"
	]
	for patron in test_patrons:
		patron_list.add_item(patron)

func _update_display() -> void:
	if not game_state:
		_initialize_ui()
		_populate_test_data()
		return
		
	phase_label.text = "Current Phase: %s" % GlobalEnums.CampaignPhase.keys()[game_state.current_phase]
	credits_label.text = "Credits: %d" % game_state.credits
	story_points_label.text = "Story Points: %d" % game_state.story_points
	
	_update_crew_list()
	_update_ship_info()
	_update_quest_info()
	_update_world_info()
	_update_patron_list()
	_update_button_states(true)

func _update_crew_list() -> void:
	crew_list.clear()
	if not game_state or not game_state.crew:
		crew_list.add_item("No Crew Members")
		return
		
	for member in game_state.crew.members:
		crew_list.add_item(member.character_name)

func _update_ship_info() -> void:
	if not game_state or not game_state.ship:
		ship_info.text = "No Ship Data"
		return
		
	ship_info.text = game_state.ship.get_info()

func _update_quest_info() -> void:
	if not game_state or not game_state.current_quest:
		quest_info.text = "No Active Quest"
		return
		
	quest_info.text = game_state.current_quest.get_description()

func _update_world_info() -> void:
	if not game_state or not game_state.current_world:
		world_info.text = "No World Data"
		return
		
	world_info.text = game_state.current_world.get_info()

func _update_patron_list() -> void:
	patron_list.clear()
	if not game_state or not game_state.patrons:
		patron_list.add_item("No Active Patrons")
		return
		
	for patron in game_state.patrons:
		patron_list.add_item(patron.name)

func _update_button_states(has_game: bool) -> void:
	action_button.disabled = not has_game
	manage_crew_button.disabled = not has_game
	save_button.disabled = not has_game

func _on_action_pressed() -> void:
	if game_state:
		# Handle action button press
		pass

func _on_manage_crew_pressed() -> void:
	if game_state:
		# Open crew management screen
		pass

func _on_save_pressed() -> void:
	if game_state:
		game_state.save_game()

func _on_load_pressed() -> void:
	# Open load game dialog
	pass

func _on_quit_pressed() -> void:
	# Return to main menu
	get_tree().change_scene_to_file("res://Resources/UI/MainMenu.tscn")
