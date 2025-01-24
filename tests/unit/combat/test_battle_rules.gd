@tool
extends "res://tests/fixtures/base_test.gd"

const TestedClass = preload("res://src/core/battle/BattleRules.gd")

var _instance: TestedClass

func before_each() -> void:
	await super.before_each()
	_instance = TestedClass.new()
	add_child(_instance)
	track_test_node(_instance)

func after_each() -> void:
	await super.after_each()
	_instance = null

# Core Constants Tests
func test_core_constants() -> void:
	assert_eq(_instance.BASE_MOVEMENT, 6, "Base movement should be 6 inches")
	assert_eq(_instance.BASE_ACTION_POINTS, 2, "Base action points should be 2")
	assert_eq(_instance.BASE_ATTACK_RANGE, 24, "Base attack range should be 24 inches")
	assert_eq(_instance.BASE_HIT_CHANCE, 0.65, "Base hit chance should be 65%")
	assert_eq(_instance.BASE_DAMAGE, 3, "Base damage should be 3")

# Combat Modifier Tests
func test_combat_modifiers() -> void:
	assert_eq(_instance.COVER_MODIFIER, -0.25, "Cover modifier should be -25%")
	assert_eq(_instance.HEIGHT_MODIFIER, 0.15, "Height modifier should be +15%")
	assert_eq(_instance.FLANK_MODIFIER, 0.2, "Flank modifier should be +20%")
	assert_eq(_instance.SUPPRESSION_MODIFIER, -0.2, "Suppression modifier should be -20%")

# Range Modifier Tests
func test_range_modifiers() -> void:
	assert_eq(_instance.OPTIMAL_RANGE_BONUS, 0.1, "Optimal range bonus should be +10%")
	assert_eq(_instance.LONG_RANGE_PENALTY, -0.2, "Long range penalty should be -20%")
	assert_eq(_instance.EXTREME_RANGE_PENALTY, -0.4, "Extreme range penalty should be -40%")

# Status Effect Threshold Tests
func test_status_effect_thresholds() -> void:
	assert_eq(_instance.CRITICAL_THRESHOLD, 0.9, "Critical threshold should be 90%")
	assert_eq(_instance.GRAZE_THRESHOLD, 0.35, "Graze threshold should be 35%")
	assert_eq(_instance.MINIMUM_HIT_CHANCE, 0.05, "Minimum hit chance should be 5%")
	assert_eq(_instance.MAXIMUM_HIT_CHANCE, 0.95, "Maximum hit chance should be 95%")

# Action Point Cost Tests
func test_action_point_costs() -> void:
	assert_eq(_instance.MOVE_COST, 1, "Move cost should be 1")
	assert_eq(_instance.ATTACK_COST, 1, "Attack cost should be 1")
	assert_eq(_instance.DASH_COST, 2, "Dash cost should be 2")
	assert_eq(_instance.OVERWATCH_COST, 2, "Overwatch cost should be 2")
	assert_eq(_instance.RELOAD_COST, 1, "Reload cost should be 1")

# Terrain Effect Tests
func test_terrain_effects() -> void:
	assert_eq(_instance.DIFFICULT_TERRAIN_MODIFIER, 0.5, "Difficult terrain should halve movement")
	assert_eq(_instance.HAZARDOUS_TERRAIN_DAMAGE, 1, "Hazardous terrain should deal 1 damage per turn")

# Action Point Rule Tests
func test_can_perform_action() -> void:
	assert_true(TestedClass.can_perform_action(GameEnums.UnitAction.MOVE, 2),
		"Should be able to move with 2 action points")
	assert_true(TestedClass.can_perform_action(GameEnums.UnitAction.ATTACK, 1),
		"Should be able to attack with 1 action point")
	assert_true(TestedClass.can_perform_action(GameEnums.UnitAction.SPECIAL_ABILITY, 2),
		"Should be able to use special ability with 2 action points")
	assert_false(TestedClass.can_perform_action(GameEnums.UnitAction.OVERWATCH, 1),
		"Should not be able to overwatch with 1 action point")