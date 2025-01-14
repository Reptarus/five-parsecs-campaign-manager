extends Node

## Required dependencies
const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")
const Character := preload("res://src/core/character/Base/Character.gd")

## Node references
@onready var house_rules_panel: PanelContainer = %HouseRulesPanel
@onready var combat_manager: Node = get_node("/root/CombatManager")

## Properties
var active_rules: Dictionary = {}
var rule_effects: Dictionary = {}

## Called when the node enters scene tree
func _ready() -> void:
	if not house_rules_panel or not combat_manager:
		push_error("HouseRulesController: Required nodes not found")
		return
	
	_connect_signals()
	_load_saved_rules()

## Connects all required signals
func _connect_signals() -> void:
	# House rules panel signals
	house_rules_panel.rule_added.connect(_on_rule_added)
	house_rules_panel.rule_modified.connect(_on_rule_modified)
	house_rules_panel.rule_removed.connect(_on_rule_removed)
	house_rules_panel.rule_applied.connect(_on_rule_applied)
	house_rules_panel.validation_requested.connect(_on_validation_requested)
	
	# Combat manager signals
	combat_manager.combat_state_changed.connect(_on_combat_state_changed)
	combat_manager.combat_result_calculated.connect(_on_combat_result_calculated)
	combat_manager.combat_advantage_changed.connect(_on_combat_advantage_changed)
	combat_manager.combat_status_changed.connect(_on_combat_status_changed)

## Loads saved house rules from game state
func _load_saved_rules() -> void:
	var game_state = get_node("/root/GameState")
	if not game_state:
		return
	
	var saved_rules = game_state.get_house_rules()
	for rule_id in saved_rules:
		_add_rule(rule_id, saved_rules[rule_id])

## Adds a new house rule
func _add_rule(rule_id: String, rule_data: Dictionary) -> void:
	active_rules[rule_id] = rule_data
	_create_rule_effect(rule_id, rule_data)
	combat_manager.house_rule_applied.emit(rule_data.name, rule_data)

## Creates and stores a rule effect
func _create_rule_effect(rule_id: String, rule_data: Dictionary) -> void:
	var effect = {
		"id": rule_id,
		"type": rule_data.type,
		"value": _get_rule_value(rule_data),
		"condition": _get_rule_condition(rule_data),
		"target": _get_rule_target(rule_data)
	}
	rule_effects[rule_id] = effect

## Gets the numerical value from a rule
func _get_rule_value(rule_data: Dictionary) -> int:
	for field in rule_data.fields:
		if field.name == "value":
			return field.value
	return 0

## Gets the condition from a rule
func _get_rule_condition(rule_data: Dictionary) -> String:
	for field in rule_data.fields:
		if field.name == "condition":
			return str(field.value)
	return ""

## Gets the target from a rule
func _get_rule_target(rule_data: Dictionary) -> String:
	for field in rule_data.fields:
		if field.name == "target":
			return str(field.value)
	return ""

## Validates a rule against current state
func _validate_rule(rule: Dictionary, context: String) -> bool:
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
	match effect.type:
		"combat_modifier":
			_apply_combat_modifier(effect, context)
		"resource_modifier":
			_apply_resource_modifier(effect, context)
		"state_condition":
			_apply_state_condition(effect, context)

## Applies a combat modifier effect
func _apply_combat_modifier(effect: Dictionary, context: String) -> void:
	if not combat_manager:
		return
	
	var modifier = {
		"source": "house_rule",
		"value": effect.value,
		"condition": effect.condition,
		"target": effect.target
	}
	combat_manager.house_rule_modifiers[effect.id] = modifier

## Applies a resource modifier effect
func _apply_resource_modifier(effect: Dictionary, context: String) -> void:
	if not combat_manager:
		return
	
	var modifier = {
		"source": "house_rule",
		"value": effect.value,
		"resource": effect.target
	}
	combat_manager.house_rule_modifiers[effect.id] = modifier

## Applies a state condition effect
func _apply_state_condition(effect: Dictionary, context: String) -> void:
	if not combat_manager:
		return
	
	var condition = {
		"source": "house_rule",
		"state_key": effect.target,
		"operator": effect.condition,
		"value": effect.value
	}
	combat_manager.house_rule_modifiers[effect.id] = condition

## Signal handlers
func _on_rule_added(rule: Dictionary) -> void:
	var rule_id = str(Time.get_unix_time_from_system())
	_add_rule(rule_id, rule)

func _on_rule_modified(rule: Dictionary) -> void:
	for rule_id in active_rules:
		if active_rules[rule_id].name == rule.name:
			_add_rule(rule_id, rule)
			break

func _on_rule_removed(rule_id: String) -> void:
	active_rules.erase(rule_id)
	rule_effects.erase(rule_id)
	if combat_manager:
		combat_manager.house_rule_modifiers.erase(rule_id)

func _on_rule_applied(rule_id: String, context: String) -> void:
	_apply_rule_effect(rule_id, context)

func _on_validation_requested(rule: Dictionary, context: String) -> void:
	var is_valid = _validate_rule(rule, context)
	house_rules_panel.validation_panel.show_success("Rule validation passed") if is_valid else house_rules_panel.validation_panel.show_error("Rule validation failed")

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