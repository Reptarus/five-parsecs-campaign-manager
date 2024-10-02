class_name TravelPhase
extends Control

var game_state: GameState

var game_world: GameWorld
var campaign_manager: CampaignManager
var mission_manager: MissionManager
var quest_manager: QuestManager
var patron_job_manager: PatronJobManager
var campaign_event_generator: CampaignEventGenerator
var starship_travel_events: StarshipTravelEvents
var world_economy_manager: WorldEconomyManager
var fringe_world_strife_manager: FringeWorldStrifeManager

var expanded_quest_progression_manager: ExpandedQuestProgressionManager

@onready var upkeep_details = $VBoxContainer/TabContainer/Upkeep/UpkeepDetails
@onready var travel_event_details = $VBoxContainer/TabContainer/Travel/TravelEventDetails
@onready var patrons_list = $VBoxContainer/TabContainer/Patrons/PatronsList
@onready var mission_details = $VBoxContainer/TabContainer/Mission/MissionDetails
@onready var log_book = $VBoxContainer/LogBook
@onready var campaign_event_ui = preload("res://Scenes/campaign/NewCampaignSetup/CampaignEventUI.tscn")

var game_state_manager: GameStateManager

func _ready():
	game_state_manager = get_node("/root/GameStateManager") as GameStateManager
	if not game_state_manager:
		push_error("Failed to get GameStateManager")
		return
	
	expanded_quest_progression_manager = ExpandedQuestProgressionManager.new(game_state_manager)
	quest_manager = game_state_manager.quest_manager
	
	initialize_game_components()
	
	assert(upkeep_details != null, "Upkeep details not found")
	assert(travel_event_details != null, "Travel event details not found")
	assert(patrons_list != null, "Patrons list not found")
	assert(mission_details != null, "Mission details not found")
	assert(log_book != null, "Log book not found")

func initialize_game_components() -> void:
	var story_track := StoryTrack.new()
	story_track.initialize(game_state)
	
	game_world = GameWorld.new(game_state_manager)
	
	campaign_manager = CampaignManager.new(game_state_manager.game_state)
	
	mission_manager = game_state.mission_generator as MissionManager
	
	expanded_quest_progression_manager = ExpandedQuestProgressionManager.new(game_state_manager)
	quest_manager = game_state_manager.quest_manager
	
	patron_job_manager = game_state_manager.patron_job_manager
	
	campaign_event_generator = CampaignEventGenerator.new(game_state_manager)
	
	var economy_manager := EconomyManager.new()
	economy_manager.initialize(game_state)
	
	world_economy_manager = WorldEconomyManager.new(game_state.current_location, economy_manager)
	
	fringe_world_strife_manager = game_state_manager.fringe_world_strife_manager
	
	starship_travel_events = StarshipTravelEvents.new()
	starship_travel_events.initialize(game_state)
	
	game_world.world_step_completed.connect(_on_world_step_completed)
	game_world.mission_selection_requested.connect(_on_mission_selection_requested)
	game_world.phase_completed.connect(_on_phase_completed)
	game_world.game_over.connect(_on_game_over)
	game_world.ui_update_requested.connect(_on_ui_update_requested)

func _on_upkeep_button_pressed():
	world_economy_manager.update_local_economy()
	fringe_world_strife_manager.update_strife()
	quest_manager.update_quests()
	
	var new_event = campaign_event_generator.generate_event()
	new_event.effect.call()
	
	var event_description = "Campaign Event: " + new_event.type + " - " + new_event.description
	log_event(event_description)
	upkeep_details.clear()
	display_result(upkeep_details, event_description)
	
	_on_ui_update_requested()

func _on_stay_button_pressed():
	var stay_result = campaign_manager.stay_in_current_location()
	travel_event_details.clear()
	display_result(travel_event_details, stay_result)
	log_event(stay_result)
	_on_world_step_completed()

func _on_travel_button_pressed():
	var travel_result = campaign_manager.travel_to_new_location()
	travel_event_details.clear()
	if travel_result.success:
		display_result(travel_event_details, "Traveled to: " + travel_result.destination)
		log_event("Traveled to: " + travel_result.destination)
		
		var event = starship_travel_events.generate_travel_event()
		var event_result = event.action.call()
		display_result(travel_event_details, event.name + ": " + event_result)
		log_event(event.name + ": " + event_result)
		
		_on_world_step_completed()
	else:
		display_result(travel_event_details, "Travel failed: " + travel_result.error)
		log_event("Travel failed: " + travel_result.error)

func _on_next_event_button_pressed():
	var event = starship_travel_events.generate_travel_event()
	var event_result = event.action.call()
	travel_event_details.clear()
	display_result(travel_event_details, event.name + ": " + event_result)
	log_event(event.name + ": " + event_result)

func _on_check_patrons_button_pressed():
	var patrons_result = patron_job_manager.determine_job_offers()
	patrons_list.clear()
	for job in patrons_result:
		display_result(patrons_list, job)
	log_event("New job offers: " + ", ".join(patrons_result))

func _on_start_mission_button_pressed():
	var mission = mission_manager.generate_missions()[0]  # Get the first generated mission
	mission_details.clear()
	if mission:
		game_state.current_mission = mission
		game_state_manager.transition_to_state(GlobalEnums.CampaignPhase.MISSION)
		display_result(mission_details, "Mission started: " + mission.name)
		log_event("Mission started: " + mission.name)
	else:
		display_result(mission_details, "No available missions.")
		log_event("No available missions.")

func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://Scenes/Scene Container/CampaignDashboard.tscn")

func log_event(event: String):
	game_state.last_mission_results += event + "\n"
	log_book.text += event + "\n"
	log_book.scroll_vertical = INF

func display_result(parent: Control, result: String):
	var label = Label.new()
	label.text = result
	label.autowrap = true
	parent.add_child(label)

func _on_mission_selection_requested(available_missions: Array):
	var mission_selection_scene = preload("res://Scenes/campaign/NewCampaignSetup/MissionSelectionUI.tscn")
	var mission_selection_instance = mission_selection_scene.instantiate()
	mission_selection_instance.populate_missions(available_missions)
	mission_selection_instance.mission_selected.connect(_on_mission_selected)
	add_child(mission_selection_instance)

func _on_mission_selected(mission: Mission):
	game_state.current_mission = mission
	game_state_manager.transition_to_state(GlobalEnums.CampaignPhase.MISSION)
	display_result(mission_details, "Mission started: " + mission.name)
	log_event("Mission started: " + mission.name)

func _on_phase_completed():
	log_event("Phase completed")
	update_ui()

func _on_game_over():
	log_event("Game Over")
	# Implement game over logic here

func _on_ui_update_requested():
	update_ui()

func update_ui():
	var _tab_container = $VBoxContainer/TabContainer
	
	upkeep_details.clear()
	
	var travel_options = $VBoxContainer/TabContainer/Travel/TravelOptions
	travel_options.clear()
	
	travel_event_details.clear()
	
	patrons_list.clear()
	
	mission_details.clear()
	
	log_book.text = game_state.last_mission_results
	
	$VBoxContainer/TabContainer/Upkeep/UpkeepButton.disabled = false
	$VBoxContainer/TabContainer/Travel/NextEventButton.disabled = false
	$VBoxContainer/TabContainer/Patrons/CheckPatronsButton.disabled = false
	$VBoxContainer/TabContainer/Mission/StartMissionButton.disabled = false

func _on_world_step_completed():
	world_economy_manager.update_economy()
	fringe_world_strife_manager.update_strife()
	quest_manager.update_quests()
	var new_event = campaign_event_generator.generate_event()
	
	new_event.effect.call()
	
	var event_description = "Campaign Event: " + new_event.type + " - " + new_event.description
	log_event(event_description)
	display_result(travel_event_details, event_description)
	
	update_ui()
