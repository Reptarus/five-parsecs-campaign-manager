extends Node

const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")

signal state_changed(old_state: Dictionary, new_state: Dictionary)
signal state_updated(state: Dictionary)
signal state_reset
signal state_validated(is_valid: bool, issues: Array)
signal state_recovered(success: bool, recovery_info: Dictionary)
signal validation_rule_added(rule_name: String)
signal state_checkpoint_created(checkpoint_id: String)
signal state_checkpoint_restored(checkpoint_id: String)

var game_state: FiveParsecsGameState
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

func _init(_game_state: FiveParsecsGameState) -> void:
    game_state = _game_state
    _initialize_state()
    _setup_default_validation_rules()
    _setup_recovery_handlers()

func _initialize_state() -> void:
    # Virtual method to be implemented by child classes
    pass

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
    var old_state = current_state.duplicate()
    
    # Create pre-update checkpoint
    var checkpoint_id = _create_checkpoint("pre_update")
    
    # Apply updates
    for key in new_values:
        if current_state.has(key) and current_state[key] != new_values[key]:
            current_state[key] = new_values[key]
    
    # Validate if required
    if not skip_validation:
        var validation_result = validate_state()
        if not validation_result.is_valid:
            if AUTO_RECOVERY_ENABLED:
                var recovery_result = _attempt_recovery(validation_result.issues)
                if not recovery_result.success:
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

# State validation
func validate_state() -> Dictionary:
    var issues = []
    var is_valid = true
    
    for rule in validation_rules:
        var result = rule.call(current_state)
        if not result.valid:
            is_valid = false
            issues.append(result)
            
    state_validated.emit(is_valid, issues)
    return {"is_valid": is_valid, "issues": issues}

func add_validation_rule(rule_name: String, rule: Callable) -> void:
    validation_rules.append(rule)
    validation_rule_added.emit(rule_name)

# Default validation rules
func _validate_state_types(state: Dictionary) -> Dictionary:
    var issues = []
    for key in state:
        if not _is_valid_type(state[key]):
            issues.append({"type": "type_mismatch", "key": key, "value": state[key]})
    return {"valid": issues.is_empty(), "issues": issues}

func _validate_required_fields(state: Dictionary) -> Dictionary:
    var required_fields = ["credits", "resources", "campaign_turns"]
    var issues = []
    
    for field in required_fields:
        if not state.has(field):
            issues.append({"type": "missing_field", "field": field})
    
    return {"valid": issues.is_empty(), "issues": issues}

func _validate_value_ranges(state: Dictionary) -> Dictionary:
    var issues = []
    
    if state.has("credits") and (state.credits < 0 or state.credits > 1000000):
        issues.append({"type": "invalid_range", "field": "credits", "value": state.credits})
    
    if state.has("campaign_turns") and state.campaign_turns < 0:
        issues.append({"type": "invalid_range", "field": "campaign_turns", "value": state.campaign_turns})
    
    return {"valid": issues.is_empty(), "issues": issues}

# State recovery
func _attempt_recovery(issues: Array) -> Dictionary:
    var recovery_attempts = []
    var success = true
    
    for issue in issues:
        if recovery_handlers.has(issue.type):
            var result = recovery_handlers[issue.type].call(issue)
            recovery_attempts.append(result)
            if not result.success:
                success = false
    
    state_recovered.emit(success, {"attempts": recovery_attempts})
    return {"success": success, "attempts": recovery_attempts}

# Recovery handlers
func _recover_missing_fields(issue: Dictionary) -> Dictionary:
    var field = issue.field
    var default_values = {
        "credits": 0,
        "resources": {},
        "campaign_turns": 0
    }
    
    if default_values.has(field):
        current_state[field] = default_values[field]
        return {"success": true, "field": field, "action": "set_default"}
    
    return {"success": false, "field": field, "reason": "no_default_value"}

func _recover_invalid_values(issue: Dictionary) -> Dictionary:
    var field = issue.field
    var value = issue.value
    
    match field:
        "credits":
            current_state.credits = clampi(value, 0, 1000000)
        "campaign_turns":
            current_state.campaign_turns = maxi(0, value)
        _:
            return {"success": false, "field": field, "reason": "unknown_field"}
    
    return {"success": true, "field": field, "action": "clamped_value"}

func _recover_type_mismatch(issue: Dictionary) -> Dictionary:
    var key = issue.key
    var value = issue.value
    
    # Attempt type conversion
    match typeof(value):
        TYPE_STRING:
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
        current_state = state_history[-1].duplicate()
        return {"success": true, "action": "restored_last_valid"}
    
    # If no history, reset to initial state
    _initialize_state()
    return {"success": true, "action": "reset_to_initial"}

# Checkpoint management
func _create_checkpoint(label: String = "") -> String:
    var checkpoint_id = str(Time.get_unix_time_from_system()) + "_" + label
    state_checkpoints[checkpoint_id] = current_state.duplicate(true)
    
    # Maintain checkpoint limit
    while state_checkpoints.size() > MAX_CHECKPOINTS:
        var oldest = state_checkpoints.keys()[0]
        state_checkpoints.erase(oldest)
    
    state_checkpoint_created.emit(checkpoint_id)
    return checkpoint_id

func _restore_checkpoint(checkpoint_id: String) -> bool:
    if not state_checkpoints.has(checkpoint_id):
        return false
    
    current_state = state_checkpoints[checkpoint_id].duplicate(true)
    state_checkpoint_restored.emit(checkpoint_id)
    return true

# Enhanced history management
func _add_to_history(state: Dictionary) -> void:
    var entry = {
        "state": state.duplicate(true),
        "timestamp": Time.get_unix_time_from_system(),
        "metadata": state_metadata.duplicate()
    }
    
    state_history.append(entry)
    while state_history.size() > max_history_size:
        state_history.pop_front()

# Utility functions
func _is_valid_type(value: Variant) -> bool:
    match typeof(value):
        TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_DICTIONARY, TYPE_ARRAY:
            return true
        _:
            return false

# Public interface
func get_state() -> Dictionary:
    return current_state.duplicate()

func get_state_value(key: String, default_value = null):
    return current_state.get(key, default_value)

func reset_tracker_state() -> void:
    var old_state = current_state.duplicate(true)
    
    # Clear the state
    current_state.clear()
    
    # Initialize fresh state
    _initialize_state()
    
    # Apply validators
    validate_state()
    
    # Emit the reset signal
    state_reset.emit()
    state_changed.emit(old_state, current_state)
    state_updated.emit(current_state)

func get_history() -> Array[Dictionary]:
    return state_history.duplicate()

func clear_history() -> void:
    state_history.clear()

func can_undo() -> bool:
    return state_history.size() > 0

func undo() -> bool:
    if not can_undo():
        return false
        
    var previous_state = state_history.pop_back()
    var old_state = current_state.duplicate()
    current_state = previous_state.state
    state_changed.emit(old_state, current_state)
    state_updated.emit(current_state)
    return true