@tool
extends Node

## Required dependencies
const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")
const Character := preload("res://src/core/character/Base/Character.gd")

## Node references
@onready var combat_manager: Node = get_node("/root/CombatManager")

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

## Called when the node enters scene tree
func _ready() -> void:
	if not combat_manager:
		push_error("StateVerificationController: CombatManager not found")
		return
	
	_connect_signals()
	_initialize_verification_rules()

## Connects required signals
func _connect_signals() -> void:
	combat_manager.verify_state_requested.connect(_on_verify_state_requested)
	combat_manager.verification_completed.connect(_on_verification_completed)
	combat_manager.verification_failed.connect(_on_verification_failed)
	
	# Combat state signals
	combat_manager.combat_state_changed.connect(_on_combat_state_changed)
	combat_manager.combat_result_calculated.connect(_on_combat_result_calculated)
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
	combat_manager.verify_state(type, scope)

func add_verification_rule(type: GameEnums.VerificationType, rule_data: Dictionary) -> void:
	if not rule_data.has_all(["required_fields", "validators"]):
		push_error("StateVerificationController: Invalid rule data format")
		return
	
	verification_rules[type] = rule_data

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
	
	# Validate phase
	if not GameEnums.CombatPhase.values().has(state_data.phase):
		result.status = GameEnums.VerificationResult.ERROR
		result.details["phase"] = "Invalid combat phase"
	
	# Validate active unit
	if state_data.active_unit != null:
		if not state_data.active_unit is Character:
			result.status = GameEnums.VerificationResult.ERROR
			result.details["active_unit"] = "Invalid active unit type"
	
	# Validate modifiers
	if not state_data.modifiers is Dictionary:
		result.status = GameEnums.VerificationResult.ERROR
		result.details["modifiers"] = "Invalid modifiers format"
	
	return result

func _validate_position(state_data: Dictionary) -> Dictionary:
	var result = {
		"status": GameEnums.VerificationResult.SUCCESS,
		"details": {}
	}
	
	if not state_data.position is Vector2i:
		result.status = GameEnums.VerificationResult.ERROR
		result.details["position"] = "Invalid position format"
	
	if not state_data.character is Character:
		result.status = GameEnums.VerificationResult.ERROR
		result.details["character"] = "Invalid character reference"
	
	return result

func _validate_status(state_data: Dictionary) -> Dictionary:
	var result = {
		"status": GameEnums.VerificationResult.SUCCESS,
		"details": {}
	}
	
	if not GameEnums.CombatStatus.values().has(state_data.status):
		result.status = GameEnums.VerificationResult.ERROR
		result.details["status"] = "Invalid status value"
	
	if not state_data.character is Character:
		result.status = GameEnums.VerificationResult.ERROR
		result.details["character"] = "Invalid character reference"
	
	return result

func _validate_resources(state_data: Dictionary) -> Dictionary:
	var result = {
		"status": GameEnums.VerificationResult.SUCCESS,
		"details": {}
	}
	
	if not state_data.value is int and not state_data.value is float:
		result.status = GameEnums.VerificationResult.ERROR
		result.details["value"] = "Invalid resource value type"
	
	return result

func _validate_override(state_data: Dictionary) -> Dictionary:
	var result = {
		"status": GameEnums.VerificationResult.SUCCESS,
		"details": {}
	}
	
	if not state_data.override_type is String:
		result.status = GameEnums.VerificationResult.ERROR
		result.details["override_type"] = "Invalid override type"
	
	return result

func _validate_rule(state_data: Dictionary) -> Dictionary:
	var result = {
		"status": GameEnums.VerificationResult.SUCCESS,
		"details": {}
	}
	
	if not state_data.parameters is Dictionary:
		result.status = GameEnums.VerificationResult.ERROR
		result.details["parameters"] = "Invalid rule parameters format"
	
	return result

## Signal handlers
func _on_verify_state_requested(type: GameEnums.VerificationType, scope: GameEnums.VerificationScope) -> void:
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