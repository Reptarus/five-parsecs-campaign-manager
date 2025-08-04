@tool
class_name CampaignCreationStateMachine
extends RefCounted

## Campaign Creation UI State Machine
## Formal finite state machine for campaign creation UI with race condition prevention,
## state validation, and recovery mechanisms

const CampaignCreationFeatureFlags = preload("res://src/core/systems/CampaignCreationFeatureFlags.gd")
const CampaignSecurityManager = preload("res://src/core/security/CampaignSecurityManager.gd")

# State machine signals
signal state_changed(old_state: UIState, new_state: UIState)
signal state_transition_requested(target_state: UIState)
signal state_transition_blocked(current_state: UIState, target_state: UIState, reason: String)
signal state_machine_error(error_type: String, details: String)
signal recovery_initiated(recovery_type: String)

# UI States - Formal finite state machine
enum UIState {
	UNINITIALIZED, # Initial state before setup
	IDLE, # Ready and waiting for user interaction
	VALIDATING_INPUT, # Validating user input before transitions
	LOADING_PANEL, # Loading a new panel
	PANEL_ACTIVE, # Panel is loaded and active
	TRANSITIONING, # Transitioning between phases
	SAVING_STATE, # Persisting current state
	LOADING_STATE, # Restoring saved state
	ERROR_RECOVERY, # Recovering from errors
	EMERGENCY_ROLLBACK, # Emergency rollback to last known good state
	TERMINATED # State machine shut down
}

# State transition events
enum TransitionEvent {
	INITIALIZE,
	VALIDATE_INPUT,
	LOAD_PANEL,
	PANEL_LOADED,
	PANEL_FAILED,
	TRANSITION_PHASE,
	SAVE_REQUIRED,
	LOAD_REQUIRED,
	ERROR_OCCURRED,
	RECOVERY_COMPLETE,
	EMERGENCY_ROLLBACK,
	SHUTDOWN
}

# State machine configuration
var current_state: UIState = UIState.UNINITIALIZED
var previous_state: UIState = UIState.UNINITIALIZED
var state_history: Array[UIState] = []
var max_history_length: int = 20

# State validation and guards
var state_transitions: Dictionary = {}
var state_guards: Dictionary = {}
var state_timeouts: Dictionary = {}
var state_entry_actions: Dictionary = {}
var state_exit_actions: Dictionary = {}

# State machine runtime
var state_lock: Mutex = Mutex.new()
var transition_in_progress: bool = false
var current_timeout_timer: Timer
var emergency_rollback_count: int = 0
var max_emergency_rollbacks: int = 3

# State persistence
var last_known_good_state: UIState = UIState.IDLE
var state_checkpoint_data: Dictionary = {}
var auto_checkpoint_enabled: bool = true
var checkpoint_interval: float = 30.0

# Performance and monitoring
var state_enter_times: Dictionary = {}
var state_durations: Dictionary = {}
var transition_counts: Dictionary = {}
var error_counts: Dictionary = {}

# Security integration
var security_manager: CampaignSecurityManager

func _init() -> void:
	"""Initialize the state machine with security integration"""
	_setup_security_integration()
	_setup_state_transitions()
	_setup_state_guards()
	_setup_state_timeouts()
	_setup_state_actions()
	_initialize_monitoring()

func _setup_security_integration() -> void:
	"""Initialize security manager integration"""
	if CampaignCreationFeatureFlags.is_enabled(CampaignCreationFeatureFlags.FeatureFlag.SECURITY_FOUNDATION):
		security_manager = CampaignSecurityManager.get_instance()

## State Machine Configuration

func _setup_state_transitions() -> void:
	"""Define valid state transitions"""
	state_transitions = {
		UIState.UNINITIALIZED: [UIState.IDLE, UIState.ERROR_RECOVERY],
		UIState.IDLE: [UIState.VALIDATING_INPUT, UIState.LOADING_PANEL, UIState.LOADING_STATE, UIState.TERMINATED],
		UIState.VALIDATING_INPUT: [UIState.IDLE, UIState.LOADING_PANEL, UIState.ERROR_RECOVERY],
		UIState.LOADING_PANEL: [UIState.PANEL_ACTIVE, UIState.ERROR_RECOVERY, UIState.EMERGENCY_ROLLBACK],
		UIState.PANEL_ACTIVE: [UIState.VALIDATING_INPUT, UIState.TRANSITIONING, UIState.SAVING_STATE, UIState.ERROR_RECOVERY],
		UIState.TRANSITIONING: [UIState.LOADING_PANEL, UIState.IDLE, UIState.ERROR_RECOVERY],
		UIState.SAVING_STATE: [UIState.IDLE, UIState.PANEL_ACTIVE, UIState.ERROR_RECOVERY],
		UIState.LOADING_STATE: [UIState.PANEL_ACTIVE, UIState.IDLE, UIState.ERROR_RECOVERY],
		UIState.ERROR_RECOVERY: [UIState.IDLE, UIState.EMERGENCY_ROLLBACK, UIState.TERMINATED],
		UIState.EMERGENCY_ROLLBACK: [UIState.IDLE, UIState.ERROR_RECOVERY, UIState.TERMINATED],
		UIState.TERMINATED: [] # Terminal state
	}

func _setup_state_guards() -> void:
	"""Define state transition guard conditions"""
	state_guards = {
		UIState.LOADING_PANEL: _can_load_panel,
		UIState.TRANSITIONING: _can_transition_phase,
		UIState.SAVING_STATE: _can_save_state,
		UIState.LOADING_STATE: _can_load_state,
		UIState.EMERGENCY_ROLLBACK: _can_emergency_rollback
	}

func _setup_state_timeouts() -> void:
	"""Define state timeout durations (in seconds)"""
	state_timeouts = {
		UIState.VALIDATING_INPUT: 10.0,
		UIState.LOADING_PANEL: 15.0,
		UIState.TRANSITIONING: 10.0,
		UIState.SAVING_STATE: 30.0,
		UIState.LOADING_STATE: 30.0,
		UIState.ERROR_RECOVERY: 60.0,
		UIState.EMERGENCY_ROLLBACK: 30.0
	}

func _setup_state_actions() -> void:
	"""Define entry and exit actions for states"""
	state_entry_actions = {
		UIState.IDLE: _on_enter_idle,
		UIState.LOADING_PANEL: _on_enter_loading_panel,
		UIState.PANEL_ACTIVE: _on_enter_panel_active,
		UIState.ERROR_RECOVERY: _on_enter_error_recovery,
		UIState.EMERGENCY_ROLLBACK: _on_enter_emergency_rollback
	}
	
	state_exit_actions = {
		UIState.LOADING_PANEL: _on_exit_loading_panel,
		UIState.PANEL_ACTIVE: _on_exit_panel_active,
		UIState.ERROR_RECOVERY: _on_exit_error_recovery
	}

## State Transition Management

func request_transition(target_state: UIState, event_data: Dictionary = {}) -> bool:
	"""Request a state transition with validation and guards"""
	state_lock.lock()
	
	# CRITICAL FIX: Ensure unlock is called in all code paths
	var transition_result = false
	
	if transition_in_progress:
		_log_state_event("TRANSITION_BLOCKED", "Transition already in progress")
		state_lock.unlock()
		return false
	
	# Validate transition is allowed
	if not _is_transition_valid(current_state, target_state):
		var reason = "Invalid transition from %s to %s" % [_state_to_string(current_state), _state_to_string(target_state)]
		state_transition_blocked.emit(current_state, target_state, reason)
		_log_state_event("TRANSITION_BLOCKED", reason)
		state_lock.unlock()
		return false
	
	# Check guard conditions
	if not _check_transition_guards(target_state, event_data):
		var reason = "Guard condition failed for transition to %s" % _state_to_string(target_state)
		state_transition_blocked.emit(current_state, target_state, reason)
		_log_state_event("TRANSITION_BLOCKED", reason)
		state_lock.unlock()
		return false
	
	# Execute transition
	transition_result = _execute_transition(target_state, event_data)
	state_lock.unlock()
	return transition_result

func _execute_transition(target_state: UIState, event_data: Dictionary) -> bool:
	"""Execute the state transition"""
	transition_in_progress = true
	var old_state = current_state
	
	# Record state history
	_record_state_transition(old_state, target_state)
	
	# Execute exit actions
	if state_exit_actions.has(old_state):
		var exit_action = state_exit_actions[old_state]
		if exit_action:
			exit_action.call(event_data)
	
	# Update state
	previous_state = current_state
	current_state = target_state
	
	# Execute entry actions
	if state_entry_actions.has(target_state):
		var entry_action = state_entry_actions[target_state]
		if entry_action:
			entry_action.call(event_data)
	
	# Setup state timeout
	_setup_state_timeout(target_state)
	
	# Create checkpoint for recovery
	if auto_checkpoint_enabled and target_state != UIState.ERROR_RECOVERY:
		_create_state_checkpoint()
	
	# Emit signals
	state_changed.emit(old_state, target_state)
	
	_log_state_event("TRANSITION_SUCCESS", "Transitioned from %s to %s" % [_state_to_string(old_state), _state_to_string(target_state)])
	
	transition_in_progress = false
	return true

## State Validation and Guards

func _is_transition_valid(from_state: UIState, to_state: UIState) -> bool:
	"""Check if transition is allowed by state machine definition"""
	if not state_transitions.has(from_state):
		return false
	
	var allowed_transitions = state_transitions[from_state]
	return to_state in allowed_transitions

func _check_transition_guards(target_state: UIState, event_data: Dictionary) -> bool:
	"""Check guard conditions for state transition"""
	if not state_guards.has(target_state):
		return true # No guard means transition is allowed
	
	var guard_function = state_guards[target_state]
	if guard_function:
		return guard_function.call(event_data)
	
	return true

# Guard condition functions
func _can_load_panel(event_data: Dictionary) -> bool:
	"""Guard: Check if panel can be loaded"""
	return event_data.has("panel_path") and FileAccess.file_exists(event_data["panel_path"])

func _can_transition_phase(event_data: Dictionary) -> bool:
	"""Guard: Check if phase transition is allowed"""
	return event_data.has("target_phase") and event_data.has("validation_passed") and event_data["validation_passed"]

func _can_save_state(event_data: Dictionary) -> bool:
	"""Guard: Check if state can be saved"""
	return current_state != UIState.ERROR_RECOVERY and current_state != UIState.EMERGENCY_ROLLBACK

func _can_load_state(event_data: Dictionary) -> bool:
	"""Guard: Check if state can be loaded"""
	return event_data.has("save_data") and not event_data["save_data"].is_empty()

func _can_emergency_rollback(event_data: Dictionary) -> bool:
	"""Guard: Check if emergency rollback is allowed"""
	return emergency_rollback_count < max_emergency_rollbacks and last_known_good_state != UIState.UNINITIALIZED

## State Actions

func _on_enter_idle(event_data: Dictionary) -> void:
	"""Action: Entering IDLE state"""
	last_known_good_state = UIState.IDLE
	emergency_rollback_count = 0 # Reset rollback count on successful idle

func _on_enter_loading_panel(event_data: Dictionary) -> void:
	"""Action: Entering LOADING_PANEL state"""
	_log_state_event("PANEL_LOAD_START", "Loading panel: %s" % event_data.get("panel_path", "unknown"))

func _on_enter_panel_active(event_data: Dictionary) -> void:
	"""Action: Entering PANEL_ACTIVE state"""
	last_known_good_state = UIState.PANEL_ACTIVE

func _on_enter_error_recovery(event_data: Dictionary) -> void:
	"""Action: Entering ERROR_RECOVERY state"""
	recovery_initiated.emit("ERROR_RECOVERY")
	_log_state_event("ERROR_RECOVERY_START", "Error recovery initiated: %s" % event_data.get("error_type", "unknown"))

func _on_enter_emergency_rollback(event_data: Dictionary) -> void:
	"""Action: Entering EMERGENCY_ROLLBACK state"""
	emergency_rollback_count += 1
	recovery_initiated.emit("EMERGENCY_ROLLBACK")
	_log_state_event("EMERGENCY_ROLLBACK_START", "Emergency rollback #%d initiated" % emergency_rollback_count)

func _on_exit_loading_panel(event_data: Dictionary) -> void:
	"""Action: Exiting LOADING_PANEL state"""
	_cleanup_loading_resources()

func _on_exit_panel_active(event_data: Dictionary) -> void:
	"""Action: Exiting PANEL_ACTIVE state"""
	_save_panel_state()

func _on_exit_error_recovery(event_data: Dictionary) -> void:
	"""Action: Exiting ERROR_RECOVERY state"""
	_cleanup_error_recovery_resources()

## State Timeout Management

func _setup_state_timeout(state: UIState) -> void:
	"""Setup timeout for state if defined"""
	if current_timeout_timer:
		current_timeout_timer.queue_free()
		current_timeout_timer = null
	
	if not state_timeouts.has(state):
		return
	
	var timeout_duration = state_timeouts[state]
	current_timeout_timer = Timer.new()
	current_timeout_timer.wait_time = timeout_duration
	current_timeout_timer.one_shot = true
	current_timeout_timer.timeout.connect(_on_state_timeout)
	current_timeout_timer.start()

func _on_state_timeout() -> void:
	"""Handle state timeout"""
	_log_state_event("STATE_TIMEOUT", "State %s timed out" % _state_to_string(current_state))
	
	match current_state:
		UIState.LOADING_PANEL:
			_trigger_error_recovery("PANEL_LOAD_TIMEOUT", "Panel loading timed out")
		UIState.TRANSITIONING:
			_trigger_error_recovery("TRANSITION_TIMEOUT", "Phase transition timed out")
		UIState.ERROR_RECOVERY:
			request_transition(UIState.EMERGENCY_ROLLBACK, {"reason": "ERROR_RECOVERY_TIMEOUT"})
		_:
			_trigger_error_recovery("STATE_TIMEOUT", "Generic state timeout")

## Error Handling and Recovery

func _trigger_error_recovery(error_type: String, details: String) -> void:
	"""Trigger error recovery process"""
	state_machine_error.emit(error_type, details)
	request_transition(UIState.ERROR_RECOVERY, {
		"error_type": error_type,
		"details": details,
		"previous_state": current_state
	})

func recover_from_error() -> bool:
	"""Attempt to recover from error state"""
	if current_state != UIState.ERROR_RECOVERY:
		return false
	
	# Try to return to last known good state
	if last_known_good_state != UIState.UNINITIALIZED:
		return request_transition(last_known_good_state, {"recovery_type": "LAST_KNOWN_GOOD"})
	else:
		return request_transition(UIState.IDLE, {"recovery_type": "FALLBACK_IDLE"})

func emergency_rollback() -> bool:
	"""Perform emergency rollback to safe state"""
	if emergency_rollback_count >= max_emergency_rollbacks:
		_log_state_event("EMERGENCY_ROLLBACK_EXHAUSTED", "Maximum emergency rollbacks reached")
		return request_transition(UIState.TERMINATED, {"reason": "MAX_ROLLBACKS_REACHED"})
	
	return request_transition(UIState.EMERGENCY_ROLLBACK, {
		"rollback_count": emergency_rollback_count,
		"target_state": UIState.IDLE
	})

## State Persistence and Checkpointing

func _create_state_checkpoint() -> void:
	"""Create a checkpoint of current state for recovery"""
	state_checkpoint_data = {
		"state": current_state,
		"previous_state": previous_state,
		"state_history": state_history.duplicate(),
		"timestamp": Time.get_unix_time_from_system(),
		"last_known_good_state": last_known_good_state
	}

func restore_from_checkpoint() -> bool:
	"""Restore state from checkpoint"""
	if state_checkpoint_data.is_empty():
		return false
	
	var checkpoint_state = state_checkpoint_data.get("state", UIState.IDLE)
	return request_transition(checkpoint_state, {"restore_type": "CHECKPOINT"})

## Monitoring and Diagnostics

func _initialize_monitoring() -> void:
	"""Initialize performance monitoring"""
	for state in UIState.values():
		state_durations[state] = []
		transition_counts[state] = 0
		error_counts[state] = 0

func _record_state_transition(from_state: UIState, to_state: UIState) -> void:
	"""Record state transition for monitoring"""
	# Update history
	state_history.append(to_state)
	if state_history.size() > max_history_length:
		state_history.pop_front()
	
	# Record timing
	var now = Time.get_unix_time_from_system()
	if state_enter_times.has(from_state):
		var duration = now - state_enter_times[from_state]
		if not state_durations.has(from_state):
			state_durations[from_state] = []
		state_durations[from_state].append(duration)
	
	state_enter_times[to_state] = now
	transition_counts[to_state] = transition_counts.get(to_state, 0) + 1

func get_state_statistics() -> Dictionary:
	"""Get comprehensive state machine statistics"""
	return {
		"current_state": _state_to_string(current_state),
		"previous_state": _state_to_string(previous_state),
		"state_history": state_history.map(_state_to_string),
		"transition_counts": _convert_enum_keys_to_strings(transition_counts),
		"error_counts": _convert_enum_keys_to_strings(error_counts),
		"emergency_rollback_count": emergency_rollback_count,
		"last_known_good_state": _state_to_string(last_known_good_state),
		"transition_in_progress": transition_in_progress
	}

func get_performance_report() -> Dictionary:
	"""Get performance metrics for the state machine"""
	var avg_durations = {}
	for state in state_durations.keys():
		var durations = state_durations[state]
		if durations.size() > 0:
			var total = durations.reduce(func(a, b): return a + b, 0.0)
			avg_durations[_state_to_string(state)] = total / durations.size()
	
	return {
		"average_state_durations": avg_durations,
		"total_transitions": transition_counts.values().reduce(func(a, b): return a + b, 0),
		"total_errors": error_counts.values().reduce(func(a, b): return a + b, 0),
		"rollback_usage": float(emergency_rollback_count) / float(max_emergency_rollbacks) * 100.0
	}

## Utility Functions

func _state_to_string(state: UIState) -> String:
	"""Convert state enum to string"""
	match state:
		UIState.UNINITIALIZED: return "UNINITIALIZED"
		UIState.IDLE: return "IDLE"
		UIState.VALIDATING_INPUT: return "VALIDATING_INPUT"
		UIState.LOADING_PANEL: return "LOADING_PANEL"
		UIState.PANEL_ACTIVE: return "PANEL_ACTIVE"
		UIState.TRANSITIONING: return "TRANSITIONING"
		UIState.SAVING_STATE: return "SAVING_STATE"
		UIState.LOADING_STATE: return "LOADING_STATE"
		UIState.ERROR_RECOVERY: return "ERROR_RECOVERY"
		UIState.EMERGENCY_ROLLBACK: return "EMERGENCY_ROLLBACK"
		UIState.TERMINATED: return "TERMINATED"
		_: return "UNKNOWN"

func _convert_enum_keys_to_strings(dict: Dictionary) -> Dictionary:
	"""Convert enum keys to strings for serialization"""
	var result = {}
	for key in dict.keys():
		result[_state_to_string(key)] = dict[key]
	return result

func _log_state_event(event_type: String, details: String) -> void:
	"""Log state machine events with security integration"""
	print("CampaignCreationStateMachine: [%s] %s" % [event_type, details])
	
	if security_manager:
		security_manager.log_audit_event(
			CampaignSecurityManager.AuditEvent.CAMPAIGN_LOADED, # Using closest available event
			{
				"event_type": event_type,
				"details": details,
				"current_state": _state_to_string(current_state),
				"component": "CampaignCreationStateMachine"
			}
		)

## Resource Cleanup

func _cleanup_loading_resources() -> void:
	"""Clean up resources from loading state"""
	pass # Override in subclasses if needed

func _save_panel_state() -> void:
	"""Save current panel state before exit"""
	pass # Override in subclasses if needed

func _cleanup_error_recovery_resources() -> void:
	"""Clean up error recovery resources"""
	pass # Override in subclasses if needed

func cleanup() -> void:
	"""Clean up state machine resources"""
	if current_timeout_timer:
		current_timeout_timer.queue_free()
		current_timeout_timer = null
	
	request_transition(UIState.TERMINATED, {"cleanup": true})
	
	# Clear all data
	state_history.clear()
	state_checkpoint_data.clear()
	state_enter_times.clear()
	state_durations.clear()
	
	_log_state_event("STATE_MACHINE_CLEANUP", "State machine cleaned up")