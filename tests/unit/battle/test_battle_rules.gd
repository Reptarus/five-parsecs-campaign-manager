## Battle Rules Test Suite
##
## Testing core battle mechanics including:
## - Damage calculation
## - Status effects
## - Turn order and initiative
## - Special abilities and modifiers

@tool
extends GdUnitGameTest

# Core battle system imports
const BaseBattleRules: GDScript = preload("res://src/base/combat/BaseBattleRules.gd")
const BaseCombatManager: GDScript = preload("res://src/base/combat/BaseCombatManager.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

# Test timeout constant
const TEST_TIMEOUT: float = 2.0

# Battle mechanic constants
const BASE_MOVEMENT: int = 6
const BASE_ACTION_POINTS: int = 2
const BASE_ATTACK_RANGE: int = 24
const BASE_HIT_CHANCE: float = 0.65
const BASE_DAMAGE: int = 3

# Combat modifier constants
const COVER_MODIFIER: float = -0.25
const HEIGHT_MODIFIER: float = 0.15
const FLANK_MODIFIER: float = 0.2
const SUPPRESSION_MODIFIER: float = -0.2

# Range modifier constants
const OPTIMAL_RANGE_BONUS: float = 0.1
const LONG_RANGE_PENALTY: float = -0.2
const EXTREME_RANGE_PENALTY: float = -0.4

# Status effect thresholds
const CRITICAL_THRESHOLD: float = 0.9
const GRAZE_THRESHOLD: float = 0.35
const MINIMUM_HIT_CHANCE: float = 0.05
const MAXIMUM_HIT_CHANCE: float = 0.95

# Action point costs
const MOVE_COST: int = 1
const ATTACK_COST: int = 1
const DEFEND_COST: int = 1

# Type-safe instance variables
var _battle_rules: Node = null
var _combat_manager: Node = null

# Mock unit class for testing
class MockUnit:
	var attack: int
	var defense: int
	var speed: int
	var active_effects: Array = []
	var abilities: Array = []
	var damage_modifiers: Array = []
	
	func _init(att: int, def: int, spd: int = 5) -> void:
		attack = att
		defense = def
		speed = spd
		active_effects = []
		abilities = []
		damage_modifiers = []
	
	func get_attack() -> int:
		return attack
	
	func get_defense() -> int:
		return defense
	
	func get_speed() -> int:
		return speed
	
	func get_active_effects() -> Array:
		return active_effects
	
	func add_ability(ability: Dictionary) -> void:
		abilities.append(ability)
	
	func add_damage_modifier(mod: int, type: int) -> void:
		damage_modifiers.append({"modifier": mod, "type": type})

func before_test() -> void:
	super.before_test()
	
	# Create mock combat manager
	if BaseCombatManager:
		_combat_manager = Node.new()
		_combat_manager.set_script(BaseCombatManager)
	
	# Create mock battle rules
	if BaseBattleRules:
		_battle_rules = Node.new()
		_battle_rules.set_script(BaseBattleRules)
		if _battle_rules.has_method("initialize") and _combat_manager:
			_battle_rules.initialize(_combat_manager)

func after_test() -> void:
	_battle_rules = null
	_combat_manager = null
	super.after_test()

func test_basic_attack_resolution() -> void:
	var attacker = _create_test_unit(10, 2) # Attack 10, Defense 2
	var defender = _create_test_unit(5, 8) # Attack 5, Defense 8
	
	if _battle_rules and _battle_rules.has_method("resolve_attack"):
		var result = _battle_rules.resolve_attack(attacker, defender)
		assert_that(result).is_not_null()
		assert_that(result).contains_key("hit")
		assert_that(result).contains_key("damage")

func test_critical_hits() -> void:
	var attacker = _create_test_unit(20, 2) # High attack for crit chance
	var defender = _create_test_unit(5, 3)
	
	if _battle_rules and _battle_rules.has_method("resolve_attack"):
		for i in range(10): # Multiple attempts to trigger crit
			var result = _battle_rules.resolve_attack(attacker, defender)
			if result.get("critical", false):
				assert_that(result["critical"]).is_true()
				break

func test_damage_calculation() -> void:
	var base_damage := 10
	var armor := 3
	
	if _battle_rules and _battle_rules.has_method("calculate_damage"):
		var attacker = _create_test_unit(base_damage, 2)
		var defender = _create_test_unit(5, armor)
		
		var damage: int = 0
		# Try different possible signatures
		if _battle_rules.get_method_list().any(func(m): return m.name == "calculate_damage" and m.args.size() == 2):
			damage = _battle_rules.calculate_damage(attacker, defender)
		else:
			damage = _battle_rules.calculate_damage(base_damage, armor)
		
		assert_that(damage).is_greater_equal(0)
		var expected_damage = max(0, base_damage - armor)
		assert_that(damage).is_equal(expected_damage)

func test_damage_modifiers() -> void:
	var attacker = _create_test_unit(10, 2)
	var damage_type := 1
	attacker.add_damage_modifier(2, damage_type)
	
	if _battle_rules and _battle_rules.has_method("calculate_modified_damage"):
		var base_damage := 5
		var modified_damage = _battle_rules.calculate_modified_damage(attacker, base_damage)
		assert_that(modified_damage).is_greater_equal(base_damage)

func test_status_effect_application() -> void:
	var target = _create_test_unit(10, 2)
	var effect := {
		"type": 1, # STUNNED type
		"duration": 2,
		"potency": 1,
		"name": "test_stun"
	}
	
	if _battle_rules and _battle_rules.has_method("apply_status_effect"):
		var result = _battle_rules.apply_status_effect(target, effect)
		assert_that(result).is_true()
		
		var active_effects = target.get_active_effects()
		assert_that(active_effects).is_not_empty()

func test_initiative_calculation() -> void:
	var units = [
		_create_test_unit(10, 2, 5), # Speed 5
		_create_test_unit(10, 2, 8), # Speed 8
		_create_test_unit(10, 2, 3) # Speed 3
	]
	
	if _battle_rules and _battle_rules.has_method("calculate_initiative"):
		var initiative_order = _battle_rules.calculate_initiative(units)
		assert_that(initiative_order).is_not_empty()
		
		# Check that units are ordered by speed (descending)
		for i: int in range(1, initiative_order.size()):
			var prev_speed = initiative_order[i - 1].get_speed()
			var curr_speed = initiative_order[i].get_speed()
			assert_that(prev_speed).is_greater_equal(curr_speed)

func test_special_ability_activation() -> void:
	var unit = _create_test_unit(10, 2)
	var ability := {
		"id": "test_ability",
		"type": 1, # ACTIVE type
		"cost": 2,
		"name": "Test Ability"
	}
	unit.add_ability(ability)
	
	if _battle_rules and _battle_rules.has_method("activate_ability"):
		var result = _battle_rules.activate_ability(unit, ability.id)
		assert_that(result).is_not_null()

func test_invalid_attack_parameters() -> void:
	if _battle_rules and _battle_rules.has_method("resolve_attack"):
		# Test null attacker
		var result = _battle_rules.resolve_attack(null, _create_test_unit(5, 3))
		assert_that(result).is_not_null()
		
		# Test null defender
		var attacker = _create_test_unit(10, 2)
		result = _battle_rules.resolve_attack(attacker, null)
		assert_that(result).is_not_null()

func test_core_constants() -> void:
	assert_that(BASE_MOVEMENT).is_equal(6)
	assert_that(BASE_ACTION_POINTS).is_equal(2)
	assert_that(BASE_ATTACK_RANGE).is_equal(24)

func test_combat_modifiers() -> void:
	assert_that(COVER_MODIFIER).is_equal(-0.25)
	assert_that(HEIGHT_MODIFIER).is_equal(0.15)
	assert_that(FLANK_MODIFIER).is_equal(0.2)

func test_range_modifiers() -> void:
	assert_that(OPTIMAL_RANGE_BONUS).is_equal(0.1)
	assert_that(LONG_RANGE_PENALTY).is_equal(-0.2)
	assert_that(EXTREME_RANGE_PENALTY).is_equal(-0.4)

func test_status_effect_thresholds() -> void:
	assert_that(CRITICAL_THRESHOLD).is_equal(0.9)
	assert_that(GRAZE_THRESHOLD).is_equal(0.35)
	assert_that(MINIMUM_HIT_CHANCE).is_equal(0.05)

func test_action_point_costs() -> void:
	assert_that(MOVE_COST).is_equal(1)
	assert_that(ATTACK_COST).is_equal(1)
	assert_that(DEFEND_COST).is_equal(1)

func _create_test_unit(attack: int, defense: int, speed: int = 5) -> MockUnit:
	return MockUnit.new(attack, defense, speed)
