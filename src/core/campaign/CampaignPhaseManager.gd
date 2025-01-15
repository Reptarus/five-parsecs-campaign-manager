class_name CampaignPhaseManager
extends RefCounted

signal phase_changed(new_phase: int)
signal phase_completed
signal event_triggered(event_data: Dictionary)
signal phase_started(phase: int)

const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsGameState := preload("res://src/core/state/GameState.gd")
const GameCampaignManager := preload("res://src/core/campaign/GameCampaignManager.gd")

var game_state: FiveParsecsGameState
var campaign_manager: GameCampaignManager
var phase_state: PhaseState
var phase_actions_completed: Dictionary = {}
var current_phase: int = GameEnums.CampaignPhase.NONE
var previous_phase: int = GameEnums.CampaignPhase.NONE

class PhaseState:
	var current_phase: int = GameEnums.CampaignPhase.NONE
	var next_phase: int = GameEnums.CampaignPhase.NONE
	var phase_actions: Dictionary = {}
	var phase_requirements: Dictionary = {}
	var phase_resources: Dictionary = {}
	
	func _init() -> void:
		reset()
	
	func reset() -> void:
		current_phase = GameEnums.CampaignPhase.NONE
		next_phase = GameEnums.CampaignPhase.NONE
		phase_actions.clear()
		phase_requirements.clear()
		phase_resources.clear()

func _init() -> void:
	phase_state = PhaseState.new()

func _can_transition_to_phase(new_phase: int) -> bool:
	match new_phase:
		GameEnums.CampaignPhase.SETUP:
			return current_phase == GameEnums.CampaignPhase.NONE
		GameEnums.CampaignPhase.UPKEEP:
			return current_phase in [GameEnums.CampaignPhase.SETUP, GameEnums.CampaignPhase.END]
		GameEnums.CampaignPhase.STORY:
			return current_phase == GameEnums.CampaignPhase.UPKEEP
		GameEnums.CampaignPhase.CAMPAIGN:
			return current_phase == GameEnums.CampaignPhase.STORY
		GameEnums.CampaignPhase.BATTLE_SETUP:
			return current_phase == GameEnums.CampaignPhase.CAMPAIGN
		GameEnums.CampaignPhase.BATTLE_RESOLUTION:
			return current_phase == GameEnums.CampaignPhase.BATTLE_SETUP
		GameEnums.CampaignPhase.ADVANCEMENT:
			return current_phase == GameEnums.CampaignPhase.BATTLE_RESOLUTION
		GameEnums.CampaignPhase.TRADE:
			return current_phase == GameEnums.CampaignPhase.ADVANCEMENT
		GameEnums.CampaignPhase.END:
			return current_phase == GameEnums.CampaignPhase.TRADE
		_:
			return false

func _store_phase_state() -> void:
	var state = PhaseState.new()
	state.current_phase = current_phase
	state.next_phase = _calculate_next_phase(current_phase)
	phase_state = state

func setup(state: FiveParsecsGameState, manager: GameCampaignManager) -> void:
	game_state = state
	campaign_manager = manager
	reset_phase_actions()
	_initialize_phase_state()

func _on_campaign_phase_changed(old_phase: int, new_phase: int) -> void:
	start_phase(new_phase)

func reset_phase_actions() -> void:
	phase_actions_completed = {
		"upkeep_paid": false,
		"tasks_assigned": false,
		"world_events_resolved": false,
		"travel_resolved": false,
		"location_checked": false,
		"patron_selected": false,
		"deployment_ready": false,
		"battle_completed": false,
		"rewards_calculated": false,
		"post_battle_resolved": false,
		"resources_updated": false,
		"management_completed": false,
		"upkeep_completed": false,
		"story_resolved": false,
		"campaign_actions_completed": false,
		"resolution_completed": false
	}

func start_phase(new_phase: int) -> bool:
	if not _can_transition_to_phase(new_phase):
		return false
	
	# Store current phase state before transition
	if current_phase != GameEnums.CampaignPhase.NONE:
		_store_phase_state()
	
	previous_phase = current_phase
	current_phase = new_phase
	
	phase_changed.emit(previous_phase, current_phase)
	phase_started.emit(current_phase)
	
	return true

func _is_valid_phase(phase: int) -> bool:
	return phase in GameEnums.CampaignPhase.values()

func _calculate_next_phase(current: int) -> int:
	match current:
		GameEnums.CampaignPhase.NONE:
			return GameEnums.CampaignPhase.SETUP
		GameEnums.CampaignPhase.SETUP:
			return GameEnums.CampaignPhase.UPKEEP
		GameEnums.CampaignPhase.UPKEEP:
			return GameEnums.CampaignPhase.STORY
		GameEnums.CampaignPhase.STORY:
			return GameEnums.CampaignPhase.CAMPAIGN
		GameEnums.CampaignPhase.CAMPAIGN:
			return GameEnums.CampaignPhase.BATTLE_SETUP
		GameEnums.CampaignPhase.BATTLE_SETUP:
			return GameEnums.CampaignPhase.BATTLE_RESOLUTION
		GameEnums.CampaignPhase.BATTLE_RESOLUTION:
			return GameEnums.CampaignPhase.ADVANCEMENT
		GameEnums.CampaignPhase.ADVANCEMENT:
			return GameEnums.CampaignPhase.TRADE
		GameEnums.CampaignPhase.TRADE:
			return GameEnums.CampaignPhase.END
		GameEnums.CampaignPhase.END:
			return GameEnums.CampaignPhase.UPKEEP
		_:
			return GameEnums.CampaignPhase.NONE

func _initialize_phase_state() -> void:
	phase_state.reset()
	
	match phase_state.current_phase:
		GameEnums.CampaignPhase.SETUP:
			_setup_phase_requirements()
		GameEnums.CampaignPhase.UPKEEP:
			_upkeep_phase_requirements()
		GameEnums.CampaignPhase.STORY:
			_story_phase_requirements()
		GameEnums.CampaignPhase.CAMPAIGN:
			_campaign_phase_requirements()
		GameEnums.CampaignPhase.BATTLE_SETUP:
			_battle_setup_requirements()
		GameEnums.CampaignPhase.BATTLE_RESOLUTION:
			_battle_resolution_requirements()
		GameEnums.CampaignPhase.ADVANCEMENT:
			_advancement_phase_requirements()
		GameEnums.CampaignPhase.TRADE:
			_trade_phase_requirements()
		GameEnums.CampaignPhase.END:
			_end_phase_requirements()

func _execute_phase_actions() -> void:
	match phase_state.current_phase:
		GameEnums.CampaignPhase.SETUP:
			_execute_setup_phase()
		GameEnums.CampaignPhase.UPKEEP:
			_execute_upkeep_phase()
		GameEnums.CampaignPhase.STORY:
			_execute_story_phase()
		GameEnums.CampaignPhase.CAMPAIGN:
			_execute_campaign_phase()
		GameEnums.CampaignPhase.BATTLE_SETUP:
			_execute_battle_setup()
		GameEnums.CampaignPhase.BATTLE_RESOLUTION:
			_execute_battle_resolution()
		GameEnums.CampaignPhase.ADVANCEMENT:
			_execute_advancement_phase()
		GameEnums.CampaignPhase.TRADE:
			_execute_trade_phase()
		GameEnums.CampaignPhase.END:
			_execute_end_phase()

# Phase Requirements Setup
func _setup_phase_requirements() -> void:
	phase_state.phase_requirements = {
		"crew_created": false,
		"resources_allocated": false,
		"tutorial_completed": false
	}

func _upkeep_phase_requirements() -> void:
	phase_state.phase_requirements = {
		"supplies_checked": false,
		"maintenance_paid": false,
		"events_processed": false
	}

func _story_phase_requirements() -> void:
	phase_state.phase_requirements = {
		"story_events_checked": false,
		"quest_progress_updated": false
	}

func _campaign_phase_requirements() -> void:
	phase_state.phase_requirements = {
		"missions_generated": false,
		"location_updated": false,
		"events_processed": false
	}

func _battle_setup_requirements() -> void:
	phase_state.phase_requirements = {
		"battlefield_generated": false,
		"deployment_complete": false,
		"objectives_set": false
	}

func _battle_resolution_requirements() -> void:
	phase_state.phase_requirements = {
		"combat_resolved": false,
		"rewards_calculated": false,
		"casualties_processed": false
	}

func _advancement_phase_requirements() -> void:
	phase_state.phase_requirements = {
		"experience_awarded": false,
		"skills_updated": false,
		"equipment_maintained": false
	}

func _trade_phase_requirements() -> void:
	phase_state.phase_requirements = {
		"market_generated": false,
		"trades_completed": false,
		"inventory_updated": false
	}

func _end_phase_requirements() -> void:
	phase_state.phase_requirements = {
		"progress_saved": false,
		"state_cleaned": false
	}

# Phase Execution
func _execute_setup_phase() -> void:
	event_triggered.emit({"type": "PHASE_STARTED", "phase": "SETUP"})
	
	# Initialize crew creation
	if not phase_state.phase_requirements["crew_created"]:
		event_triggered.emit({
			"type": "CREW_CREATION_STARTED",
			"data": {
				"max_size": game_state.max_crew_size,
				"starting_credits": game_state.credits
			}
		})
	
	# Initialize resource allocation
	if not phase_state.phase_requirements["resources_allocated"]:
		event_triggered.emit({
			"type": "RESOURCE_ALLOCATION_STARTED",
			"data": {
				"available_credits": game_state.credits,
				"available_supplies": game_state.supplies
			}
		})
	
	# Start tutorial if needed
	if not phase_state.phase_requirements["tutorial_completed"] and game_state.is_tutorial_enabled:
		event_triggered.emit({
			"type": "TUTORIAL_STARTED",
			"data": {
				"tutorial_type": "CAMPAIGN_SETUP"
			}
		})

func _execute_upkeep_phase() -> void:
	event_triggered.emit({"type": "PHASE_STARTED", "phase": "UPKEEP"})
	
	# Check supplies
	if not phase_state.phase_requirements["supplies_checked"]:
		var supply_cost = _calculate_supply_cost()
		game_state.modify_resource(GameEnums.ResourceType.SUPPLIES, -supply_cost)
		
		if game_state.supplies <= 0:
			event_triggered.emit({
				"type": "CRITICAL_SUPPLY_SHORTAGE",
				"data": {
					"current_supplies": 0,
					"required_supplies": supply_cost
				}
			})
	
	# Pay maintenance
	if not phase_state.phase_requirements["maintenance_paid"]:
		var maintenance_cost = _calculate_maintenance_cost()
		game_state.modify_resource(GameEnums.ResourceType.CREDITS, -maintenance_cost)
		
		if game_state.credits < 0:
			event_triggered.emit({
				"type": "MAINTENANCE_PAYMENT_FAILED",
				"data": {
					"current_credits": game_state.credits,
					"required_credits": maintenance_cost
				}
			})
	
	# Process events
	if not phase_state.phase_requirements["events_processed"]:
		_process_upkeep_events()

func _execute_story_phase() -> void:
	event_triggered.emit({"type": "PHASE_STARTED", "phase": "STORY"})
	
	# Check for story events
	if not phase_state.phase_requirements["story_events_checked"]:
		var story_events = _get_available_story_events()
		if not story_events.is_empty():
			event_triggered.emit({
				"type": "STORY_EVENTS_AVAILABLE",
				"data": {
					"events": story_events
				}
			})
	
	# Update quest progress
	if not phase_state.phase_requirements["quest_progress_updated"]:
		_update_quest_progress()

func _execute_campaign_phase() -> void:
	event_triggered.emit({"type": "PHASE_STARTED", "phase": "CAMPAIGN"})
	
	# Generate missions
	if not phase_state.phase_requirements["missions_generated"]:
		var available_missions = _generate_missions()
		event_triggered.emit({
			"type": "MISSIONS_GENERATED",
			"data": {
				"missions": available_missions
			}
		})
	
	# Update location
	if not phase_state.phase_requirements["location_updated"]:
		var new_location = _determine_next_location()
		game_state.current_location = new_location
		event_triggered.emit({
			"type": "LOCATION_CHANGED",
			"data": {
				"location": new_location
			}
		})
	
	# Process campaign events
	if not phase_state.phase_requirements["events_processed"]:
		_process_campaign_events()

func _execute_battle_setup() -> void:
	event_triggered.emit({"type": "PHASE_STARTED", "phase": "BATTLE_SETUP"})
	
	# Generate battlefield
	if not phase_state.phase_requirements["battlefield_generated"]:
		var battlefield_data = _generate_battlefield()
		event_triggered.emit({
			"type": "BATTLEFIELD_GENERATED",
			"data": battlefield_data
		})
	
	# Setup deployment
	if not phase_state.phase_requirements["deployment_complete"]:
		var deployment_zones = _setup_deployment_zones()
		event_triggered.emit({
			"type": "DEPLOYMENT_READY",
			"data": {
				"zones": deployment_zones
			}
		})
	
	# Set objectives
	if not phase_state.phase_requirements["objectives_set"]:
		var objectives = _setup_battle_objectives()
		event_triggered.emit({
			"type": "OBJECTIVES_SET",
			"data": {
				"objectives": objectives
			}
		})

func _execute_battle_resolution() -> void:
	event_triggered.emit({"type": "PHASE_STARTED", "phase": "BATTLE_RESOLUTION"})
	
	# Resolve combat
	if not phase_state.phase_requirements["combat_resolved"]:
		var combat_results = _resolve_combat()
		event_triggered.emit({
			"type": "COMBAT_RESOLVED",
			"data": combat_results
		})
	
	# Calculate rewards
	if not phase_state.phase_requirements["rewards_calculated"]:
		var rewards = _calculate_battle_rewards()
		event_triggered.emit({
			"type": "REWARDS_CALCULATED",
			"data": rewards
		})
	
	# Process casualties
	if not phase_state.phase_requirements["casualties_processed"]:
		var casualties = _process_battle_casualties()
		event_triggered.emit({
			"type": "CASUALTIES_PROCESSED",
			"data": casualties
		})

func _execute_advancement_phase() -> void:
	event_triggered.emit({"type": "PHASE_STARTED", "phase": "ADVANCEMENT"})
	
	# Award experience
	if not phase_state.phase_requirements["experience_awarded"]:
		var experience_data = _award_experience()
		event_triggered.emit({
			"type": "EXPERIENCE_AWARDED",
			"data": experience_data
		})
	
	# Update skills
	if not phase_state.phase_requirements["skills_updated"]:
		var skill_updates = _process_skill_updates()
		event_triggered.emit({
			"type": "SKILLS_UPDATED",
			"data": skill_updates
		})
	
	# Maintain equipment
	if not phase_state.phase_requirements["equipment_maintained"]:
		var maintenance_results = _maintain_equipment()
		event_triggered.emit({
			"type": "EQUIPMENT_MAINTAINED",
			"data": maintenance_results
		})

func _execute_trade_phase() -> void:
	event_triggered.emit({"type": "PHASE_STARTED", "phase": "TRADE"})
	
	# Generate market
	if not phase_state.phase_requirements["market_generated"]:
		var market_data = _generate_market()
		event_triggered.emit({
			"type": "MARKET_GENERATED",
			"data": market_data
		})
	
	# Process trades
	if not phase_state.phase_requirements["trades_completed"]:
		event_triggered.emit({
			"type": "TRADE_STARTED",
			"data": {
				"available_credits": game_state.credits
			}
		})
	
	# Update inventory
	if not phase_state.phase_requirements["inventory_updated"]:
		_update_inventory()

func _execute_end_phase() -> void:
	event_triggered.emit({"type": "PHASE_STARTED", "phase": "END"})
	
	# Save progress
	if not phase_state.phase_requirements["progress_saved"]:
		_save_campaign_progress()
	
	# Clean up state
	if not phase_state.phase_requirements["state_cleaned"]:
		_cleanup_phase_state()

# Helper functions for phase execution
func _calculate_supply_cost() -> int:
	var base_cost: int = game_state.crew_members.size()
	var modifier: float = 1.0
	
	# Apply modifiers based on game state
	if game_state.current_location:
		match game_state.current_location.type:
			GameEnums.LocationType.FRONTIER_WORLD:
				modifier *= 1.2
			GameEnums.LocationType.TRADE_CENTER:
				modifier *= 0.8
	
	return int(base_cost * modifier)

func _calculate_maintenance_cost() -> int:
	var base_cost: int = 0
	
	# Calculate equipment maintenance
	for equipment in game_state.crew_equipment:
		base_cost += equipment.get("maintenance_cost", 0)
	
	# Add ship maintenance if applicable
	if game_state.has_ship:
		base_cost += game_state.ship_maintenance_cost
	
	return base_cost

func _process_upkeep_events() -> void:
	var events = []
	
	# Check for random events
	if randf() < 0.3: # 30% chance for random event
		events.append(_generate_random_event())
	
	# Check for location-specific events
	if game_state.current_location:
		var location_events = _get_location_events()
		events.append_array(location_events)
	
	# Emit events
	for event in events:
		event_triggered.emit({
			"type": "UPKEEP_EVENT",
			"data": event
		})

func _get_location_events() -> Array:
	var events = []
	
	if game_state.current_location and campaign_manager.has_method("get_location_events"):
		events = campaign_manager.get_location_events(game_state.current_location)
	
	return events

func _get_available_story_events() -> Array:
	var available_events = []
	
	# Get story events from campaign manager
	if campaign_manager.has_method("get_story_events"):
		available_events = campaign_manager.get_story_events()
	
	return available_events

func _update_quest_progress() -> void:
	if campaign_manager.has_method("update_quest_progress"):
		campaign_manager.update_quest_progress()

func _generate_missions() -> Array:
	var missions = []
	
	if campaign_manager.has_method("generate_available_missions"):
		missions = campaign_manager.generate_available_missions()
	
	return missions

func _determine_next_location() -> Dictionary:
	if campaign_manager.has_method("get_next_location"):
		return campaign_manager.get_next_location()
	return {}

func _process_campaign_events() -> void:
	if campaign_manager.has_method("process_campaign_events"):
		campaign_manager.process_campaign_events()

func _generate_battlefield() -> Dictionary:
	if campaign_manager.has_method("generate_battlefield"):
		return campaign_manager.generate_battlefield()
	return {}

func _setup_deployment_zones() -> Array:
	if campaign_manager.has_method("get_deployment_zones"):
		return campaign_manager.get_deployment_zones()
	return []

func _setup_battle_objectives() -> Array:
	if campaign_manager.has_method("get_battle_objectives"):
		return campaign_manager.get_battle_objectives()
	return []

func _resolve_combat() -> Dictionary:
	if campaign_manager.has_method("resolve_combat"):
		return campaign_manager.resolve_combat()
	return {}

func _calculate_battle_rewards() -> Dictionary:
	if campaign_manager.has_method("calculate_battle_rewards"):
		return campaign_manager.calculate_battle_rewards()
	return {}

func _process_battle_casualties() -> Dictionary:
	if campaign_manager.has_method("process_battle_casualties"):
		return campaign_manager.process_battle_casualties()
	return {}

func _award_experience() -> Dictionary:
	if campaign_manager.has_method("award_experience"):
		return campaign_manager.award_experience()
	return {}

func _process_skill_updates() -> Dictionary:
	if campaign_manager.has_method("process_skill_updates"):
		return campaign_manager.process_skill_updates()
	return {}

func _maintain_equipment() -> Dictionary:
	if campaign_manager.has_method("maintain_equipment"):
		return campaign_manager.maintain_equipment()
	return {}

func _generate_market() -> Dictionary:
	if campaign_manager.has_method("generate_market"):
		return campaign_manager.generate_market()
	return {}

func _update_inventory() -> void:
	if campaign_manager.has_method("update_inventory"):
		campaign_manager.update_inventory()

func _save_campaign_progress() -> void:
	if campaign_manager.has_method("save_campaign"):
		campaign_manager.save_campaign()

func _cleanup_phase_state() -> void:
	phase_state.reset()

func _generate_random_event() -> Dictionary:
	# Implementation will be added when event system is complete
	return {}

# Phase Completion Checks
func check_phase_completion() -> bool:
	var requirements := phase_state.phase_requirements
	
	for requirement in requirements:
		if not requirements[requirement]:
			return false
	
	phase_completed.emit()
	return true

func complete_requirement(requirement: String) -> void:
	if requirement in phase_state.phase_requirements:
		phase_state.phase_requirements[requirement] = true
		check_phase_completion()