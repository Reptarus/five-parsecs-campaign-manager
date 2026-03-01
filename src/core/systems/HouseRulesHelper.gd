class_name HouseRulesHelper
extends RefCounted

## Centralized house rule checking utility
##
## Provides static methods to check if house rules are enabled and get their modifiers.
## Avoids circular dependencies by accessing GameState autoload at runtime.
##
## Usage:
##   if HouseRulesHelper.is_enabled("brutal_combat"):
##       damage *= 2
##
##   var multiplier = HouseRulesHelper.get_modifier("wealthy_patrons", 1.5)

const HouseRulesDefinitions = preload("res://src/data/house_rules_definitions.gd")

## Check if a specific house rule is enabled via GameState/GameStateManager autoload
## SPRINT 7.2: Updated to check GameStateManager (reads from campaign) as fallback
static func is_enabled(rule_id: String) -> bool:
	# First try GameState
	var game_state = _get_game_state()
	if game_state and game_state.has_method("is_house_rule_enabled"):
		return game_state.is_house_rule_enabled(rule_id)

	# Fallback to GameStateManager (reads house_rules from campaign)
	var game_state_manager = _get_game_state_manager()
	if game_state_manager and game_state_manager.has_method("get_house_rules"):
		var enabled_rules = game_state_manager.get_house_rules()
		if enabled_rules is Array:
			return rule_id in enabled_rules

	return false

## Get modifier value for a rule (e.g., wealthy_patrons = 1.5)
## Returns default if rule is not enabled or has no value
static func get_modifier(rule_id: String, default: float = 1.0) -> float:
	if not is_enabled(rule_id):
		return default

	var rule = HouseRulesDefinitions.get_rule(rule_id)
	if rule.is_empty():
		return default

	for effect in rule.get("effects", []):
		if effect.has("value"):
			return effect.value

	return default

## Get all effects for enabled rules in a specific context
## Context examples: "enemy_generation", "combat", "mission_reward", etc.
## SPRINT 7.2: Updated to check GameStateManager as fallback
static func get_effects_for_context(context: String) -> Array[Dictionary]:
	var enabled_rules = get_enabled_rules()
	if enabled_rules.is_empty():
		return []
	return HouseRulesDefinitions.get_effects_for_context(enabled_rules, context)

## Get all currently enabled house rule IDs
## SPRINT 7.2: Updated to check GameStateManager (reads from campaign) as fallback
static func get_enabled_rules() -> Array[String]:
	# First try GameState
	var game_state = _get_game_state()
	if game_state and game_state.has_method("get_house_rules"):
		var rules = game_state.get_house_rules()
		if rules is Array and not rules.is_empty():
			var typed_rules: Array[String] = []
			for r in rules:
				if r is String:
					typed_rules.append(r)
			return typed_rules

	# Fallback to GameStateManager (reads from campaign)
	var game_state_manager = _get_game_state_manager()
	if game_state_manager and game_state_manager.has_method("get_house_rules"):
		var rules = game_state_manager.get_house_rules()
		if rules is Array:
			var typed_rules: Array[String] = []
			for r in rules:
				if r is String:
					typed_rules.append(r)
			return typed_rules

	return []

## Get full rule data for an enabled rule
static func get_rule_data(rule_id: String) -> Dictionary:
	return HouseRulesDefinitions.get_rule(rule_id)

## Internal helper to get GameState autoload
static func _get_game_state() -> Node:
	var main_loop = Engine.get_main_loop()
	if main_loop == null:
		return null
	var root = main_loop.get_root()
	if root == null:
		return null
	return root.get_node_or_null("/root/GameState")

## SPRINT 7.2: Internal helper to get GameStateManager autoload
## GameStateManager.get_house_rules() now reads from campaign (source of truth)
static func _get_game_state_manager() -> Node:
	var main_loop = Engine.get_main_loop()
	if main_loop == null:
		return null
	var root = main_loop.get_root()
	if root == null:
		return null
	return root.get_node_or_null("/root/GameStateManager")
