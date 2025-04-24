@tool
extends Node

const GameEnums = preload("res://src/core/enums/GameEnums.gd")
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")
const FiveParsecsCampaign = preload("res://src/game/campaign/FiveParsecsCampaign.gd")
const ValidationManager = preload("res://src/core/systems/ValidationManager.gd")

# Import the enums directly for cleaner code
const FiveParcsecsCampaignPhase = GameEnums.FiveParcsecsCampaignPhase
const CampaignSubPhase = GameEnums.CampaignSubPhase

signal phase_changed(old_phase: FiveParcsecsCampaignPhase, new_phase: FiveParcsecsCampaignPhase)
signal sub_phase_changed(old_sub_phase: CampaignSubPhase, new_sub_phase: CampaignSubPhase)
signal phase_completed
signal phase_started(phase: FiveParcsecsCampaignPhase)
signal phase_action_completed(action: String)
signal phase_event_triggered(event: Dictionary)
signal phase_error(error_message: String, is_critical: bool)

var game_state: FiveParsecsGameState
var current_phase: FiveParcsecsCampaignPhase = FiveParcsecsCampaignPhase.NONE
var previous_phase: FiveParcsecsCampaignPhase = FiveParcsecsCampaignPhase.NONE
var current_sub_phase: CampaignSubPhase = CampaignSubPhase.NONE
var previous_sub_phase: CampaignSubPhase = CampaignSubPhase.NONE

# Phase tracking
var phase_actions_completed: Dictionary = {}
var phase_requirements: Dictionary = {}
var phase_resources: Dictionary = {}
var phase_events: Array = []
var phase_errors: Array = []
var validator: ValidationManager

func _ready() -> void:
	reset_phase_tracking()

func setup(state: FiveParsecsGameState) -> void:
	game_state = state
	validator = ValidationManager.new(game_state)
	reset_phase_tracking()
	
	# Connect to campaign signals if available
	if game_state and game_state.current_campaign:
		_connect_to_campaign(game_state.current_campaign)

func _connect_to_campaign(campaign) -> void:
	# Connect relevant campaign signals for tracking state changes
	# First check if the campaign has the required signals
	if not (campaign is Resource):
		push_error("Campaign must be a Resource")
		return
		
	if not campaign.has_signal("campaign_state_changed") or not campaign.has_signal("resource_changed") or not campaign.has_signal("world_changed"):
		push_error("Campaign does not have required signals")
		return
		
	if campaign.is_connected("campaign_state_changed", Callable(self, "_on_campaign_state_changed")):
		campaign.disconnect("campaign_state_changed", Callable(self, "_on_campaign_state_changed"))
	
	campaign.connect("campaign_state_changed", Callable(self, "_on_campaign_state_changed"))
	campaign.connect("resource_changed", Callable(self, "_on_campaign_resource_changed"))
	campaign.connect("world_changed", Callable(self, "_on_campaign_world_changed"))

func _on_campaign_state_changed(_property: String) -> void:
	# Validate current state after a change
	var validation_result = validator.validate_campaign()
	if not validation_result.valid:
		var error_message = validation_result.errors.join(", ")
		phase_error.emit(error_message, validation_result.errors.size() > 1)
		phase_errors.append(error_message)

func _on_campaign_resource_changed(resource_type: String, amount: int) -> void:
	# Update phase resources
	phase_resources[resource_type] = amount
	
	# Check if resource affects any phase requirements
	_check_resource_requirements(resource_type, amount)

func _on_campaign_world_changed(world_data: Dictionary) -> void:
	# Update location information and potentially trigger events
	if current_phase == FiveParcsecsCampaignPhase.PRE_MISSION:
		phase_events.append({
			"type": "world_arrival",
			"world": world_data
		})
		phase_event_triggered.emit(phase_events[-1])
		
		# Mark location checked action as completed
		complete_phase_action("location_checked")
		
		# Start appropriate sub-phase based on current travel status
		if current_sub_phase == CampaignSubPhase.TRAVEL:
			start_sub_phase(CampaignSubPhase.WORLD_ARRIVAL)

func reset_phase_tracking() -> void:
	phase_actions_completed = {
		# Upkeep Phase
		"upkeep_paid": false,
		"crew_maintained": false,
		"ship_maintained": false,
		
		# Story Phase
		"events_resolved": false,
		"story_progressed": false,
		
		# Campaign Phase - Travel Steps
		"travel_destination_selected": false,
		"travel_completed": false,
		
		# Campaign Phase - World Arrival
		"location_checked": false,
		"local_events_resolved": false,
		"patron_contacted": false,
		
		# Campaign Phase - World Steps
		"mission_selected": false,
		"mission_prepared": false,
		
		# Battle Setup
		"battlefield_generated": false,
		"enemy_forces_generated": false,
		"deployment_ready": false,
		
		# Battle Resolution
		"battle_completed": false,
		"casualties_resolved": false,
		
		# Post-Battle
		"rewards_calculated": false,
		"loot_collected": false,
		"resources_updated": false,
		
		# Advancement
		"experience_gained": false,
		"skills_improved": false,
		"advancement_completed": false,
		
		# Trade
		"trade_completed": false,
		"equipment_updated": false,
		
		# End
		"turn_completed": false
	}
	
	phase_requirements.clear()
	phase_resources.clear()
	phase_events.clear()
	phase_errors.clear()
	current_phase = FiveParcsecsCampaignPhase.NONE
	previous_phase = FiveParcsecsCampaignPhase.NONE
	current_sub_phase = CampaignSubPhase.NONE
	previous_sub_phase = CampaignSubPhase.NONE

func start_phase(new_phase: FiveParcsecsCampaignPhase) -> bool:
	if not _can_transition_to_phase(new_phase):
		phase_error.emit("Cannot transition from phase " + str(current_phase) + " to " + str(new_phase), false)
		return false
	
	previous_phase = current_phase
	current_phase = new_phase
	
	# Reset sub-phase when changing main phases
	previous_sub_phase = CampaignSubPhase.NONE
	current_sub_phase = CampaignSubPhase.NONE
	
	# Initialize phase requirements
	_setup_phase_requirements(current_phase)
	
	# Emit signals
	phase_changed.emit(previous_phase, current_phase)
	phase_started.emit(current_phase)
	
	# Start phase execution
	_execute_phase_start()
	
	return true

func start_sub_phase(new_sub_phase: CampaignSubPhase) -> bool:
	if not _can_transition_to_sub_phase(new_sub_phase):
		phase_error.emit("Cannot transition to sub-phase " + str(new_sub_phase) + " from current state", false)
		return false
		
	previous_sub_phase = current_sub_phase
	current_sub_phase = new_sub_phase
	
	# Emit sub-phase change signal
	sub_phase_changed.emit(previous_sub_phase, current_sub_phase)
	
	# Execute sub-phase specific logic
	_execute_sub_phase_start()
	
	return true

func complete_phase_action(action: String) -> void:
	if action in phase_actions_completed:
		phase_actions_completed[action] = true
		phase_action_completed.emit(action)
		
		# Check if phase or sub-phase is complete
		if _are_current_sub_phase_requirements_met():
			_complete_current_sub_phase()
			
		if _are_phase_requirements_met():
			phase_completed.emit()

func _can_transition_to_phase(new_phase: FiveParcsecsCampaignPhase) -> bool:
	match new_phase:
		FiveParcsecsCampaignPhase.SETUP:
			return current_phase == FiveParcsecsCampaignPhase.NONE
		FiveParcsecsCampaignPhase.UPKEEP:
			return current_phase in [FiveParcsecsCampaignPhase.SETUP, FiveParcsecsCampaignPhase.RETIREMENT]
		FiveParcsecsCampaignPhase.STORY:
			return current_phase == FiveParcsecsCampaignPhase.UPKEEP
		FiveParcsecsCampaignPhase.PRE_MISSION:
			return current_phase == FiveParcsecsCampaignPhase.STORY
		FiveParcsecsCampaignPhase.BATTLE_SETUP:
			return current_phase == FiveParcsecsCampaignPhase.PRE_MISSION
		FiveParcsecsCampaignPhase.BATTLE_RESOLUTION:
			return current_phase == FiveParcsecsCampaignPhase.BATTLE_SETUP
		FiveParcsecsCampaignPhase.ADVANCEMENT:
			return current_phase == FiveParcsecsCampaignPhase.BATTLE_RESOLUTION
		FiveParcsecsCampaignPhase.TRADING:
			return current_phase == FiveParcsecsCampaignPhase.ADVANCEMENT
		FiveParcsecsCampaignPhase.RETIREMENT:
			return current_phase == FiveParcsecsCampaignPhase.TRADING
		_:
			return false

func _can_transition_to_sub_phase(new_sub_phase: CampaignSubPhase) -> bool:
	# First, check if we're in a phase that supports sub-phases
	if current_phase != FiveParcsecsCampaignPhase.PRE_MISSION:
		return false
		
	match new_sub_phase:
		CampaignSubPhase.TRAVEL:
			return current_sub_phase == CampaignSubPhase.NONE
		CampaignSubPhase.WORLD_ARRIVAL:
			return current_sub_phase == CampaignSubPhase.TRAVEL
		CampaignSubPhase.WORLD_EVENTS:
			return current_sub_phase == CampaignSubPhase.WORLD_ARRIVAL
		CampaignSubPhase.PATRON_CONTACT:
			return current_sub_phase == CampaignSubPhase.WORLD_EVENTS
		CampaignSubPhase.MISSION_SELECTION:
			return current_sub_phase == CampaignSubPhase.PATRON_CONTACT
		_:
			return false

func _execute_phase_start() -> void:
	# Execute phase-specific initialization
	match current_phase:
		FiveParcsecsCampaignPhase.SETUP:
			_execute_setup_phase_start()
		FiveParcsecsCampaignPhase.UPKEEP:
			_execute_upkeep_phase_start()
		FiveParcsecsCampaignPhase.STORY:
			_execute_story_phase_start()
		FiveParcsecsCampaignPhase.PRE_MISSION:
			_execute_campaign_phase_start()
		FiveParcsecsCampaignPhase.BATTLE_SETUP:
			_execute_battle_setup_phase_start()
		FiveParcsecsCampaignPhase.BATTLE_RESOLUTION:
			_execute_battle_resolution_phase_start()
		FiveParcsecsCampaignPhase.ADVANCEMENT:
			_execute_advancement_phase_start()
		FiveParcsecsCampaignPhase.TRADING:
			_execute_trade_phase_start()
		FiveParcsecsCampaignPhase.RETIREMENT:
			_execute_end_phase_start()

func _execute_sub_phase_start() -> void:
	# Only relevant for Campaign Phase
	if current_phase != FiveParcsecsCampaignPhase.PRE_MISSION:
		return
		
	match current_sub_phase:
		CampaignSubPhase.TRAVEL:
			# Initialize travel destination selection
			phase_events.append({
				"type": "travel_options",
				"options": _get_travel_options()
			})
			phase_event_triggered.emit(phase_events[-1])
		CampaignSubPhase.WORLD_ARRIVAL:
			# Generate world details and arrival events
			phase_events.append({
				"type": "world_arrival_events",
				"events": _generate_world_arrival_events()
			})
			phase_event_triggered.emit(phase_events[-1])
		CampaignSubPhase.WORLD_EVENTS:
			# Generate local events
			phase_events.append({
				"type": "local_events",
				"events": _generate_local_events()
			})
			phase_event_triggered.emit(phase_events[-1])
		CampaignSubPhase.PATRON_CONTACT:
			# Check for patrons
			phase_events.append({
				"type": "patron_availability",
				"patrons": _check_patron_availability()
			})
			phase_event_triggered.emit(phase_events[-1])
		CampaignSubPhase.MISSION_SELECTION:
			# Generate available missions
			phase_events.append({
				"type": "available_missions",
				"missions": _generate_available_missions()
			})
			phase_event_triggered.emit(phase_events[-1])

func _execute_setup_phase_start() -> void:
	# Initial campaign setup
	if not game_state.current_campaign:
		phase_error.emit("No active campaign during setup phase", true)
		return

func _execute_upkeep_phase_start() -> void:
	# Calculate upkeep costs and resources required
	var upkeep_costs = _calculate_upkeep_costs()
	phase_resources["upkeep_costs"] = upkeep_costs
	phase_events.append({
		"type": "upkeep_required",
		"costs": upkeep_costs
	})
	phase_event_triggered.emit(phase_events[-1])

func _execute_story_phase_start() -> void:
	# Generate story events
	var story_events = _generate_story_events()
	phase_events.append({
		"type": "story_events",
		"events": story_events
	})
	phase_event_triggered.emit(phase_events[-1])

func _execute_campaign_phase_start() -> void:
	# Start with Travel sub-phase
	start_sub_phase(CampaignSubPhase.TRAVEL)

func _execute_battle_setup_phase_start() -> void:
	# Generate battlefield
	var battlefield = _generate_battlefield()
	phase_events.append({
		"type": "battlefield_generated",
		"battlefield": battlefield
	})
	phase_event_triggered.emit(phase_events[-1])
	
	# Generate enemy forces
	var enemy_forces = _generate_enemy_forces()
	phase_events.append({
		"type": "enemy_forces_generated",
		"enemies": enemy_forces
	})
	phase_event_triggered.emit(phase_events[-1])

func _execute_battle_resolution_phase_start() -> void:
	# Initialize battle state
	phase_events.append({
		"type": "battle_started",
		"battle_data": _get_current_battle_data()
	})
	phase_event_triggered.emit(phase_events[-1])

func _execute_advancement_phase_start() -> void:
	# Calculate experience earned
	var experience_earned = _calculate_experience_earned()
	phase_resources["experience_earned"] = experience_earned
	phase_events.append({
		"type": "experience_earned",
		"experience": experience_earned
	})
	phase_event_triggered.emit(phase_events[-1])

func _execute_trade_phase_start() -> void:
	# Generate trade options
	var trade_options = _generate_trade_options()
	phase_events.append({
		"type": "trade_options",
		"options": trade_options
	})
	phase_event_triggered.emit(phase_events[-1])

func _execute_end_phase_start() -> void:
	# Generate turn summary
	var turn_summary = _generate_turn_summary()
	phase_events.append({
		"type": "turn_summary",
		"summary": turn_summary
	})
	phase_event_triggered.emit(phase_events[-1])
	
	# Advance campaign turn
	game_state.advance_turn()

func _complete_current_sub_phase() -> void:
	if current_phase != FiveParcsecsCampaignPhase.PRE_MISSION:
		return
		
	# Move to next sub-phase or complete campaign phase
	match current_sub_phase:
		CampaignSubPhase.TRAVEL:
			start_sub_phase(CampaignSubPhase.WORLD_ARRIVAL)
		CampaignSubPhase.WORLD_ARRIVAL:
			start_sub_phase(CampaignSubPhase.WORLD_EVENTS)
		CampaignSubPhase.WORLD_EVENTS:
			start_sub_phase(CampaignSubPhase.PATRON_CONTACT)
		CampaignSubPhase.PATRON_CONTACT:
			start_sub_phase(CampaignSubPhase.MISSION_SELECTION)
		CampaignSubPhase.MISSION_SELECTION:
			# This is the final sub-phase, mark the campaign phase as complete
			complete_phase_action("mission_selected")
			complete_phase_action("mission_prepared")

func _setup_phase_requirements(phase: FiveParcsecsCampaignPhase) -> void:
	match phase:
		FiveParcsecsCampaignPhase.UPKEEP:
			phase_requirements = {
				"actions": ["upkeep_paid", "crew_maintained", "ship_maintained"],
				"resources": {"credits": 0} # Will be updated during execution
			}
		FiveParcsecsCampaignPhase.STORY:
			phase_requirements = {
				"actions": ["events_resolved", "story_progressed"]
			}
		FiveParcsecsCampaignPhase.PRE_MISSION:
			phase_requirements = {
				"actions": ["travel_completed", "location_checked", "mission_selected", "mission_prepared"],
				"sub_phases": [
					CampaignSubPhase.TRAVEL,
					CampaignSubPhase.WORLD_ARRIVAL,
					CampaignSubPhase.WORLD_EVENTS,
					CampaignSubPhase.PATRON_CONTACT,
					CampaignSubPhase.MISSION_SELECTION
				]
			}
		FiveParcsecsCampaignPhase.BATTLE_SETUP:
			phase_requirements = {
				"actions": ["battlefield_generated", "enemy_forces_generated", "deployment_ready"]
			}
		FiveParcsecsCampaignPhase.BATTLE_RESOLUTION:
			phase_requirements = {
				"actions": ["battle_completed", "casualties_resolved"]
			}
		FiveParcsecsCampaignPhase.ADVANCEMENT:
			phase_requirements = {
				"actions": ["experience_gained", "skills_improved", "advancement_completed"]
			}
		FiveParcsecsCampaignPhase.TRADING:
			phase_requirements = {
				"actions": ["trade_completed", "equipment_updated"]
			}
		FiveParcsecsCampaignPhase.RETIREMENT:
			phase_requirements = {
				"actions": ["turn_completed"]
			}

func _are_phase_requirements_met() -> bool:
	# Check if all required actions are completed
	if "actions" in phase_requirements:
		for action in phase_requirements.actions:
			if not phase_actions_completed.get(action, false):
				return false
	
	# Check if all required resources are available
	if "resources" in phase_requirements:
		for resource in phase_requirements.resources:
			if phase_resources.get(resource, 0) < phase_requirements.resources[resource]:
				return false
	
	# For campaign phase, also check sub-phases
	if current_phase == FiveParcsecsCampaignPhase.PRE_MISSION:
		return current_sub_phase == CampaignSubPhase.MISSION_SELECTION and _are_current_sub_phase_requirements_met()
	
	return true

func _are_current_sub_phase_requirements_met() -> bool:
	match current_sub_phase:
		CampaignSubPhase.TRAVEL:
			return phase_actions_completed.get("travel_completed", false)
		CampaignSubPhase.WORLD_ARRIVAL:
			return phase_actions_completed.get("location_checked", false)
		CampaignSubPhase.WORLD_EVENTS:
			return phase_actions_completed.get("local_events_resolved", false)
		CampaignSubPhase.PATRON_CONTACT:
			return phase_actions_completed.get("patron_contacted", false)
		CampaignSubPhase.MISSION_SELECTION:
			return phase_actions_completed.get("mission_selected", false)
		_:
			return false

func _check_resource_requirements(resource_type: String, amount: int) -> void:
	# Check if this resource affects any phase requirements
	if current_phase == FiveParcsecsCampaignPhase.UPKEEP and resource_type == "credits":
		if amount >= phase_resources.get("upkeep_costs", 0):
			complete_phase_action("upkeep_paid")

# Helper methods for generating campaign content
# These would need actual implementation based on your data files
func _get_travel_options() -> Array:
	# Stub: Return possible travel destinations
	return []

func _generate_world_arrival_events() -> Array:
	# Stub: Return events that happen upon arrival
	return []

func _generate_local_events() -> Array:
	# Stub: Return local events for the current world
	return []

func _check_patron_availability() -> Array:
	# Stub: Check for available patrons
	return []

func _generate_available_missions() -> Array:
	# Stub: Generate available missions
	return []

func _calculate_upkeep_costs() -> int:
	# Stub: Calculate crew and ship upkeep
	return 0

func _generate_story_events() -> Array:
	# Stub: Generate story events
	return []

func _generate_battlefield() -> Dictionary:
	# Stub: Generate battlefield details
	return {}

func _generate_enemy_forces() -> Array:
	# Stub: Generate enemy forces
	return []

func _get_current_battle_data() -> Dictionary:
	# Stub: Get current battle data
	return {}

func _calculate_experience_earned() -> Dictionary:
	# Stub: Calculate experience earned from battle
	return {}

func _generate_trade_options() -> Array:
	# Stub: Generate trade options
	return []

func _generate_turn_summary() -> Dictionary:
	# Stub: Generate turn summary
	return {}

func validate_current_campaign() -> bool:
	if not validator or not game_state:
		phase_errors.append("Cannot validate campaign: validator or game state not ready")
		return false
	
	var validation_result = validator.validate_campaign()
	
	if not validation_result.valid and validation_result.errors.size() > 0:
		phase_errors.append_array(validation_result.errors)
		return false
	
	return true

# Method to set the game state for testing purposes
func set_game_state(state) -> bool:
	if state != null and is_instance_valid(state):
		game_state = state
		validator = ValidationManager.new(game_state)
		reset_phase_tracking()
		
		# Connect to campaign signals if available
		if game_state and game_state.current_campaign:
			_connect_to_campaign(game_state.current_campaign)
		return true
	return false

# Setup battle functionality for battle phase
func setup_battle() -> bool:
	if not game_state or not game_state.current_campaign:
		push_error("Cannot setup battle - no active campaign")
		return false
		
	# Validate we're in the correct phase
	if current_phase != FiveParcsecsCampaignPhase.BATTLE_SETUP:
		push_error("Cannot setup battle - not in BATTLE_SETUP phase")
		return false
		
	# Mark required actions as completed
	complete_phase_action("battlefield_generated")
	complete_phase_action("enemy_forces_generated")
	complete_phase_action("deployment_ready")
	
	# Emit phase action completed signal
	phase_action_completed.emit("battle_setup_completed")
	return true

# Get campaign results summary
func get_campaign_results() -> Dictionary:
	if not game_state or not game_state.current_campaign:
		push_error("Cannot get campaign results - no active campaign")
		return {}
		
	var campaign = game_state.current_campaign
	var results = {
		"campaign_id": "",
		"campaign_name": "Unknown Campaign",
		"completed": false,
		"victory": false,
		"turns": 0,
		"final_credits": 0,
		"battles_won": 0,
		"enemies_defeated": 0
	}
	
	# Extract data based on available methods
	if campaign.has_method("get_campaign_id"):
		results.campaign_id = campaign.get_campaign_id()
	elif "campaign_id" in campaign:
		results.campaign_id = campaign.campaign_id
	
	if campaign.has_method("get_campaign_name"):
		results.campaign_name = campaign.get_campaign_name()
	elif "campaign_name" in campaign:
		results.campaign_name = campaign.campaign_name
	
	if campaign.has_method("get_turn"):
		results.turns = campaign.get_turn()
	elif "turn" in campaign:
		results.turns = campaign.turn
	
	if campaign.has_method("get_credits"):
		results.final_credits = campaign.get_credits()
	elif "credits" in campaign:
		results.final_credits = campaign.credits
	
	# Check for battle stats
	if "battle_stats" in campaign:
		if campaign.battle_stats.has("battles_won"):
			results.battles_won = campaign.battle_stats.battles_won
		if campaign.battle_stats.has("enemies_defeated"):
			results.enemies_defeated = campaign.battle_stats.enemies_defeated
	
	return results

# Calculate upkeep for the campaign
func calculate_upkeep() -> Dictionary:
	if not game_state or not game_state.current_campaign:
		push_error("Cannot calculate upkeep - no active campaign")
		return {}
		
	var campaign = game_state.current_campaign
	var upkeep = {
		"crew": 0,
		"equipment": 0,
		"ship": 0,
		"total": 0
	}
	
	# Calculate crew upkeep
	if "crew" in campaign and campaign.crew:
		# For each crew member, upkeep is 10 credits
		if campaign.crew.has_method("get_members"):
			var members = campaign.crew.get_members()
			upkeep.crew = members.size() * 10
		elif "members" in campaign.crew:
			upkeep.crew = campaign.crew.members.size() * 10
	
	# Calculate equipment upkeep
	if "equipment" in campaign:
		upkeep.equipment = round(len(campaign.equipment) * 5)
	
	# Calculate ship upkeep if applicable
	if "ship" in campaign and campaign.ship:
		upkeep.ship = 50
	
	# Calculate total
	upkeep.total = upkeep.crew + upkeep.equipment + upkeep.ship
	
	return upkeep

# Advance the campaign to the next turn
func advance_campaign() -> bool:
	if not game_state or not game_state.current_campaign:
		push_error("Cannot advance campaign - no active campaign")
		return false
		
	var campaign = game_state.current_campaign
	
	# Increment turn counter
	if campaign.has_method("increment_turn"):
		campaign.increment_turn()
	elif "turn" in campaign:
		campaign.turn += 1
	
	# Complete current phase
	complete_phase_action("turn_completed")
	
	# Start the next phase (upkeep phase)
	return start_phase(FiveParcsecsCampaignPhase.UPKEEP)
