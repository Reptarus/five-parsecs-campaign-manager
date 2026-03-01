class_name FPCM_PostBattleProcessor
extends Node

## Post-Battle Results Processor
##
## Processes injuries, experience, and loot per Five Parsecs Core Rules p.119.
## Each character that became a casualty rolls D100 on the Injury Table.
## XP awards per Core Rules p.119. Loot via D100 Battlefield Finds (p.66) and Loot Table (p.70-72).

# Dependencies
const BattlefieldTypes = preload("res://src/core/battle/BattlefieldTypes.gd")
const DifficultyModifiers = preload("res://src/core/systems/DifficultyModifiers.gd")

# Signals
signal results_processed(battle_results: BattlefieldTypes.BattleResults)
signal casualty_processed(unit_name: String, casualty_data: Dictionary)
signal injury_processed(unit_name: String, injury_data: Dictionary)
signal experience_calculated(experience_data: Dictionary)
signal loot_generated(loot_items: Array[Dictionary])
signal processing_error(error_code: String, details: Dictionary)

# Processing pipeline stages
enum ProcessingStage {
	VALIDATE_INPUT,
	PROCESS_INJURIES,
	CALCULATE_EXPERIENCE,
	GENERATE_LOOT,
	FINALIZE_RESULTS
}

# Core Rules p.119 -- XP Awards (per character)
const XP_BECAME_CASUALTY := 1
const XP_SURVIVED_LOST := 2
const XP_SURVIVED_WON := 3
const XP_FIRST_KILL := 1
const XP_UNIQUE_INDIVIDUAL := 1

# System state
@export var processing_active: bool = false
@export var current_stage: ProcessingStage = ProcessingStage.VALIDATE_INPUT

# Manager dependencies
var dice_manager: Node = null

func _ready() -> void:
	_initialize_dependencies()

func _initialize_dependencies() -> void:
	dice_manager = _get_manager_safely("DiceManager")

func _get_manager_safely(manager_name: String) -> Node:
	var singleton_path := "/root/%s" % manager_name
	if has_node(singleton_path):
		return get_node(singleton_path)
	return null

# =====================================================
# MAIN PROCESSING PIPELINE
# =====================================================

func process_battle_end(
		tracked_units: Dictionary,
		battle_context: Dictionary
		) -> BattlefieldTypes.BattleResults:
	## Process complete battle end per Core Rules p.119
	## @param tracked_units: Dictionary of unit_id -> UnitData from battle tracker
	## @param battle_context: Battle context including victory, rounds, held_field, etc.
	## @return: Complete battle results ready for post-battle phase
	if processing_active:
		push_warning("PostBattleProcessor: Processing already in progress")
		return _create_empty_results()

	processing_active = true
	current_stage = ProcessingStage.VALIDATE_INPUT

	var validation_result := _validate_processing_input(tracked_units, battle_context)
	if not validation_result.valid:
		processing_error.emit("VALIDATION_FAILED", validation_result.errors)
		processing_active = false
		return _create_empty_results()

	# Initialize results
	var battle_results := BattlefieldTypes.BattleResults.new()
	var bid = battle_context.get(
		"battle_id",
		"unknown_%d" % Time.get_unix_time_from_system())
	battle_results.battle_id = str(bid)
	battle_results.rounds_fought = int(battle_context.get("rounds", 1))

	var victory: bool = battle_context.get("victory", false)
	battle_results.set_outcome("victory" if victory else "defeat")
	battle_results.enemies_defeated = _count_defeated_enemies(tracked_units)
	battle_results.hold_field = battle_context.get("held_field", victory)

	# Register all crew as participants
	var crew_units := _get_crew_units(tracked_units)
	for unit in crew_units:
		battle_results.add_participant(unit.unit_id)

	# Stage 1: Process injuries for all casualties (Core Rules p.119 Injury Table)
	current_stage = ProcessingStage.PROCESS_INJURIES
	_process_injury_table(tracked_units, battle_results)

	# Stage 2: Calculate experience gains (Core Rules p.119 XP Awards)
	current_stage = ProcessingStage.CALCULATE_EXPERIENCE
	_calculate_experience_gains(
		tracked_units, battle_context, battle_results)

	# Stage 3: Generate loot (Core Rules p.66-72)
	current_stage = ProcessingStage.GENERATE_LOOT
	_generate_loot(battle_context, battle_results)

	# Finalize
	current_stage = ProcessingStage.FINALIZE_RESULTS
	_finalize_battle_results(battle_results, battle_context)

	processing_active = false
	results_processed.emit(battle_results)
	return battle_results

func process_quick_victory(crew_alive: bool, rounds_fought: int) -> BattlefieldTypes.BattleResults:
	## Quick processing for simple victory/defeat scenarios
	var results := BattlefieldTypes.BattleResults.new()
	results.set_outcome("victory" if crew_alive else "defeat")
	results.rounds_fought = rounds_fought
	return results

# =====================================================
# INJURY TABLE -- Core Rules p.119
# =====================================================

func _process_injury_table(
		tracked_units: Dictionary,
		results: BattlefieldTypes.BattleResults) -> void:
	## Roll on Injury Table (D100) for each character that became a casualty.
	## Knocked-out characters (3 simultaneous Stun) skip this roll.
	## Bots/Soulless use the Bot Injury Table.
	var crew_units := _get_crew_units(tracked_units)

	for unit in crew_units:
		if not unit.is_alive():
			# Skip if knocked out from 3 simultaneous Stun results
			if "knocked_out_stun" in unit.status_effects:
				continue

			var is_bot := _is_bot_or_soulless(unit)
			var injury_data: Dictionary

			if is_bot:
				injury_data = _roll_bot_injury_table(unit)
			else:
				injury_data = _roll_human_injury_table(unit)

			if injury_data.get("dead", false) or injury_data.get("destroyed", false):
				# Check Luck override: character with Luck survives but loses ALL Luck
				var has_luck := false
				if not is_bot and unit.original_character:
					var luck_value = unit.original_character.get("luck")
					if luck_value != null and int(luck_value) > 0:
						has_luck = true

				if has_luck:
					injury_data["dead"] = false
					injury_data["luck_override"] = true
					injury_data["effects"] = [
						"Survived via Luck (lost ALL Luck)"]
					var luck_name: String = "Luck override - " \
						+ injury_data.get("name", "")
					results.add_injury(
						unit.unit_id, luck_name, 0, 0)
				else:
					var cause: String = injury_data.get(
						"name", "killed")
					results.add_casualty(
						unit.unit_id, cause,
						results.rounds_fought, cause)
				casualty_processed.emit(unit.unit_name, injury_data)
			else:
				var recovery: int = injury_data.get(
					"recovery_time", 0)
				var inj_name: String = injury_data.get(
					"name", "unknown")
				results.add_injury(
					unit.unit_id, inj_name, 1, recovery)
				injury_processed.emit(unit.unit_name, injury_data)

func _roll_human_injury_table(unit: BattlefieldTypes.UnitData) -> Dictionary:
	## Human Injury Table -- Core Rules p.119
	## Roll D100 per casualty
	var roll := _roll_d100()
	var injury_data := {"unit_name": unit.unit_name, "roll": roll}

	if roll <= 5:
		# Gruesome fate -- dead, all carried equipment damaged
		injury_data["name"] = "Gruesome fate"
		injury_data["dead"] = true
		injury_data["recovery_time"] = 0
		injury_data["effects"] = [
			"Character is dead",
			"All carried equipment is damaged"]
	elif roll <= 15:
		# Death or permanent injury -- dead/removed
		injury_data["name"] = "Death or permanent injury"
		injury_data["dead"] = true
		injury_data["recovery_time"] = 0
		injury_data["effects"] = ["Dead, or removed from the campaign"]
	elif roll == 16:
		# Miraculous escape -- survives, +1 Luck, all items permanently lost
		injury_data["name"] = "Miraculous escape"
		injury_data["dead"] = false
		injury_data["recovery_time"] = 0
		injury_data["luck_bonus"] = 1
		injury_data["effects"] = [
			"Character survives and receives +1 Luck",
			"All items carried are permanently lost"]
	elif roll <= 30:
		# Equipment loss -- random carried item is damaged
		injury_data["name"] = "Equipment loss"
		injury_data["dead"] = false
		injury_data["recovery_time"] = 0
		injury_data["effects"] = ["Random carried item is damaged"]
	elif roll <= 45:
		# Crippling wound -- 1D6 credits surgery or -1 to Speed/Toughness (highest)
		var surgery_cost := _roll_dice_safely("d6")
		injury_data["name"] = "Crippling wound"
		injury_data["dead"] = false
		injury_data["recovery_time"] = _roll_dice_safely("d6")
		injury_data["surgery_cost"] = surgery_cost
		injury_data["stat_reduction"] = {
			"stats": ["speed", "toughness"],
			"pick": "highest", "amount": -1}
		injury_data["effects"] = [
			"Require %d credits of surgery immediately" % surgery_cost,
			"Or suffer -1 permanent reduction to highest of Speed or Toughness"
		]
	elif roll <= 54:
		# Serious injury -- recovery 1D3+1 turns
		injury_data["name"] = "Serious injury"
		injury_data["dead"] = false
		injury_data["recovery_time"] = _roll_dice_safely("d3") + 1
		injury_data["effects"] = ["No long-term effect"]
	elif roll <= 80:
		# Minor injuries -- recovery 1 turn
		injury_data["name"] = "Minor injuries"
		injury_data["dead"] = false
		injury_data["recovery_time"] = 1
		injury_data["effects"] = ["No long-term effect"]
	elif roll <= 95:
		# Knocked out -- no recovery
		injury_data["name"] = "Knocked out"
		injury_data["dead"] = false
		injury_data["recovery_time"] = 0
		injury_data["effects"] = ["No long-term effect"]
	else:
		# School of hard knocks -- earn 1 XP
		injury_data["name"] = "School of hard knocks"
		injury_data["dead"] = false
		injury_data["recovery_time"] = 0
		injury_data["xp_bonus"] = 1
		injury_data["effects"] = ["Earn 1 XP"]

	return injury_data

func _roll_bot_injury_table(unit: BattlefieldTypes.UnitData) -> Dictionary:
	## Bot/Soulless Injury Table -- Core Rules p.119
	var roll := _roll_d100()
	var injury_data := {
		"unit_name": unit.unit_name, "roll": roll}

	if roll <= 5:
		# Obliterated -- destroyed, all equipment damaged
		injury_data["name"] = "Obliterated"
		injury_data["destroyed"] = true
		injury_data["recovery_time"] = 0
		injury_data["effects"] = [
			"Destroyed",
			"All carried equipment is damaged"]
	elif roll <= 15:
		# Destroyed
		injury_data["name"] = "Destroyed"
		injury_data["destroyed"] = true
		injury_data["recovery_time"] = 0
		injury_data["effects"] = ["Destroyed"]
	elif roll <= 30:
		# Equipment loss -- random carried item is damaged
		injury_data["name"] = "Equipment loss"
		injury_data["destroyed"] = false
		injury_data["recovery_time"] = 0
		injury_data["effects"] = ["Random carried item is damaged"]
	elif roll <= 45:
		# Severe damage -- repair 1D6 turns
		injury_data["name"] = "Severe damage"
		injury_data["destroyed"] = false
		injury_data["recovery_time"] = _roll_dice_safely("d6")
		injury_data["effects"] = ["No long-term effect"]
	elif roll <= 65:
		# Minor damage -- repair 1 turn
		injury_data["name"] = "Minor damage"
		injury_data["destroyed"] = false
		injury_data["recovery_time"] = 1
		injury_data["effects"] = ["No long-term effect"]
	else:
		# Just a few dents -- no repair needed
		injury_data["name"] = "Just a few dents"
		injury_data["destroyed"] = false
		injury_data["recovery_time"] = 0
		injury_data["effects"] = ["No long-term effect"]

	return injury_data

func _is_bot_or_soulless(unit: BattlefieldTypes.UnitData) -> bool:
	## Check if unit is a bot or soulless (uses Bot Injury Table)
	if unit.original_character:
		var species = unit.original_character.get("species")
		if species != null:
			var species_str := str(species).to_lower()
			if species_str in ["bot", "soulless", "robot", "android"]:
				return true
	return false

# =====================================================
# EXPERIENCE -- Core Rules p.119
# =====================================================

func _calculate_experience_gains(
		tracked_units: Dictionary,
		battle_context: Dictionary,
		results: BattlefieldTypes.BattleResults) -> void:
	## Calculate XP per Core Rules p.119
	## - Became a casualty: 1 XP
	## - Survived, but did not Win: 2 XP
	## - Survived and Won: 3 XP
	## - First character to inflict a casualty: +1 XP
	## - Killed Unique Individual: +1 XP
	## - Campaign is on Easy mode: +1 XP
	## Note: Bots do not receive XP.
	var crew_units := _get_crew_units(tracked_units)
	var victory: bool = battle_context.get("victory", false)
	var difficulty_level: int = battle_context.get(
		"difficulty_level", GlobalEnums.DifficultyLevel.NORMAL)
	var difficulty_xp_bonus: int = DifficultyModifiers.get_xp_bonus(
		difficulty_level)
	var first_kill_id: String = battle_context.get(
		"first_kill_crew_id", "")
	var killed_unique: bool = battle_context.get(
		"unique_individual_killed", false)

	for unit in crew_units:
		# Bots do not receive XP
		if _is_bot_or_soulless(unit):
			continue

		var xp := 0

		if not unit.is_alive():
			# Became a casualty: 1 XP
			xp += XP_BECAME_CASUALTY
		else:
			# Survived
			if victory:
				xp += XP_SURVIVED_WON  # 3 XP
			else:
				xp += XP_SURVIVED_LOST  # 2 XP

		# Easy mode bonus: +1 XP for all participants
		xp += difficulty_xp_bonus

		results.set_xp(unit.unit_id, xp)

	# First character to inflict a casualty: +1 XP
	if first_kill_id != "":
		results.add_achievement(
			first_kill_id, "First kill", XP_FIRST_KILL)

	# Killed Unique Individual: +1 XP
	if killed_unique:
		var unique_killer: String = battle_context.get(
			"unique_kill_crew_id", first_kill_id)
		if unique_killer == "" and crew_units.size() > 0:
			unique_killer = crew_units[0].unit_id
		if unique_killer != "":
			results.add_achievement(
				unique_killer,
				"Killed Unique Individual",
				XP_UNIQUE_INDIVIDUAL)

	# School of hard knocks XP bonus from injury table
	for injury in results.injuries:
		if injury.get("injury_type", "") == "School of hard knocks":
			var crew_id: String = injury.get("crew_id", "")
			if crew_id != "":
				results.add_xp(crew_id, 1)

	experience_calculated.emit(results.xp_earned.duplicate())

# =====================================================
# LOOT -- Core Rules p.66-72
# =====================================================

func _generate_loot(
		battle_context: Dictionary,
		results: BattlefieldTypes.BattleResults) -> void:
	## Generate loot per Core Rules.
	## Battlefield Finds (p.66): D100 per find opportunity (held field, etc.)
	## Loot Table (p.70-72): D100 per loot roll earned
	var victory: bool = battle_context.get("victory", false)
	if not victory:
		return

	# Battlefield Finds -- number of rolls from battle context
	var find_rolls: int = battle_context.get("loot_opportunities", 0)
	if find_rolls <= 0 and results.hold_field:
		find_rolls = 1  # At least 1 find if held field

	for i in find_rolls:
		var find_roll := _roll_d100()
		var category: int = LootSystemConstants.get_battlefield_finds_category(find_roll)
		var find_data := _resolve_battlefield_find(category)
		results.add_loot(
			find_data.get("type", "unknown"),
			find_data.get("quality", "standard"),
			find_data.get("item_id", ""))

	# Loot Table rolls -- typically 1 for victory
	var loot_rolls: int = battle_context.get("loot_rolls", 1)
	results.loot_rolls = loot_rolls

	for i in loot_rolls:
		var loot_roll := _roll_d100()
		var loot_category: int = LootSystemConstants.get_main_loot_category(loot_roll)
		var loot_data := _resolve_loot_item(loot_category)
		results.add_loot(
			loot_data.get("type", "unknown"),
			loot_data.get("quality", "standard"),
			loot_data.get("item_id", ""))

	var items_copy: Array[Dictionary] = []
	for item in results.loot_items:
		items_copy.append(item)
	loot_generated.emit(items_copy)

func _resolve_battlefield_find(category: int) -> Dictionary:
	## Resolve a single battlefield find from its D100 category
	match category:
		LootSystemConstants.LootCategory.WEAPON:
			var weapon_roll := _roll_d100()
			var weapon_name := LootSystemConstants.get_weapon_from_subtable(weapon_roll)
			return {"type": "weapon", "item_id": weapon_name, "quality": "standard"}
		LootSystemConstants.LootCategory.CONSUMABLE:
			return {"type": "consumable", "item_id": "consumable_item", "quality": "standard"}
		LootSystemConstants.LootCategory.QUEST_RUMOR:
			return {"type": "quest_rumor", "item_id": "data_stick", "quality": "standard"}
		LootSystemConstants.LootCategory.SHIP_PART:
			return {"type": "ship_part", "item_id": "starship_part", "quality": "standard"}
		LootSystemConstants.LootCategory.TRINKET:
			return {"type": "trinket", "item_id": "personal_trinket", "quality": "standard"}
		LootSystemConstants.LootCategory.DEBRIS:
			var credits := _roll_dice_safely("d3")
			return {"type": "credits", "item_id": "debris_%d" % credits, "quality": str(credits)}
		LootSystemConstants.LootCategory.VITAL_INFO:
			return {
				"type": "vital_info",
				"item_id": "corporate_patron_opportunity",
				"quality": "standard"}
		_:
			return {"type": "nothing", "item_id": "", "quality": "standard"}

func _resolve_loot_item(category: int) -> Dictionary:
	## Resolve a single loot table result from its D100 category
	match category:
		LootSystemConstants.LootCategory.WEAPON:
			var weapon_roll := _roll_d100()
			var weapon_name := LootSystemConstants.get_weapon_from_subtable(weapon_roll)
			return {"type": "weapon", "item_id": weapon_name, "quality": "standard"}
		LootSystemConstants.LootCategory.DAMAGED_WEAPONS:
			var w1 := LootSystemConstants.get_weapon_from_subtable(_roll_d100())
			var w2 := LootSystemConstants.get_weapon_from_subtable(_roll_d100())
			return {
				"type": "damaged_weapons",
				"item_id": "%s, %s" % [w1, w2],
				"quality": "damaged"}
		LootSystemConstants.LootCategory.DAMAGED_GEAR:
			var g1 := LootSystemConstants.get_gear_from_subtable(_roll_d100())
			var g2 := LootSystemConstants.get_gear_from_subtable(_roll_d100())
			return {
				"type": "damaged_gear",
				"item_id": "%s, %s" % [g1, g2],
				"quality": "damaged"}
		LootSystemConstants.LootCategory.GEAR:
			var gear_roll := _roll_d100()
			var gear_name := LootSystemConstants.get_gear_from_subtable(gear_roll)
			return {"type": "gear", "item_id": gear_name, "quality": "standard"}
		LootSystemConstants.LootCategory.ODDS_AND_ENDS:
			var odds_roll := _roll_d100()
			var odds_data := LootSystemConstants.get_odds_and_ends_from_subtable(odds_roll)
			return {
				"type": "odds_and_ends",
				"item_id": odds_data.get("item", ""),
				"quality": "standard"}
		LootSystemConstants.LootCategory.REWARDS:
			var reward_roll := _roll_d100()
			var reward_data := LootSystemConstants.get_reward_from_subtable(reward_roll)
			return {
				"type": "rewards",
				"item_id": reward_data.get("item", ""),
				"quality": "standard"}
		_:
			return {"type": "unknown", "item_id": "", "quality": "standard"}

# =====================================================
# UTILITY FUNCTIONS
# =====================================================

func _validate_processing_input(
		tracked_units: Dictionary,
		battle_context: Dictionary) -> Dictionary:
	## Validate input data for processing
	var validation := {"valid": true, "errors": {}}

	if tracked_units == null:
		validation.valid = false
		validation.errors["units_null"] = "tracked_units is null"
		return validation

	if battle_context == null:
		validation.valid = false
		validation.errors["context_null"] = "battle_context is null"
		return validation

	if tracked_units.is_empty():
		validation.valid = false
		validation.errors["units"] = "No tracked units provided"

	if not battle_context.has("victory"):
		validation.valid = false
		validation.errors["victory"] = "Missing victory status"

	var crew_count := _get_crew_units(tracked_units).size()
	if crew_count == 0:
		validation.valid = false
		validation.errors["crew"] = "No crew units found"

	return validation

func _get_crew_units(tracked_units: Dictionary) -> Array[BattlefieldTypes.UnitData]:
	## Get all crew units from tracked units
	var crew_units: Array[BattlefieldTypes.UnitData] = []
	for unit in tracked_units.values():
		if unit.team == "crew":
			crew_units.append(unit)
	return crew_units

func _count_defeated_enemies(tracked_units: Dictionary) -> int:
	## Count defeated enemy units
	var defeated := 0
	for unit in tracked_units.values():
		if unit.team == "enemy" and not unit.is_alive():
			defeated += 1
	return defeated

func _finalize_battle_results(
		results: BattlefieldTypes.BattleResults,
		context: Dictionary) -> void:
	## Finalize results with metadata
	if context.has("mission_type"):
		results.objectives_completed.append("Mission type: %s" % context.mission_type)

func _create_empty_results() -> BattlefieldTypes.BattleResults:
	## Create empty results object for error cases
	var results := BattlefieldTypes.BattleResults.new()
	results.set_outcome("defeat")
	return results

func _roll_d100() -> int:
	## Roll D100 (1-100)
	return _roll_dice_safely("d100")

func _roll_dice_safely(pattern: String) -> int:
	## Safe dice rolling with DiceManager fallback
	if dice_manager and dice_manager.has_method("roll_dice"):
		return dice_manager.roll_dice(
			"PostBattleProcessor", pattern)
	return _fallback_dice_roll(pattern)

func _fallback_dice_roll(pattern: String) -> int:
	## Fallback dice implementation when DiceManager unavailable
	match pattern.to_lower():
		"d3": return randi_range(1, 3)
		"d6": return randi_range(1, 6)
		"d100": return randi_range(1, 100)
		"2d6": return randi_range(1, 6) + randi_range(1, 6)
		_: return randi_range(1, 6)

func get_processing_status() -> Dictionary:
	## Get current processing status
	return {
		"active": processing_active,
		"stage": ProcessingStage.keys()[current_stage]
	}
