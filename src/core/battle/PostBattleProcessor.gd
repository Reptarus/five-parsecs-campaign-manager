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

# Injury + XP data loaded from data/injury_results.json (Core Rules p.122-123)
static var _injury_json: Dictionary = {}
static var _injury_json_loaded: bool = false

static func _load_injury_json() -> void:
	if _injury_json_loaded:
		return
	var file := FileAccess.open("res://data/injury_results.json", FileAccess.READ)
	if file:
		var json := JSON.new()
		if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
			_injury_json = json.data
	if _injury_json.is_empty():
		push_warning("PostBattleProcessor: Failed to load injury_results.json, using fallback values")
	_injury_json_loaded = true

static func _get_xp(key: String, fallback: int) -> int:
	_load_injury_json()
	var xp_data: Dictionary = _injury_json.get("xp_awards", {})
	return int(xp_data.get(key, fallback))

static func _get_injury_entries(table_key: String) -> Array:
	_load_injury_json()
	var tables: Dictionary = _injury_json.get("tables", {})
	var table: Dictionary = tables.get(table_key, {})
	return table.get("entries", [])

# XP award accessors — canonical source: data/injury_results.json (Core Rules p.123)
var XP_BECAME_CASUALTY: int:
	get: return _get_xp("became_casualty", 1)
var XP_SURVIVED_LOST: int:
	get: return _get_xp("survived_lost_battle", 2)
var XP_SURVIVED_WON: int:
	get: return _get_xp("survived_won_battle", 3)
var XP_FIRST_KILL: int:
	get: return _get_xp("first_kill", 1)
var XP_UNIQUE_INDIVIDUAL: int:
	get: return _get_xp("unique_individual", 1)

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

## Process complete battle end per Core Rules p.119
func process_battle_end(
		tracked_units: Dictionary,
		battle_context: Dictionary
		) -> BattlefieldTypes.BattleResults:
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
	## Human Injury Table — data-driven from data/injury_results.json (Core Rules p.122)
	var roll := _roll_d100()
	var injury_data := {"unit_name": unit.unit_name, "roll": roll}

	var entries: Array = _get_injury_entries("human")
	var matched := _match_injury_entry(entries, roll)
	if matched.is_empty():
		# Fallback if JSON unavailable
		injury_data["name"] = "Minor injuries"
		injury_data["dead"] = false
		injury_data["recovery_time"] = 1
		injury_data["effects"] = ["No long-term effect"]
		return injury_data

	injury_data["name"] = matched.get("name", "Unknown")
	injury_data["dead"] = matched.get("dead", false)
	injury_data["effects"] = matched.get("effects", [])

	# Handle recovery time: fixed value or dice roll
	if matched.has("recovery_time_roll"):
		injury_data["recovery_time"] = _resolve_dice_expression(str(matched["recovery_time_roll"]))
	else:
		injury_data["recovery_time"] = int(matched.get("recovery_time", 0))

	# Handle surgery cost (Crippling wound)
	if matched.has("surgery_cost_roll"):
		var surgery_cost: int = _resolve_dice_expression(str(matched["surgery_cost_roll"]))
		injury_data["surgery_cost"] = surgery_cost
		# Update effects text with actual rolled cost
		var effects: Array = []
		for effect in injury_data["effects"]:
			effects.append(str(effect).replace("1D6 credits", "%d credits" % surgery_cost))
		injury_data["effects"] = effects

	# Handle stat reduction (Crippling wound)
	if matched.has("stat_reduction"):
		injury_data["stat_reduction"] = matched["stat_reduction"]

	# Handle luck bonus (Miraculous escape)
	if matched.has("luck_bonus"):
		injury_data["luck_bonus"] = int(matched["luck_bonus"])

	# Handle XP bonus (School of hard knocks)
	if matched.has("xp_bonus"):
		injury_data["xp_bonus"] = int(matched["xp_bonus"])

	return injury_data

func _roll_bot_injury_table(unit: BattlefieldTypes.UnitData) -> Dictionary:
	## Bot/Soulless Injury Table — data-driven from data/injury_results.json (Core Rules p.122)
	var roll := _roll_d100()
	var injury_data := {"unit_name": unit.unit_name, "roll": roll}

	var entries: Array = _get_injury_entries("bot")
	var matched := _match_injury_entry(entries, roll)
	if matched.is_empty():
		injury_data["name"] = "Just a few dents"
		injury_data["destroyed"] = false
		injury_data["recovery_time"] = 0
		injury_data["effects"] = ["No long-term effect"]
		return injury_data

	injury_data["name"] = matched.get("name", "Unknown")
	injury_data["destroyed"] = matched.get("destroyed", false)
	injury_data["effects"] = matched.get("effects", [])

	if matched.has("recovery_time_roll"):
		injury_data["recovery_time"] = _resolve_dice_expression(str(matched["recovery_time_roll"]))
	else:
		injury_data["recovery_time"] = int(matched.get("recovery_time", 0))

	return injury_data

func _match_injury_entry(entries: Array, roll: int) -> Dictionary:
	## Find the injury entry matching a D100 roll from JSON entries
	for entry in entries:
		var roll_range: Array = entry.get("roll_range", [])
		if roll_range.size() == 2:
			if roll >= int(roll_range[0]) and roll <= int(roll_range[1]):
				return entry
	return {}

func _resolve_dice_expression(expr: String) -> int:
	## Resolve a dice expression like "1d6" or "1d3+1" via DiceManager or fallback
	var lower := expr.to_lower().strip_edges()
	# Handle "NdX+Y" pattern
	if "+" in lower:
		var parts := lower.split("+")
		return _roll_dice_safely(parts[0].strip_edges()) + int(parts[1].strip_edges())
	return _roll_dice_safely(lower)

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
