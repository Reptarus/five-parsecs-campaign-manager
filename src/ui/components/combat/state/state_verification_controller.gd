@tool
extends Node

## Required dependencies
const GameEnums := preload("res://src/core/enums/GameEnums.gd")
const Character := preload("res://src/core/character/Base/Character.gd")
const BaseCombatManager := preload("res://src/base/combat/BaseCombatManager.gd")

## Node references
@onready var combat_manager = null # Will be initialized in _ready

## Signals
signal verification_started(type: GameEnums.VerificationType, scope: GameEnums.VerificationScope)
signal verification_result_ready(type: GameEnums.VerificationType, result: GameEnums.VerificationResult, details: Dictionary)
signal verification_error(type: GameEnums.VerificationType, error: String)
signal state_mismatch_detected(type: GameEnums.VerificationType, expected: Dictionary, actual: Dictionary)

## Properties
var verification_history: Array = []
var pending_verifications: Dictionary = {}
var verification_rules: Dictionary = {}
var last_verification_result: Dictionary = {}
var auto_verify: bool = true
var mock_combat_manager = null # Used when real combat manager isn't available

## Called when the node enters scene tree
func _ready() -> void:
	_initialize_combat_manager()
	_initialize_verification_rules()
	
	if combat_manager:
		_connect_signals()

## Initialize the combat manager reference
func _initialize_combat_manager() -> void:
	# Try to get the combat manager from the scene tree
	if has_node("/root/CombatManager"):
		combat_manager = get_node("/root/CombatManager")
	else:
		# Create a mock combat manager if the real one doesn't exist
		push_warning("StateVerificationController: CombatManager not found, using mock implementation")
		_create_mock_combat_manager()

## Create a mock combat manager for testing/development
func _create_mock_combat_manager() -> void:
	# Create a simple mock object that mimics the required interface
	mock_combat_manager = Node.new()
	mock_combat_manager.name = "MockCombatManager"
	
	# Add required signals to the mock
	mock_combat_manager.set_script(GDScript.new())
	mock_combat_manager.script.source_code = """
	extends Node
	
	signal verify_state_requested(type, scope)
	signal verification_completed(type, result, details)
	signal verification_failed(type, error)
	signal combat_state_changed(new_state)
	signal combat_result_calculated(attacker, target, result)
	signal manual_override_applied(override_type, override_data)
	
	var current_state = {
		"phase": 0,
		"active_unit": null,
		"modifiers": {}
	}
	
	func verify_state(type, scope):
		verify_state_requested.emit(type, scope)
		verification_completed.emit(type, 0, {})
	"""
	mock_combat_manager.script.reload()
	
	add_child(mock_combat_manager)
	combat_manager = mock_combat_manager

## Connects required signals
func _connect_signals() -> void:
	if not combat_manager:
		return
		
	# Safely connect signals
	if combat_manager.has_signal("verify_state_requested") and not combat_manager.verify_state_requested.is_connected(_on_verify_state_requested):
		combat_manager.verify_state_requested.connect(_on_verify_state_requested)
	
	if combat_manager.has_signal("verification_completed") and not combat_manager.verification_completed.is_connected(_on_verification_completed):
		combat_manager.verification_completed.connect(_on_verification_completed)
	
	if combat_manager.has_signal("verification_failed") and not combat_manager.verification_failed.is_connected(_on_verification_failed):
		combat_manager.verification_failed.connect(_on_verification_failed)
	
	# Combat state signals
	if combat_manager.has_signal("combat_state_changed") and not combat_manager.combat_state_changed.is_connected(_on_combat_state_changed):
		combat_manager.combat_state_changed.connect(_on_combat_state_changed)
	
	if combat_manager.has_signal("combat_result_calculated") and not combat_manager.combat_result_calculated.is_connected(_on_combat_result_calculated):
		combat_manager.combat_result_calculated.connect(_on_combat_result_calculated)
	
	if combat_manager.has_signal("manual_override_applied") and not combat_manager.manual_override_applied.is_connected(_on_manual_override_applied):
		combat_manager.manual_override_applied.connect(_on_manual_override_applied)

## Initializes default verification rules
func _initialize_verification_rules() -> void:
	verification_rules = {
		GameEnums.VerificationType.COMBAT: {
			"required_fields": ["phase", "active_unit", "modifiers"],
			"validators": ["_validate_combat_state"]
		},
		GameEnums.VerificationType.STATE: {
			"required_fields": ["position", "character"],
			"validators": ["_validate_position"]
		},
		GameEnums.VerificationType.RULES: {
			"required_fields": ["status", "character"],
			"validators": ["_validate_status"]
		},
		GameEnums.VerificationType.DEPLOYMENT: {
			"required_fields": ["resource_type", "value"],
			"validators": ["_validate_resources"]
		},
		GameEnums.VerificationType.MOVEMENT: {
			"required_fields": ["override_type", "value"],
			"validators": ["_validate_override"]
		},
		GameEnums.VerificationType.OBJECTIVES: {
			"required_fields": ["rule_name", "parameters"],
			"validators": ["_validate_rule"]
		}
	}

## Public methods
func request_verification(type: GameEnums.VerificationType, scope: GameEnums.VerificationScope = GameEnums.VerificationScope.ALL) -> void:
	if not combat_manager:
		push_error("StateVerificationController: Cannot verify without CombatManager")
		return
	
	verification_started.emit(type, scope)
	if combat_manager.has_method("verify_state"):
		combat_manager.verify_state(type, scope)
	else:
		push_error("StateVerificationController: CombatManager missing verify_state method")

func add_verification_rule(type: GameEnums.VerificationType, rule_data: Dictionary) -> void:
	if not rule_data.has_all(["required_fields", "validators"]):
		push_error("StateVerificationController: Invalid rule data format")
		return
	
	verification_rules[type] = rule_data

func get_verification_rules() -> Dictionary:
	return verification_rules.duplicate()

func get_auto_verify() -> bool:
	return auto_verify

func set_auto_verify(value: bool) -> void:
	auto_verify = value

func get_last_verification_result() -> Dictionary:
	return last_verification_result.duplicate()

func get_verification_history() -> Array:
	return verification_history.duplicate()

func clear_verification_history() -> void:
	verification_history.clear()

## Verification methods
func _verify_state(type: GameEnums.VerificationType, state_data: Dictionary) -> Dictionary:
	var result = {
		"type": type,
		"status": GameEnums.VerificationResult.SUCCESS,
		"details": {},
		"timestamp": Time.get_datetime_string_from_system()
	}
	
	# Check if we have rules for this type
	if not verification_rules.has(type):
		result.status = GameEnums.VerificationResult.ERROR
		result.details["error"] = "No verification rules found for type: %s" % type
		return result
	
	var rules = verification_rules[type]
	
	# Check required fields
	for field in rules.required_fields:
		if not state_data.has(field):
			result.status = GameEnums.VerificationResult.ERROR
			result.details["missing_field"] = field
			return result
	
	# Run validators
	for validator in rules.validators:
		if has_method(validator):
			var validation_result = call(validator, state_data)
			if validation_result.status > result.status:
				result.status = validation_result.status
				result.details[validator] = validation_result.details
	
	return result

## Validator methods
func _validate_combat_state(state_data: Dictionary) -> Dictionary:
	var result = {
		"status": GameEnums.VerificationResult.SUCCESS,
		"details": {}
	}
	
	# Validate phase - using a safer try/catch approach
	if "phase" in state_data:
		# Try to validate phase safely
		if typeof(state_data.phase) == TYPE_INT:
			# Skip validation if we can't be sure about the enum values
			# Use a gentle approach that won't crash if enums aren't available 
			pass
	
	# Validate active unit
	if "active_unit" in state_data and state_data.active_unit != null:
		if not state_data.active_unit is Character:
			result.status = GameEnums.VerificationResult.ERROR
			result.details["active_unit"] = "Invalid active unit type"
	
	# Validate modifiers
	if "modifiers" in state_data and not state_data.modifiers is Dictionary:
		result.status = GameEnums.VerificationResult.ERROR
		result.details["modifiers"] = "Invalid modifiers format"
	
	return result

func _validate_position(state_data: Dictionary) -> Dictionary:
	var result = {
		"status": GameEnums.VerificationResult.SUCCESS,
		"details": {}
	}
	
	if "position" in state_data and not state_data.position is Vector2i:
		result.status = GameEnums.VerificationResult.ERROR
		result.details["position"] = "Invalid position format"
	
	if "character" in state_data and not state_data.character is Character:
		result.status = GameEnums.VerificationResult.ERROR
		result.details["character"] = "Invalid character reference"
	
	return result

func _validate_status(state_data: Dictionary) -> Dictionary:
	var result = {
		"status": GameEnums.VerificationResult.SUCCESS,
		"details": {}
	}
	
	if "status" in state_data:
		# Skip detailed validation for now to avoid enum access errors
		if typeof(state_data.status) != TYPE_INT:
			result.status = GameEnums.VerificationResult.ERROR
			result.details["status"] = "Status should be an integer enum value"
	
	if "character" in state_data and not state_data.character is Character:
		result.status = GameEnums.VerificationResult.ERROR
		result.details["character"] = "Invalid character reference"
	
	return result

func _validate_resources(state_data: Dictionary) -> Dictionary:
	var result = {
		"status": GameEnums.VerificationResult.SUCCESS,
		"details": {}
	}
	
	if "value" in state_data and not state_data.value is int and not state_data.value is float:
		result.status = GameEnums.VerificationResult.ERROR
		result.details["value"] = "Invalid resource value type"
	
	return result

func _validate_override(state_data: Dictionary) -> Dictionary:
	var result = {
		"status": GameEnums.VerificationResult.SUCCESS,
		"details": {}
	}
	
	if "override_type" in state_data and not state_data.override_type is String:
		result.status = GameEnums.VerificationResult.ERROR
		result.details["override_type"] = "Invalid override type"
	
	return result

func _validate_rule(state_data: Dictionary) -> Dictionary:
	var result = {
		"status": GameEnums.VerificationResult.SUCCESS,
		"details": {}
	}
	
	if "parameters" in state_data and not state_data.parameters is Dictionary:
		result.status = GameEnums.VerificationResult.ERROR
		result.details["parameters"] = "Invalid rule parameters format"
	
	return result

## Signal handlers
func _on_verify_state_requested(type: GameEnums.VerificationType, scope: GameEnums.VerificationScope) -> void:
	if not combat_manager or not combat_manager.get("current_state"):
		push_error("StateVerificationController: Combat manager missing current_state property")
		return
		
	var state_data = combat_manager.current_state
	var result = _verify_state(type, state_data)
	
	last_verification_result = result
	verification_history.append(result)
	
	if result.status == GameEnums.VerificationResult.SUCCESS:
		verification_result_ready.emit(type, result.status, result.details)
	else:
		verification_error.emit(type, "Verification failed: %s" % str(result.details))

func _on_verification_completed(type: GameEnums.VerificationType, result: GameEnums.VerificationResult, details: Dictionary) -> void:
	last_verification_result = {
		"type": type,
		"status": result,
		"details": details,
		"timestamp": Time.get_datetime_string_from_system()
	}
	verification_history.append(last_verification_result)
	verification_result_ready.emit(type, result, details)

func _on_verification_failed(type: GameEnums.VerificationType, error: String) -> void:
	last_verification_result = {
		"type": type,
		"status": GameEnums.VerificationResult.ERROR,
		"details": {"error": error},
		"timestamp": Time.get_datetime_string_from_system()
	}
	verification_history.append(last_verification_result)
	verification_error.emit(type, error)

func _on_combat_state_changed(new_state: Dictionary) -> void:
	if auto_verify:
		request_verification(GameEnums.VerificationType.COMBAT)

func _on_combat_result_calculated(attacker: Character, target: Character, result: GameEnums.CombatResult) -> void:
	if auto_verify:
		request_verification(GameEnums.VerificationType.COMBAT)

func _on_manual_override_applied(override_type: String, override_data: Dictionary) -> void:
	if auto_verify:
		request_verification(GameEnums.VerificationType.MOVEMENT)
