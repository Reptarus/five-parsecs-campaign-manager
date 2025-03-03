@tool
extends Node

## Signals
signal override_applied(context: String, value: int)
signal override_cancelled(context: String)

## Required dependencies
const BaseCombatManager := preload("res://src/base/combat/BaseCombatManager.gd")

## Node references
@onready var override_panel: PanelContainer = %ManualOverridePanel

## Properties
var active_context: String = ""
var combat_resolver: Node = null
var combat_manager: BaseCombatManager = null

## Called when the node enters scene tree
func _ready() -> void:
	if not Engine.is_editor_hint():
		override_panel.override_applied.connect(_on_override_applied)
		override_panel.override_cancelled.connect(_on_override_cancelled)

## Sets up combat system references
func setup_combat_system(resolver: Node, manager: BaseCombatManager) -> void:
	combat_resolver = resolver
	combat_manager = manager
	
	# Connect combat system signals
	if combat_resolver:
		combat_resolver.override_requested.connect(_on_combat_override_requested)
		combat_resolver.dice_roll_completed.connect(_on_dice_roll_completed)
	
	if combat_manager:
		combat_manager.combat_state_changed.connect(_on_combat_state_changed)
		combat_manager.override_validation_requested.connect(_on_override_validation_requested)

## Shows override panel for combat context
func request_override(context: String, current_value: int, min_val: int = 1, max_val: int = 6) -> void:
	active_context = context
	override_panel.show_override(context, current_value, min_val, max_val)

## Validates override value against current combat state
func validate_override(context: String, value: int) -> bool:
	if not combat_manager:
		return true
	
	# Get validation rules based on context
	var validation_rules = _get_validation_rules(context)
	
	# Check against current combat state
	var current_state = combat_manager.get_current_state()
	
	# Apply validation rules
	for rule in validation_rules:
		if not rule.validate(current_state, value):
			return false
	
	return true

## Gets validation rules for context
func _get_validation_rules(context: String) -> Array:
	var rules = []
	
	match context:
		"attack_roll":
			rules.append({
				validate = func(state: Dictionary, value: int) -> bool:
					var max_bonus = state.get("attack_bonus", 0)
					return value <= (6 + max_bonus)
			})
		"damage_roll":
			rules.append({
				validate = func(state: Dictionary, value: int) -> bool:
					var weapon_damage = state.get("weapon_damage", 0)
					return value <= weapon_damage * 2
			})
		"defense_roll":
			rules.append({
				validate = func(state: Dictionary, value: int) -> bool:
					var max_defense = state.get("defense_value", 0)
					return value <= (6 + max_defense)
			})
	
	return rules

## Signal handlers
func _on_override_applied(value: int) -> void:
	if validate_override(active_context, value):
		override_applied.emit(active_context, value)
		if combat_resolver:
			combat_resolver.apply_override(active_context, value)
	else:
		# TODO: Show validation error
		pass

func _on_override_cancelled() -> void:
	override_cancelled.emit(active_context)
	active_context = ""

func _on_combat_override_requested(context: String, current_value: int) -> void:
	request_override(context, current_value)

func _on_dice_roll_completed(context: String, value: int) -> void:
	if active_context == context:
		override_panel.hide()

func _on_combat_state_changed(_new_state: Dictionary) -> void:
	# Update any active override validations
	if not active_context.is_empty():
		var current_value = override_panel.override_value_spinbox.value
		if not validate_override(active_context, current_value):
			override_panel.hide()

func _on_override_validation_requested(context: String, value: int) -> bool:
	return validate_override(context, value)