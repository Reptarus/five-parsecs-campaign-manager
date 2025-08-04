class_name CampaignCreationCoordinator
extends RefCounted

## CampaignCreationCoordinator - Lightweight orchestration for campaign creation workflow
## Implements Coordinator Pattern to manage phase transitions and navigation state
## Extracted from CampaignCreationUI monolith to reduce complexity and improve maintainability

# State management integration
const CampaignCreationStateManager = preload("res://src/core/campaign/creation/CampaignCreationStateManager.gd")

# Navigation state signals
signal navigation_updated(can_go_back: bool, can_go_forward: bool, can_finish: bool)
signal phase_transition_requested(from_phase: CampaignCreationStateManager.Phase, to_phase: CampaignCreationStateManager.Phase)
signal step_changed(step: int, total_steps: int)

# Phase management
var state_manager: CampaignCreationStateManager
var current_step: int = 0
var total_steps: int = 6  # CONFIG, CREW_SETUP, CAPTAIN_CREATION, SHIP_ASSIGNMENT, EQUIPMENT_GENERATION, FINAL_REVIEW

# Phase completion tracking
var phase_completion_status: Dictionary = {
	CampaignCreationStateManager.Phase.CONFIG: false,
	CampaignCreationStateManager.Phase.CREW_SETUP: false,
	CampaignCreationStateManager.Phase.CAPTAIN_CREATION: false,
	CampaignCreationStateManager.Phase.SHIP_ASSIGNMENT: false,
	CampaignCreationStateManager.Phase.EQUIPMENT_GENERATION: false,
	CampaignCreationStateManager.Phase.FINAL_REVIEW: false
}

func _init(campaign_state_manager: CampaignCreationStateManager = null) -> void:
	if campaign_state_manager:
		state_manager = campaign_state_manager
	else:
		state_manager = CampaignCreationStateManager.new()
	
	_connect_state_manager_signals()
	_initialize_navigation_state()

func _connect_state_manager_signals() -> void:
	"""Connect to state manager signals for phase updates"""
	if state_manager:
		state_manager.state_updated.connect(_on_state_updated)
		state_manager.phase_completed.connect(_on_phase_completed)
		state_manager.validation_changed.connect(_on_validation_changed)

func _initialize_navigation_state() -> void:
	"""Initialize navigation state based on current phase"""
	current_step = int(state_manager.current_phase)
	_update_navigation_state()

## Public API - Navigation Control

func can_advance_to_next_phase() -> bool:
	"""Check if we can advance to the next phase"""
	var current_phase = state_manager.current_phase
	
	# Special case: Allow advancing from CONFIG phase even if empty for initial setup
	if current_phase == CampaignCreationStateManager.Phase.CONFIG:
		return true
	
	# Check if current phase is completed
	return phase_completion_status.get(current_phase, false)

func advance_to_next_phase() -> bool:
	"""Advance to the next phase if possible"""
	if not can_advance_to_next_phase():
		return false
	
	var current_phase = state_manager.current_phase
	var next_phase_int = int(current_phase) + 1
	
	if next_phase_int >= CampaignCreationStateManager.Phase.FINAL_REVIEW + 1:
		return false  # Already at final phase
	
	var next_phase = CampaignCreationStateManager.Phase.values()[next_phase_int]
	phase_transition_requested.emit(current_phase, next_phase)
	
	if state_manager.advance_to_next_phase():
		current_step = next_phase_int
		_update_navigation_state()
		return true
	
	return false

func can_go_back_to_previous_phase() -> bool:
	"""Check if we can go back to the previous phase"""
	return current_step > 0

func go_back_to_previous_phase() -> bool:
	"""Go back to the previous phase if possible"""
	if not can_go_back_to_previous_phase():
		return false
	
	var current_phase = state_manager.current_phase
	var previous_phase_int = int(current_phase) - 1
	
	if previous_phase_int < 0:
		return false
	
	var previous_phase = CampaignCreationStateManager.Phase.values()[previous_phase_int]
	phase_transition_requested.emit(current_phase, previous_phase)
	
	if state_manager.go_to_previous_phase():
		current_step = previous_phase_int
		_update_navigation_state()
		return true
	
	return false

func can_finish_campaign_creation() -> bool:
	"""Check if all phases are complete and we can finish"""
	# Must be at FINAL_REVIEW phase or beyond
	if state_manager.current_phase < CampaignCreationStateManager.Phase.FINAL_REVIEW:
		return false
	
	# Check all critical phases are completed
	var required_phases = [
		CampaignCreationStateManager.Phase.CONFIG,
		CampaignCreationStateManager.Phase.CREW_SETUP,
		CampaignCreationStateManager.Phase.CAPTAIN_CREATION,
		CampaignCreationStateManager.Phase.SHIP_ASSIGNMENT,
		CampaignCreationStateManager.Phase.EQUIPMENT_GENERATION
	]
	
	for phase in required_phases:
		if not phase_completion_status.get(phase, false):
			return false
	
	return true

## Phase Status Management

func mark_phase_complete(phase: CampaignCreationStateManager.Phase, is_complete: bool = true) -> void:
	"""Mark a specific phase as complete or incomplete"""
	phase_completion_status[phase] = is_complete
	_update_navigation_state()

func get_phase_completion_status(phase: CampaignCreationStateManager.Phase) -> bool:
	"""Get completion status for a specific phase"""
	return phase_completion_status.get(phase, false)

func get_overall_completion_percentage() -> float:
	"""Get overall completion percentage across all phases"""
	var completed_count = 0
	var total_count = phase_completion_status.size()
	
	for phase in phase_completion_status:
		if phase_completion_status[phase]:
			completed_count += 1
	
	return float(completed_count) / float(total_count)

## State Manager Event Handlers

func _on_state_updated(phase: CampaignCreationStateManager.Phase, data: Dictionary) -> void:
	"""Handle state manager updates"""
	current_step = int(phase)
	_update_navigation_state()

func _on_phase_completed(phase: CampaignCreationStateManager.Phase) -> void:
	"""Handle phase completion from state manager"""
	mark_phase_complete(phase, true)

func _on_validation_changed(is_valid: bool, errors: Array[String]) -> void:
	"""Handle validation changes from state manager"""
	# Update navigation based on current phase validation
	_update_navigation_state()

## Internal Navigation Logic

func _update_navigation_state() -> void:
	"""Update navigation button states and emit signals"""
	var can_go_back = can_go_back_to_previous_phase()
	var can_go_forward = can_advance_to_next_phase()
	var can_finish = can_finish_campaign_creation()
	
	navigation_updated.emit(can_go_back, can_go_forward, can_finish)
	step_changed.emit(current_step, total_steps)

## Debug and Information

func get_current_phase_name() -> String:
	"""Get human-readable name for current phase"""
	match state_manager.current_phase:
		CampaignCreationStateManager.Phase.CONFIG:
			return "Configuration"
		CampaignCreationStateManager.Phase.CREW_SETUP:
			return "Crew Setup"
		CampaignCreationStateManager.Phase.CAPTAIN_CREATION:
			return "Captain Creation"
		CampaignCreationStateManager.Phase.SHIP_ASSIGNMENT:
			return "Ship Assignment"
		CampaignCreationStateManager.Phase.EQUIPMENT_GENERATION:
			return "Equipment Generation"
		CampaignCreationStateManager.Phase.FINAL_REVIEW:
			return "Final Review"
		_:
			return "Unknown Phase"

func get_navigation_state() -> Dictionary:
	"""Get current navigation state for UI updates"""
	return {
		"can_go_back": can_go_back_to_previous_phase(),
		"can_go_forward": can_advance_to_next_phase(),
		"can_finish": can_finish_campaign_creation(),
		"current_step": current_step,
		"total_steps": total_steps,
		"current_phase": state_manager.current_phase,
		"current_phase_name": get_current_phase_name()
	}

func get_debug_info() -> Dictionary:
	"""Get debug information about coordinator state"""
	return {
		"current_step": current_step,
		"total_steps": total_steps,
		"current_phase": state_manager.current_phase,
		"current_phase_name": get_current_phase_name(),
		"phase_completion_status": phase_completion_status,
		"overall_completion": get_overall_completion_percentage(),
		"can_go_back": can_go_back_to_previous_phase(),
		"can_go_forward": can_advance_to_next_phase(),
		"can_finish": can_finish_campaign_creation()
	}

## Campaign Finalization

func finalize_campaign() -> Dictionary:
	"""Finalize campaign creation by aggregating all phase data"""
	print("CampaignCreationCoordinator: Finalizing campaign creation...")
	
	# Validate all required phases are complete
	var validation_result = _validate_campaign_completion()
	if not validation_result.valid:
		print("CampaignCreationCoordinator: Campaign finalization failed validation: ", validation_result.errors)
		return {
			"success": false,
			"error": "Campaign validation failed",
			"errors": validation_result.errors,
			"completion_percentage": get_overall_completion_percentage()
		}
	
	# Aggregate all phase data
	var finalized_campaign_data = _aggregate_all_phase_data()
	
	# Add finalization metadata
	finalized_campaign_data["finalization"] = {
		"finalized_at": Time.get_datetime_string_from_system(),
		"finalized_by": "CampaignCreationCoordinator",
		"version": "1.0",
		"completion_percentage": get_overall_completion_percentage(),
		"total_phases": total_steps,
		"coordinator_state": get_debug_info()
	}
	
	print("CampaignCreationCoordinator: ✅ Campaign finalization complete")
	return {
		"success": true,
		"campaign_data": finalized_campaign_data,
		"completion_percentage": get_overall_completion_percentage()
	}

func _validate_campaign_completion() -> Dictionary:
	"""Validate that campaign is ready for finalization"""
	var errors: Array[String] = []
	
	# Check minimum required phases
	var required_phases = [
		CampaignCreationStateManager.Phase.CONFIG,
		CampaignCreationStateManager.Phase.CREW_SETUP,
		CampaignCreationStateManager.Phase.CAPTAIN_CREATION
	]
	
	for phase in required_phases:
		if not phase_completion_status.get(phase, false):
			errors.append("Required phase not complete: %s" % get_phase_name(phase))
	
	# Check overall completion percentage
	var completion_pct = get_overall_completion_percentage()
	if completion_pct < 75.0:  # Require at least 75% completion
		errors.append("Campaign is only %.1f%% complete. Need at least 75%% for finalization." % completion_pct)
	
	# Validate state manager has data
	if not state_manager:
		errors.append("State manager is not available.")
	else:
		var validation_summary = state_manager.get_validation_summary()
		if validation_summary.get("has_critical_errors", false):
			errors.append("Campaign has critical validation errors.")
	
	return {
		"valid": errors.is_empty(),
		"errors": errors
	}

func _aggregate_all_phase_data() -> Dictionary:
	"""Aggregate data from all phases into final campaign structure"""
	if not state_manager:
		return {}
	
	var campaign_data = {
		"config": state_manager.get_phase_data(CampaignCreationStateManager.Phase.CONFIG),
		"crew": state_manager.get_phase_data(CampaignCreationStateManager.Phase.CREW_SETUP),
		"captain": state_manager.get_phase_data(CampaignCreationStateManager.Phase.CAPTAIN_CREATION),
		"ship": state_manager.get_phase_data(CampaignCreationStateManager.Phase.SHIP_ASSIGNMENT),
		"equipment": state_manager.get_phase_data(CampaignCreationStateManager.Phase.EQUIPMENT_GENERATION),
		"world": state_manager.get_phase_data(CampaignCreationStateManager.Phase.WORLD_GENERATION),
		"validation_summary": state_manager.get_validation_summary(),
		"completion_status": state_manager.get_completion_status(),
		"phase_completion": phase_completion_status.duplicate()
	}
	
	print("CampaignCreationCoordinator: Aggregated %d phases of campaign data" % campaign_data.keys().size())
	return campaign_data

func get_phase_name(phase: CampaignCreationStateManager.Phase) -> String:
	"""Get human-readable name for any phase"""
	match phase:
		CampaignCreationStateManager.Phase.CONFIG:
			return "Configuration"
		CampaignCreationStateManager.Phase.CREW_SETUP:
			return "Crew Setup"
		CampaignCreationStateManager.Phase.CAPTAIN_CREATION:
			return "Captain Creation"
		CampaignCreationStateManager.Phase.SHIP_ASSIGNMENT:
			return "Ship Assignment"
		CampaignCreationStateManager.Phase.EQUIPMENT_GENERATION:
			return "Equipment Generation"
		CampaignCreationStateManager.Phase.WORLD_GENERATION:
			return "World Generation"
		CampaignCreationStateManager.Phase.FINAL_REVIEW:
			return "Final Review"
		_:
			return "Unknown Phase"
