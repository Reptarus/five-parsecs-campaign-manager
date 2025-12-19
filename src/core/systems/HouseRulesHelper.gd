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

## Check if a specific house rule is enabled via GameState autoload
static func is_enabled(rule_id: String) -> bool:
	var game_state = _get_game_state()
	if game_state and game_state.has_method("is_house_rule_enabled"):
		return game_state.is_house_rule_enabled(rule_id)
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
static func get_effects_for_context(context: String) -> Array[Dictionary]:
	var game_state = _get_game_state()
	if not game_state:
		return []

	var enabled_rules = game_state.get_house_rules() if game_state.has_method("get_house_rules") else []
	return HouseRulesDefinitions.get_effects_for_context(enabled_rules, context)

## Get all currently enabled house rule IDs
static func get_enabled_rules() -> Array[String]:
	var game_state = _get_game_state()
	if game_state and game_state.has_method("get_house_rules"):
		return game_state.get_house_rules()
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
