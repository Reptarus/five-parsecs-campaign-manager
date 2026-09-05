class_name HouseRulesDefinitions
extends RefCounted

## The book's OPTIONAL RULES, offered as toggles at campaign creation.
##
## Core Rules p.65, Campaign Preparation step 5 "Establish House Rules":
##   "Finally, evaluate whether you want to make any house rules. If this is your
##    first time playing, I strongly encourage you to play the rules as written...
##    In most cases, it is best to not add, remove, or change a house rule
##    mid-campaign."
##
## SCOPE, decided 2026-09-04. This table holds ONLY rules the rulebook prints.
## It previously carried six more entries tagged `"source": "Community"` —
## invented mechanics (double-damage crits, +50% patron pay, 0 starting XP, a
## +1 danger level, a bonus Rumor, narrative injuries), two of them with
## unsourced numeric values. They were untagged fabricated game data living in
## src/data/, which the project's data-integrity rule says to purge, and every
## one of them was unreachable anyway: HouseRulesHelper.is_enabled() probed two
## methods that exist on nothing and returned false unconditionally.
##
## A player's OWN house rules are not modelled here at all. They are recorded as
## free prose on the campaign (see ExpandedConfigPanel's "your own house rules"
## box), which is exactly what p.65 asks for — the book invites you to make
## house rules, it does not supply a menu of them.
##
## ADDING A RULE: it must print in the Core Rules or the Compendium, cite the
## printed folio (PDF index + 1 for the Core Rules), and quote the book in
## `book_text`. Anything else belongs in the free-text box.

## ============================================================================
## HOUSE RULE DATA STRUCTURE
## ============================================================================

## The optional rules the books actually print.
const HOUSE_RULES: Array[Dictionary] = [
	{
		"id": "varied_armaments",
		"name": "Varied Armaments",
		"description": "Split the non-Specialist enemies into two groups and roll a weapon for each. More varied battles, at the cost of tracking which enemy carries what.",
		"book_text": "Using this optional rule, split the non-Specialist opponents into two groups, and roll for the weapon carried by each group. This requires tracking which enemy has which weapon, but can lead to a more varied and interesting battle.",
		"category": "combat",
		"source": "Core Rules p.104",
		"effects": [
			{"type": "enemy_generation", "modifier": "varied_weapons"}
		]
	},
	{
		"id": "wild_galaxy",
		"name": "Wild Galaxy",
		# NOTE the second sentence. The old description read "roll twice for
		# world traits and use both results", which is not what the book says:
		# a contradictory second roll is IGNORED, not stacked.
		"description": "Roll twice for world traits on every world you visit. If the two results contradict, ignore the second.",
		"book_text": "If you prefer a more chaotic and wild place to adventure, you may opt to roll twice for each world you visit. If the results would seem to contradict, ignore the second roll.",
		"category": "world",
		# Cited as p.65 until 2026-09-04. The rule is printed in the World Traits
		# table sidebar on p.73 (PDF idx 72); p.65 is the campaign-setup step that
		# merely invites house rules.
		"source": "Core Rules p.73",
		"effects": [
			{"type": "world_generation", "modifier": "double_traits"}
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


## Every canonical rule id. The picker writes these; free prose never matches one.
static func get_all_rule_ids() -> Array[String]:
	var ids: Array[String] = []
	for rule in HOUSE_RULES:
		ids.append(str(rule.get("id", "")))
	return ids


## True when `rule_id` names a rule this table defines. Used to keep a player's
## free-text prose out of the mechanical rule list.
static func is_known_rule(rule_id: String) -> bool:
	return rule_id in get_all_rule_ids()


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
