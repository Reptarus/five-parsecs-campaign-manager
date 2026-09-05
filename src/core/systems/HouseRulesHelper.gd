class_name HouseRulesHelper
extends RefCounted

## Centralized house rule checking utility.
##
## Usage:
##   if HouseRulesHelper.is_enabled("varied_armaments"):
##       ...
##
## THE BUG THIS FIXES (2026-09-04). is_enabled() asked
## `GameState.is_house_rule_enabled()` and then `GameStateManager.get_house_rules()`.
## NEITHER METHOD EXISTS ANYWHERE IN src/ — `grep house_rule` over
## GameStateManager.gd returns nothing — so both has_method() guards were
## permanently false and every call returned `false`. Eight guarded call sites
## across combat, enemy generation, crew generation, patron rewards and
## post-battle injuries sat in their default branch for the life of the feature.
##
## The OWNER of house_rules is the campaign: FiveParsecsCampaignCore declares it
## at :54, writes it via set_house_rules() :302 and reads it via
## get_house_rules() :307 — and PostBattleContext.gd:66-70 was already resolving
## it correctly. This now uses that same owner.
##
## SECOND, INDEPENDENT CAUSE, fixed in ExpandedConfigPanel: the creation UI was a
## free-text TextEdit whose lines were stored verbatim, so `campaign.house_rules`
## held prose like "Crits do double damage" and a repaired accessor still would
## never have matched the id "varied_armaments". Fixing either half alone changes
## nothing a player can see. The picker now writes canonical ids, and a player's
## own prose is kept in a separate field that is deliberately never matched here.

const HouseRulesDefinitions = preload("res://src/data/house_rules_definitions.gd")

## Check whether a specific house rule is enabled on the current campaign.
##
## Only ids defined by HouseRulesDefinitions can ever be true — a player's own
## free-text house rules are prose and are stored elsewhere on purpose.
static func is_enabled(rule_id: String) -> bool:
	if rule_id.is_empty():
		return false
	return rule_id in get_enabled_rules()

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

## Every enabled house rule id on the current campaign.
##
## Reads the OWNER (the campaign), which is the only place house_rules is
## written — CampaignFinalizationService:686-688 calls campaign.set_house_rules()
## with what the creation wizard collected.
##
## Filtered against HouseRulesDefinitions so a stray value can never switch on a
## mechanic: legacy saves carry free-text prose in this array (that was the only
## thing the old TextEdit could produce), and a save hand-edited to
## "brutal_combat" must not resurrect a rule that no longer exists.
static func get_enabled_rules() -> Array[String]:
	var raw: Variant = _campaign_house_rules()
	if not (raw is Array):
		return []
	var enabled: Array[String] = []
	for r: Variant in (raw as Array):
		if not (r is String):
			continue
		var id: String = (r as String).strip_edges()
		if HouseRulesDefinitions.is_known_rule(id) and not (id in enabled):
			enabled.append(id)
	return enabled


## Raw house_rules off the current campaign, in whatever shape it exposes.
## Mirrors PostBattleContext.gd:66-70, the one place that already read this
## correctly.
static func _campaign_house_rules() -> Variant:
	var campaign: Variant = _get_current_campaign()
	if campaign == null:
		return []
	if campaign.has_method("get_house_rules"):
		return campaign.get_house_rules()
	if "house_rules" in campaign:
		return campaign.house_rules
	return []


## The active campaign, via the GameState autoload.
##
## Resolved through Engine.get_main_loop() rather than get_node_or_null(): this
## is a static method on a RefCounted, so there is no tree context, and a bare
## absolute get_node() from outside the tree ERRORS and aborts the caller rather
## than returning null.
static func _get_current_campaign() -> Variant:
	var game_state := _get_game_state()
	if game_state == null:
		return null
	if game_state.has_method("get_current_campaign"):
		return game_state.get_current_campaign()
	if "current_campaign" in game_state:
		return game_state.current_campaign
	return null

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

