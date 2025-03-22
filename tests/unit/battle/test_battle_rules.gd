## Battle Rules Test Suite
## Tests the functionality of the battle rules system including:
## - Combat resolution
## - Damage calculation
## - Status effects
## - Turn order and initiative
## - Special abilities and modifiers
@tool
extends "res://tests/fixtures/base/game_test.gd"

# Type-safe script references
const BaseBattleRules: GDScript = preload("res://src/base/combat/BaseBattleRules.gd")
const BaseCombatManager: GDScript = preload("res://src/base/combat/BaseCombatManager.gd")

# Type-safe constants
const TEST_TIMEOUT: float = 2.0

# Battle System Constants
const BASE_MOVEMENT: int = 6
const BASE_ACTION_POINTS: int = 2
const BASE_ATTACK_RANGE: int = 24
const BASE_HIT_CHANCE: float = 0.65
const BASE_DAMAGE: int = 3

# Combat Modifiers
const COVER_MODIFIER: float = -0.25
const HEIGHT_MODIFIER: float = 0.15
const FLANK_MODIFIER: float = 0.2
const SUPPRESSION_MODIFIER: float = -0.2

# Range Modifiers
const OPTIMAL_RANGE_BONUS: float = 0.1
const LONG_RANGE_PENALTY: float = -0.2
const EXTREME_RANGE_PENALTY: float = -0.4

# Status Effect Thresholds
const CRITICAL_THRESHOLD: float = 0.9
const GRAZE_THRESHOLD: float = 0.35
const MINIMUM_HIT_CHANCE: float = 0.05
const MAXIMUM_HIT_CHANCE: float = 0.95

# Action Point Costs
const MOVE_COST: int = 1
const ATTACK_COST: int = 1
const DEFEND_COST: int = 1

# Type-safe instance variables
var _battle_rules: Node = null
var _combat_manager: Node = null

# Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	
	# Initialize combat manager
	var combat_manager_instance: Node = BaseCombatManager.new()
	_combat_manager = TypeSafeMixin._safe_cast_to_node(combat_manager_instance)
	if not _combat_manager:
		push_error("Failed to create combat manager")
		return
	add_child_autofree(_combat_manager)
	track_test_node(_combat_manager)
	
	# Initialize battle rules
	var battle_rules_instance: Node = BaseBattleRules.new()
	_battle_rules = TypeSafeMixin._safe_cast_to_node(battle_rules_instance)
	if not _battle_rules:
		push_error("Failed to create battle rules")
		return
	TypeSafeMixin._call_node_method_bool(_battle_rules, "initialize", [_combat_manager])
	add_child_autofree(_battle_rules)
	track_test_node(_battle_rules)
	
	watch_signals(_battle_rules)
	watch_signals(_combat_manager)
	await stabilize_engine(STABILIZE_TIME)

func after_each() -> void:
	_battle_rules = null
	_combat_manager = null
	await super.after_each()

# Combat Resolution Tests
func test_basic_attack_resolution() -> void:
	var attacker := _create_test_unit(10, 2) # Attack 10, Defense 2
	var defender := _create_test_unit(5, 5) # Attack 5, Defense 5
	
	var result: Dictionary = TypeSafeMixin._call_node_method_dict(_battle_rules, "resolve_attack", [attacker, defender])
	assert_not_null(result, "Attack resolution should return result")
	assert_true(result.has("damage"), "Result should include damage")
	assert_true(result.has("hit"), "Result should include hit status")

func test_critical_hits() -> void:
	var attacker := _create_test_unit(20, 2) # High attack for crit chance
	var defender := _create_test_unit(5, 5)
	
	watch_signals(_battle_rules)
	var result: Dictionary = TypeSafeMixin._call_node_method_dict(_battle_rules, "resolve_attack", [attacker, defender, {"critical_threshold": 18}])
	
	if result.get("critical", false):
		verify_signal_emitted(_battle_rules, "critical_hit")
		assert_true(result.get("damage", 0) > result.get("base_damage", 0), "Critical hit should increase damage")

# Damage Calculation Tests
func test_damage_calculation() -> void:
	var base_damage := 10
	var armor := 5
	
	var damage: int = TypeSafeMixin._call_node_method_int(_battle_rules, "calculate_damage", [base_damage, armor])
	assert_true(damage < base_damage, "Armor should reduce damage")
	assert_true(damage >= 0, "Damage should not be negative")

func test_damage_modifiers() -> void:
	var attacker := _create_test_unit(10, 2)
	TypeSafeMixin._call_node_method_bool(attacker, "add_damage_modifier", [2, TestEnums.DamageType.PHYSICAL])
	
	var result: Dictionary = TypeSafeMixin._call_node_method_dict(_battle_rules, "calculate_modified_damage", [attacker, 10])
	assert_eq(result.get("final_damage", 0), 12, "Damage modifier should be applied")

	var target := _create_test_unit(10, 2)
	var effect := {
		"type": TestEnums.StatusEffect.STUNNED,
		"duration": 2,
		"potency": 1
	}
	
	TypeSafeMixin._call_node_method_bool(target, "apply_status_effect", [effect])
	result = TypeSafeMixin._call_node_method_dict(_battle_rules, "calculate_modified_damage", [attacker, 10, target])
	assert_eq(result.get("final_damage", 0), 12, "Status effect should modify damage calculation")

# Status Effect Tests
func test_status_effect_application() -> void:
	var target := _create_test_unit(10, 2)
	var effect := {
		"type": TestEnums.StatusEffect.STUNNED,
		"duration": 2,
		"potency": 1
	}
	
	watch_signals(_battle_rules)
	var result: bool = TypeSafeMixin._call_node_method_bool(_battle_rules, "apply_status_effect", [target, effect])
	assert_true(result, "Status effect should be applied")
	verify_signal_emitted(_battle_rules, "status_effect_applied")
	
	var active_effects: Array = TypeSafeMixin._call_node_method_array(target, "get_active_effects", [])
	assert_true(active_effects.size() > 0, "Target should have active effect")

# Turn Order Tests
func test_initiative_calculation() -> void:
	var units := [
		_create_test_unit(10, 2, 5), # Speed 5
		_create_test_unit(10, 2, 8), # Speed 8
		_create_test_unit(10, 2, 3) # Speed 3
	]
	
	var initiative_order: Array = TypeSafeMixin._call_node_method_array(_battle_rules, "calculate_initiative", [units])
	assert_eq(initiative_order.size(), units.size(), "All units should be in initiative order")
	
	# Verify descending speed order
	for i in range(1, initiative_order.size()):
		var prev_speed: int = TypeSafeMixin._call_node_method_int(initiative_order[i - 1], "get_speed", [])
		var curr_speed: int = TypeSafeMixin._call_node_method_int(initiative_order[i], "get_speed", [])
		assert_true(prev_speed >= curr_speed, "Units should be ordered by descending speed")

# Special Ability Tests
func test_special_ability_activation() -> void:
	var unit := _create_test_unit(10, 2)
	var ability := {
		"id": "test_ability",
		"type": TestEnums.AbilityType.ACTIVE,
		"cost": 2
	}
	
	watch_signals(_battle_rules)
	TypeSafeMixin._call_node_method_bool(unit, "add_ability", [ability])
	
	var result: Dictionary = TypeSafeMixin._call_node_method_dict(_battle_rules, "activate_ability", [unit, ability.id])
	assert_not_null(result, "Ability activation should return result")
	verify_signal_emitted(_battle_rules, "ability_activated")

# Error Handling Tests
func test_invalid_attack_parameters() -> void:
	var result: Dictionary = TypeSafeMixin._call_node_method_dict(_battle_rules, "resolve_attack", [null, null])
	assert_true(result.has("error"), "Should handle null units")
	
	var attacker := _create_test_unit(10, 2)
	result = TypeSafeMixin._call_node_method_dict(_battle_rules, "resolve_attack", [attacker, null])
	assert_true(result.has("error"), "Should handle null defender")

# Helper Methods
func _create_test_unit(attack: int, defense: int, speed: int = 5) -> Node:
	var unit := Node.new()
	if not unit:
		push_error("Failed to create test unit")
		return null
	
	TypeSafeMixin._call_node_method_bool(unit, "set_attack", [attack])
	TypeSafeMixin._call_node_method_bool(unit, "set_defense", [defense])
	TypeSafeMixin._call_node_method_bool(unit, "set_speed", [speed])
	
	add_child_autofree(unit)
	track_test_node(unit)
	return unit

# Core Constants Tests
func test_core_constants() -> void:
	var actual_movement: int = TypeSafeMixin._call_node_method_int(_battle_rules, "get_base_movement", [])
	var actual_action_points: int = TypeSafeMixin._call_node_method_int(_battle_rules, "get_base_action_points", [])
	var actual_attack_range: int = TypeSafeMixin._call_node_method_int(_battle_rules, "get_base_attack_range", [])
	var actual_hit_chance: float = TypeSafeMixin._safe_cast_float(TypeSafeMixin._call_node_method(_battle_rules, "get_base_hit_chance", []))
	var actual_damage: int = TypeSafeMixin._call_node_method_int(_battle_rules, "get_base_damage", [])
	
	assert_eq(actual_movement, BASE_MOVEMENT, "Base movement should be %d inches" % BASE_MOVEMENT)
	assert_eq(actual_action_points, BASE_ACTION_POINTS, "Base action points should be %d" % BASE_ACTION_POINTS)
	assert_eq(actual_attack_range, BASE_ATTACK_RANGE, "Base attack range should be %d inches" % BASE_ATTACK_RANGE)
	assert_eq(actual_hit_chance, BASE_HIT_CHANCE, "Base hit chance should be %.2f" % BASE_HIT_CHANCE)
	assert_eq(actual_damage, BASE_DAMAGE, "Base damage should be %d" % BASE_DAMAGE)

# Combat Modifier Tests
func test_combat_modifiers() -> void:
	var actual_cover: float = TypeSafeMixin._safe_cast_float(TypeSafeMixin._call_node_method(_battle_rules, "get_cover_modifier", []))
	var actual_height: float = TypeSafeMixin._safe_cast_float(TypeSafeMixin._call_node_method(_battle_rules, "get_height_modifier", []))
	var actual_flank: float = TypeSafeMixin._safe_cast_float(TypeSafeMixin._call_node_method(_battle_rules, "get_flank_modifier", []))
	var actual_suppression: float = TypeSafeMixin._safe_cast_float(TypeSafeMixin._call_node_method(_battle_rules, "get_suppression_modifier", []))
	
	assert_eq(actual_cover, COVER_MODIFIER, "Cover modifier should be %.2f" % COVER_MODIFIER)
	assert_eq(actual_height, HEIGHT_MODIFIER, "Height modifier should be %.2f" % HEIGHT_MODIFIER)
	assert_eq(actual_flank, FLANK_MODIFIER, "Flank modifier should be %.2f" % FLANK_MODIFIER)
	assert_eq(actual_suppression, SUPPRESSION_MODIFIER, "Suppression modifier should be %.2f" % SUPPRESSION_MODIFIER)

# Range Modifier Tests
func test_range_modifiers() -> void:
	var actual_optimal: float = TypeSafeMixin._safe_cast_float(TypeSafeMixin._call_node_method(_battle_rules, "get_optimal_range_bonus", []))
	var actual_long: float = TypeSafeMixin._safe_cast_float(TypeSafeMixin._call_node_method(_battle_rules, "get_long_range_penalty", []))
	var actual_extreme: float = TypeSafeMixin._safe_cast_float(TypeSafeMixin._call_node_method(_battle_rules, "get_extreme_range_penalty", []))
	
	assert_eq(actual_optimal, OPTIMAL_RANGE_BONUS, "Optimal range bonus should be %.2f" % OPTIMAL_RANGE_BONUS)
	assert_eq(actual_long, LONG_RANGE_PENALTY, "Long range penalty should be %.2f" % LONG_RANGE_PENALTY)
	assert_eq(actual_extreme, EXTREME_RANGE_PENALTY, "Extreme range penalty should be %.2f" % EXTREME_RANGE_PENALTY)

# Status Effect Threshold Tests
func test_status_effect_thresholds() -> void:
	var actual_critical: float = TypeSafeMixin._safe_cast_float(TypeSafeMixin._call_node_method(_battle_rules, "get_critical_threshold", []))
	var actual_graze: float = TypeSafeMixin._safe_cast_float(TypeSafeMixin._call_node_method(_battle_rules, "get_graze_threshold", []))
	var actual_min_hit: float = TypeSafeMixin._safe_cast_float(TypeSafeMixin._call_node_method(_battle_rules, "get_minimum_hit_chance", []))
	var actual_max_hit: float = TypeSafeMixin._safe_cast_float(TypeSafeMixin._call_node_method(_battle_rules, "get_maximum_hit_chance", []))
	
	assert_eq(actual_critical, CRITICAL_THRESHOLD, "Critical threshold should be %.2f" % CRITICAL_THRESHOLD)
	assert_eq(actual_graze, GRAZE_THRESHOLD, "Graze threshold should be %.2f" % GRAZE_THRESHOLD)
	assert_eq(actual_min_hit, MINIMUM_HIT_CHANCE, "Minimum hit chance should be %.2f" % MINIMUM_HIT_CHANCE)
	assert_eq(actual_max_hit, MAXIMUM_HIT_CHANCE, "Maximum hit chance should be %.2f" % MAXIMUM_HIT_CHANCE)

# Action Point Cost Tests
func test_action_point_costs() -> void:
	var actual_move: int = TypeSafeMixin._call_node_method_int(_battle_rules, "get_move_cost", [])
	var actual_attack: int = TypeSafeMixin._call_node_method_int(_battle_rules, "get_attack_cost", [])
	var actual_defend: int = TypeSafeMixin._call_node_method_int(_battle_rules, "get_defend_cost", [])
	
	assert_eq(actual_move, MOVE_COST, "Move cost should be %d" % MOVE_COST)
	assert_eq(actual_attack, ATTACK_COST, "Attack cost should be %d" % ATTACK_COST)
	assert_eq(actual_defend, DEFEND_COST, "Defend cost should be %d" % DEFEND_COST)

func test_ability_system() -> void:
	var ability := {
		"id": "test_ability",
		"type": TestEnums.AbilityType.ACTIVE,
		"cost": 2
	}
	
	var unit := _create_test_unit(10, 4)
	TypeSafeMixin._call_node_method_bool(unit, "add_ability", [ability])
	
	var has_ability: bool = TypeSafeMixin._call_node_method_bool(unit, "has_ability", [ability.id])
	assert_true(has_ability, "Unit should have the ability")
	
	var can_use: bool = TypeSafeMixin._call_node_method_bool(_battle_rules, "can_use_ability", [unit, ability.id])
	assert_true(can_use, "Unit should be able to use the ability")
	
	TypeSafeMixin._call_node_method_bool(_battle_rules, "use_ability", [unit, ability.id])
	var current_action_points: int = TypeSafeMixin._call_node_method_int(unit, "get_action_points", [])
	assert_eq(current_action_points, 2, "Ability should consume action points")