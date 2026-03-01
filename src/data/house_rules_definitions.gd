class_name HouseRulesDefinitions
extends RefCounted

## Five Parsecs From Home House Rules Definitions
##
## Core Rules Reference: p.65 Step 5 - House Rules
## Provides predefined optional rule modifications that players can enable
## during campaign creation.

## ============================================================================
## HOUSE RULE DATA STRUCTURE
## ============================================================================

## Available house rules from Core Rules and expansions
const HOUSE_RULES: Array[Dictionary] = [
	{
		"id": "varied_armaments",
		"name": "Varied Armaments",
		"description": "Enemy forces use split weapon types instead of uniform loadouts. Roll separately for each enemy's weapon.",
		"category": "combat",
		"source": "Core Rules p.65",
		"effects": [
			{"type": "enemy_generation", "modifier": "varied_weapons"}
		]
	},
	{
		"id": "wild_galaxy",
		"name": "Wild Galaxy",
		"description": "Roll twice for world traits and use both results. Makes each world more unique and challenging.",
		"category": "world",
		"source": "Core Rules p.65",
		"effects": [
			{"type": "world_generation", "modifier": "double_traits"}
		]
	},
	{
		"id": "brutal_combat",
		"name": "Brutal Combat",
		"description": "Critical hits deal double damage instead of automatic kills. More tactical, less instantly lethal.",
		"category": "combat",
		"source": "Community",
		"effects": [
			{"type": "combat", "modifier": "critical_double_damage"}
		]
	},
	{
		"id": "narrative_injuries",
		"name": "Narrative Injuries",
		"description": "Instead of rolling on injury table, player describes the injury. Must still have game effect.",
		"category": "character",
		"source": "Community",
		"effects": [
			{"type": "injury", "modifier": "narrative_choice"}
		]
	},
	{
		"id": "wealthy_patrons",
		"name": "Wealthy Patrons",
		"description": "Patron missions pay 50% more credits. Good for slower-paced campaigns.",
		"category": "economy",
		"source": "Community",
		"effects": [
			{"type": "mission_reward", "modifier": "patron_credits_bonus", "value": 1.5}
		]
	},
	{
		"id": "rookie_crew",
		"name": "Rookie Crew",
		"description": "Starting crew begins with 0 XP instead of rolled XP. A harder start for experienced players.",
		"category": "character",
		"source": "Community",
		"effects": [
			{"type": "crew_creation", "modifier": "zero_starting_xp"}
		]
	},
	{
		"id": "expanded_rumors",
		"name": "Expanded Rumors",
		"description": "+1 Quest Rumor whenever you complete a patron mission. More story progression.",
		"category": "story",
		"source": "Community",
		"effects": [
			{"type": "mission_complete", "modifier": "bonus_rumor"}
		]
	},
	{
		"id": "dangerous_fringe",
		"name": "Dangerous Fringe",
		"description": "All worlds have +1 danger level. For players who want more challenge.",
		"category": "world",
		"source": "Community",
		"effects": [
			{"type": "world_generation", "modifier": "danger_bonus", "value": 1}
		]
	}
]

## House rule categories for UI organization
const CATEGORIES: Dictionary = {
	"combat": {
		"name": "Combat Rules",
		"description": "Modifications to battle mechanics"
	},
	"world": {
		"name": "World Rules",
		"description": "Changes to world generation and traits"
	},
	"character": {
		"name": "Character Rules",
		"description": "Modifications to crew and character handling"
	},
	"economy": {
		"name": "Economy Rules",
		"description": "Changes to credits and rewards"
	},
	"story": {
		"name": "Story Rules",
		"description": "Modifications to story and quest progression"
	}
}


## ============================================================================
## STATIC HELPER METHODS
## ============================================================================

## Get all available house rules
static func get_all_rules() -> Array[Dictionary]:
	var rules: Array[Dictionary] = []
	for rule in HOUSE_RULES:
		rules.append(rule.duplicate())
	return rules


## Get house rules by category
static func get_rules_by_category(category: String) -> Array[Dictionary]:
	var filtered: Array[Dictionary] = []
	for rule in HOUSE_RULES:
		if rule.get("category", "") == category:
			filtered.append(rule.duplicate())
	return filtered


## Get a specific house rule by ID
static func get_rule(rule_id: String) -> Dictionary:
	for rule in HOUSE_RULES:
		if rule.get("id", "") == rule_id:
			return rule.duplicate()
	return {}


## Check if a house rule effect applies to a given context
static func has_effect_for_context(rule: Dictionary, context: String) -> bool:
	var effects: Array = rule.get("effects", [])
	for effect in effects:
		if effect is Dictionary and effect.get("type", "") == context:
			return true
	return false


## Get all effects for a specific context from enabled rules
static func get_effects_for_context(enabled_rule_ids: Array, context: String) -> Array[Dictionary]:
	var effects: Array[Dictionary] = []
	for rule_id in enabled_rule_ids:
		var rule := get_rule(rule_id)
		if rule.is_empty():
			continue
		for effect in rule.get("effects", []):
			if effect is Dictionary and effect.get("type", "") == context:
				effects.append(effect.duplicate())
	return effects


## Get all category names
static func get_category_names() -> Array[String]:
	var names: Array[String] = []
	for key in CATEGORIES.keys():
		names.append(key)
	return names


## Get category display info
static func get_category_info(category: String) -> Dictionary:
	return CATEGORIES.get(category, {"name": category, "description": ""})
