extends Node

## Required dependencies
const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")
const Character := preload("res://src/core/character/Base/Character.gd")
const BaseCombatManager := preload("res://src/base/combat/BaseCombatManager.gd")
const GameState := preload("res://src/core/state/GameState.gd")

## Node references
@onready var house_rules_panel: PanelContainer = %HouseRulesPanel
@onready var combat_manager: BaseCombatManager = get_node_or_null("/root/CombatManager")

## Properties
var active_rules: Dictionary = {}
var rule_effects: Dictionary = {}

## Called when the node enters scene tree
func _ready() -> void:
	# Ensure critical nodes are available
	if not is_instance_valid(house_rules_panel):
		push_error("HouseRulesController: house_rules_panel not found")
		return
	
	if not is_instance_valid(combat_manager):
		push_warning("HouseRulesController: combat_manager not found - some functionality will be limited")
	
	_connect_signals()
	_load_saved_rules()

## Connects all required signals
func _connect_signals() -> void:
	# Safety check for house_rules_panel
	if not is_instance_valid(house_rules_panel):
		return
		
	# House rules panel signals
	house_rules_panel.rule_added.connect(_on_rule_added)
	house_rules_panel.rule_modified.connect(_on_rule_modified)
	house_rules_panel.rule_removed.connect(_on_rule_removed)
	house_rules_panel.rule_applied.connect(_on_rule_applied)
	house_rules_panel.validation_requested.connect(_on_validation_requested)
	
	# Combat manager signals - with safety check
	if is_instance_valid(combat_manager):
		if combat_manager.has_signal("combat_state_changed"):
			combat_manager.combat_state_changed.connect(_on_combat_state_changed)
		
		if combat_manager.has_signal("combat_result_calculated"):
			combat_manager.combat_result_calculated.connect(_on_combat_result_calculated)
		
		if combat_manager.has_signal("combat_advantage_changed"):
			combat_manager.combat_advantage_changed.connect(_on_combat_advantage_changed)
		
		if combat_manager.has_signal("combat_status_changed"):
			combat_manager.combat_status_changed.connect(_on_combat_status_changed)

## Loads saved house rules from game state
func _load_saved_rules() -> void:
	var game_state = get_node_or_null("/root/GameState")
	if not game_state:
		return
	
	# Ensure game_state has the get_house_rules method
	if not game_state.has_method("get_house_rules"):
		push_warning("HouseRulesController: GameState missing get_house_rules method")
		return
		
	var saved_rules = game_state.get_house_rules()
	if typeof(saved_rules) != TYPE_DICTIONARY:
		push_warning("HouseRulesController: Invalid saved rules format")
		return
		
	for rule_id in saved_rules:
		_add_rule(rule_id, saved_rules[rule_id])

## Adds a new house rule
func _add_rule(rule_id: String, rule_data: Dictionary) -> void:
	# Validate rule data
	if not _is_valid_rule_data(rule_data):
		push_warning("HouseRulesController: Invalid rule data for rule_id: " + rule_id)
		return
		
	active_rules[rule_id] = rule_data
	_create_rule_effect(rule_id, rule_data)
	
	if is_instance_valid(combat_manager):
		if combat_manager.has_signal("house_rule_applied"):
			combat_manager.house_rule_applied.emit(
				rule_data.get("name", "Unnamed Rule"),
				rule_data
			)
	else:
		push_warning("HouseRulesController: combat_manager is null when attempting to emit house_rule_applied")

## Checks if rule data has required fields
func _is_valid_rule_data(rule_data: Dictionary) -> bool:
	if not rule_data.has("type") or typeof(rule_data.type) != TYPE_STRING:
		return false
		
	if not rule_data.has("name") or typeof(rule_data.name) != TYPE_STRING:
		return false
		
	return true

## Creates and stores a rule effect
func _create_rule_effect(rule_id: String, rule_data: Dictionary) -> void:
	var effect = {
		"id": rule_id,
		"type": rule_data.get("type", ""),
		"value": _get_rule_value(rule_data),
		"condition": _get_rule_condition(rule_data),
		"target": _get_rule_target(rule_data)
	}
	rule_effects[rule_id] = effect

## Gets the numerical value from a rule
func _get_rule_value(rule_data: Dictionary) -> int:
	# Safely check if fields property exists and handle the case when it doesn't
	if not rule_data.has("fields"):
		return 0
		
	# If fields exists, iterate through them safely
	if typeof(rule_data.fields) == TYPE_ARRAY:
		for field in rule_data.fields:
			if typeof(field) == TYPE_DICTIONARY and field.has("name") and field.name == "value":
				if field.has("value") and (typeof(field.value) == TYPE_INT or typeof(field.value) == TYPE_FLOAT):
					return int(field.value)
	return 0

## Gets the condition from a rule
func _get_rule_condition(rule_data: Dictionary) -> String:
	# Safely check if fields property exists and handle the case when it doesn't
	if not rule_data.has("fields"):
		return ""
		
	# If fields exists, iterate through them safely
	if typeof(rule_data.fields) == TYPE_ARRAY:
		for field in rule_data.fields:
			if typeof(field) == TYPE_DICTIONARY and field.has("name") and field.name == "condition":
				if field.has("value"):
					return str(field.value)
	return ""

## Gets the target from a rule
func _get_rule_target(rule_data: Dictionary) -> String:
	# Safely check if fields property exists and handle the case when it doesn't
	if not rule_data.has("fields"):
		return ""
		
	# If fields exists, iterate through them safely
	if typeof(rule_data.fields) == TYPE_ARRAY:
		for field in rule_data.fields:
			if typeof(field) == TYPE_DICTIONARY and field.has("name") and field.name == "target":
				if field.has("value"):
					return str(field.value)
	return ""

## Validates a rule against current state
func _validate_rule(rule: Dictionary, context: String) -> bool:
	if not rule.has("type"):
		return false
		
	match rule.type:
		"combat_modifier":
			return _validate_combat_modifier(rule, context)
		"resource_modifier":
			return _validate_resource_modifier(rule, context)
		"state_condition":
			return _validate_state_condition(rule, context)
	return false

## Validates a combat modifier rule
func _validate_combat_modifier(rule: Dictionary, context: String) -> bool:
	var value = _get_rule_value(rule)
	return value >= -3 and value <= 3

## Validates a resource modifier rule
func _validate_resource_modifier(rule: Dictionary, context: String) -> bool:
	var value = _get_rule_value(rule)
	return value >= -5 and value <= 5

## Validates a state condition rule
func _validate_state_condition(rule: Dictionary, context: String) -> bool:
	return true # Complex validation based on state

## Applies a rule effect to the current context
func _apply_rule_effect(rule_id: String, context: String) -> void:
	if not rule_effects.has(rule_id):
		return
	
	var effect = rule_effects[rule_id]
	if not effect.has("type"):
		push_warning("HouseRulesController: Rule effect missing 'type' for rule_id: " + rule_id)
		return
		
	match effect.type:
		"combat_modifier":
			_apply_combat_modifier(effect, context)
		"resource_modifier":
			_apply_resource_modifier(effect, context)
		"state_condition":
			_apply_state_condition(effect, context)

## Applies a combat modifier effect
func _apply_combat_modifier(effect: Dictionary, context: String) -> void:
	if not is_instance_valid(combat_manager):
		return
	
	# Safety check for house_rule_modifiers
	if not combat_manager.has("house_rule_modifiers"):
		push_warning("HouseRulesController: combat_manager missing house_rule_modifiers")
		return
		
	var modifier = {
		"source": "house_rule",
		"value": effect.get("value", 0),
		"condition": effect.get("condition", ""),
		"target": effect.get("target", "")
	}
	combat_manager.house_rule_modifiers[effect.id] = modifier

## Applies a resource modifier effect
func _apply_resource_modifier(effect: Dictionary, context: String) -> void:
	if not is_instance_valid(combat_manager):
		return
	
	# Safety check for house_rule_modifiers
	if not combat_manager.has("house_rule_modifiers"):
		push_warning("HouseRulesController: combat_manager missing house_rule_modifiers")
		return
		
	var modifier = {
		"source": "house_rule",
		"value": effect.get("value", 0),
		"resource": effect.get("target", "")
	}
	combat_manager.house_rule_modifiers[effect.id] = modifier

## Applies a state condition effect
func _apply_state_condition(effect: Dictionary, context: String) -> void:
	if not is_instance_valid(combat_manager):
		return
	
	# Safety check for house_rule_modifiers
	if not combat_manager.has("house_rule_modifiers"):
		push_warning("HouseRulesController: combat_manager missing house_rule_modifiers")
		return
		
	var condition = {
		"source": "house_rule",
		"state_key": effect.get("target", ""),
		"operator": effect.get("condition", ""),
		"value": effect.get("value", 0)
	}
	combat_manager.house_rule_modifiers[effect.id] = condition

## Signal handlers
func _on_rule_added(rule: Dictionary) -> void:
	if not _is_valid_rule_data(rule):
		push_warning("HouseRulesController: Attempted to add invalid rule")
		return
		
	var rule_id = str(Time.get_unix_time_from_system())
	_add_rule(rule_id, rule)

func _on_rule_modified(rule: Dictionary) -> void:
	if not _is_valid_rule_data(rule):
		push_warning("HouseRulesController: Attempted to modify with invalid rule")
		return
		
	for rule_id in active_rules:
		if active_rules[rule_id].has("name") and rule.has("name") and active_rules[rule_id].name == rule.name:
			_add_rule(rule_id, rule)
			break

func _on_rule_removed(rule_id: String) -> void:
	active_rules.erase(rule_id)
	rule_effects.erase(rule_id)
	
	if is_instance_valid(combat_manager) and combat_manager.has("house_rule_modifiers"):
		combat_manager.house_rule_modifiers.erase(rule_id)

func _on_rule_applied(rule_id: String, context: String) -> void:
	if active_rules.has(rule_id):
		_apply_rule_effect(rule_id, context)

func _on_validation_requested(rule: Dictionary, context: String) -> void:
	var is_valid = _validate_rule(rule, context)
	
	# Safety check for validation_panel
	if is_instance_valid(house_rules_panel) and house_rules_panel.has("validation_panel"):
		var validation_panel = house_rules_panel.validation_panel
		if is_instance_valid(validation_panel):
			if is_valid:
				if validation_panel.has_method("show_success"):
					validation_panel.show_success("Rule validation passed")
			else:
				if validation_panel.has_method("show_error"):
					validation_panel.show_error("Rule validation failed")

func _on_combat_state_changed(new_state: Dictionary) -> void:
	# Update rule effects based on new combat state
	for rule_id in active_rules:
		_apply_rule_effect(rule_id, "combat_state_changed")

func _on_combat_result_calculated(attacker: Character, target: Character, result: GameEnums.CombatResult) -> void:
	# Apply relevant rule effects to combat result
	for rule_id in active_rules:
		_apply_rule_effect(rule_id, "combat_result")

func _on_combat_advantage_changed(character: Character, advantage: GameEnums.CombatAdvantage) -> void:
	# Apply relevant rule effects to advantage changes
	for rule_id in active_rules:
		_apply_rule_effect(rule_id, "combat_advantage")

func _on_combat_status_changed(character: Character, status: GameEnums.CombatStatus) -> void:
	# Apply relevant rule effects to status changes
	for rule_id in active_rules:
		_apply_rule_effect(rule_id, "combat_status")
