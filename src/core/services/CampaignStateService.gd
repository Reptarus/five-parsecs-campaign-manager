extends Node

## Campaign State Service - Centralized Campaign State Management Singleton
## Manages campaign state, phase transitions, and state validation for Five Parsecs

# Campaign State Data
var current_campaign: Dictionary = {}
var current_phase: GlobalEnums.FiveParsecsCampaignPhase = GlobalEnums.FiveParsecsCampaignPhase.TRAVEL
var campaign_turn: int = 0
var state_history: Array[Dictionary] = []

# State Validation
var state_validator: Resource = null
var transition_rules: Dictionary = {}

# Signals
signal campaign_state_changed(state_data: Dictionary)
signal phase_transition_requested(from_phase: GlobalEnums.FiveParsecsCampaignPhase, to_phase: GlobalEnums.FiveParsecsCampaignPhase)
signal phase_transition_completed(new_phase: GlobalEnums.FiveParsecsCampaignPhase)
signal campaign_turn_advanced(new_turn: int)
signal state_validation_failed(error: String)

func _ready() -> void:
	"""Initialize campaign state service"""
	_initialize_transition_rules()
	_initialize_state_validator()
	
	print("CampaignStateService: Initialized successfully")

func _initialize_transition_rules() -> void:
	"""Initialize Five Parsecs campaign phase transition rules"""
	transition_rules = {
		GlobalEnums.FiveParsecsCampaignPhase.TRAVEL: [
			GlobalEnums.FiveParsecsCampaignPhase.WORLD
		],
		GlobalEnums.FiveParsecsCampaignPhase.WORLD: [
			GlobalEnums.FiveParsecsCampaignPhase.BATTLE,
			GlobalEnums.FiveParsecsCampaignPhase.TRAVEL  # Skip battle if no job taken
		],
		GlobalEnums.FiveParsecsCampaignPhase.BATTLE: [
			GlobalEnums.FiveParsecsCampaignPhase.POST_BATTLE
		],
		GlobalEnums.FiveParsecsCampaignPhase.POST_BATTLE: [
			GlobalEnums.FiveParsecsCampaignPhase.TRAVEL  # Start next turn
		]
	}

func _initialize_state_validator() -> void:
	"""Initialize state validation system"""
	# Future: Load from proper validator class
	print("CampaignStateService: State validator initialized")

## Public Interface

func initialize_new_campaign(campaign_data: Dictionary) -> bool:
	"""Initialize a new campaign with provided data"""
	current_campaign = campaign_data.duplicate(true)
	current_phase = GlobalEnums.FiveParsecsCampaignPhase.TRAVEL
	campaign_turn = 1
	state_history.clear()
	
	# Set default campaign state
	if not current_campaign.has("name"):
		current_campaign["name"] = "New Campaign"
	
	if not current_campaign.has("difficulty"):
		current_campaign["difficulty"] = "Standard"
	
	if not current_campaign.has("victory_condition"):
		current_campaign["victory_condition"] = "Standard"
	
	# Add creation timestamp
	current_campaign["created_at"] = Time.get_datetime_string_from_system()
	current_campaign["last_played"] = Time.get_datetime_string_from_system()
	
	_save_state_snapshot("campaign_initialized")
	_emit_state_changed()
	
	print("CampaignStateService: New campaign initialized - %s" % current_campaign.name)
	return true

func restore_campaign(save_data: Dictionary) -> bool:
	"""Restore campaign from save data"""
	if not _validate_save_data(save_data):
		state_validation_failed.emit("Invalid save data format")
		return false
	
	current_campaign = save_data.get("campaign_data", {})
	current_phase = save_data.get("current_phase", GlobalEnums.FiveParsecsCampaignPhase.TRAVEL)
	campaign_turn = save_data.get("campaign_turn", 1)
	state_history = save_data.get("state_history", [])
	
	# Update last played timestamp
	current_campaign["last_played"] = Time.get_datetime_string_from_system()
	
	_emit_state_changed()
	
	print("CampaignStateService: Campaign restored - %s" % current_campaign.get("name", "Unknown"))
	return true

func transition_to_phase(new_phase: GlobalEnums.FiveParsecsCampaignPhase) -> bool:
	"""Attempt to transition to a new campaign phase"""
	var validation_result = validate_phase_transition(current_phase, new_phase)
	
	if not validation_result.valid:
		state_validation_failed.emit(validation_result.error_message)
		print("CampaignStateService: Phase transition failed - %s" % validation_result.error_message)
		return false
	
	var old_phase = current_phase
	phase_transition_requested.emit(old_phase, new_phase)
	
	current_phase = new_phase
	
	# Check if we completed a full campaign turn
	if old_phase == GlobalEnums.FiveParsecsCampaignPhase.POST_BATTLE and new_phase == GlobalEnums.FiveParsecsCampaignPhase.TRAVEL:
		campaign_turn += 1
		campaign_turn_advanced.emit(campaign_turn)
		print("CampaignStateService: Advanced to campaign turn %d" % campaign_turn)
	
	_save_state_snapshot("phase_transition")
	_emit_state_changed()
	phase_transition_completed.emit(new_phase)
	
	print("CampaignStateService: Phase transition %s -> %s completed" % [
		GlobalEnums.FiveParsecsCampaignPhase.keys()[old_phase],
		GlobalEnums.FiveParsecsCampaignPhase.keys()[new_phase]
	])
	
	return true

func validate_phase_transition(from_phase: GlobalEnums.FiveParsecsCampaignPhase, to_phase: GlobalEnums.FiveParsecsCampaignPhase) -> Dictionary:
	"""Validate if a phase transition is allowed by Five Parsecs rules"""
	# Check if transition is allowed
	var allowed_transitions = transition_rules.get(from_phase, [])
	
	if to_phase not in allowed_transitions:
		return {
			"valid": false,
			"error_message": "Invalid phase transition: %s -> %s not allowed by Five Parsecs rules" % [
				GlobalEnums.FiveParsecsCampaignPhase.keys()[from_phase],
				GlobalEnums.FiveParsecsCampaignPhase.keys()[to_phase]
			]
		}
	
	# Additional validation based on campaign state
	match to_phase:
		GlobalEnums.FiveParsecsCampaignPhase.BATTLE:
			if not _has_active_job():
				return {
					"valid": false,
					"error_message": "Cannot enter battle phase without an active job or mission"
				}
		
		GlobalEnums.FiveParsecsCampaignPhase.POST_BATTLE:
			if not _has_battle_results():
				return {
					"valid": false,
					"error_message": "Cannot enter post-battle phase without battle results"
				}
	
	return {"valid": true, "error_message": ""}

func update_campaign_data(key: String, value: Variant) -> void:
	"""Update a specific piece of campaign data"""
	current_campaign[key] = value
	current_campaign["last_played"] = Time.get_datetime_string_from_system()
	
	_save_state_snapshot("data_updated")
	_emit_state_changed()

func get_campaign_data(key: String = "") -> Variant:
	"""Get campaign data (specific key or entire dictionary)"""
	if key.is_empty():
		return current_campaign.duplicate(true)
	else:
		return current_campaign.get(key, null)

func get_current_phase() -> GlobalEnums.FiveParsecsCampaignPhase:
	"""Get current campaign phase"""
	return current_phase

func get_campaign_turn() -> int:
	"""Get current campaign turn"""
	return campaign_turn

func get_full_state() -> Dictionary:
	"""Get complete campaign state for saving"""
	return {
		"campaign_data": current_campaign.duplicate(true),
		"current_phase": current_phase,
		"campaign_turn": campaign_turn,
		"state_history": state_history.duplicate(true),
		"last_saved": Time.get_datetime_string_from_system()
	}

## Private Methods

func _validate_save_data(save_data: Dictionary) -> bool:
	"""Validate save data structure"""
	var required_keys = ["campaign_data", "current_phase", "campaign_turn"]
	
	for key in required_keys:
		if not save_data.has(key):
			print("CampaignStateService: Missing required save data key: %s" % key)
			return false
	
	# Validate phase enum value
	var phase_value = save_data.get("current_phase")
	if not phase_value in GlobalEnums.FiveParsecsCampaignPhase.values():
		print("CampaignStateService: Invalid phase value in save data: %s" % phase_value)
		return false
	
	return true

func _has_active_job() -> bool:
	"""Check if campaign has an active job/mission"""
	# Future: Implement proper job system integration
	return current_campaign.get("active_job", null) != null

func _has_battle_results() -> bool:
	"""Check if battle results are available"""
	# Future: Implement proper battle results integration
	return current_campaign.get("battle_results", null) != null

func _save_state_snapshot(reason: String) -> void:
	"""Save a snapshot of current state to history"""
	var snapshot = {
		"timestamp": Time.get_datetime_string_from_system(),
		"reason": reason,
		"phase": current_phase,
		"turn": campaign_turn,
		"campaign_data": current_campaign.duplicate(true)
	}
	
	state_history.append(snapshot)
	
	# Keep only last 50 snapshots to prevent memory bloat
	if state_history.size() > 50:
		state_history = state_history.slice(-50)

func _emit_state_changed() -> void:
	"""Emit state changed signal with current state data"""
	var state_data = {
		"campaign_data": current_campaign.duplicate(true),
		"current_phase": current_phase,
		"campaign_turn": campaign_turn,
		"phase_name": GlobalEnums.FiveParsecsCampaignPhase.keys()[current_phase]
	}
	
	campaign_state_changed.emit(state_data)

## Debug and Testing

func _debug_print_state() -> void:
	"""Debug method to print current state"""
	print("=== Campaign State Service Debug ===")
	print("Campaign: %s" % current_campaign.get("name", "Unknown"))
	print("Phase: %s" % GlobalEnums.FiveParsecsCampaignPhase.keys()[current_phase])
	print("Turn: %d" % campaign_turn)
	print("History entries: %d" % state_history.size())
	print("=====================================")

func _test_phase_transitions() -> void:
	"""Test method for phase transitions"""
	print("Testing phase transitions...")
	
	var test_phases = [
		GlobalEnums.FiveParsecsCampaignPhase.WORLD,
		GlobalEnums.FiveParsecsCampaignPhase.BATTLE,
		GlobalEnums.FiveParsecsCampaignPhase.POST_BATTLE,
		GlobalEnums.FiveParsecsCampaignPhase.TRAVEL
	]
	
	for phase in test_phases:
		var result = transition_to_phase(phase)
		print("Transition to %s: %s" % [GlobalEnums.FiveParsecsCampaignPhase.keys()[phase], result])
		await get_tree().create_timer(0.5).timeout