class_name CampaignDashboardUI
extends Control

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const GameState = preload("res://src/core/state/GameState.gd")
const Character = preload("res://src/core/character/Management/CharacterDataManager.gd")
const VictoryProgressPanel = preload("res://src/ui/screens/campaign/VictoryProgressPanel.tscn")

@onready var phase_label = $MarginContainer/VBoxContainer/HeaderPanel/HBoxContainer/PhaseLabel
@onready var credits_label = $MarginContainer/VBoxContainer/HeaderPanel/HBoxContainer/CreditsLabel
@onready var story_points_label = $MarginContainer/VBoxContainer/HeaderPanel/HBoxContainer/StoryPointsLabel
@onready var crew_list = $MarginContainer/VBoxContainer/MainContent/LeftPanel/CrewPanel/VBoxContainer/CrewList
@onready var ship_info = $MarginContainer/VBoxContainer/MainContent/LeftPanel/ShipPanel/VBoxContainer/ShipInfo
@onready var quest_info = $MarginContainer/VBoxContainer/MainContent/RightPanel/QuestPanel/VBoxContainer/QuestInfo
@onready var world_info = $MarginContainer/VBoxContainer/MainContent/RightPanel/WorldPanel/VBoxContainer/WorldInfo
@onready var patron_list = $MarginContainer/VBoxContainer/MainContent/RightPanel/PatronPanel/VBoxContainer/PatronList
@onready var victory_progress_container = $MarginContainer/VBoxContainer/VictoryProgressContainer

@onready var action_button = $MarginContainer/VBoxContainer/ButtonContainer/ActionButton
@onready var manage_crew_button = $MarginContainer/VBoxContainer/ButtonContainer/ManageCrewButton
@onready var save_button = $MarginContainer/VBoxContainer/ButtonContainer/SaveButton
@onready var load_button = $MarginContainer/VBoxContainer/ButtonContainer/LoadButton
@onready var quit_button = $MarginContainer/VBoxContainer/ButtonContainer/QuitButton

var game_state: GameState
var campaign_manager: GameCampaignManager
var victory_progress_panel: Control

func _ready() -> void:
	campaign_manager = get_node("/root/CampaignManager")
	if not campaign_manager:
		push_error("CampaignManager not found")
		queue_free()
		return
		
	game_state = campaign_manager.game_state
	if not game_state:
		push_error("GameState not found")
		queue_free()
		return
		
	_connect_signals()
	_initialize_ui()
	_setup_victory_progress()
	_update_display()

func _connect_signals() -> void:
	if campaign_manager:
		campaign_manager.campaign_system.campaign_phase_changed.connect(_on_phase_changed)
		campaign_manager.campaign_system.campaign_turn_completed.connect(_on_turn_completed)
		campaign_manager.campaign_saved.connect(_on_save_completed)
		campaign_manager.campaign_loaded.connect(_on_load_completed)
	
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

func _setup_victory_progress() -> void:
	if victory_progress_panel:
		victory_progress_panel.queue_free()
	
	victory_progress_panel = VictoryProgressPanel.instantiate()
	victory_progress_container.add_child(victory_progress_panel)

func _update_display() -> void:
	if not game_state:
		_initialize_ui()
		return
		
	phase_label.text = "Current Phase: %s" % GameEnums.CampaignPhase.keys()[game_state.current_phase]
	credits_label.text = "Credits: %d" % game_state.credits
	story_points_label.text = "Story Points: %d" % game_state.story_points
	
	_update_crew_list()
	_update_ship_info()
	_update_quest_info()
	_update_world_info()
	_update_patron_list()
	_update_button_states(true)
	_update_action_button()

func _update_crew_list() -> void:
	crew_list.clear()
	if not game_state or not game_state.crew:
		crew_list.add_item("No Crew Members")
		return
		
	for member in game_state.crew:
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

func _update_action_button() -> void:
	var phase = game_state.current_phase
	match phase:
		GameEnums.CampaignPhase.UPKEEP:
			action_button.text = "Start Upkeep"
		GameEnums.CampaignPhase.BATTLE:
			action_button.text = "Start Battle"
		GameEnums.CampaignPhase.POST_BATTLE:
			action_button.text = "Post-Battle"
		GameEnums.CampaignPhase.MANAGEMENT:
			action_button.text = "Management"
		GameEnums.CampaignPhase.TRAVEL:
			action_button.text = "Travel"
		_:
			action_button.text = "Next Phase"

func _on_action_pressed() -> void:
	if campaign_manager:
		campaign_manager.process_current_phase()

func _on_manage_crew_pressed() -> void:
	get_tree().change_scene_to_file("res://src/data/resources/CrewAndCharacters/Scenes/CrewManagement.tscn")

func _on_save_pressed() -> void:
	if campaign_manager:
		campaign_manager.save_campaign()

func _on_load_pressed() -> void:
	get_tree().change_scene_to_file("res://src/data/resources/UI/Screens/LoadGameScreen.tscn")

func _on_quit_pressed() -> void:
	if campaign_manager:
		campaign_manager.end_campaign()
	get_tree().change_scene_to_file("res://src/data/resources/UI/Screens/MainMenu.tscn")

func _on_phase_changed(_new_phase: GameEnums.CampaignPhase) -> void:
	_update_display()

func _on_turn_completed() -> void:
	_update_display()

func _on_save_completed() -> void:
	# Show save confirmation
	pass

func _on_load_completed() -> void:
	_update_display()
