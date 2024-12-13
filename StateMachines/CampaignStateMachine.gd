class_name CampaignStateMachine
extends Node

const GlobalEnums = preload("res://Resources/Core/Systems/GlobalEnums.gd")

signal state_changed(new_state: GlobalEnums.CampaignPhase)
signal turn_completed
signal event_generated(event: Dictionary)

var game_state: GameState
var game_state_manager: GameStateManager
var crew_system: CrewSystem

# Campaign state tracking
var current_phase: GlobalEnums.CampaignPhase = GlobalEnums.CampaignPhase.UPKEEP
var current_turn: int = 1

func initialize(gsm: GameStateManager) -> void:
	game_state_manager = gsm
	game_state = gsm.game_state
	_initialize_systems()

func _initialize_systems() -> void:
	crew_system = CrewSystem.new(game_state)

func transition_to(new_phase: GlobalEnums.CampaignPhase) -> void:
	current_phase = new_phase
	
	match new_phase:
		GlobalEnums.CampaignPhase.UPKEEP:
			handle_upkeep_phase()
		GlobalEnums.CampaignPhase.WORLD_STEP:
			handle_world_phase()
		GlobalEnums.CampaignPhase.TRAVEL:
			handle_travel_phase()
		GlobalEnums.CampaignPhase.PATRONS:
			handle_patron_phase()
		GlobalEnums.CampaignPhase.BATTLE:
			handle_battle_phase()
		GlobalEnums.CampaignPhase.POST_BATTLE:
			handle_post_battle_phase()
		GlobalEnums.CampaignPhase.MANAGEMENT:
			handle_management_phase()
	
	state_changed.emit(new_phase)

func handle_upkeep_phase() -> void:
	# Process crew upkeep costs
	var upkeep_cost = crew_system.calculate_upkeep()
	if not game_state.remove_credits(upkeep_cost):
		crew_system.handle_failed_upkeep()
	
	# Process crew tasks
	crew_system.process_task_results()
	
	# Check for events
	if randf() < game_state.difficulty_settings.event_frequency:
		var event = _generate_campaign_event()
		event_generated.emit(event)

func handle_world_phase() -> void:
	game_state.world_manager.process_world_events()
	game_state.world_manager.update_world_resources()

func handle_travel_phase() -> void:
	# Handle travel between locations
	if game_state.current_location:
		game_state.current_location.on_departure()
	
	# Generate new location options
	game_state.world_manager.generate_location_options()

func handle_patron_phase() -> void:
	# Process patron jobs
	game_state.job_manager.update_available_jobs()
	
	# Update patron relationships
	game_state.faction_manager.update_faction_standings()

func handle_battle_phase() -> void:
	# Prepare for battle
	game_state.combat_manager.prepare_battle()
	game_state_manager.transition_to_state(GlobalEnums.CampaignPhase.BATTLE)

func handle_post_battle_phase() -> void:
	# Process battle results
	game_state.combat_manager.process_battle_results()
	
	# Handle casualties and rewards
	crew_system.handle_battle_aftermath()
	
	# Update story progress if needed
	if game_state.story_track:
		game_state.story_track.update_progress()

func handle_management_phase() -> void:
	# Process crew advancement
	for character in crew_system.get_available_members():
		game_state.character_manager.check_advancement(character)
	
	# Handle equipment maintenance
	game_state.equipment_manager.process_maintenance()

func end_turn() -> void:
	current_turn += 1
	turn_completed.emit()

func _generate_campaign_event() -> Dictionary:
	# Implementation of event generation
	return {}
