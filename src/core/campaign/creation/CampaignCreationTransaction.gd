class_name CampaignCreationTransaction
extends RefCounted

## Enterprise-grade Transaction Management for Campaign Creation
## Provides atomic operations with rollback capability for multi-step processes

const FiveParsecsValidationResult = preload("res://src/core/validation/ValidationResult.gd")
const SecurityValidator = preload("res://src/core/validation/SecurityValidator.gd")

# Transaction states
enum TransactionState {
	PENDING,
	ACTIVE,
	COMMITTED,
	ROLLED_BACK,
	FAILED
}

# Transaction metadata
var transaction_id: String
var transaction_state: TransactionState = TransactionState.PENDING
var created_at: float
var started_at: float = 0.0
var completed_at: float = 0.0

# Operation tracking
var operations: Array[Dictionary] = []
var rollback_operations: Array[Dictionary] = []
var current_operation_index: int = 0

# State snapshots for rollback
var initial_state_snapshot: Dictionary = {}
var intermediate_snapshots: Array[Dictionary] = []

# Error tracking
var transaction_errors: Array[String] = []
var last_error: String = ""

# Concurrency protection
var _operation_lock: Mutex = Mutex.new()
var _is_executing: bool = false

signal transaction_started(transaction_id: String)
signal operation_completed(operation_index: int, operation_type: String)
signal transaction_committed(transaction_id: String, final_data: Dictionary)
signal transaction_rolled_back(transaction_id: String, reason: String)
signal transaction_failed(transaction_id: String, error: String)

func _init() -> void:
	transaction_id = _generate_transaction_id()
	created_at = Time.get_unix_time_from_system()

func _generate_transaction_id() -> String:
	## Generate unique transaction ID
	var timestamp = Time.get_unix_time_from_system()
	var random_suffix = randi() % 10000
	return "txn_%d_%04d" % [timestamp, random_suffix]

## Transaction Lifecycle Management

func begin_transaction(initial_state: Dictionary) -> bool:
	## Begin the transaction with initial state snapshot
	_operation_lock.lock()
	
	if transaction_state != TransactionState.PENDING:
		_operation_lock.unlock()
		last_error = "Transaction already started or completed"
		return false
	
	if _is_executing:
		_operation_lock.unlock()
		last_error = "Transaction already executing"
		return false
	
	# Create initial state snapshot
	initial_state_snapshot = initial_state.duplicate(true)
	
	# Initialize transaction
	transaction_state = TransactionState.ACTIVE
	started_at = Time.get_unix_time_from_system()
	_is_executing = false
	
	_operation_lock.unlock()
	
	transaction_started.emit(transaction_id)
	return true

func add_operation(operation_type: String, operation_data: Dictionary, rollback_data: Dictionary = {}) -> bool:
	## Add operation to transaction queue
	if transaction_state != TransactionState.ACTIVE:
		last_error = "Transaction not active"
		return false
	
	var operation = {
		"type": operation_type,
		"data": operation_data.duplicate(true),
		"rollback_data": rollback_data.duplicate(true),
		"timestamp": Time.get_unix_time_from_system(),
		"executed": false
	}
	
	operations.append(operation)
	return true

func execute_operations(state_manager: RefCounted) -> bool:
	## Execute all queued operations atomically
	_operation_lock.lock()
	
	if transaction_state != TransactionState.ACTIVE:
		_operation_lock.unlock()
		last_error = "Transaction not active"
		return false
	
	if _is_executing:
		_operation_lock.unlock()
		last_error = "Transaction already executing"
		return false
	
	_is_executing = true
	_operation_lock.unlock()
	
	# Execute operations sequentially
	for i in range(operations.size()):
		var operation = operations[i]
		current_operation_index = i
		
		# Create intermediate state snapshot before operation
		var current_state = _get_state_snapshot(state_manager)
		intermediate_snapshots.append(current_state)
		
		# Execute operation
		var success = _execute_single_operation(operation, state_manager)
		if not success:
			# Rollback on failure
			_rollback_to_initial_state(state_manager)
			_is_executing = false
			transaction_state = TransactionState.FAILED
			transaction_failed.emit(transaction_id, last_error)
			return false
		
		operation.executed = true
		operation_completed.emit(i, operation.type)
	
	_is_executing = false
	return true

func commit_transaction(state_manager: RefCounted) -> Dictionary:
	## Commit transaction and return final state
	if transaction_state != TransactionState.ACTIVE:
		last_error = "Transaction not active for commit"
		return {}
	
	if _is_executing:
		last_error = "Cannot commit while executing"
		return {}
	
	# Validate final state
	var final_state = _get_state_snapshot(state_manager)
	var validation_result = _validate_final_state(final_state)
	
	if not validation_result.valid:
		last_error = "Final state validation failed: " + validation_result.error
		_rollback_to_initial_state(state_manager)
		transaction_state = TransactionState.FAILED
		transaction_failed.emit(transaction_id, last_error)
		return {}
	
	# Commit successful
	transaction_state = TransactionState.COMMITTED
	completed_at = Time.get_unix_time_from_system()
	
	transaction_committed.emit(transaction_id, final_state)
	return final_state

func rollback_transaction(state_manager: RefCounted, reason: String = "") -> bool:
	## Rollback transaction to initial state
	if transaction_state == TransactionState.ROLLED_BACK:
		return true
	
	if transaction_state != TransactionState.ACTIVE and transaction_state != TransactionState.FAILED:
		last_error = "Transaction not in rollback-able state"
		return false
	
	var rollback_reason = reason if not reason.is_empty() else "Manual rollback"
	var success = _rollback_to_initial_state(state_manager)
	
	if success:
		transaction_state = TransactionState.ROLLED_BACK
		completed_at = Time.get_unix_time_from_system()
		transaction_rolled_back.emit(transaction_id, rollback_reason)
	
	return success

## Operation Execution

func _execute_single_operation(operation: Dictionary, state_manager: RefCounted) -> bool:
	## Execute a single operation with error handling
	var operation_type = operation.type
	var operation_data = operation.data
	
	
	match operation_type:
		"update_captain":
			return _execute_captain_update(operation_data, state_manager)
		"update_crew":
			return _execute_crew_update(operation_data, state_manager)
		"update_config":
			return _execute_config_update(operation_data, state_manager)
		"confirm_captain":
			return _execute_captain_confirmation(operation_data, state_manager)
		"validate_phase":
			return _execute_phase_validation(operation_data, state_manager)
		_:
			last_error = "Unknown operation type: " + operation_type
			return false

func _execute_captain_update(data: Dictionary, state_manager: RefCounted) -> bool:
	## Execute captain data update operation
	if not state_manager.has_method("update_captain_data"):
		last_error = "State manager missing update_captain_data method"
		return false
	
	# Validate captain data with security checks
	var validation_result = _validate_captain_data(data)
	if not validation_result.valid:
		last_error = "Captain data validation failed: " + validation_result.error
		return false
	
	# Execute update
	var success = state_manager.update_captain_data(validation_result.sanitized_value)
	if not success:
		last_error = "Failed to update captain data in state manager"
		return false
	
	return true

func _execute_crew_update(data: Dictionary, state_manager: RefCounted) -> bool:
	## Execute crew data update operation
	if not state_manager.has_method("update_crew_data"):
		last_error = "State manager missing update_crew_data method"
		return false
	
	var success = state_manager.update_crew_data(data)
	if not success:
		last_error = "Failed to update crew data in state manager"
		return false
	
	return true

func _execute_config_update(data: Dictionary, state_manager: RefCounted) -> bool:
	## Execute config data update operation
	if not state_manager.has_method("update_config_data"):
		last_error = "State manager missing update_config_data method"
		return false
	
	var success = state_manager.update_config_data(data)
	if not success:
		last_error = "Failed to update config data in state manager"
		return false
	
	return true

func _execute_captain_confirmation(data: Dictionary, state_manager: RefCounted) -> bool:
	## Execute captain confirmation operation
	if not state_manager.has_method("confirm_captain_creation"):
		last_error = "State manager missing confirm_captain_creation method"
		return false
	
	var result = state_manager.confirm_captain_creation(data)
	if not result.get("success", false):
		last_error = "Captain confirmation failed: " + result.get("error", "Unknown error")
		return false
	
	return true

func _execute_phase_validation(data: Dictionary, state_manager: RefCounted) -> bool:
	## Execute phase validation operation
	var phase = data.get("phase", -1)
	if phase == -1:
		last_error = "Invalid phase for validation"
		return false
	
	if not state_manager.has_method("validate_phase"):
		last_error = "State manager missing validate_phase method"
		return false
	
	var is_valid = state_manager.validate_phase(phase)
	if not is_valid:
		last_error = "Phase validation failed for phase " + str(phase)
		return false
	
	return true

## State Management

func _get_state_snapshot(state_manager: RefCounted) -> Dictionary:
	## Get current state snapshot from state manager
	if state_manager.has_method("get_campaign_data"):
		return state_manager.get_campaign_data()
	elif state_manager.has_method("export_for_save"):
		return state_manager.export_for_save()
	else:
		return {}

func _rollback_to_initial_state(state_manager: RefCounted) -> bool:
	## Rollback state manager to initial snapshot
	if initial_state_snapshot.is_empty():
		last_error = "No initial state snapshot available"
		return false
	
	if state_manager.has_method("import_from_save"):
		return state_manager.import_from_save(initial_state_snapshot)
	else:
		# Manual rollback using individual update methods
		return _manual_state_rollback(state_manager)

func _manual_state_rollback(state_manager: RefCounted) -> bool:
	## Manual rollback using individual state updates
	var success = true
	
	# Rollback captain data
	if initial_state_snapshot.has("captain") and state_manager.has_method("update_captain_data"):
		success = success and state_manager.update_captain_data(initial_state_snapshot.captain)
	
	# Rollback crew data
	if initial_state_snapshot.has("crew") and state_manager.has_method("update_crew_data"):
		success = success and state_manager.update_crew_data(initial_state_snapshot.crew)
	
	# Rollback config data
	if initial_state_snapshot.has("config") and state_manager.has_method("update_config_data"):
		success = success and state_manager.update_config_data(initial_state_snapshot.config)
	
	return success

## Validation

func _validate_final_state(final_state: Dictionary) -> FiveParsecsValidationResult:
	## Validate final transaction state
	var result = FiveParsecsValidationResult.new()
	result.valid = true
	
	# Validate required keys exist
	var required_keys = ["config", "crew", "captain"]
	for key in required_keys:
		if not final_state.has(key):
			result.valid = false
			result.error = "Missing required state key: " + key
			return result
	
	# Validate data integrity
	if final_state.captain.is_empty():
		result.valid = false
		result.error = "Captain data is empty in final state"
		return result
	
	result.sanitized_value = final_state
	return result

func _validate_captain_data(captain_data: Dictionary) -> FiveParsecsValidationResult:
	## Validate captain data with security checks
	var result = FiveParsecsValidationResult.new()
	
	# Basic validation
	if not captain_data.has("character_name") or captain_data.character_name.is_empty():
		result.valid = false
		result.error = "Captain name is required"
		return result
	
	# Security validation
	var security_validator = SecurityValidator.new()
	var name_validation = security_validator.validate_character_name(captain_data.character_name)
	if not name_validation.valid:
		result.valid = false
		result.error = "Captain name security validation failed: " + name_validation.error
		return result
	
	# Create sanitized data
	var sanitized_data = captain_data.duplicate()
	sanitized_data.character_name = name_validation.sanitized_value
	
	result.valid = true
	result.sanitized_value = sanitized_data
	return result

## Utility Methods

func get_transaction_status() -> Dictionary:
	## Get comprehensive transaction status
	return {
		"transaction_id": transaction_id,
		"state": TransactionState.keys()[transaction_state],
		"created_at": created_at,
		"started_at": started_at,
		"completed_at": completed_at,
		"operations_count": operations.size(),
		"executed_operations": current_operation_index,
		"is_executing": _is_executing,
		"has_errors": not transaction_errors.is_empty(),
		"last_error": last_error
	}

func get_operation_history() -> Array[Dictionary]:
	## Get history of all operations
	var history: Array[Dictionary] = []
	for i in range(operations.size()):
		var op = operations[i]
		history.append({
			"index": i,
			"type": op.type,
			"executed": op.executed,
			"timestamp": op.timestamp
		})
	return history

func is_transaction_complete() -> bool:
	## Check if transaction is in a completed state
	return transaction_state == TransactionState.COMMITTED or \
		   transaction_state == TransactionState.ROLLED_BACK or \
		   transaction_state == TransactionState.FAILED

func cleanup_transaction() -> void:
	## Clean up transaction resources
	operations.clear()
	rollback_operations.clear()
	intermediate_snapshots.clear()
	initial_state_snapshot.clear()
	transaction_errors.clear()
	