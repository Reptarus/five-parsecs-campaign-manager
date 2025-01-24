@tool
extends "res://tests/fixtures/base_test.gd"

const TestedClass = preload("res://src/core/battle/EnemyScalingSystem.gd")

var _instance: TestedClass

func before_each() -> void:
	await super.before_each()
	_instance = TestedClass.new()
	add_child(_instance)
	track_test_node(_instance)

func after_each() -> void:
	await super.after_each()
	_instance = null

# Base Value Tests
func test_base_values() -> void:
	assert_eq(_instance.base_health, 100.0, "Base health should be 100")
	assert_eq(_instance.base_damage, 10.0, "Base damage should be 10")
	assert_eq(_instance.base_armor, 5.0, "Base armor should be 5")
	assert_eq(_instance.base_speed, 4.0, "Base speed should be 4")

# Difficulty Scaling Tests
func test_easy_difficulty_scaling() -> void:
	var result = _instance.calculate_enemy_scaling(GameEnums.DifficultyLevel.EASY, 1, GameEnums.MissionType.NONE)
	assert_eq(result.health, 80.0, "Easy difficulty should reduce health to 80%")
	assert_eq(result.damage, 8.0, "Easy difficulty should reduce damage to 80%")
	assert_eq(result.armor, 4.0, "Easy difficulty should reduce armor to 80%")
	assert_eq(result.count_modifier, 0.8, "Easy difficulty should reduce enemy count to 80%")

func test_normal_difficulty_scaling() -> void:
	var result = _instance.calculate_enemy_scaling(GameEnums.DifficultyLevel.NORMAL, 1, GameEnums.MissionType.NONE)
	assert_eq(result.health, 100.0, "Normal difficulty should keep base health")
	assert_eq(result.damage, 10.0, "Normal difficulty should keep base damage")
	assert_eq(result.armor, 5.0, "Normal difficulty should keep base armor")
	assert_eq(result.count_modifier, 1.0, "Normal difficulty should keep base enemy count")

func test_hard_difficulty_scaling() -> void:
	var result = _instance.calculate_enemy_scaling(GameEnums.DifficultyLevel.HARD, 1, GameEnums.MissionType.NONE)
	assert_eq(result.health, 120.0, "Hard difficulty should increase health by 20%")
	assert_eq(result.damage, 12.0, "Hard difficulty should increase damage by 20%")
	assert_eq(result.armor, 5.5, "Hard difficulty should increase armor by 10%")
	assert_eq(result.count_modifier, 1.2, "Hard difficulty should increase enemy count by 20%")

func test_elite_difficulty_scaling() -> void:
	var result = _instance.calculate_enemy_scaling(GameEnums.DifficultyLevel.ELITE, 1, GameEnums.MissionType.NONE)
	assert_eq(result.health, 160.0, "Elite difficulty should increase health by 60%")
	assert_eq(result.damage, 14.0, "Elite difficulty should increase damage by 40%")
	assert_eq(result.armor, 6.5, "Elite difficulty should increase armor by 30%")
	assert_eq(result.count_modifier, 1.4, "Elite difficulty should increase enemy count by 40%")

# Mission Type Scaling Tests
func test_green_zone_scaling() -> void:
	var result = _instance.calculate_enemy_scaling(GameEnums.DifficultyLevel.NORMAL, 1, GameEnums.MissionType.GREEN_ZONE)
	assert_eq(result.health, 90.0, "Green zone should reduce health by 10%")
	assert_eq(result.damage, 9.0, "Green zone should reduce damage by 10%")

func test_red_zone_scaling() -> void:
	var result = _instance.calculate_enemy_scaling(GameEnums.DifficultyLevel.NORMAL, 1, GameEnums.MissionType.RED_ZONE)
	assert_eq(result.health, 120.0, "Red zone should increase health by 20%")
	assert_eq(result.damage, 12.0, "Red zone should increase damage by 20%")
	assert_eq(result.count_modifier, 1.1, "Red zone should increase enemy count by 10%")

func test_black_zone_scaling() -> void:
	var result = _instance.calculate_enemy_scaling(GameEnums.DifficultyLevel.NORMAL, 1, GameEnums.MissionType.BLACK_ZONE)
	assert_eq(result.health, 140.0, "Black zone should increase health by 40%")
	assert_eq(result.damage, 14.0, "Black zone should increase damage by 40%")
	assert_eq(result.armor, 6.0, "Black zone should increase armor by 20%")
	assert_eq(result.count_modifier, 1.2, "Black zone should increase enemy count by 20%")

# Level Scaling Tests
func test_level_scaling() -> void:
	# Test level 1 (base case already tested in other tests)
	var level1 = _instance.calculate_enemy_scaling(GameEnums.DifficultyLevel.NORMAL, 1, GameEnums.MissionType.NONE)
	assert_eq(level1.health, 100.0, "Level 1 should have base health")
	
	# Test level 5 (50% increase)
	var level5 = _instance.calculate_enemy_scaling(GameEnums.DifficultyLevel.NORMAL, 5, GameEnums.MissionType.NONE)
	assert_eq(level5.health, 150.0, "Level 5 should increase health by 50%")
	assert_eq(level5.damage, 15.0, "Level 5 should increase damage by 50%")
	assert_eq(level5.armor, 7.5, "Level 5 should increase armor by 50%")
	
	# Test level 10 (100% increase)
	var level10 = _instance.calculate_enemy_scaling(GameEnums.DifficultyLevel.NORMAL, 10, GameEnums.MissionType.NONE)
	assert_eq(level10.health, 200.0, "Level 10 should double health")
	assert_eq(level10.damage, 20.0, "Level 10 should double damage")
	assert_eq(level10.armor, 10.0, "Level 10 should double armor")