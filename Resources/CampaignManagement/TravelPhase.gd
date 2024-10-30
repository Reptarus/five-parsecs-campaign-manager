class_name TravelPhase
extends Control

signal phase_completed
signal step_completed

enum TravelStep {
	UPKEEP,
	TRAVEL_DECISION,
	EVENT_RESOLUTION,
	PATRON_CHECK,
	MISSION_START
}

var current_step: TravelStep = TravelStep.UPKEEP
var game_state: GameState
var game_state_manager: GameStateManager

# Managers
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

# UI Elements
@onready var tab_container = $VBoxContainer/TabContainer
@onready var log_book = $VBoxContainer/LogBook
@onready var back_button = $VBoxContainer/BackButton
@onready var upkeep_details = $VBoxContainer/TabContainer/Upkeep/UpkeepDetails
@onready var travel_event_details = $VBoxContainer/TabContainer/Travel/TravelEventDetails
@onready var patrons_list = $VBoxContainer/TabContainer/Patrons/PatronsList
@onready var mission_details = $VBoxContainer/TabContainer/Mission/MissionDetails

func _ready() -> void:
	initialize_game_state()
	initialize_game_components()
	setup_signals()
	setup_current_step()

func initialize_game_state() -> void:
	game_state_manager = get_node("/root/GameStateManager") as GameStateManager
	if not game_state_manager:
		push_error("Failed to get GameStateManager")
		return
	game_state = game_state_manager.game_state

func initialize_game_components() -> void:
	var story_track := StoryTrack.new()
	story_track.initialize(game_state_manager)
	
	game_world = GameWorld.new(game_state_manager)
	campaign_manager = CampaignManager.new(game_state)
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

func setup_signals() -> void:
	game_world.world_step_completed.connect(_on_world_step_completed)
	game_world.mission_selection_requested.connect(_on_mission_selection_requested)
	game_world.phase_completed.connect(_on_phase_completed)
	game_world.game_over.connect(_on_game_over)
	game_world.ui_update_requested.connect(_on_ui_update_requested)

func process_step() -> void:
	match current_step:
		TravelStep.UPKEEP:
			process_upkeep()
		TravelStep.TRAVEL_DECISION:
			process_travel_decision()
		TravelStep.EVENT_RESOLUTION:
			process_event_resolution()
		TravelStep.PATRON_CHECK:
			process_patron_check()
		TravelStep.MISSION_START:
			process_mission_start()

func process_upkeep() -> void:
	var upkeep_report = {}
	
	# Calculate crew maintenance
	var crew_cost = _calculate_crew_maintenance()
	upkeep_report["crew"] = crew_cost
	
	# Calculate ship maintenance
	var ship_cost = _calculate_ship_maintenance()
	upkeep_report["ship"] = ship_cost
	
	# Calculate resource consumption
	var resource_cost = _calculate_resource_consumption()
	upkeep_report["resources"] = resource_cost
	
	# Total costs
	var total_cost = crew_cost + ship_cost + resource_cost
	
	# Try to pay upkeep
	if world_economy_manager.pay_upkeep(game_state.current_crew):
		_apply_upkeep_effects(upkeep_report)
		display_result(upkeep_details, _format_upkeep_report(upkeep_report))
	else:
		_handle_upkeep_failure(upkeep_report)
	
	# Continue with existing functionality
	world_economy_manager.update_local_economy()
	fringe_world_strife_manager.update_strife()
	quest_manager.update_quests()
	
	var new_event = campaign_event_generator.generate_event()
	new_event.effect.call()
	
	var event_description = "Campaign Event: " + new_event.type + " - " + new_event.description
	log_event(event_description)
	display_result(upkeep_details, event_description)
	step_completed.emit()

func _calculate_crew_maintenance() -> int:
	var base_cost = 50  # Base cost per crew member
	var total_cost = 0
	
	for crew_member in game_state.current_crew.members:
		var skill_modifier = crew_member.get_total_skill_level() * 0.1
		total_cost += base_cost + (base_cost * skill_modifier)
	
	return total_cost

func _calculate_ship_maintenance() -> int:
	var ship = game_state.current_ship
	var base_cost = 100  # Base maintenance cost
	
	# Factor in ship health
	var health_modifier = (100 - ship.current_hull) * 0.02
	var size_modifier = ship.get_total_weight() * 0.001
	
	return base_cost + (base_cost * health_modifier) + (base_cost * size_modifier)

func _calculate_resource_consumption() -> int:
	var crew_size = game_state.current_crew.members.size()
	var base_consumption = 25 * crew_size  # Base resource cost per crew member
	
	# Factor in ship efficiency
	var efficiency_modifier = game_state.current_ship.get_efficiency_rating()
	return base_consumption * (2 - efficiency_modifier)  # Efficiency reduces cost

func _apply_upkeep_effects(report: Dictionary) -> void:
	# Apply morale effects
	var morale_change = 0
	if report["crew"] > game_state.credits * 0.5:  # If crew costs are more than 50% of credits
		morale_change -= 1
	
	# Apply ship effects
	if report["ship"] > 0:
		game_state.current_ship.perform_maintenance()
	
	# Apply resource effects
	game_state.consume_resources(report["resources"])

func _handle_upkeep_failure(report: Dictionary) -> void:
	display_result(upkeep_details, "WARNING: Unable to pay upkeep costs!")
	
	# Decrease morale
	game_state.current_crew.decrease_morale()
	
	# Ship deterioration
	game_state.current_ship.deteriorate()
	
	# Resource crisis
	game_state.trigger_resource_crisis()

func _format_upkeep_report(report: Dictionary) -> String:
	return """Upkeep Report:
	Crew Maintenance: {crew} credits
	Ship Maintenance: {ship} credits
	Resource Consumption: {resources} credits
	Total: {total} credits""".format({
		"crew": report["crew"],
		"ship": report["ship"],
		"resources": report["resources"],
		"total": report["crew"] + report["ship"] + report["resources"]
	})

func process_travel_decision() -> void:
	var travel_options = world_economy_manager.get_available_destinations()
	for destination in travel_options:
		var travel_cost = world_economy_manager.calculate_travel_cost(destination)
		display_result(travel_event_details, "Travel to %s: %d credits" % [destination.name, travel_cost])
	step_completed.emit()

func process_event_resolution() -> void:
	var event = starship_travel_events.generate_travel_event()
	event.resolve()
	display_result(travel_event_details, event.get_description())
	step_completed.emit()

func process_patron_check() -> void:
	var available_patrons = patron_job_manager.get_available_patrons()
	for patron in available_patrons:
		display_result(patrons_list, patron.get_description())
	step_completed.emit()

func process_mission_start() -> void:
	if game_state.current_mission:
		game_state_manager.transition_to_state(GlobalEnums.CampaignPhase.MISSION)
		display_result(mission_details, "Starting mission: " + game_state.current_mission.name)
	else:
		display_result(mission_details, "No mission selected.")
	phase_completed.emit()

# UI Update Functions
func setup_current_step() -> void:
	update_tab_visibility()
	update_button_states()

func update_tab_visibility() -> void:
	tab_container.current_tab = current_step

func update_button_states() -> void:
	back_button.disabled = current_step == TravelStep.UPKEEP

func display_result(parent: Control, result: String) -> void:
	var label = Label.new()
	label.text = result
	label.autowrap = true
	parent.add_child(label)

func log_event(event: String) -> void:
	game_state.last_mission_results += event + "\n"
	log_book.text += event + "\n"
	log_book.scroll_vertical = INF

# Signal Handlers
func _on_next_button_pressed() -> void:
	process_step()

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Scene Container/CampaignDashboard.tscn")

func _on_world_step_completed() -> void:
	if current_step < TravelStep.size() - 1:
		current_step += 1
		setup_current_step()
	else:
		_on_phase_completed()

func _on_phase_completed() -> void:
	log_event("Travel Phase completed")
	game_state_manager.advance_phase()

func _on_game_over() -> void:
	log_event("Game Over")
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

func _on_ui_update_requested() -> void:
	setup_current_step()

func _on_mission_selection_requested() -> void:
	var mission_selection = preload("res://Scenes/campaign/MissionSelectionPanel.tscn").instantiate()
	mission_selection.initialize(game_state)
	add_child(mission_selection)
	mission_selection.mission_selected.connect(_on_mission_selected)

func _on_mission_selected(mission: Mission) -> void:
	game_state.current_mission = mission
	log_event("Selected mission: " + mission.name)
	process_step()
