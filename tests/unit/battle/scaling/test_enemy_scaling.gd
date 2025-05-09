@tool
extends "res://tests/fixtures/specialized/enemy_test_base.gd"

# Enemy scaling system tests

# Handle missing file with a safer approach
var TestedClass = null
const TypeSafeHelper = preload("res://tests/fixtures/helpers/type_safe_test_mixin.gd")

# Type-safe instance variables
var _instance: Node = null

# Type-safe lifecycle methods
func before_each() -> void:
	await super.before_each()
	
	# Try to load the class dynamically to avoid preload errors
	if TestedClass == null:
		TestedClass = load("res://src/systems/scaling/EnemyScalingSystem.gd")
		if TestedClass == null:
			# Fallback - try an alternative path
			TestedClass = load("res://src/core/systems/scaling/EnemyScalingSystem.gd")
			if TestedClass == null:
				push_error("Could not find EnemyScalingSystem script")
				return
	
	_instance = TestedClass.new()
	if not _instance:
		push_error("Failed to create EnemyScalingSystem instance")
		return
	add_child_autofree(_instance)
	track_test_node(_instance)
	await stabilize_engine()

func after_each() -> void:
	_instance = null
	await super.after_each()

# Implementation of track_test_node for cases where it's not available from the parent class
# This ensures compatibility even if parent class changes.
func track_test_node(node: Node) -> void:
	if not is_instance_valid(node):
		push_warning("Cannot track invalid node")
		return
		
	# Don't try to call parent method since it doesn't exist
	# Just implement the functionality directly
	
	# Use GUT's autoqfree if available (preferred method)
	if has_method("add_child_autoqfree"):
		if not node.is_inside_tree():
			add_child_autoqfree(node)
		return
		
	# Fallback to autofree if autoqfree doesn't exist
	if has_method("add_child_autofree") and not node.is_inside_tree():
		add_child_autofree(node)

# Type-safe helper methods
func _verify_scaling_result(result: Dictionary, expected: Dictionary, message: String) -> void:
	for key in expected:
		var got: float = result.get(key, 0.0)
		var want: float = expected.get(key, 0.0)
		assert_eq(got, want, "%s: %s should be %f" % [message, key, want])

func _create_test_instance() -> Node:
	var instance: Node = TestedClass.new()
	if not instance:
		push_error("Failed to create EnemyScalingSystem instance")
		return null
	add_child_autofree(instance)
	track_test_node(instance)
	await stabilize_engine()
	return instance

# Base Value Tests
func test_base_values() -> void:
	var base_health: float = TypeSafeHelper._call_node_method_float(_instance, "get_base_health", [])
	var base_damage: float = TypeSafeHelper._call_node_method_float(_instance, "get_base_damage", [])
	var base_armor: float = TypeSafeHelper._call_node_method_float(_instance, "get_base_armor", [])
	var base_speed: float = TypeSafeHelper._call_node_method_float(_instance, "get_base_speed", [])
	
	assert_eq(base_health, 100.0, "Base health should be 100")
	assert_eq(base_damage, 10.0, "Base damage should be 10")
	assert_eq(base_armor, 5.0, "Base armor should be 5")
	assert_eq(base_speed, 4.0, "Base speed should be 4")

# Difficulty Scaling Tests
func test_easy_difficulty_scaling() -> void:
	var result: Dictionary = TypeSafeHelper._call_node_method_dict(_instance, "calculate_enemy_scaling", [
		GameEnums.DifficultyLevel.EASY,
		1,
		GameEnums.MissionType.NONE
	])
	
	_verify_scaling_result(result, {
		"health": 80.0,
		"damage": 8.0,
		"armor": 4.0,
		"count_modifier": 0.8
	}, "Easy difficulty scaling")

func test_normal_difficulty_scaling() -> void:
	var result: Dictionary = TypeSafeHelper._call_node_method_dict(_instance, "calculate_enemy_scaling", [
		GameEnums.DifficultyLevel.NORMAL,
		1,
		GameEnums.MissionType.NONE
	])
	
	_verify_scaling_result(result, {
		"health": 100.0,
		"damage": 10.0,
		"armor": 5.0,
		"count_modifier": 1.0
	}, "Normal difficulty scaling")

func test_hard_difficulty_scaling() -> void:
	var result: Dictionary = TypeSafeHelper._call_node_method_dict(_instance, "calculate_enemy_scaling", [
		GameEnums.DifficultyLevel.HARD,
		1,
		GameEnums.MissionType.NONE
	])
	
	_verify_scaling_result(result, {
		"health": 120.0,
		"damage": 12.0,
		"armor": 5.5,
		"count_modifier": 1.2
	}, "Hard difficulty scaling")

func test_elite_difficulty_scaling() -> void:
	var result: Dictionary = TypeSafeHelper._call_node_method_dict(_instance, "calculate_enemy_scaling", [
		GameEnums.DifficultyLevel.ELITE,
		1,
		GameEnums.MissionType.NONE
	])
	
	_verify_scaling_result(result, {
		"health": 160.0,
		"damage": 14.0,
		"armor": 6.5,
		"count_modifier": 1.4
	}, "Elite difficulty scaling")

func test_hardcore_difficulty_scaling() -> void:
	var base_health: float = TypeSafeHelper._call_node_method_float(_instance, "get_base_health", [])
	var base_damage: float = TypeSafeHelper._call_node_method_float(_instance, "get_base_damage", [])
	
	var result: Dictionary = TypeSafeHelper._call_node_method_dict(_instance, "calculate_enemy_scaling", [
		GameEnums.DifficultyLevel.HARDCORE,
		1,
		GameEnums.MissionType.RED_ZONE
	])
	
	_verify_scaling_result(result, {
		"health": base_health * 1.4 * 1.2 * 1.1,
		"damage": base_damage * 1.3 * 1.2 * 1.1
	}, "Hardcore difficulty in red zone scaling")

# Mission Type Scaling Tests
func test_green_zone_scaling() -> void:
	var result: Dictionary = TypeSafeHelper._call_node_method_dict(_instance, "calculate_enemy_scaling", [
		GameEnums.DifficultyLevel.NORMAL,
		1,
		GameEnums.MissionType.GREEN_ZONE
	])
	
	_verify_scaling_result(result, {
		"health": 90.0,
		"damage": 9.0
	}, "Green zone scaling")

func test_red_zone_scaling() -> void:
	var result: Dictionary = TypeSafeHelper._call_node_method_dict(_instance, "calculate_enemy_scaling", [
		GameEnums.DifficultyLevel.NORMAL,
		1,
		GameEnums.MissionType.RED_ZONE
	])
	
	_verify_scaling_result(result, {
		"health": 120.0,
		"damage": 12.0,
		"count_modifier": 1.1
	}, "Red zone scaling")

func test_black_zone_scaling() -> void:
	var result: Dictionary = TypeSafeHelper._call_node_method_dict(_instance, "calculate_enemy_scaling", [
		GameEnums.DifficultyLevel.NORMAL,
		1,
		GameEnums.MissionType.BLACK_ZONE
	])
	
	_verify_scaling_result(result, {
		"health": 140.0,
		"damage": 14.0,
		"armor": 6.0,
		"count_modifier": 1.2
	}, "Black zone scaling")

# Level Scaling Tests
func test_level_scaling() -> void:
	# Test level 1 (base case)
	var level1: Dictionary = TypeSafeHelper._call_node_method_dict(_instance, "calculate_enemy_scaling", [
		GameEnums.DifficultyLevel.NORMAL,
		1,
		GameEnums.MissionType.NONE
	])
	_verify_scaling_result(level1, {
		"health": 100.0
	}, "Level 1 scaling")
	
	# Test level 5 (50% increase)
	var level5: Dictionary = TypeSafeHelper._call_node_method_dict(_instance, "calculate_enemy_scaling", [
		GameEnums.DifficultyLevel.NORMAL,
		5,
		GameEnums.MissionType.NONE
	])
	_verify_scaling_result(level5, {
		"health": 150.0,
		"damage": 15.0,
		"armor": 7.5
	}, "Level 5 scaling")
	
	# Test level 10 (100% increase)
	var level10: Dictionary = TypeSafeHelper._call_node_method_dict(_instance, "calculate_enemy_scaling", [
		GameEnums.DifficultyLevel.NORMAL,
		10,
		GameEnums.MissionType.NONE
	])
	_verify_scaling_result(level10, {
		"health": 200.0,
		"damage": 20.0,
		"armor": 10.0
	}, "Level 10 scaling")

# Combined Scaling Tests
func test_combined_scaling() -> void:
	var base_health: float = TypeSafeHelper._call_node_method_float(_instance, "get_base_health", [])
	var base_damage: float = TypeSafeHelper._call_node_method_float(_instance, "get_base_damage", [])
	
	var scaling: Dictionary = TypeSafeHelper._call_node_method_dict(_instance, "calculate_enemy_scaling", [
		GameEnums.DifficultyLevel.HARD,
		3,
		GameEnums.MissionType.RED_ZONE
	])
	
	# Verify combined scaling effects
	var health: float = scaling.get("health", 0.0)
	var damage: float = scaling.get("damage", 0.0)
	var count_modifier: float = scaling.get("count_modifier", 0.0)
	
	assert_true(health > base_health, "Combined scaling should increase health")
	assert_true(damage > base_damage, "Combined scaling should increase damage")
	assert_true(count_modifier > 1.0, "Combined scaling should increase enemy count")

func test_extreme_scaling_combination() -> void:
	var base_health: float = TypeSafeHelper._call_node_method_float(_instance, "get_base_health", [])
	var base_damage: float = TypeSafeHelper._call_node_method_float(_instance, "get_base_damage", [])
	
	var scaling: Dictionary = TypeSafeHelper._call_node_method_dict(_instance, "calculate_enemy_scaling", [
		GameEnums.DifficultyLevel.ELITE,
		10,
		GameEnums.MissionType.BLACK_ZONE
	])
	
	# Verify scaling doesn't go too extreme
	var health: float = scaling.get("health", 0.0)
	var damage: float = scaling.get("damage", 0.0)
	
	assert_true(health < base_health * 5.0, "Health scaling should have reasonable limits")
	assert_true(damage < base_damage * 5.0, "Damage scaling should have reasonable limits")
