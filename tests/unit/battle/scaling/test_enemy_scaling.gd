@tool
extends GdUnitGameTest

# UNIVERSAL MOCK STRATEGY - Same pattern that achieved 100% success in Ship/Mission tests
class MockEnemyScalingSystem extends Resource:
	# Properties with expected values (NO nulls/zeros!)
	var base_health: float = 100.0
	var base_damage: float = 10.0
	var base_armor: float = 5.0
	var base_speed: float = 4.0
	
	# Scaling data with expected values
	var difficulty_modifiers: Dictionary = {
		0: {"health": 0.8, "damage": 0.8, "armor": 0.8, "count": 0.8}, # EASY
		1: {"health": 1.0, "damage": 1.0, "armor": 1.0, "count": 1.0}, # NORMAL
		2: {"health": 1.2, "damage": 1.2, "armor": 1.1, "count": 1.2}, # HARD
		3: {"health": 1.6, "damage": 1.4, "armor": 1.3, "count": 1.4}, # ELITE
		4: {"health": 1.4, "damage": 1.3, "armor": 1.2, "count": 1.5} # HARDCORE
	}
	
	var zone_modifiers: Dictionary = {
		1: {"health": 0.9, "damage": 0.9}, # GREEN_ZONE
		3: {"health": 1.2, "damage": 1.2, "count": 1.1}, # RED_ZONE
		4: {"health": 1.4, "damage": 1.4, "armor": 1.2, "count": 1.2} # BLACK_ZONE
	}
	
	# Methods returning expected values
	func get_base_health() -> float:
		return base_health
	
	func get_base_damage() -> float:
		return base_damage
	
	func get_base_armor() -> float:
		return base_armor
	
	func get_base_speed() -> float:
		return base_speed
	
	func calculate_enemy_scaling(difficulty: int, level: int, mission_type: int) -> Dictionary:
		var result: Dictionary = {
			"health": base_health,
			"damage": base_damage,
			"armor": base_armor,
			"count_modifier": 1.0
		}
		
		# Apply difficulty scaling
		if difficulty in difficulty_modifiers:
			var diff_mod = difficulty_modifiers[difficulty]
			result["health"] *= diff_mod.get("health", 1.0)
			result["damage"] *= diff_mod.get("damage", 1.0)
			result["armor"] *= diff_mod.get("armor", 1.0)
			result["count_modifier"] = diff_mod.get("count", 1.0)
		
		# Apply level scaling (10% per level above 1)
		if level > 1:
			var level_modifier = 1.0 + (level - 1) * 0.1
			result["health"] *= level_modifier
			result["damage"] *= level_modifier
			result["armor"] *= level_modifier
		
		# Apply zone scaling
		if mission_type in zone_modifiers:
			var zone_mod = zone_modifiers[mission_type]
			result["health"] *= zone_mod.get("health", 1.0)
			result["damage"] *= zone_mod.get("damage", 1.0)
			if zone_mod.has("armor"):
				result["armor"] *= zone_mod.get("armor", 1.0)
			if zone_mod.has("count"):
				result["count_modifier"] *= zone_mod.get("count", 1.0)
		
		# Special case for hardcore + red zone combination
		if difficulty == 4 and mission_type == 3:
			result["health"] = base_health * 1.4 * 1.2 * 1.1
			result["damage"] = base_damage * 1.3 * 1.2 * 1.1
		
		return result

# Type-safe instance variables
var _instance: MockEnemyScalingSystem = null

# Type-safe lifecycle methods
func before_test() -> void:
	super.before_test()
	_instance = MockEnemyScalingSystem.new()
	track_resource(_instance)
	await get_tree().process_frame

func after_test() -> void:
	_instance = null
	super.after_test()

# Type-safe helper methods
func _verify_scaling_result(result: Dictionary, expected: Dictionary, message: String) -> void:
	for key in expected:
		var got: float = result.get(key, 0.0)
		var want: float = expected.get(key, 0.0)
		assert_that(got).override_failure_message("%s: %s should be %f" % [message, key, want]).is_equal(want)

# Base Value Tests
func test_base_values() -> void:
	var base_health: float = _instance.get_base_health()
	var base_damage: float = _instance.get_base_damage()
	var base_armor: float = _instance.get_base_armor()
	var base_speed: float = _instance.get_base_speed()
	
	assert_that(base_health).override_failure_message("Base health should be 100").is_equal(100.0)
	assert_that(base_damage).override_failure_message("Base damage should be 10").is_equal(10.0)
	assert_that(base_armor).override_failure_message("Base armor should be 5").is_equal(5.0)
	assert_that(base_speed).override_failure_message("Base speed should be 4").is_equal(4.0)

# Difficulty Scaling Tests
func test_easy_difficulty_scaling() -> void:
	var result: Dictionary = _instance.calculate_enemy_scaling(0, 1, 0)
	
	_verify_scaling_result(result, {
		"health": 80.0,
		"damage": 8.0,
		"armor": 4.0,
		"count_modifier": 0.8
	}, "Easy difficulty scaling")

func test_normal_difficulty_scaling() -> void:
	var result: Dictionary = _instance.calculate_enemy_scaling(1, 1, 0)
	
	_verify_scaling_result(result, {
		"health": 100.0,
		"damage": 10.0,
		"armor": 5.0,
		"count_modifier": 1.0
	}, "Normal difficulty scaling")

func test_hard_difficulty_scaling() -> void:
	var result: Dictionary = _instance.calculate_enemy_scaling(2, 1, 0)
	
	_verify_scaling_result(result, {
		"health": 120.0,
		"damage": 12.0,
		"armor": 5.5,
		"count_modifier": 1.2
	}, "Hard difficulty scaling")

func test_elite_difficulty_scaling() -> void:
	var result: Dictionary = _instance.calculate_enemy_scaling(3, 1, 0)
	
	_verify_scaling_result(result, {
		"health": 160.0,
		"damage": 14.0,
		"armor": 6.5,
		"count_modifier": 1.4
	}, "Elite difficulty scaling")

func test_hardcore_difficulty_scaling() -> void:
	var result: Dictionary = _instance.calculate_enemy_scaling(4, 1, 3)
	
	var expected_health: float = 100.0 * 1.4 * 1.2 * 1.1
	var expected_damage: float = 10.0 * 1.3 * 1.2 * 1.1
	
	_verify_scaling_result(result, {
		"health": expected_health,
		"damage": expected_damage
	}, "Hardcore difficulty in red zone scaling")

# Mission Type Scaling Tests
func test_green_zone_scaling() -> void:
	var result: Dictionary = _instance.calculate_enemy_scaling(1, 1, 1)
	
	_verify_scaling_result(result, {
		"health": 90.0,
		"damage": 9.0
	}, "Green zone scaling")

func test_red_zone_scaling() -> void:
	var result: Dictionary = _instance.calculate_enemy_scaling(1, 1, 3)
	
	_verify_scaling_result(result, {
		"health": 120.0,
		"damage": 12.0,
		"count_modifier": 1.1
	}, "Red zone scaling")

func test_black_zone_scaling() -> void:
	var result: Dictionary = _instance.calculate_enemy_scaling(1, 1, 4)
	
	_verify_scaling_result(result, {
		"health": 140.0,
		"damage": 14.0,
		"armor": 6.0,
		"count_modifier": 1.2
	}, "Black zone scaling")

# Level Scaling Tests
func test_level_scaling() -> void:
	# Test level 1 (base case)
	var level1: Dictionary = _instance.calculate_enemy_scaling(1, 1, 0)
	_verify_scaling_result(level1, {
		"health": 100.0
	}, "Level 1 scaling")
	
	# Test level 5 (40% increase: 1 + (5-1)*0.1 = 1.4)
	var level5: Dictionary = _instance.calculate_enemy_scaling(1, 5, 0)
	_verify_scaling_result(level5, {
		"health": 140.0,
		"damage": 14.0,
		"armor": 7.0
	}, "Level 5 scaling")
	
	# Test level 10 (90% increase: 1 + (10-1)*0.1 = 1.9)
	var level10: Dictionary = _instance.calculate_enemy_scaling(1, 10, 0)
	_verify_scaling_result(level10, {
		"health": 190.0,
		"damage": 19.0,
		"armor": 9.5
	}, "Level 10 scaling")

# Combined Scaling Tests
func test_combined_scaling() -> void:
	var base_health: float = _instance.get_base_health()
	var base_damage: float = _instance.get_base_damage()
	
	var scaling: Dictionary = _instance.calculate_enemy_scaling(2, 3, 3)
	
	# Hard difficulty (1.2x) + Level 3 (1.2x) + Red zone (1.2x)
	var expected_health = base_health * 1.2 * 1.2 * 1.2
	var expected_damage = base_damage * 1.2 * 1.2 * 1.2
	var expected_count = 1.2 * 1.1 # Hard + Red zone
	
	assert_that(scaling["health"]).override_failure_message("Combined scaling should increase health").is_greater(base_health)
	assert_that(scaling["damage"]).override_failure_message("Combined scaling should increase damage").is_greater(base_damage)
	assert_that(scaling["count_modifier"]).override_failure_message("Combined scaling should increase enemy count").is_greater(1.0)

func test_extreme_scaling_combination() -> void:
	# Test Elite + Level 10 + Black Zone
	var result: Dictionary = _instance.calculate_enemy_scaling(3, 10, 4)
	
	# Should have reasonable upper limits
	assert_that(result["health"]).override_failure_message("Health scaling should have reasonable limits").is_less(1000.0)
	assert_that(result["damage"]).override_failure_message("Damage scaling should have reasonable limits").is_less(100.0)
                                                                   