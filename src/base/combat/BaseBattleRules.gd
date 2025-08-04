@tool
extends Node
class_name FiveParsecsBattleRules

# Enhanced battle rules management - Universal framework removed for simplification

# Dependencies
const DataManager = preload("res://src/core/data/DataManager.gd")

# Comprehensive Warning Ignore Coverage
@warning_ignore("unused_signal")

## Base class for battle rules
##
## Defines the core rules and constants for the battle system.
## Game-specific implementations should extend this class.

# Enhanced Battle Rules Signals
signal rules_updated()
signal modifier_applied(modifier_type: String, modifier_data: Dictionary)
signal combat_calculation_performed(calculation_type: String, result: Dictionary)
signal action_cost_calculated(action: int, cost: int)
signal hit_chance_calculated(base_chance: float, final_chance: float, modifiers: Dictionary)

# JSON data loaded from data/ directory
var rule_constants_data: Dictionary = {}
var action_costs_data: Dictionary = {}
var terrain_effects_data: Dictionary = {}
var data_manager: DataManager

## Core game constants (fallback values)
var BASE_MOVEMENT: int = 6 # Base movement in inches
var _BASE_ACTION_POINTS: int = 2 # Base action points per turn
var _BASE_ATTACK_RANGE: int = 24 # Base attack range in inches
var _BASE_HIT_CHANCE: float = 0.65 # Base 65% hit chance
var BASE_DAMAGE: int = 3 # Base damage value

## Combat modifiers (fallback values)
var COVER_MODIFIER: float = -0.25 # -25% when target is in cover
var HEIGHT_MODIFIER: float = 0.15 # +15% when attacker has height advantage
var FLANK_MODIFIER: float = 0.2 # +20% when attacking from flank
var SUPPRESSION_MODIFIER: float = -0.2 # -20% when suppressed

## Range modifiers (fallback values)
var _OPTIMAL_RANGE_BONUS: float = 0.1 # +10% at optimal range
var _LONG_RANGE_PENALTY: float = -0.2 # -20% at long range
var _EXTREME_RANGE_PENALTY: float = -0.4 # -40% at extreme range

## Status effect thresholds (fallback values)
var CRITICAL_THRESHOLD: float = 0.9 # 90% for critical hits
var GRAZE_THRESHOLD: float = 0.35 # 35% for graze hits
var MINIMUM_HIT_CHANCE: float = 0.05 # 5% minimum hit chance
var MAXIMUM_HIT_CHANCE: float = 0.95 # 95% maximum hit chance

## Action point costs (fallback values)
var _MOVE_COST: int = 1
var _ATTACK_COST: int = 1
var _DEFEND_COST: int = 1
var _OVERWATCH_COST: int = 2
var _RELOAD_COST: int = 1
var _USE_ITEM_COST: int = 1
var _SPECIAL_COST: int = 2
var _TAKE_COVER_COST: int = 1
var _DASH_COST: int = 2
var _BRAWL_COST: int = 1
var _SNAP_FIRE_COST: int = 1
var _END_TURN_COST: int = 0

## Terrain effects (fallback values)
var _DIFFICULT_TERRAIN_MODIFIER: float = 0.5 # Halves movement
var _HAZARDOUS_TERRAIN_DAMAGE: int = 1 # Damage per turn in hazardous terrain

# Enhanced rules tracking
var _rules_statistics: Dictionary = {}
var _calculation_history: Array[Dictionary] = []
var _data_cache: Dictionary = {}

func _ready() -> void:
	# Initialize enhanced rules tracking
	_initialize_rules_statistics()
	_setup_universal_framework()
	_load_rule_configuration()

func _load_rule_configuration() -> void:
	"""Load rule configuration from JSON files"""
	data_manager = DataManager.new()
	
	# Load rule constants data
	rule_constants_data = data_manager.load_json_file("res://data/combat/rule_constants.json")
	if rule_constants_data.is_empty():
		print("BaseBattleRules: rule_constants.json not found, using fallback values")
		_create_rule_constants_fallback()
	else:
		print("BaseBattleRules: Loaded rule constants from JSON")
		_apply_rule_constants()
	
	# Load action costs data
	action_costs_data = data_manager.load_json_file("res://data/combat/action_costs.json")
	if action_costs_data.is_empty():
		print("BaseBattleRules: action_costs.json not found, using fallback values")
		_create_action_costs_fallback()
	else:
		print("BaseBattleRules: Loaded action costs from JSON")
		_apply_action_costs()
	
	# Load terrain effects data
	terrain_effects_data = data_manager.load_json_file("res://data/combat/terrain_effects.json")
	if terrain_effects_data.is_empty():
		print("BaseBattleRules: terrain_effects.json not found, using fallback values")
		_create_terrain_effects_fallback()
	else:
		print("BaseBattleRules: Loaded terrain effects from JSON")
		_apply_terrain_effects()

func _create_rule_constants_fallback() -> void:
	"""Create fallback rule constants when JSON unavailable"""
	rule_constants_data = {
		"movement": {
			"base_movement": 6,
			"base_action_points": 2,
			"base_attack_range": 24
		},
		"combat_modifiers": {
			"cover_modifier": - 0.25,
			"height_modifier": 0.15,
			"flank_modifier": 0.2,
			"suppression_modifier": - 0.2
		},
		"range_modifiers": {
			"optimal_range_bonus": 0.1,
			"long_range_penalty": - 0.2,
			"extreme_range_penalty": - 0.4
		},
		"hit_thresholds": {
			"base_hit_chance": 0.65,
			"critical_threshold": 0.9,
			"graze_threshold": 0.35,
			"minimum_hit_chance": 0.05,
			"maximum_hit_chance": 0.95
		},
		"damage": {
			"base_damage": 3
		}
	}

func _create_action_costs_fallback() -> void:
	"""Create fallback action costs when JSON unavailable"""
	action_costs_data = {
		"action_costs": {
			"move": 1,
			"attack": 1,
			"defend": 1,
			"overwatch": 2,
			"reload": 1,
			"use_item": 1,
			"special": 2,
			"take_cover": 1,
			"dash": 2,
			"brawl": 1,
			"snap_fire": 1,
			"end_turn": 0
		},
		"cost_modifiers": {
			"heavy_weapon_penalty": 1,
			"wounded_penalty": 1,
			"expertise_bonus": 0
		}
	}

func _create_terrain_effects_fallback() -> void:
	"""Create fallback terrain effects when JSON unavailable"""
	terrain_effects_data = {
		"terrain_modifiers": {
			"difficult_terrain_modifier": 0.5,
			"hazardous_terrain_damage": 1,
			"cover_bonus": 0.3,
			"elevation_bonus": 0.2
		},
		"terrain_types": {
			"open": {"movement_modifier": 1.0, "cover_value": 0.0},
			"rough": {"movement_modifier": 0.75, "cover_value": 0.1},
			"difficult": {"movement_modifier": 0.5, "cover_value": 0.2},
			"cover": {"movement_modifier": 1.0, "cover_value": 0.5},
			"heavy_cover": {"movement_modifier": 0.8, "cover_value": 0.8},
			"hazardous": {"movement_modifier": 0.5, "damage_per_turn": 1}
		}
	}

func _apply_rule_constants() -> void:
	"""Apply rule constants from JSON data"""
	if rule_constants_data.has("movement"):
		var movement = rule_constants_data.movement
		BASE_MOVEMENT = movement.get("base_movement", 6)
		_BASE_ACTION_POINTS = movement.get("base_action_points", 2)
		_BASE_ATTACK_RANGE = movement.get("base_attack_range", 24)
	
	if rule_constants_data.has("combat_modifiers"):
		var modifiers = rule_constants_data.combat_modifiers
		COVER_MODIFIER = modifiers.get("cover_modifier", -0.25)
		HEIGHT_MODIFIER = modifiers.get("height_modifier", 0.15)
		FLANK_MODIFIER = modifiers.get("flank_modifier", 0.2)
		SUPPRESSION_MODIFIER = modifiers.get("suppression_modifier", -0.2)
	
	if rule_constants_data.has("range_modifiers"):
		var range_mods = rule_constants_data.range_modifiers
		_OPTIMAL_RANGE_BONUS = range_mods.get("optimal_range_bonus", 0.1)
		_LONG_RANGE_PENALTY = range_mods.get("long_range_penalty", -0.2)
		_EXTREME_RANGE_PENALTY = range_mods.get("extreme_range_penalty", -0.4)
	
	if rule_constants_data.has("hit_thresholds"):
		var thresholds = rule_constants_data.hit_thresholds
		_BASE_HIT_CHANCE = thresholds.get("base_hit_chance", 0.65)
		CRITICAL_THRESHOLD = thresholds.get("critical_threshold", 0.9)
		GRAZE_THRESHOLD = thresholds.get("graze_threshold", 0.35)
		MINIMUM_HIT_CHANCE = thresholds.get("minimum_hit_chance", 0.05)
		MAXIMUM_HIT_CHANCE = thresholds.get("maximum_hit_chance", 0.95)
	
	if rule_constants_data.has("damage"):
		var damage = rule_constants_data.damage
		BASE_DAMAGE = damage.get("base_damage", 3)

func _apply_action_costs() -> void:
	"""Apply action costs from JSON data"""
	if action_costs_data.has("action_costs"):
		var costs = action_costs_data.action_costs
		_MOVE_COST = costs.get("move", 1)
		_ATTACK_COST = costs.get("attack", 1)
		_DEFEND_COST = costs.get("defend", 1)
		_OVERWATCH_COST = costs.get("overwatch", 2)
		_RELOAD_COST = costs.get("reload", 1)
		_USE_ITEM_COST = costs.get("use_item", 1)
		_SPECIAL_COST = costs.get("special", 2)
		_TAKE_COVER_COST = costs.get("take_cover", 1)
		_DASH_COST = costs.get("dash", 2)
		_BRAWL_COST = costs.get("brawl", 1)
		_SNAP_FIRE_COST = costs.get("snap_fire", 1)
		_END_TURN_COST = costs.get("end_turn", 0)

func _apply_terrain_effects() -> void:
	"""Apply terrain effects from JSON data"""
	if terrain_effects_data.has("terrain_modifiers"):
		var modifiers = terrain_effects_data.terrain_modifiers
		_DIFFICULT_TERRAIN_MODIFIER = modifiers.get("difficult_terrain_modifier", 0.5)
		_HAZARDOUS_TERRAIN_DAMAGE = modifiers.get("hazardous_terrain_damage", 1)

func _setup_universal_framework() -> void:
	# Configure enhanced rules tracking
	_connect_rules_signals()

func _connect_rules_signals() -> void:
	# Connect internal signals for rules tracking
	if not hit_chance_calculated.is_connected(_on_hit_chance_calculated):
		if not hit_chance_calculated.is_connected(_on_hit_chance_calculated): hit_chance_calculated.connect(_on_hit_chance_calculated)

	if not combat_calculation_performed.is_connected(_on_combat_calculation_performed):
		if not combat_calculation_performed.is_connected(_on_combat_calculation_performed): combat_calculation_performed.connect(_on_combat_calculation_performed)

func _on_hit_chance_calculated(base_chance: float, final_chance: float, modifiers: Dictionary) -> void:
	# Track hit chance calculations
	_data_cache["last_hit_calculation"] = {
		"base_chance": base_chance,
		"final_chance": final_chance,
		"modifiers": modifiers,
		"timestamp": Time.get_unix_time_from_system()
	}

func _on_combat_calculation_performed(calculation_type: String, result: Dictionary) -> void:
	# Track combat calculations with Universal framework
	_calculation_history.append({
		"type": calculation_type,
		"result": result,
		"timestamp": Time.get_unix_time_from_system()
	})

	# Limit history size
	if _calculation_history.size() > 100:
		_calculation_history.pop_front()

func _initialize_rules_statistics() -> void:
	# Initialize comprehensive rules statistics
	_rules_statistics = {
		"action_cost_calculations": 0,
		"hit_chance_calculations": 0,
		"damage_calculations": 0,
		"movement_calculations": 0,
		"combat_results_generated": 0,
		"modifiers_applied": 0,
		"last_updated": Time.get_unix_time_from_system()
	}

## Base class for enhanced combat modifiers with Universal framework
class BaseCombatModifiers:
	var cover: bool = false
	var height_advantage: bool = false
	var flanking: bool = false
	var suppressed: bool = false
	var _range_modifier: float = 0.0
	var critical: bool = false
	var armor: int = 0

	# Enhanced modifiers with Universal framework support
	var _combat_advantage: int = 0
	var _combat_status: int = 0
	var _combat_range: int = 0
	var _combat_tactic: int = 0
	# Removed Universal framework variable

	func _init() -> void:
		# Initialize data access - simplified approach
		pass

	func apply_modifier(modifier_name: String, modifier_value: Variant) -> void:
		# Simplified modifier application without Universal framework
		pass

	func get_modifier(modifier_name: String, default_value: Variant = null) -> Variant:
		# Simplified modifier retrieval without Universal framework
		return default_value

	func validate_modifiers() -> bool:
		# Simplified validation without Universal framework
		return true

## Enhanced action validation with Universal framework tracking
## @param action: The action to check
## @param action_points: The available action points
## @return: Whether the action can be performed
func can_perform_action(action: int, action_points: int) -> bool:
	var cost: int = get_action_cost(action)
	var can_perform: bool = action_points >= cost

	# Update statistics
	_rules_statistics.action_cost_calculations += 1

	# Log action check
	_data_cache["last_action_check"] = {
		"action": action,
		"action_points": action_points,
		"cost": cost,
		"can_perform": can_perform,
		"timestamp": Time.get_unix_time_from_system()
	}

	# Emit enhanced signal
	action_cost_calculated.emit(action, cost)

	return can_perform

## Enhanced action cost calculation with tracking
## @param action: The action to get the cost for
## @return: The cost of the action
func get_action_cost(action: int) -> int:
	var cost: int = 1 # Default cost

	# Enhanced action cost mapping - should be overridden in game-specific implementations
	# with appropriate action enums

	# Log cost calculation
	_data_cache["last_cost_calculation"] = {
		"action": action,
		"cost": cost,
		"timestamp": Time.get_unix_time_from_system()
	}

	return cost

## Enhanced hit chance calculation with Universal framework tracking
## @param base_chance: The base hit chance
## @param modifiers: The combat modifiers
## @return: The final hit chance
func calculate_hit_chance(base_chance: float, modifiers: BaseCombatModifiers) -> float:
	var final_chance: float = base_chance

	# Apply standard modifiers
	if modifiers.cover:
		final_chance += COVER_MODIFIER
	if modifiers.height_advantage:
		final_chance += HEIGHT_MODIFIER
	if modifiers.flanking:
		final_chance += FLANK_MODIFIER
	if modifiers.suppressed:
		final_chance += SUPPRESSION_MODIFIER

	# Apply range modifiers - should be implemented in derived classes

	# Clamp final chance between minimum and maximum
	final_chance = clampf(final_chance, MINIMUM_HIT_CHANCE, MAXIMUM_HIT_CHANCE)

	# Update statistics
	_rules_statistics.hit_chance_calculations += 1

	# Log hit chance calculation
	_data_cache["last_hit_chance_calculation"] = {
		"base_chance": base_chance,
		"final_chance": final_chance,
		"modifiers": {
			"cover": modifiers.cover,
			"height_advantage": modifiers.height_advantage,
			"flanking": modifiers.flanking,
			"suppressed": modifiers.suppressed
		},
		"timestamp": Time.get_unix_time_from_system()
	}

	# Emit enhanced signal
	hit_chance_calculated.emit(base_chance, final_chance, {
		"cover": modifiers.cover,
		"height_advantage": modifiers.height_advantage,
		"flanking": modifiers.flanking,
		"suppressed": modifiers.suppressed
	})

	return final_chance

## Enhanced damage calculation with tracking
## @param base_damage: The base damage
## @param modifiers: The combat modifiers
## @return: The final damage
func calculate_damage(base_damage: int, modifiers: BaseCombatModifiers) -> int:
	var final_damage: int = base_damage

	# Apply critical hit
	if modifiers.critical:
		final_damage *= 2

	# Apply damage modifiers
	if modifiers.flanking:
		final_damage += 1
	if modifiers.height_advantage:
		final_damage += 1

	# Apply combat advantage modifiers - should be implemented in derived classes

	# Apply armor reduction
	final_damage = maxi(1, final_damage - modifiers.armor) # Minimum 1 damage

	# Update statistics
	_rules_statistics.damage_calculations += 1

	# Log damage calculation
	_data_cache["last_damage_calculation"] = {
		"base_damage": base_damage,
		"final_damage": final_damage,
		"modifiers": {
			"critical": modifiers.critical,
			"flanking": modifiers.flanking,
			"height_advantage": modifiers.height_advantage,
			"armor": modifiers.armor
		},
		"timestamp": Time.get_unix_time_from_system()
	}

	# Emit enhanced signal
	combat_calculation_performed.emit("damage", {
		"base_damage": base_damage,
		"final_damage": final_damage,
		"modifiers": modifiers
	})

	return final_damage

## Enhanced movement cost calculation with tracking
## @param distance: The distance to move
## @param terrain_type: The type of terrain
## @return: The movement cost
func calculate_movement_cost(distance: float, terrain_type: int) -> int:
	var cost: int = int(distance / BASE_MOVEMENT)

	# Apply terrain modifiers - should be implemented in derived classes

	cost = maxi(1, cost) # Minimum 1 movement point

	# Update statistics
	_rules_statistics.movement_calculations += 1

	# Log movement calculation
	_data_cache["last_movement_calculation"] = {
		"distance": distance,
		"terrain_type": terrain_type,
		"cost": cost,
		"timestamp": Time.get_unix_time_from_system()
	}

	# Emit enhanced signal
	combat_calculation_performed.emit("movement", {
		"distance": distance,
		"terrain_type": terrain_type,
		"cost": cost
	})

	return cost

## Enhanced combat result generation with tracking
## @param hit_chance: The hit chance
## @param modifiers: The combat modifiers
## @return: The combat result
func get_combat_result(hit_chance: float, modifiers: BaseCombatModifiers) -> int:
	var roll: float = randf()
	var result: int = 0 # Default result

	if roll >= CRITICAL_THRESHOLD and not modifiers.suppressed:
		result = 1 # Critical hit - should use appropriate enum in derived classes
	elif roll >= hit_chance:
		result = 0 # Miss - should use appropriate enum in derived classes
	elif roll <= GRAZE_THRESHOLD:
		result = 2 # Graze - should use appropriate enum in derived classes
	else:
		result = 3 # Hit - should use appropriate enum in derived classes

	# Update statistics
	_rules_statistics.combat_results_generated += 1

	# Log combat result
	_data_cache["last_combat_result"] = {
		"hit_chance": hit_chance,
		"roll": roll,
		"result": result,
		"modifiers": modifiers,
		"timestamp": Time.get_unix_time_from_system()
	}

	# Emit enhanced signal
	combat_calculation_performed.emit("combat_result", {
		"hit_chance": hit_chance,
		"roll": roll,
		"result": result
	})

	return result

# Enhanced utility methods
func get_rules_statistics() -> Dictionary:
	return _rules_statistics.duplicate()

func get_calculation_history() -> Array[Dictionary]:
	return _calculation_history.duplicate()

func reset_rules_statistics() -> void:
	_initialize_rules_statistics()
	_calculation_history.clear()
	_data_cache.clear()

func validate_rules_integrity() -> bool:
	# Simple validation check
	return _rules_statistics.size() > 0

func update_rule_constant(constant_name: String, new_value: Variant) -> void:
	# Enhanced rule constant updates with tracking
	var old_value: Variant = get(constant_name)

	if has_method("set_" + str(constant_name)):
		call("set_" + str(constant_name), new_value)
	else:
		set(constant_name, new_value)

	# Log rule update
	_data_cache["rule_update_" + constant_name] = {
		"old_value": old_value,
		"new_value": new_value,
		"timestamp": Time.get_unix_time_from_system()
	}

	# Emit enhanced signal
	rules_updated.emit()

func get_rule_constant(constant_name: String, default_value: Variant = null) -> Variant:
	if has_method("get_" + str(constant_name)):
		return call("get_" + str(constant_name))
	elif constant_name in self:
		return get(constant_name)
	else:
		return default_value

func apply_rules_modifier(modifier_type: String, modifier_data: Dictionary) -> void:
	# Enhanced modifier application with tracking
	_rules_statistics.modifiers_applied += 1

	# Log modifier application
	_data_cache["last_modifier_applied"] = {
		"type": modifier_type,
		"data": modifier_data,
		"timestamp": Time.get_unix_time_from_system()
	}

	# Emit enhanced signal
	modifier_applied.emit(modifier_type, modifier_data)

## Enhanced JSON-driven rule methods
func get_terrain_modifier(terrain_type: String) -> Dictionary:
	"""Get terrain modifier from JSON data"""
	var default_modifier = {"movement_modifier": 1.0, "cover_value": 0.0}
	
	if terrain_effects_data.has("terrain_types") and terrain_effects_data.terrain_types.has(terrain_type):
		return terrain_effects_data.terrain_types[terrain_type]
	
	return default_modifier

func get_action_cost_with_modifiers(action_name: String, modifiers: Array = []) -> int:
	"""Get action cost with modifiers from JSON data"""
	var base_cost = 1
	
	# Get base cost from JSON data
	if action_costs_data.has("action_costs") and action_costs_data.action_costs.has(action_name):
		base_cost = action_costs_data.action_costs[action_name]
	
	# Apply cost modifiers
	var final_cost = base_cost
	if action_costs_data.has("cost_modifiers"):
		for modifier in modifiers:
			if action_costs_data.cost_modifiers.has(modifier):
				final_cost += action_costs_data.cost_modifiers[modifier]
	
	return maxi(0, final_cost) # Minimum 0 cost

func get_rule_constant_from_category(constant_category: String, constant_name: String) -> Variant:
	"""Get rule constant from JSON data with fallback"""
	if rule_constants_data.has(constant_category):
		var category = rule_constants_data[constant_category]
		if category.has(constant_name):
			return category[constant_name]
	
	# Fallback to hardcoded values
	return get(constant_name.to_upper()) if has_method("get") else null

func update_rule_from_json(json_file_path: String) -> bool:
	"""Update specific rule configuration from JSON file"""
	if not data_manager:
		data_manager = DataManager.new()
	
	var new_data = data_manager.load_json_file(json_file_path)
	if new_data.is_empty():
		return false
	
	# Determine which type of data this is and update accordingly
	if json_file_path.ends_with("rule_constants.json"):
		rule_constants_data = new_data
		_apply_rule_constants()
	elif json_file_path.ends_with("action_costs.json"):
		action_costs_data = new_data
		_apply_action_costs()
	elif json_file_path.ends_with("terrain_effects.json"):
		terrain_effects_data = new_data
		_apply_terrain_effects()
	else:
		return false
	
	rules_updated.emit()
	return true

func get_combat_configuration_summary() -> Dictionary:
	"""Get summary of current combat configuration"""
	return {
		"rule_constants_loaded": not rule_constants_data.is_empty(),
		"action_costs_loaded": not action_costs_data.is_empty(),
		"terrain_effects_loaded": not terrain_effects_data.is_empty(),
		"current_modifiers": {
			"cover": COVER_MODIFIER,
			"height": HEIGHT_MODIFIER,
			"flank": FLANK_MODIFIER,
			"suppression": SUPPRESSION_MODIFIER
		},
		"action_costs": {
			"move": _MOVE_COST,
			"attack": _ATTACK_COST,
			"special": _SPECIAL_COST
		},
		"statistics": _rules_statistics
	}
