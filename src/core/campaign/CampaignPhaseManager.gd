@tool
extends Node

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")

# Import the enums directly for cleaner code
const FiveParcsecsCampaignPhase = GameEnums.FiveParcsecsCampaignPhase

signal phase_changed(old_phase: FiveParcsecsCampaignPhase, new_phase: FiveParcsecsCampaignPhase)
signal phase_completed
signal phase_started(phase: FiveParcsecsCampaignPhase)
signal phase_action_completed(action: String)
signal phase_event_triggered(event: Dictionary)

var game_state: FiveParsecsGameState
var current_phase: FiveParcsecsCampaignPhase = FiveParcsecsCampaignPhase.NONE
var previous_phase: FiveParcsecsCampaignPhase = FiveParcsecsCampaignPhase.NONE

# Phase tracking
var phase_actions_completed: Dictionary = {}
var phase_requirements: Dictionary = {}
var phase_resources: Dictionary = {}
var phase_events: Array = []

func _ready() -> void:
	reset_phase_tracking()

func setup(state: FiveParsecsGameState) -> void:
	game_state = state
	reset_phase_tracking()

func reset_phase_tracking() -> void:
	phase_actions_completed = {
		"upkeep_paid": false,
		"tasks_assigned": false,
		"events_resolved": false,
		"travel_completed": false,
		"location_checked": false,
		"mission_selected": false,
		"deployment_ready": false,
		"battle_completed": false,
		"rewards_calculated": false,
		"resources_updated": false,
		"advancement_completed": false,
		"trade_completed": false
	}
	
	phase_requirements.clear()
	phase_resources.clear()
	phase_events.clear()
	current_phase = FiveParcsecsCampaignPhase.NONE
	previous_phase = FiveParcsecsCampaignPhase.NONE

func start_phase(new_phase: FiveParcsecsCampaignPhase) -> bool:
	if not _can_transition_to_phase(new_phase):
		return false
	
	previous_phase = current_phase
	current_phase = new_phase
	
	# Initialize phase requirements
	_setup_phase_requirements(current_phase)
	
	# Emit signals
	phase_changed.emit(previous_phase, current_phase)
	phase_started.emit(current_phase)
	
	# Start phase execution
	_execute_phase_start()
	
	return true

func complete_phase_action(action: String) -> void:
	if action in phase_actions_completed:
		phase_actions_completed[action] = true
		phase_action_completed.emit(action)
		
		# Check if phase is complete
		if _are_phase_requirements_met():
			phase_completed.emit()

func _can_transition_to_phase(new_phase: FiveParcsecsCampaignPhase) -> bool:
	match new_phase:
		FiveParcsecsCampaignPhase.SETUP:
			return current_phase == FiveParcsecsCampaignPhase.NONE
		FiveParcsecsCampaignPhase.UPKEEP:
			return current_phase in [FiveParcsecsCampaignPhase.SETUP, FiveParcsecsCampaignPhase.END]
		FiveParcsecsCampaignPhase.STORY:
			return current_phase == FiveParcsecsCampaignPhase.UPKEEP
		FiveParcsecsCampaignPhase.CAMPAIGN:
			return current_phase == FiveParcsecsCampaignPhase.STORY
		FiveParcsecsCampaignPhase.BATTLE_SETUP:
			return current_phase == FiveParcsecsCampaignPhase.CAMPAIGN
		FiveParcsecsCampaignPhase.BATTLE_RESOLUTION:
			return current_phase == FiveParcsecsCampaignPhase.BATTLE_SETUP
		FiveParcsecsCampaignPhase.ADVANCEMENT:
			return current_phase == FiveParcsecsCampaignPhase.BATTLE_RESOLUTION
		FiveParcsecsCampaignPhase.TRADE:
			return current_phase == FiveParcsecsCampaignPhase.ADVANCEMENT
		FiveParcsecsCampaignPhase.END:
			return current_phase == FiveParcsecsCampaignPhase.TRADE
		_:
			return false

func _setup_phase_requirements(phase: FiveParcsecsCampaignPhase) -> void:
	match phase:
		FiveParcsecsCampaignPhase.UPKEEP:
			phase_requirements = {
				"upkeep_paid": true,
				"tasks_assigned": true,
				"events_resolved": true
			}
		FiveParcsecsCampaignPhase.STORY:
			phase_requirements = {
				"events_resolved": true
			}
		FiveParcsecsCampaignPhase.CAMPAIGN:
			phase_requirements = {
				"location_checked": true,
				"mission_selected": true
			}
		FiveParcsecsCampaignPhase.BATTLE_SETUP:
			phase_requirements = {
				"deployment_ready": true
			}
		FiveParcsecsCampaignPhase.BATTLE_RESOLUTION:
			phase_requirements = {
				"battle_completed": true,
				"rewards_calculated": true
			}
		FiveParcsecsCampaignPhase.ADVANCEMENT:
			phase_requirements = {
				"advancement_completed": true
			}
		FiveParcsecsCampaignPhase.TRADE:
			phase_requirements = {
				"trade_completed": true
			}
		FiveParcsecsCampaignPhase.END:
			phase_requirements = {
				"resources_updated": true
			}
		_:
			phase_requirements.clear()

func _execute_phase_start() -> void:
	match current_phase:
		FiveParcsecsCampaignPhase.UPKEEP:
			_start_upkeep_phase()
		FiveParcsecsCampaignPhase.STORY:
			_start_story_phase()
		FiveParcsecsCampaignPhase.CAMPAIGN:
			_start_campaign_phase()
		FiveParcsecsCampaignPhase.BATTLE_SETUP:
			_start_battle_setup()
		FiveParcsecsCampaignPhase.BATTLE_RESOLUTION:
			_start_battle_resolution()
		FiveParcsecsCampaignPhase.ADVANCEMENT:
			_start_advancement_phase()
		FiveParcsecsCampaignPhase.TRADE:
			_start_trade_phase()
		FiveParcsecsCampaignPhase.END:
			_start_end_phase()

func _are_phase_requirements_met() -> bool:
	for requirement in phase_requirements:
		if not phase_actions_completed.get(requirement, false):
			return false
	return true

# Phase Start Implementations
func _start_upkeep_phase() -> void:
	var campaign = game_state.get_campaign()
	if not campaign:
		return
	
	# Calculate upkeep costs
	var upkeep_cost = campaign.crew_members.size() * 100
	phase_resources["upkeep_cost"] = upkeep_cost
	
	# Trigger upkeep event
	phase_event_triggered.emit({
		"type": "UPKEEP_STARTED",
		"cost": upkeep_cost,
		"crew_size": campaign.crew_members.size()
	})

func _start_story_phase() -> void:
	phase_event_triggered.emit({
		"type": "STORY_STARTED"
	})

func _start_campaign_phase() -> void:
	phase_event_triggered.emit({
		"type": "CAMPAIGN_STARTED"
	})

func _start_battle_setup() -> void:
	phase_event_triggered.emit({
		"type": "BATTLE_SETUP_STARTED"
	})

func _start_battle_resolution() -> void:
	phase_event_triggered.emit({
		"type": "BATTLE_RESOLUTION_STARTED"
	})

func _start_advancement_phase() -> void:
	phase_event_triggered.emit({
		"type": "ADVANCEMENT_STARTED"
	})

func _start_trade_phase() -> void:
	phase_event_triggered.emit({
		"type": "TRADE_STARTED"
	})

func _start_end_phase() -> void:
	phase_event_triggered.emit({
		"type": "END_PHASE_STARTED"
	})