class_name CharacterAdvancementService
## Character Advancement Service for Five Parsecs Campaign Manager
## Handles character stat advancement, XP spending, and advancement validation
## Based on Five Parsecs Core Rulebook p.67-76 (Character Advancement)
##
## Usage: Service layer implementing advancement business logic
## Architecture: Stateless service using CharacterAdvancementConstants

## Dependencies
const CharacterAdvancementConstants = preload("res://src/core/systems/CharacterAdvancementConstants.gd")
const OnboardItemServiceRef = preload("res://src/core/equipment/OnboardItemService.gd")

## Signals for advancement events

## ==========================================
## PUBLIC API - ADVANCEMENT VALIDATION
## ==========================================

## Check if character can advance a specific stat
static func can_advance_stat(character: Dictionary, stat_name: String) -> Dictionary:
	## Check if character can advance a stat with detailed result
	##
	## Args:
	## character: Character data dictionary with stats and experience
	## stat_name: Name of stat to check (reactions, combat_skill, speed, savvy, toughness, luck)
	##
	## Returns:
	## Dictionary with:
	## - can_advance: bool - Whether advancement is possible
	## - reason: String - Human-readable reason if cannot advance
	## - xp_cost: int - Cost to advance
	## - current_value: int - Current stat value
	## - max_value: int - Maximum stat value for this character
	var result := {
		"can_advance": false,
		"reason": "",
		"xp_cost": 0,
		"current_value": 0,
		"max_value": 0
	}

	# Normalize stat name
	var stat_lower := stat_name.to_lower()

	# Get advancement cost
	var cost := CharacterAdvancementConstants.get_advancement_cost(stat_lower)

	# On-board item, Genetic reconfiguration kit (Core Rules p.57): "Reduce the
	# cost of an ability score upgrade by 2 XP. Has no effect on Bots or Soulless.
	# K'Erin may only use this to increase Toughness. Single-use."
	#
	# The discount is applied HERE rather than in advance_stat() because this
	# function also runs the affordability check ("Insufficient XP"). Discounting
	# only at deduction time would refuse a character holding exactly cost-2 XP —
	# the precise case the kit exists to solve — and get_available_advancements()
	# would hide the upgrade the player just armed the kit for.
	var kit_discount: int = _genetic_kit_discount(character, stat_lower)
	if kit_discount > 0:
		cost = maxi(0, cost - kit_discount)
		result["genetic_kit_discount"] = kit_discount
	result.xp_cost = cost

	if cost >= 999:
		result.reason = "Invalid stat name: " + stat_name
		return result

	# De-converted (Core Rules p.19) and Assault Bots (p.21): Savvy can
	# never be improved. str()-wrap origin — legacy saves store it as float.
	if stat_lower == "savvy":
		var sid := str(character.get(
			"species_id", character.get("origin", ""))).to_lower()
		if sid in ["de_converted", "de-converted", "assault_bot", "assault bot"]:
			result.reason = "Savvy can never be improved (species rule)"
			return result

	# Get current XP
	var current_xp: int = character.get("experience", 0)
	if current_xp < cost:
		result.reason = "Insufficient XP: have %d, need %d" % [current_xp, cost]
		return result

	# Get current stat value
	var current_value: int = character.get(stat_lower, 0)
	result.current_value = current_value

	# Get maximum value for this character (considering background/species)
	var max_value: int = CharacterAdvancementConstants.get_stat_maximum(stat_lower, character)
	result.max_value = max_value

	if current_value >= max_value:
		result.reason = "Stat already at maximum: %d/%d" % [current_value, max_value]
		return result

	# All checks passed
	result.can_advance = true
	result.reason = "Can advance %s from %d to %d for %d XP" % [stat_name, current_value, current_value + 1, cost]
	return result

## Get list of all stats the character can currently advance
static func get_available_advancements(character: Dictionary) -> Array[Dictionary]:

	## Args:
	## 	character: Character data dictionary
	##
	## Returns:
	## 	Array of advancement info dictionaries, sorted by priority
	##
	var available: Array[Dictionary] = []

	# Core Rules p.123: Player freely chooses which stat to advance (no priority)
	for stat in CharacterAdvancementConstants.ADVANCEMENT_COSTS.keys():
		var check_result = can_advance_stat(character, stat)
		if check_result.can_advance:
			available.append({
				"stat": stat,
				"cost": check_result.xp_cost,
				"current": check_result.current_value,
				"max": check_result.max_value
			})

	return available

## ==========================================
## PUBLIC API - ADVANCEMENT EXECUTION
## ==========================================

## Advance a single stat for a character
static func advance_stat(character: Dictionary, stat_name: String) -> Dictionary:
	## Advance a stat and deduct XP
	##
	## Args:
	## character: Character data dictionary (will be modified)
	## stat_name: Stat to advance
	##
	## Returns:
	## Dictionary with:
	## - success: bool - Whether advancement succeeded
	## - message: String - Result message
	## - stat: String - Stat name
	## - old_value: int - Previous stat value
	## - new_value: int - New stat value
	## - xp_remaining: int - XP after advancement
	var result := {
		"success": false,
		"message": "",
		"stat": stat_name,
		"old_value": 0,
		"new_value": 0,
		"xp_remaining": 0
	}

	# Validate advancement
	var can_advance_result = can_advance_stat(character, stat_name)

	if not can_advance_result.can_advance:
		result.message = can_advance_result.reason
		return result

	# Perform advancement
	var stat_lower := stat_name.to_lower()
	var old_value: int = character.get(stat_lower, 0)
	var new_value: int = old_value + 1
	var cost: int = can_advance_result.xp_cost

	# Update character data
	character[stat_lower] = new_value
	character["experience"] = character.get("experience", 0) - cost

	# Core Rules p.64: the three "Upgrade N Characters 10 Times" Victory
	# Conditions count Character Upgrades, and NOTHING counted them — no
	# per-character tally existed and GameStateManager's milestone recorder had
	# zero callers, so those conditions sat at 0/N for the life of every
	# campaign. Recorded here, at the service every live Dictionary-crew path
	# goes through (post-battle wizard, character sheet, upgrade dialog).
	var gsm: Node = _game_state_manager()
	if gsm and gsm.has_method("record_character_upgrade"):
		gsm.record_character_upgrade(character)

	# Spend the kit only once the upgrade actually went through — can_advance_stat
	# is called speculatively by get_available_advancements() for every stat, so
	# consuming it there would burn the item on a menu refresh.
	if int(can_advance_result.get("genetic_kit_discount", 0)) > 0:
		OnboardItemServiceRef.consume_armed_genetic_kit(_campaign())
		result.message += " (Genetic Reconfiguration Kit: -2 XP, kit used up)"

	# Set result
	result.success = true
	result.message = "Advanced %s from %d to %d (-%d XP)" % [stat_name, old_value, new_value, cost]
	result.old_value = old_value
	result.new_value = new_value
	result.xp_remaining = character.experience

	return result

## Auto-advance character using XP (prioritizes combat skills)
static func auto_advance_character(character: Dictionary, max_advancements: int = 999) -> Dictionary:

	## Args:
	## 	character: Character data dictionary (will be modified)
	## 	max_advancements: Maximum number of advancements to apply
	##
	## Returns:
	## 	Dictionary with:
	## 	- advancements_applied: int - Number of successful advancements
	## 	- advancements: Array[Dictionary] - List of advancement results
	## 	- xp_spent: int - Total XP spent
	## 	- xp_remaining: int - XP after all advancements
	##
	var result := {
		"advancements_applied": 0,
		"advancements": [] as Array[Dictionary],
		"xp_spent": 0,
		"xp_remaining": character.get("experience", 0)
	}

	var advancements_made := 0

	# Keep advancing until no more possible or limit reached
	while advancements_made < max_advancements:
		var available := get_available_advancements(character)

		if available.is_empty():
			break  # No more advancements possible

		# Take first available (highest priority)
		var next_advancement := available[0]
		var advancement_result := advance_stat(character, next_advancement.stat)

		if advancement_result.success:
			result.advancements.append(advancement_result)
			result.xp_spent += next_advancement.cost
			advancements_made += 1
		else:
			break  # Something went wrong, stop

	result.advancements_applied = advancements_made
	result.xp_remaining = character.get("experience", 0)

	return result

## ==========================================
## PUBLIC API - ADVANCEMENT PREVIEW
## ==========================================

## Preview what auto-advancement would do without applying it
static func preview_auto_advancement(character: Dictionary, max_advancements: int = 999) -> Dictionary:
	## Preview auto-advancement without modifying character
	##
	## Args:
	## character: Character data dictionary (will NOT be modified)
	## max_advancements: Maximum number of advancements to preview
	##
	## Returns:
	## Dictionary with preview info (same structure as auto_advance_character)
	# Create a deep copy to avoid modifying original
	var character_copy := character.duplicate(true)

	# Run auto-advancement on copy
	return auto_advance_character(character_copy, max_advancements)

## Get advancement cost summary for character
static func get_advancement_summary(character: Dictionary) -> Dictionary:

	## Args:
	## 	character: Character data dictionary
	##
	## Returns:
	## 	Dictionary with:
	## 	- current_xp: int
	## 	- available_advancements: Array[Dictionary]
	## 	- next_affordable: Dictionary (cheapest advancement character can afford)
	## 	- total_advancement_cost: int (cost to max all stats)
	##
	var summary := {
		"current_xp": character.get("experience", 0),
		"available_advancements": get_available_advancements(character),
		"next_affordable": {},
		"total_advancement_cost": 0
	}

	# Find cheapest affordable advancement
	for advancement in summary.available_advancements:
		if summary.next_affordable.is_empty() or advancement.cost < summary.next_affordable.cost:
			summary.next_affordable = advancement

	# Calculate total cost to max all stats
	for stat in CharacterAdvancementConstants.ADVANCEMENT_COSTS.keys():
		var current_value: int = character.get(stat, 0)
		var max_value: int = CharacterAdvancementConstants.get_stat_maximum(stat, character)
		var steps := max_value - current_value

		if steps > 0:
			var cost := CharacterAdvancementConstants.get_advancement_cost(stat)
			summary.total_advancement_cost += cost * steps

	return summary


## GameState is an autoload NODE, not an engine singleton, so a non-Node class
## must resolve it through the scene tree root (see CLAUDE.md).
## The GameStateManager autoload, or null. Separate from `_campaign()` below:
## the campaign is a Resource and the counters live behind the manager's setters.
static func _game_state_manager() -> Node:
	var loop: Variant = Engine.get_main_loop()
	if loop == null or not ("root" in loop):
		return null
	return loop.root.get_node_or_null("/root/GameStateManager")


static func _campaign():
	var loop: Variant = Engine.get_main_loop()
	if loop == null or not ("root" in loop):
		return null
	var gs: Node = loop.root.get_node_or_null("/root/GameState")
	if gs == null:
		return null
	return gs.get_current_campaign() if gs.has_method("get_current_campaign") 		else null


## 2 XP off ONE ability upgrade, if the player armed the kit and this character
## and stat are eligible under p.57's restrictions. 0 otherwise.
static func _genetic_kit_discount(character: Dictionary, stat_lower: String) -> int:
	var campaign: Variant = _campaign()
	if campaign == null or not OnboardItemServiceRef.is_genetic_kit_armed(campaign):
		return 0
	var species: String = str(character.get(
		"species_id", character.get("origin", ""))).to_lower()
	if not OnboardItemServiceRef.genetic_kit_allows(
			species,
			bool(character.get("is_bot", false)),
			bool(character.get("is_soulless", false)),
			stat_lower):
		return 0
	return 2
