class_name CampaignPhaseManager
extends Node

signal phase_changed(old_phase: int, new_phase: int)
signal phase_completed
signal phase_started(phase: int)
signal phase_action_completed(action: String)
signal phase_event_triggered(event: Dictionary)

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const GameState = preload("res://src/core/state/GameState.gd")

var game_state: GameState
var current_phase: GameEnums.CampaignPhase = GameEnums.CampaignPhase.NONE
var previous_phase: GameEnums.CampaignPhase = GameEnums.CampaignPhase.NONE

# Phase tracking
var phase_actions_completed: Dictionary = {}
var phase_requirements: Dictionary = {}
var phase_resources: Dictionary = {}

func _init() -> void:
	reset_phase_tracking()

func setup(state: GameState) -> void:
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

func start_phase(new_phase: GameEnums.CampaignPhase) -> bool:
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

func _can_transition_to_phase(new_phase: GameEnums.CampaignPhase) -> bool:
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

func _setup_phase_requirements(phase: GameEnums.CampaignPhase) -> void:
	match phase:
		GameEnums.CampaignPhase.UPKEEP:
			phase_requirements = {
				"upkeep_paid": true,
				"tasks_assigned": true,
				"events_resolved": true
			}
		GameEnums.CampaignPhase.STORY:
			phase_requirements = {
				"events_resolved": true
			}
		GameEnums.CampaignPhase.CAMPAIGN:
			phase_requirements = {
				"location_checked": true,
				"mission_selected": true
			}
		GameEnums.CampaignPhase.BATTLE_SETUP:
			phase_requirements = {
				"deployment_ready": true
			}
		GameEnums.CampaignPhase.BATTLE_RESOLUTION:
			phase_requirements = {
				"battle_completed": true,
				"rewards_calculated": true
			}
		GameEnums.CampaignPhase.ADVANCEMENT:
			phase_requirements = {
				"advancement_completed": true
			}
		GameEnums.CampaignPhase.TRADE:
			phase_requirements = {
				"trade_completed": true
			}
		GameEnums.CampaignPhase.END:
			phase_requirements = {
				"resources_updated": true
			}
		_:
			phase_requirements.clear()

func _execute_phase_start() -> void:
	match current_phase:
		GameEnums.CampaignPhase.UPKEEP:
			_start_upkeep_phase()
		GameEnums.CampaignPhase.STORY:
			_start_story_phase()
		GameEnums.CampaignPhase.CAMPAIGN:
			_start_campaign_phase()
		GameEnums.CampaignPhase.BATTLE_SETUP:
			_start_battle_setup()
		GameEnums.CampaignPhase.BATTLE_RESOLUTION:
			_start_battle_resolution()
		GameEnums.CampaignPhase.ADVANCEMENT:
			_start_advancement_phase()
		GameEnums.CampaignPhase.TRADE:
			_start_trade_phase()
		GameEnums.CampaignPhase.END:
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