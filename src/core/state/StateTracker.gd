extends Node

const GameState = preload("res://src/core/state/GameState.gd")

signal state_changed(old_state: Dictionary, new_state: Dictionary)
signal state_updated(state: Dictionary)
signal state_reset
signal state_validated(is_valid: bool, issues: Array)
signal state_recovered(success: bool, recovery_info: Dictionary)
signal validation_rule_added(rule_name: String)
signal state_checkpoint_created(checkpoint_id: String)
signal state_checkpoint_restored(checkpoint_id: String)

var game_state: GameState
var current_state: Dictionary = {}
var state_history: Array[Dictionary] = []
var max_history_size: int = 100

# Enhanced state management
var validation_rules: Array[Callable] = []
var state_checkpoints: Dictionary = {}
var recovery_handlers: Dictionary = {}
var state_metadata: Dictionary = {}
var is_transitioning: bool = false

# Configuration
const MAX_CHECKPOINTS: int = 10
const VALIDATION_BATCH_SIZE: int = 50
const AUTO_RECOVERY_ENABLED: bool = true

func _init(p_game_state: GameState) -> void:
	game_state = p_game_state
	_initialize_state()
	_setup_default_validation_rules()
	_setup_recovery_handlers()

func _initialize_state() -> void:
	# Virtual method to be implemented by child classes
	current_state = {
		"credits": 0,
		"resources": {},
		"campaign_turns": 0
	}

func _setup_default_validation_rules() -> void:
	# Add basic validation rules
	add_validation_rule("type_check", _validate_state_types)
	add_validation_rule("required_fields", _validate_required_fields)
	add_validation_rule("value_ranges", _validate_value_ranges)

func _setup_recovery_handlers() -> void:
	# Setup default recovery handlers
	recovery_handlers = {
		"missing_fields": _recover_missing_fields,
		"invalid_values": _recover_invalid_values,
		"type_mismatch": _recover_type_mismatch,
		"corrupted_state": _recover_corrupted_state
	}

# Enhanced state update with validation
func update_state(new_values: Dictionary, skip_validation: bool = false) -> void:
	if is_transitioning:
		push_warning("State update attempted during transition")
		return

	is_transitioning = true
	var old_state: Dictionary = current_state.duplicate()

	# Create pre-update checkpoint
	var checkpoint_id: String = _create_checkpoint("pre_update")

	# Apply updates
	for key in new_values:
		var typed_key: Variant = key
		if current_state.has(key) and current_state[key] != new_values[key]:
			current_state[key] = new_values[key]

	# Validate if required
	if not skip_validation:
		var validation_result: Dictionary = validate_state()
		if validation_result.has("is_valid") and not validation_result.is_valid:
			if AUTO_RECOVERY_ENABLED:
				var issues: Array = validation_result.get("issues", [])
				var recovery_result: Dictionary = _attempt_recovery(issues)
				if recovery_result.has("success") and not recovery_result.success:
					_restore_checkpoint(checkpoint_id)
					is_transitioning = false
					return
			else:
				_restore_checkpoint(checkpoint_id)
				is_transitioning = false
				return

	_add_to_history(old_state)
	state_changed.emit(old_state, current_state)
	state_updated.emit(current_state)
	is_transitioning = false

# State _validation
func validate_state() -> Dictionary:
	var issues: Array = []
	var is_valid: bool = true

	for rule in validation_rules:
		if rule.is_valid():
			var result: Dictionary = rule.call(current_state)
			if result.has("valid") and result.has("valid") and not result.get("valid", true):
				is_valid = false
				if result.has("issues"):
					var result_issues: Variant = result.get("issues", [])
					if result_issues is Array:
						var rule_issues: Array = result_issues as Array
						issues.append_array(rule_issues)

	state_validated.emit(is_valid, issues)
	return {"is_valid": is_valid, "issues": issues}

func add_validation_rule(rule_name: String, rule: Callable) -> void:
	validation_rules.append(rule)
	validation_rule_added.emit(rule_name) # warning: return value discarded (intentional)

# Default validation rules
func _validate_state_types(state: Dictionary) -> Dictionary:
	var issues: Array = []
	for key in state:
		var typed_key: String = key as String
		var state_value: Variant = state.get(key)
		if not _is_valid_type(state_value):
			issues.append({"type": "type_mismatch", "key": key, "value": state_value})
	return {"valid": issues.is_empty(), "issues": issues}

func _validate_required_fields(state: Dictionary) -> Dictionary:
	var required_fields: Array[String] = ["credits", "resources", "campaign_turns"]
	var issues: Array = []

	for field in required_fields:
		var typed_field: Variant = field
		if not state.has(field):
			issues.append({"type": "missing_field", "field": field})

	return {"valid": issues.is_empty(), "issues": issues}

func _validate_value_ranges(state: Dictionary) -> Dictionary:
	var issues: Array = []

	if state.has("credits"):
		var credits_value: Variant = state.get("credits", 0)
		if credits_value is int:
			var credits: int = credits_value as int
			if credits < 0 or credits > 1000000:
				issues.append({"type": "invalid_range", "field": "credits", "value": credits})

	if state.has("campaign_turns"):
		var turns_value: Variant = state.get("campaign_turns", 0)
		if turns_value is int:
			var turns: int = turns_value as int
			if turns < 0:
				issues.append({"type": "invalid_range", "field": "campaign_turns", "value": turns})

	return {"valid": issues.is_empty(), "issues": issues}

# State recovery
func _attempt_recovery(issues: Array) -> Dictionary:
	var recovery_attempts: Array = []
	var success: bool = true

	for issue in issues:
		if issue is Dictionary:
			var issue_dict: Dictionary = issue as Dictionary
			var issue_type: String = issue_dict.get("type", "")

			if recovery_handlers.has(issue_type):
				var handler_variant: Variant = recovery_handlers.get(issue_type)
				if handler_variant is Callable:
					var handler: Callable = handler_variant as Callable
					if handler.is_valid():
						var result: Dictionary = handler.call(issue_dict)
						recovery_attempts.append(result)
						if result.has("success") and not result.get("success", false):
							success = false
					else:
						var failed_result: Dictionary = {"success": false, "reason": "invalid_handler", "type": issue_type}
						recovery_attempts.append(failed_result)
						success = false
				else:
					var failed_result: Dictionary = {"success": false, "reason": "handler_not_callable", "type": issue_type}
					recovery_attempts.append(failed_result)
					success = false
			else:
				var failed_result: Dictionary = {"success": false, "reason": "no_handler_found", "type": issue_type}
				recovery_attempts.append(failed_result)
				success = false
		else:
			var failed_result: Dictionary = {"success": false, "reason": "invalid_issue_format"}
			recovery_attempts.append(failed_result)
			success = false

	state_recovered.emit(success, {"attempts": recovery_attempts}) # warning: return value discarded (intentional)
	return {"success": success, "attempts": recovery_attempts}

# Recovery handlers
func _recover_missing_fields(issue: Dictionary) -> Dictionary:
	var field_variant: Variant = issue.get("field", "")
	if not field_variant is String:
		return {"success": false, "reason": "invalid_field_type"}

	var field: String = field_variant as String
	var default_values: Dictionary = {
		"credits": 0,
		"resources": {},
		"campaign_turns": 0
	}

	if default_values.has(field):
		current_state[field] = default_values[field]
		return {"success": true, "field": field, "action": "set_default"}

	return {"success": false, "field": field, "reason": "no_default_value"}

func _recover_invalid_values(issue: Dictionary) -> Dictionary:
	var field_variant: Variant = issue.get("field", "")
	var value_variant: Variant = issue.get("value", null)

	if not field_variant is String:
		return {"success": false, "reason": "invalid_field_type"}

	var field: String = field_variant as String

	match field:
		"credits":
			if value_variant is int:
				var value: int = value_variant as int
				current_state["credits"] = clampi(value, 0, 1000000)
				return {"success": true, "field": field, "action": "clamped_value"}
		"campaign_turns":
			if value_variant is int:
				var value: int = value_variant as int
				current_state["campaign_turns"] = maxi(0, value)
				return {"success": true, "field": field, "action": "clamped_value"}
		_:
			return {"success": false, "field": field, "reason": "unknown_field"}

	return {"success": false, "field": field, "reason": "invalid_value_type"}

func _recover_type_mismatch(issue: Dictionary) -> Dictionary:
	var key_variant: Variant = issue.get("key", "")
	var value_variant: Variant = issue.get("value", null)

	if not key_variant is String:
		return {"success": false, "reason": "invalid_key_type"}

	var key: String = key_variant as String

	# Attempt type conversion
	match typeof(value_variant):
		TYPE_STRING:
			if value_variant is String:
				var value: String = value_variant as String
				if value.is_valid_int():
					current_state[key] = value.to_int()
					return {"success": true, "key": key, "action": "converted_to_int"}
				if value.is_valid_float():
					current_state[key] = value.to_float()
					return {"success": true, "key": key, "action": "converted_to_float"}

	return {"success": false, "key": key, "reason": "conversion_failed"}

func _recover_corrupted_state(issue: Dictionary) -> Dictionary:
	# Attempt to recover from corruption by restoring last valid state
	if not state_history.is_empty():
		var last_entry: Dictionary = state_history[-1]
		if last_entry.has("state"):
			var last_state_variant: Variant = last_entry.get("state")
			if last_state_variant is Dictionary:
				current_state = last_state_variant.duplicate()
				return {"success": true, "action": "restored_last_valid"}

	# If no history, reset to initial state
	_initialize_state()
	return {"success": true, "action": "reset_to_initial"}

# Checkpoint management
func _create_checkpoint(label: String = "") -> String:
	var checkpoint_id: String = str(Time.get_unix_time_from_system()) + "_" + label
	state_checkpoints[checkpoint_id] = current_state.duplicate(true)

	# Maintain checkpoint limit
	while state_checkpoints.size() > MAX_CHECKPOINTS:
		var keys: Array = state_checkpoints.keys()
		if not keys.is_empty():
			var oldest: Variant = keys[0]
			if oldest is String:
				state_checkpoints.erase(oldest)
			else:
				break

	state_checkpoint_created.emit(checkpoint_id)
	return checkpoint_id

func _restore_checkpoint(checkpoint_id: String) -> bool:
	if not state_checkpoints.has(checkpoint_id):
		return false

	var checkpoint_data: Variant = state_checkpoints.get(checkpoint_id)
	if checkpoint_data is Dictionary:
		current_state = checkpoint_data.duplicate(true)
		state_checkpoint_restored.emit(checkpoint_id)
		return true

	return false

# Enhanced history management
func _add_to_history(state: Dictionary) -> void:
	var entry: Dictionary = {
		"state": state.duplicate(true),
		"timestamp": Time.get_unix_time_from_system(),
		"metadata": state_metadata.duplicate()
	}

	state_history.append(entry)
	while state_history.size() > max_history_size:
		state_history.pop_front()

# Utility functions
func _is_valid_type(value: Variant) -> bool:
	# Parameter validation - eliminates UNSAFE_CALL_ARGUMENT warnings
	if not is_instance_valid(self):
		return false
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_DICTIONARY, TYPE_ARRAY:
			return true
		_:
			return false

# Public interface
func get_state() -> Dictionary:
	return current_state.duplicate()

func get_state_value(key: String, default_value: Variant = null) -> Variant:
	# Parameter validation - eliminates UNSAFE_CALL_ARGUMENT warnings
	if not is_instance_valid(self):
		return default_value
	return current_state.get(key, default_value)

func reset_state() -> void:
	var old_state: Dictionary = current_state.duplicate()
	current_state.clear()
	_initialize_state()
	state_changed.emit(old_state, current_state)
	state_reset.emit()

func get_history() -> Array[Dictionary]:
	return state_history.duplicate()

func clear_history() -> void:
	state_history.clear()

func can_undo() -> bool:
	return state_history.size() > 0

func undo() -> bool:
	if not can_undo():
		return false

	var previous_entry: Dictionary = state_history.pop_back()
	var old_state: Dictionary = current_state.duplicate()

	if previous_entry.has("state"):
		var previous_state_variant: Variant = previous_entry.get("state")
		if previous_state_variant is Dictionary:
			current_state = previous_state_variant as Dictionary
			state_changed.emit(old_state, current_state)
			state_updated.emit(current_state)
			return true

	return false

