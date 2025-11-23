class_name FPCM_PostBattleProcessor
extends Node

## Post-Battle Results Processor
##
## Handles transition from tactical battle to post-battle campaign phase.
## Processes casualties, injuries, experience, and loot per Five Parsecs rules.
## Optimized for seamless integration with existing post-battle systems.
##
## Architecture: Clean data transformation pipeline with validation
## Performance: Efficient processing with comprehensive error handling

# Dependencies
const BattlefieldTypes = preload("res://src/core/battle/BattlefieldTypes.gd")
# GlobalEnums available as autoload singleton

# Processing completion signals
signal results_processed(battle_results: BattlefieldTypes.BattleResults)
signal casualty_processed(unit_name: String, casualty_data: Dictionary)
signal injury_processed(unit_name: String, injury_data: Dictionary)
signal experience_calculated(experience_data: Dictionary)
signal loot_generated(loot_opportunities: Array[String])
signal processing_error(error_code: String, details: Dictionary)

# Processing pipeline stages
enum ProcessingStage {
	VALIDATE_INPUT,
	PROCESS_CASUALTIES,
	PROCESS_INJURIES,
	CALCULATE_EXPERIENCE,
	GENERATE_LOOT,
	FINALIZE_RESULTS
}

# Injury types per Five Parsecs rules (Core Rules p.94-95)
enum InjuryType {
	LIGHT_WOUND,
	SERIOUS_INJURY,
	KNOCKED_OUT,
	EQUIPMENT_DAMAGE,
	PERMANENT_INJURY,
	CRITICAL_CONDITION
}

# Experience calculation parameters
const BASE_EXPERIENCE := {
	"victory": 2,
	"defeat": 1,
	"survival": 1,
	"first_kill": 1,
	"scenario_bonus": 1
}

# Loot generation parameters per rulebook
const LOOT_BASE_CHANCES := {
	"credits": 0.4, # 40% chance
	"equipment": 0.25, # 25% chance
	"consumables": 0.2, # 20% chance
	"information": 0.1, # 10% chance
	"special": 0.05 # 5% chance
}

# System state
@export var processing_active: bool = false
@export var current_stage: ProcessingStage = ProcessingStage.VALIDATE_INPUT
@export var validate_crew_data: bool = true
@export var apply_house_rules: bool = false

# Manager dependencies
var dice_manager: Node = null
var campaign_manager: Node = null

func _ready() -> void:
	"""Initialize processor with dependency injection"""
	_initialize_dependencies()

func _initialize_dependencies() -> void:
	"""Initialize manager dependencies safely"""
	dice_manager = _get_manager_safely("DiceManager")
	campaign_manager = _get_manager_safely("CampaignManager")

func _get_manager_safely(manager_name: String) -> Node:
	"""Safe manager retrieval with fallback handling"""
	var singleton_path := "/root/%s" % manager_name
	if has_node(singleton_path):
		return get_node(singleton_path)

	# Try alternative paths
	for path in ["../%s" % manager_name, "../../%s" % manager_name]:
		if has_node(path):
			return get_node(path)

	return null

# =====================================================
# MAIN PROCESSING PIPELINE
# =====================================================

func process_battle_end(tracked_units: Dictionary, battle_context: Dictionary) -> BattlefieldTypes.BattleResults:
	"""
	Process complete battle end with comprehensive result generation

	@param tracked_units: Dictionary of unit_id -> UnitData from battle tracker
	@param battle_context: Battle context including victory status, rounds, etc.
	@return: Complete battle results ready for post-battle phase
	"""
	if processing_active:
		push_warning("PostBattleProcessor: Processing already in progress")
		return _create_empty_results()

	processing_active = true
	current_stage = ProcessingStage.VALIDATE_INPUT

	# Stage 1: Validate input data
	var validation_result := _validate_processing_input(tracked_units, battle_context)
	if not validation_result.valid:
		processing_error.emit("VALIDATION_FAILED", validation_result.errors)
		processing_active = false
		return _create_empty_results()

	# Initialize results object
	var battle_results := BattlefieldTypes.BattleResults.new()
	var battle_id_value = battle_context.get("battle_id")
	battle_results.battle_id = battle_id_value if battle_id_value != null else "unknown_%d" % Time.get_unix_time_from_system()

	var rounds_value = battle_context.get("rounds")
	battle_results.rounds_fought = rounds_value if rounds_value != null else 1

	var victory_value = battle_context.get("victory")
	battle_results.victory = victory_value if victory_value != null else false

	# Stage 2: Process casualties and injuries for crew
	current_stage = ProcessingStage.PROCESS_CASUALTIES
	_process_crew_casualties(tracked_units, battle_results)

	current_stage = ProcessingStage.PROCESS_INJURIES
	_process_crew_injuries(tracked_units, battle_results)

	# Stage 3: Calculate experience gains
	current_stage = ProcessingStage.CALCULATE_EXPERIENCE
	_calculate_experience_gains(tracked_units, battle_context, battle_results)

	# Stage 4: Generate loot opportunities
	current_stage = ProcessingStage.GENERATE_LOOT
	_generate_loot_opportunities(tracked_units, battle_context, battle_results)

	# Stage 5: Finalize and validate results
	current_stage = ProcessingStage.FINALIZE_RESULTS
	_finalize_battle_results(battle_results, battle_context)

	processing_active = false
	results_processed.emit(battle_results)
	return battle_results

func process_quick_victory(crew_alive: bool, rounds_fought: int) -> BattlefieldTypes.BattleResults:
	"""Quick processing for simple victory/defeat scenarios"""
	var results := BattlefieldTypes.BattleResults.new()
	results.victory = crew_alive
	results.rounds_fought = rounds_fought

	# Basic experience for quick resolution
	if crew_alive:
		results.experience_gained["crew_bonus"] = BASE_EXPERIENCE.victory
	else:
		results.experience_gained["participation"] = BASE_EXPERIENCE.defeat

	# Basic loot for victory
	if crew_alive:
		results.loot_opportunities.append("Roll for battlefield salvage")

	return results

# =====================================================
# CASUALTY PROCESSING - FIVE PARSECS RULES
# =====================================================

func _process_crew_casualties(tracked_units: Dictionary, results: BattlefieldTypes.BattleResults) -> void:
	"""Process crew casualties per Five Parsecs Core Rules p.94"""
	var crew_units := _get_crew_units(tracked_units)

	for unit in crew_units:
		if not unit.is_alive():
			var casualty_data := _determine_casualty_fate(unit)

			if casualty_data.is_casualty:
				results.add_casualty(unit.unit_name, casualty_data.casualty_type)
				casualty_processed.emit(unit.unit_name, casualty_data)
			# If not a casualty, they'll be processed as injured

func _determine_casualty_fate(unit: BattlefieldTypes.UnitData) -> Dictionary:
	"""Determine if a downed unit is a casualty or injury (Five Parsecs p.94)"""
	var casualty_roll := _roll_dice_safely("d6")
	var casualty_data := {
		"unit_name": unit.unit_name,
		"casualty_roll": casualty_roll,
		"is_casualty": false,
		"casualty_type": "",
		"modifiers_applied": []
	}

	# Base casualty chance (1-2 on d6 = casualty)
	var casualty_threshold := 2

	# Apply character modifiers
	if unit.original_character:
		casualty_threshold += _get_character_casualty_modifiers(unit.original_character, casualty_data)

	# Apply equipment modifiers
	casualty_threshold += _get_equipment_casualty_modifiers(unit, casualty_data)

	# Determine final result
	if casualty_roll <= casualty_threshold:
		casualty_data.is_casualty = true
		casualty_data.casualty_type = _determine_casualty_type(casualty_roll, unit)

	return casualty_data

func _get_character_casualty_modifiers(character: Resource, casualty_data: Dictionary) -> int:
	"""Get character-based casualty modifiers"""
	var modifier := 0

	# Toughness bonus (Five Parsecs rule)
	var toughness_value = character.get("toughness")
	var toughness: int = toughness_value if toughness_value != null else 0
	if toughness >= 5:
		modifier -= 1
		casualty_data.modifiers_applied.append("Toughness bonus (-1)")

	# Class/background modifiers
	var background_value = character.get("background")
	var background: String = background_value if background_value != null else ""
	match background.to_lower():
		"military", "soldier":
			modifier -= 1
			casualty_data.modifiers_applied.append("Military training (-1)")
		"medic", "doctor":
			modifier -= 2
			casualty_data.modifiers_applied.append("Medical knowledge (-2)")

	return modifier

func _get_equipment_casualty_modifiers(unit: BattlefieldTypes.UnitData, casualty_data: Dictionary) -> int:
	"""Get equipment-based casualty modifiers"""
	var modifier := 0

	# Check for protective equipment
	if "armor" in unit.equipment:
		modifier -= 1
		casualty_data.modifiers_applied.append("Armor protection (-1)")

	if "medkit" in unit.equipment:
		modifier -= 1
		casualty_data.modifiers_applied.append("Medical supplies (-1)")

	return modifier

func _determine_casualty_type(roll: int, unit: BattlefieldTypes.UnitData) -> String:
	"""Determine specific casualty type based on roll and context"""
	match roll:
		1:
			return "killed_in_action"
		2:
			return "critically_wounded"
		_:
			return "missing_in_action" # Should not normally reach here

# =====================================================
# INJURY PROCESSING - COMPREHENSIVE SYSTEM
# =====================================================

func _process_crew_injuries(tracked_units: Dictionary, results: BattlefieldTypes.BattleResults) -> void:
	"""Process crew injuries for non-casualty units"""
	var crew_units := _get_crew_units(tracked_units)

	for unit in crew_units:
		if not unit.is_alive():
			# Check if unit was already processed as casualty
			var is_casualty := results.casualties.any(func(c): return c.name == unit.unit_name)

			if not is_casualty:
				var injury_data := _roll_injury_type(unit)
				results.add_injury(unit.unit_name, injury_data.injury_type, injury_data.recovery_time)
				injury_processed.emit(unit.unit_name, injury_data)

func _roll_injury_type(unit: BattlefieldTypes.UnitData) -> Dictionary:
	"""Roll for injury type per Five Parsecs injury table"""
	var injury_roll := _roll_dice_safely("d6")
	var injury_data := {
		"unit_name": unit.unit_name,
		"injury_roll": injury_roll,
		"injury_type": "",
		"recovery_time": 1,
		"permanent_effects": [],
		"treatment_options": []
	}

	# Five Parsecs injury table (simplified)
	match injury_roll:
		1:
			injury_data.injury_type = "Light wound"
			injury_data.recovery_time = 1
			injury_data.treatment_options = ["Rest", "Medical treatment"]
		2:
			injury_data.injury_type = "Serious injury"
			injury_data.recovery_time = _roll_dice_safely("d3") + 1
			injury_data.treatment_options = ["Medical treatment", "Surgery"]
		3:
			injury_data.injury_type = "Knocked unconscious"
			injury_data.recovery_time = 1
			injury_data.treatment_options = ["Rest", "Stimulants"]
		4:
			injury_data.injury_type = "Equipment damaged"
			injury_data.recovery_time = 0 # No recovery needed, replace equipment
			injury_data.treatment_options = ["Replace equipment", "Repair"]
		5:
			injury_data.injury_type = "Shaken"
			injury_data.recovery_time = 2
			injury_data.permanent_effects = ["Temporary morale penalty"]
		6:
			var critical_injury := _roll_critical_injury(unit)
			injury_data.injury_type = critical_injury.type
			injury_data.recovery_time = critical_injury.recovery_time
			injury_data.permanent_effects = critical_injury.permanent_effects

	return injury_data

func _roll_critical_injury(unit: BattlefieldTypes.UnitData) -> Dictionary:
	"""Roll for critical injury effects"""
	var critical_roll := _roll_dice_safely("d6")

	match critical_roll:
		1:
			return {
				"type": "Permanent limp",
				"recovery_time": 6,
				"permanent_effects": ["Movement -1"]
			}
		2:
			return {
				"type": "Scarred",
				"recovery_time": 3,
				"permanent_effects": ["Intimidation bonus"]
			}
		3:
			return {
				"type": "Concussion",
				"recovery_time": 4,
				"permanent_effects": ["Tech skill -1 (temporary)"]
			}
		4:
			return {
				"type": "Nerve damage",
				"recovery_time": 5,
				"permanent_effects": ["Shooting -1"]
			}
		5:
			return {
				"type": "Broken bones",
				"recovery_time": _roll_dice_safely("d6") + 2,
				"permanent_effects": ["Combat -1 (temporary)"]
			}
		6:
			return {
				"type": "Critical system damage",
				"recovery_time": 8,
				"permanent_effects": ["Random stat -1 (permanent)"]
			}
		_:
			return {
				"type": "Unknown injury",
				"recovery_time": 3,
				"permanent_effects": []
			}

# =====================================================
# EXPERIENCE CALCULATION
# =====================================================

func _calculate_experience_gains(tracked_units: Dictionary, battle_context: Dictionary, results: BattlefieldTypes.BattleResults) -> void:
	"""Calculate experience gains per Five Parsecs rules"""
	var crew_units := _get_crew_units(tracked_units)
	var victory_value = battle_context.get("victory")
	var victory: bool = victory_value if victory_value != null else false

	# Base experience for all surviving crew
	var base_exp := BASE_EXPERIENCE.victory if victory else BASE_EXPERIENCE.defeat

	for unit in crew_units:
		if unit.is_alive():
			var unit_experience := base_exp

			# Survival bonus
			unit_experience += BASE_EXPERIENCE.survival

			# Performance bonuses
			unit_experience += _calculate_performance_bonuses(unit, tracked_units, battle_context)

			results.set_experience_gained(unit.unit_name, unit_experience)

	experience_calculated.emit(results.experience_gained.duplicate())

func _calculate_performance_bonuses(unit: BattlefieldTypes.UnitData, all_units: Dictionary, context: Dictionary) -> int:
	"""Calculate individual performance bonuses"""
	var bonus := 0

	# First kill bonus (if any enemies were defeated)
	var enemies_defeated := _count_defeated_enemies(all_units)
	if enemies_defeated > 0:
		bonus += BASE_EXPERIENCE.first_kill

	# Leadership bonus (for leaders)
	if "leader" in unit.unit_name.to_lower():
		bonus += 1

	# Scenario-specific bonuses
	var scenario_bonus_value = context.get("scenario_bonus")
	var scenario_bonus: int = scenario_bonus_value if scenario_bonus_value != null else 0
	bonus += scenario_bonus

	return bonus

# =====================================================
# LOOT GENERATION
# =====================================================

func _generate_loot_opportunities(tracked_units: Dictionary, battle_context: Dictionary, results: BattlefieldTypes.BattleResults) -> void:
	"""Generate loot opportunities per Five Parsecs rules"""
	var victory_value = battle_context.get("victory")
	var victory: bool = victory_value if victory_value != null else false

	if not victory:
		# No loot on defeat, but might salvage equipment
		if randf() < 0.3: # 30% chance to salvage something
			results.add_loot_opportunity("Emergency salvage - roll once on equipment table")
		return

	# Victory loot generation
	var loot_rolls := _calculate_loot_rolls(tracked_units, battle_context)

	for i in loot_rolls:
		var loot_opportunity := _generate_single_loot_opportunity()
		results.add_loot_opportunity(loot_opportunity)

	loot_generated.emit(results.loot_opportunities.duplicate())

func _calculate_loot_rolls(tracked_units: Dictionary, battle_context: Dictionary) -> int:
	"""Calculate number of loot rolls based on victory conditions"""
	var base_rolls := 1 # Base victory loot

	# Bonus for overwhelming victory
	var enemies_defeated := _count_defeated_enemies(tracked_units)
	if enemies_defeated >= 5:
		base_rolls += 1

	# Bonus for quick victory
	var rounds_value = battle_context.get("rounds")
	var rounds: int = rounds_value if rounds_value != null else 10
	if rounds <= 3:
		base_rolls += 1

	# Mission type bonuses
	var mission_type_value = battle_context.get("mission_type")
	var mission_type: String = mission_type_value if mission_type_value != null else "patrol"
	if mission_type in ["assault", "investigation"]:
		base_rolls += 1

	return base_rolls

func _generate_single_loot_opportunity() -> String:
	"""Generate single loot opportunity"""
	var loot_roll := randf()
	var cumulative := 0.0

	for loot_type in LOOT_BASE_CHANCES.keys():
		cumulative += LOOT_BASE_CHANCES[loot_type]
		if loot_roll <= cumulative:
			return _get_loot_description(loot_type)

	return "Miscellaneous salvage"

func _get_loot_description(loot_type: String) -> String:
	"""Get descriptive text for loot type"""
	match loot_type:
		"credits": return "Credits found - roll 2d6 x 10 credits"
		"equipment": return "Equipment cache - roll on equipment table"
		"consumables": return "Consumables found - roll for medical supplies or ammunition"
		"information": return "Information discovered - potential quest hook"
		"special": return "Special item found - GM determines unusual discovery"
		_: return "Unknown salvage opportunity"

# =====================================================
# UTILITY FUNCTIONS
# =====================================================

func _validate_processing_input(tracked_units: Dictionary, battle_context: Dictionary) -> Dictionary:
	"""Validate input data for processing with comprehensive checks"""
	var validation := {"valid": true, "errors": {}}

	# CRITICAL: Null and type validation
	if tracked_units == null:
		validation.valid = false
		validation.errors["units_null"] = "tracked_units is null"
		return validation

	if battle_context == null:
		validation.valid = false
		validation.errors["context_null"] = "battle_context is null"
		return validation

	# Validate tracked units
	if (safe_call_method(tracked_units, "is_empty") == true):
		validation.valid = false
		validation.errors["units"] = "No tracked units provided"

	# VALIDATION: Ensure battle context has required fields
	if not battle_context.has("victory"):
		validation.valid = false
		validation.errors["victory"] = "Missing victory status (required)"

	# Validate battle_id exists or can be generated
	if not battle_context.has("battle_id") or battle_context.get("battle_id") == null:
		# Warning only - will be auto-generated
		if not validation.errors.has("warnings"):
			validation.errors["warnings"] = []
		validation.errors["warnings"].append("Missing battle_id - will be auto-generated")

	# Validate rounds (critical for experience calculation)
	if not battle_context.has("rounds"):
		validation.valid = false
		validation.errors["rounds"] = "Missing rounds count (required for experience)"
	else:
		var rounds_value = battle_context.get("rounds")
		if rounds_value == null or (not rounds_value is int and not rounds_value is float):
			validation.valid = false
			validation.errors["rounds_type"] = "Rounds must be a number"
		elif rounds_value < 0:
			validation.valid = false
			validation.errors["rounds_negative"] = "Rounds cannot be negative"

	# Validate mission_type exists
	if not battle_context.has("mission_type"):
		# Warning only - will use default "patrol"
		if not validation.errors.has("warnings"):
			validation.errors["warnings"] = []
		validation.errors["warnings"].append("Missing mission_type - will default to 'patrol'")

	# Validate crew presence
	var crew_count := _get_crew_units(tracked_units).size()
	if crew_count == 0:
		validation.valid = false
		validation.errors["crew"] = "No crew units found in tracked_units"

	return validation

func _get_crew_units(tracked_units: Dictionary) -> Array[BattlefieldTypes.UnitData]:
	"""Get all crew units from tracked units"""
	var crew_units: Array[BattlefieldTypes.UnitData] = []

	for unit in tracked_units.values():
		if unit.team == "crew":
			crew_units.append(unit)

	return crew_units

func _count_defeated_enemies(tracked_units: Dictionary) -> int:
	"""Count defeated enemy units"""
	var defeated := 0

	for unit in tracked_units.values():
		if unit.team == "enemy" and not unit.is_alive():
			defeated += 1

	return defeated

func _finalize_battle_results(results: BattlefieldTypes.BattleResults, context: Dictionary) -> void:
	"""Finalize battle results with metadata"""
	results.post_battle_notes = "Battle processed on %s" % Time.get_datetime_string_from_system()

	# Add context data
	if context.has("mission_type"):
		results.mission_objectives_completed.append("Mission type: %s" % context.mission_type)

	# Validate results completeness
	if results.casualties.is_empty() and results.injuries.is_empty():
		results.post_battle_notes += " - No casualties or injuries sustained"

func _create_empty_results() -> BattlefieldTypes.BattleResults:
	"""Create empty results object for error cases"""
	var results := BattlefieldTypes.BattleResults.new()
	results.battle_id = "error_%d" % Time.get_unix_time_from_system()
	results.post_battle_notes = "Error occurred during processing"
	return results

func _roll_dice_safely(pattern: String) -> int:
	"""Safe dice rolling with fallback"""
	if dice_manager and dice_manager.has_method("roll_dice"):
		return dice_manager.roll_dice("PostBattleProcessor", pattern)
	else:
		return _fallback_dice_roll(pattern)

func _fallback_dice_roll(pattern: String) -> int:
	"""Fallback dice implementation"""
	match pattern.to_lower():
		"d3": return randi_range(1, 3)
		"d6": return randi_range(1, 6)
		"2d6": return randi_range(1, 6) + randi_range(1, 6)
		_: return randi_range(1, 6)

# =====================================================
# HOUSE RULES AND CUSTOMIZATION
# =====================================================

func apply_house_rule_modifiers(results: BattlefieldTypes.BattleResults, house_rules: Dictionary) -> void:
	"""Apply custom house rules to results"""
	if not apply_house_rules:
		return

	# Experience modifiers
	if house_rules.has("experience_multiplier"):
		var multiplier := house_rules.experience_multiplier as float
		for crew_member in results.experience_gained.keys():
			results.experience_gained[crew_member] = int(results.experience_gained[crew_member] * multiplier)

	# Injury recovery modifiers
	if house_rules.has("faster_recovery"):
		for injury in results.injuries:
			injury.recovery_rounds = max(1, injury.recovery_rounds - 1)

func set_house_rules_enabled(enabled: bool) -> void:
	"""Enable or disable house rules processing"""
	apply_house_rules = enabled

func get_processing_status() -> Dictionary:
	"""Get current processing status"""
	return {
		"active": processing_active,
		"stage": ProcessingStage.keys()[current_stage],
		"validate_crew": validate_crew_data,
		"house_rules": apply_house_rules
	}

## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_get_property(obj: Object, property: String, default_value: Variant = null) -> Variant:

	# Parameter validation - eliminates UNSAFE_CALL_ARGUMENT warnings
	if not is_instance_valid(self):
		return obj.get(property) if obj and obj.has_method("get") else default_value
	return default_value
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null