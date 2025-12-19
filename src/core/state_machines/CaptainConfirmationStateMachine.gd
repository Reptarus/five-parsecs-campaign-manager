class_name CaptainConfirmationStateMachine
extends RefCounted

## Captain Confirmation State Machine
##
## Manages the complex state transitions during captain creation and confirmation
## Provides event-driven state management with validation guards and recovery mechanisms

# State enumeration
enum State {
	IDLE,           # No captain creation in progress
	EDITING,        # Captain is being created/edited
	VALIDATING,     # Captain data is being validated
	CONFIRMING,     # Captain confirmation is in progress
	CONFIRMED,      # Captain has been successfully confirmed
	ERROR,          # Error state - requires intervention
	RECOVERY        # Attempting to recover from error
}

# Event enumeration
enum Event {
	START_CREATION,     # Begin captain creation
	EDIT_CAPTAIN,       # Edit existing captain
	VALIDATE_DATA,      # Trigger validation
	VALIDATION_PASSED,  # Validation successful
	VALIDATION_FAILED,  # Validation failed
	CONFIRM_CAPTAIN,    # Begin confirmation process
	CONFIRMATION_SUCCESS, # Confirmation completed
	CONFIRMATION_FAILED, # Confirmation failed
	ERROR_OCCURRED,     # Unexpected error
	RESET,             # Reset to idle state
	RETRY_OPERATION    # Retry current operation
}

# State machine signals
signal state_changed(from_state: State, to_state: State, event: Event)
signal validation_status_changed(is_valid: bool, errors: Array[String])
signal confirmation_status_changed(is_confirmed: bool, captain_data: Dictionary)
signal error_occurred(error_message: String, recovery_options: Array[String])
signal operation_progress(operation: String, progress: float, message: String)

# State machine data
var current_state: State = State.IDLE
var previous_state: State = State.IDLE
var captain_data: Dictionary = {}
var validation_errors: Array[String] = []
var confirmation_result: Dictionary = {}
var error_context: Dictionary = {}

# State transition table - defines valid transitions
var transition_table: Dictionary = {
	State.IDLE: [State.EDITING, State.ERROR],
	State.EDITING: [State.VALIDATING, State.IDLE, State.ERROR],
	State.VALIDATING: [State.EDITING, State.CONFIRMING, State.ERROR],
	State.CONFIRMING: [State.CONFIRMED, State.ERROR, State.RECOVERY],
	State.CONFIRMED: [State.EDITING, State.IDLE],
	State.ERROR: [State.RECOVERY, State.IDLE, State.EDITING],
	State.RECOVERY: [State.EDITING, State.VALIDATING, State.ERROR, State.IDLE]
}

# Operation tracking
var current_operation: String = ""
var operation_start_time: float = 0.0
var retry_count: int = 0
var max_retries: int = 3

func _init() -> void:
	print("CaptainConfirmationStateMachine: Initialized")

## Public API Methods

func start_captain_creation(initial_data: Dictionary = {}) -> bool:
	"""Start the captain creation process"""
	if not _can_transition_to(State.EDITING):
		push_warning("CaptainConfirmationStateMachine: Cannot start creation from state %s" % get_state_name(current_state))
		return false
	
	captain_data = initial_data.duplicate()
	validation_errors.clear()
	confirmation_result.clear()
	retry_count = 0
	
	return _transition_to_state(State.EDITING, Event.START_CREATION)

func edit_captain(captain_data_dict: Dictionary) -> bool:
	"""Edit existing captain data"""
	if not _can_transition_to(State.EDITING):
		push_warning("CaptainConfirmationStateMachine: Cannot edit captain from state %s" % get_state_name(current_state))
		return false
	
	captain_data = captain_data_dict.duplicate()
	validation_errors.clear()
	
	return _transition_to_state(State.EDITING, Event.EDIT_CAPTAIN)

func validate_captain() -> bool:
	"""Trigger captain validation"""
	if current_state != State.EDITING:
		push_warning("CaptainConfirmationStateMachine: Cannot validate from state %s" % get_state_name(current_state))
		return false
	
	current_operation = "validation"
	operation_start_time = Time.get_unix_time_from_system()
	
	return _transition_to_state(State.VALIDATING, Event.VALIDATE_DATA)

func set_validation_result(is_valid: bool, errors: Array = []) -> bool:
	"""Set the result of captain validation"""
	if current_state != State.VALIDATING:
		push_warning("CaptainConfirmationStateMachine: Cannot set validation result from state %s" % get_state_name(current_state))
		return false
	
	validation_errors = errors.duplicate()
	validation_status_changed.emit(is_valid, validation_errors)
	
	if is_valid:
		return _transition_to_state(State.CONFIRMING, Event.VALIDATION_PASSED)
	else:
		return _transition_to_state(State.EDITING, Event.VALIDATION_FAILED)

func confirm_captain() -> bool:
	"""Begin captain confirmation process"""
	if current_state != State.CONFIRMING:
		push_warning("CaptainConfirmationStateMachine: Cannot confirm from state %s" % get_state_name(current_state))
		return false
	
	current_operation = "confirmation"
	operation_start_time = Time.get_unix_time_from_system()
	
	# Emit progress signal
	operation_progress.emit("confirmation", 0.0, "Starting captain confirmation...")
	
	return true

func set_confirmation_result(success: bool, result_data: Dictionary = {}) -> bool:
	"""Set the result of captain confirmation"""
	if current_state != State.CONFIRMING:
		push_warning("CaptainConfirmationStateMachine: Cannot set confirmation result from state %s" % get_state_name(current_state))
		return false
	
	confirmation_result = result_data.duplicate()
	confirmation_status_changed.emit(success, captain_data)
	
	if success:
		operation_progress.emit("confirmation", 1.0, "Captain confirmation successful!")
		return _transition_to_state(State.CONFIRMED, Event.CONFIRMATION_SUCCESS)
	else:
		var error_msg = result_data.get("error", "Confirmation failed")
		_handle_error("Confirmation failed: " + error_msg, ["Retry confirmation", "Edit captain", "Reset"])
		return _transition_to_state(State.ERROR, Event.CONFIRMATION_FAILED)

func handle_error(error_message: String, recovery_options: Array = []) -> bool:
	"""Handle an error condition"""
	_handle_error(error_message, recovery_options)
	return _transition_to_state(State.ERROR, Event.ERROR_OCCURRED)

func reset_state_machine() -> bool:
	"""Reset state machine to idle state"""
	captain_data.clear()
	validation_errors.clear()
	confirmation_result.clear()
	error_context.clear()
	current_operation = ""
	retry_count = 0
	
	return _transition_to_state(State.IDLE, Event.RESET)

func retry_current_operation() -> bool:
	"""Retry the current operation"""
	if current_state != State.ERROR:
		push_warning("CaptainConfirmationStateMachine: Cannot retry from state %s" % get_state_name(current_state))
		return false
	
	if retry_count >= max_retries:
		_handle_error("Maximum retry attempts reached", ["Reset state machine", "Manual intervention required"])
		return false
	
	retry_count += 1
	print("CaptainConfirmationStateMachine: Retrying operation (attempt %d/%d)" % [retry_count, max_retries])
	
	# Transition to recovery state
	if not _transition_to_state(State.RECOVERY, Event.RETRY_OPERATION):
		return false
	
	# Determine which state to recover to based on the failed operation
	match current_operation:
		"validation":
			return _transition_to_state(State.VALIDATING, Event.VALIDATE_DATA)
		"confirmation":
			return _transition_to_state(State.CONFIRMING, Event.CONFIRM_CAPTAIN)
		_:
			return _transition_to_state(State.EDITING, Event.EDIT_CAPTAIN)

## State Machine Core Methods

func _can_transition_to(target_state: State) -> bool:
	"""Check if transition to target state is valid"""
	if not transition_table.has(current_state):
		return false
	
	return target_state in transition_table[current_state]

func _transition_to_state(new_state: State, event: Event) -> bool:
	"""Execute state transition with validation"""
	if not _can_transition_to(new_state):
		push_error("CaptainConfirmationStateMachine: Invalid transition from %s to %s" % [
			get_state_name(current_state), 
			get_state_name(new_state)
		])
		return false
	
	var old_state = current_state
	previous_state = current_state
	current_state = new_state
	
	print("CaptainConfirmationStateMachine: %s -> %s (event: %s)" % [
		get_state_name(old_state),
		get_state_name(new_state),
		get_event_name(event)
	])
	
	# Execute state entry actions
	_on_state_entered(new_state, event)
	
	# Emit state change signal
	state_changed.emit(old_state, new_state, event)
	
	return true

func _on_state_entered(state: State, event: Event) -> void:
	"""Execute actions when entering a state"""
	match state:
		State.IDLE:
			_on_idle_entered()
		State.EDITING:
			_on_editing_entered(event)
		State.VALIDATING:
			_on_validating_entered()
		State.CONFIRMING:
			_on_confirming_entered()
		State.CONFIRMED:
			_on_confirmed_entered()
		State.ERROR:
			_on_error_entered()
		State.RECOVERY:
			_on_recovery_entered()

func _on_idle_entered() -> void:
	"""Actions when entering IDLE state"""
	current_operation = ""
	operation_progress.emit("idle", 1.0, "Ready for captain creation")

func _on_editing_entered(event: Event) -> void:
	"""Actions when entering EDITING state"""
	current_operation = "editing"
	
	match event:
		Event.START_CREATION:
			operation_progress.emit("editing", 0.2, "Captain creation started")
		Event.EDIT_CAPTAIN:
			operation_progress.emit("editing", 0.1, "Editing captain data")
		Event.VALIDATION_FAILED:
			operation_progress.emit("editing", 0.3, "Validation failed - please review captain data")

func _on_validating_entered() -> void:
	"""Actions when entering VALIDATING state"""
	operation_progress.emit("validation", 0.5, "Validating captain data...")

func _on_confirming_entered() -> void:
	"""Actions when entering CONFIRMING state"""
	operation_progress.emit("confirmation", 0.7, "Confirming captain creation...")

func _on_confirmed_entered() -> void:
	"""Actions when entering CONFIRMED state"""
	current_operation = "completed"
	operation_progress.emit("completed", 1.0, "Captain successfully created and confirmed!")

func _on_error_entered() -> void:
	"""Actions when entering ERROR state"""
	operation_progress.emit("error", 0.0, "Error occurred - recovery options available")

func _on_recovery_entered() -> void:
	"""Actions when entering RECOVERY state"""
	operation_progress.emit("recovery", 0.1, "Attempting recovery...")

func _handle_error(error_message: String, recovery_options: Array) -> void:
	"""Handle error with context and recovery options"""
	error_context = {
		"message": error_message,
		"recovery_options": recovery_options,
		"timestamp": Time.get_unix_time_from_system(),
		"current_operation": current_operation,
		"retry_count": retry_count
	}
	
	push_error("CaptainConfirmationStateMachine: %s" % error_message)
	error_occurred.emit(error_message, recovery_options)

## Utility Methods

func get_state_name(state: State) -> String:
	"""Get human-readable state name"""
	match state:
		State.IDLE: return "IDLE"
		State.EDITING: return "EDITING"
		State.VALIDATING: return "VALIDATING"
		State.CONFIRMING: return "CONFIRMING"
		State.CONFIRMED: return "CONFIRMED"
		State.ERROR: return "ERROR"
		State.RECOVERY: return "RECOVERY"
		_: return "UNKNOWN"

func get_event_name(event: Event) -> String:
	"""Get human-readable event name"""
	match event:
		Event.START_CREATION: return "START_CREATION"
		Event.EDIT_CAPTAIN: return "EDIT_CAPTAIN"
		Event.VALIDATE_DATA: return "VALIDATE_DATA"
		Event.VALIDATION_PASSED: return "VALIDATION_PASSED"
		Event.VALIDATION_FAILED: return "VALIDATION_FAILED"
		Event.CONFIRM_CAPTAIN: return "CONFIRM_CAPTAIN"
		Event.CONFIRMATION_SUCCESS: return "CONFIRMATION_SUCCESS"
		Event.CONFIRMATION_FAILED: return "CONFIRMATION_FAILED"
		Event.ERROR_OCCURRED: return "ERROR_OCCURRED"
		Event.RESET: return "RESET"
		Event.RETRY_OPERATION: return "RETRY_OPERATION"
		_: return "UNKNOWN"

func get_current_state_info() -> Dictionary:
	"""Get comprehensive current state information"""
	return {
		"current_state": current_state,
		"current_state_name": get_state_name(current_state),
		"previous_state": previous_state,
		"previous_state_name": get_state_name(previous_state),
		"current_operation": current_operation,
		"operation_duration": Time.get_unix_time_from_system() - operation_start_time if operation_start_time > 0 else 0.0,
		"retry_count": retry_count,
		"max_retries": max_retries,
		"has_captain_data": not captain_data.is_empty(),
		"validation_errors_count": validation_errors.size(),
		"is_confirmed": current_state == State.CONFIRMED,
		"can_retry": current_state == State.ERROR and retry_count < max_retries
	}

func is_busy() -> bool:
	"""Check if state machine is currently processing"""
	return current_state in [State.VALIDATING, State.CONFIRMING, State.RECOVERY]

func can_edit() -> bool:
	"""Check if captain can be edited in current state"""
	return current_state in [State.IDLE, State.EDITING, State.CONFIRMED, State.ERROR]

func can_validate() -> bool:
	"""Check if validation can be triggered in current state"""
	return current_state == State.EDITING

func can_confirm() -> bool:
	"""Check if confirmation can be started in current state"""
	return current_state == State.CONFIRMING

func is_confirmed() -> bool:
	"""Check if captain is confirmed"""
	return current_state == State.CONFIRMED

func has_errors() -> bool:
	"""Check if there are validation or other errors"""
	return current_state == State.ERROR or not validation_errors.is_empty()
