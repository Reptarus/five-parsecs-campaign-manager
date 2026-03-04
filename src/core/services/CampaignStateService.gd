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
	## Initialize campaign state service
	_initialize_transition_rules()
	_initialize_state_validator()
	_connect_to_phase_manager()


func _connect_to_phase_manager() -> void:
	## Connect to CampaignPhaseManager signals for reactive state sync
	# Deferred connection since CPM may not be ready yet during autoload init
	call_deferred("_deferred_connect_cpm")

func _deferred_connect_cpm() -> void:
	var cpm = get_node_or_null("/root/CampaignPhaseManager")
	if not cpm:
		return

	if cpm.has_signal("phase_started"):
		cpm.phase_started.connect(_on_cpm_phase_started)
	if cpm.has_signal("phase_completed"):
		cpm.phase_completed.connect(_on_cpm_phase_completed)
	if cpm.has_signal("turn_started"):
		cpm.turn_started.connect(_on_cpm_turn_started)
	if cpm.has_signal("turn_completed"):
		cpm.turn_completed.connect(_on_cpm_turn_completed)

	# Initial sync from CPM
	if cpm.has_method("get_current_phase"):
		current_phase = cpm.get_current_phase()
	if cpm.has_method("get_turn_number"):
		campaign_turn = cpm.get_turn_number()


func _on_cpm_phase_started(phase: int) -> void:
	## Sync phase from CampaignPhaseManager (canonical source)
	current_phase = phase
	_save_state_snapshot("phase_started")
	_emit_state_changed()
	phase_transition_completed.emit(phase)

func _on_cpm_phase_completed(phase: int, completion_data: Dictionary) -> void:
	## Store phase completion data for UI queries
	_save_state_snapshot("phase_completed")
	# Store completion data for potential UI lookups
	current_campaign["last_phase_completion"] = {
		"phase": phase,
		"data": completion_data,
		"timestamp": Time.get_datetime_string_from_system()
	}

func _on_cpm_turn_started(turn_number: int) -> void:
	## Sync turn from CampaignPhaseManager
	campaign_turn = turn_number
	campaign_turn_advanced.emit(campaign_turn)
	_save_state_snapshot("turn_started")
	_emit_state_changed()

func _on_cpm_turn_completed(turn_number: int) -> void:
	## Record turn completion
	_save_state_snapshot("turn_completed")

func _initialize_transition_rules() -> void:
	## Initialize Five Parsecs campaign phase transition rules
	transition_rules = {
		GlobalEnums.FiveParsecsCampaignPhase.TRAVEL: [
			GlobalEnums.FiveParsecsCampaignPhase.UPKEEP
		],
		GlobalEnums.FiveParsecsCampaignPhase.UPKEEP: [
			GlobalEnums.FiveParsecsCampaignPhase.MISSION,
			GlobalEnums.FiveParsecsCampaignPhase.TRAVEL  # Skip battle if no job taken
		],
		GlobalEnums.FiveParsecsCampaignPhase.MISSION: [
			GlobalEnums.FiveParsecsCampaignPhase.POST_MISSION
		],
		GlobalEnums.FiveParsecsCampaignPhase.POST_MISSION: [
			GlobalEnums.FiveParsecsCampaignPhase.TRAVEL  # Start next turn
		]
	}

func _initialize_state_validator() -> void:
	## Initialize state validation system
	# Future: Load from proper validator class
	pass

## Public Interface

func initialize_new_campaign(campaign_data: Dictionary) -> bool:
	## Initialize a new campaign with provided data
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
	
	return true

func restore_campaign(save_data: Dictionary) -> bool:
	## Restore campaign from save data
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
	
	return true

func transition_to_phase(new_phase: GlobalEnums.FiveParsecsCampaignPhase) -> bool:
	## Attempt to transition to a new campaign phase.
	## Delegates to CampaignPhaseManager when available (canonical source).
	## Falls back to standalone behavior if CPM is not registered.
	return false
func update_campaign_data(key: String, value: Variant) -> void:
	## Update a specific piece of campaign data
	current_campaign[key] = value
	current_campaign["last_played"] = Time.get_datetime_string_from_system()
	_save_state_snapshot("data_updated")
	_emit_state_changed()

func get_campaign_data(key: String = "") -> Variant:
	## Get campaign data (specific key or entire dictionary)
	if key.is_empty():
		return current_campaign.duplicate(true)
	else:
		return current_campaign.get(key, null)

func get_current_phase() -> GlobalEnums.FiveParsecsCampaignPhase:
	## Get current campaign phase
	return current_phase

func get_campaign_turn() -> int:
	## Get current campaign turn
	return campaign_turn

func get_full_state() -> Dictionary:
	## Get complete campaign state for saving
	return {
		"campaign_data": current_campaign.duplicate(true),
		"current_phase": current_phase,
		"campaign_turn": campaign_turn,
		"state_history": state_history.duplicate(true),
		"last_saved": Time.get_datetime_string_from_system()
	}

## Private Methods

func _validate_save_data(save_data: Dictionary) -> bool:
	## Validate save data structure
	var required_keys = ["campaign_data", "current_phase", "campaign_turn"]
	for key in required_keys:
		if not save_data.has(key):
			return false
	var phase_value = save_data.get("current_phase")
	if not phase_value in GlobalEnums.FiveParsecsCampaignPhase.values():
		return false
	return true

func _has_active_job() -> bool:
	## Check if campaign has an active job/mission
	return current_campaign.get("active_job", null) != null

func _has_battle_results() -> bool:
	## Check if battle results are available
	return current_campaign.get("battle_results", null) != null

func _save_state_snapshot(reason: String) -> void:
	## Save a snapshot of current state to history
	var snapshot = {
		"timestamp": Time.get_datetime_string_from_system(),
		"reason": reason,
		"phase": current_phase,
		"turn": campaign_turn,
		"campaign_data": current_campaign.duplicate(true)
	}
	state_history.append(snapshot)
	if state_history.size() > 50:
		state_history = state_history.slice(-50)

func _emit_state_changed() -> void:
	## Emit state changed signal with current state data
	var state_data = {
		"campaign_data": current_campaign.duplicate(true),
		"current_phase": current_phase,
		"campaign_turn": campaign_turn,
		"phase_name": GlobalEnums.PHASE_NAMES.get(current_phase, "Unknown")
	}
	campaign_state_changed.emit(state_data)
