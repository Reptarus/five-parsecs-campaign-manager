extends "res://addons/gut/test.gd"

const EnemyData = preload("res://src/core/rivals/EnemyData.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const GameWeapon = preload("res://src/core/systems/items/Weapon.gd")

var enemy_data: EnemyData

func before_each() -> void:
	enemy_data = EnemyData.new(GameEnums.EnemyType.GANGERS, GameEnums.EnemyCategory.CRIMINAL_ELEMENTS)

func test_enemy_initialization() -> void:
	assert_not_null(enemy_data)
	assert_eq(enemy_data.enemy_type, GameEnums.EnemyType.GANGERS)
	assert_eq(enemy_data.enemy_category, GameEnums.EnemyCategory.CRIMINAL_ELEMENTS)

func test_default_stats() -> void:
	assert_eq(enemy_data.get_stat(GameEnums.CharacterStats.COMBAT_SKILL), 0)
	assert_eq(enemy_data.get_stat(GameEnums.CharacterStats.TOUGHNESS), 3)
	assert_eq(enemy_data.morale, 8)

func test_characteristics() -> void:
	assert_true(enemy_data.has_characteristic(GameEnums.EnemyTrait.LEG_IT))
	assert_true(enemy_data.has_characteristic(GameEnums.EnemyTrait.FRIDAY_NIGHT_WARRIORS))
	assert_eq(enemy_data.deployment_pattern, GameEnums.EnemyDeploymentPattern.SCATTERED)

func test_weapon_management() -> void:
	var weapon = GameWeapon.new()
	enemy_data.add_weapon(weapon)
	assert_has(enemy_data.get_weapons(), weapon)
	enemy_data.remove_weapon(weapon)
	assert_does_not_have(enemy_data.get_weapons(), weapon)

func test_loot_table() -> void:
	enemy_data.add_loot_reward(1, 0.5)
	assert_eq(enemy_data.get_loot_table()[1], 0.5)
	enemy_data.remove_loot_reward(1)
	assert_false(enemy_data.get_loot_table().has(1))

func test_behavior_validation() -> void:
	enemy_data.enemy_behavior = GameEnums.EnemyBehavior.AGGRESSIVE
	enemy_data.set_deployment_pattern(GameEnums.EnemyDeploymentPattern.OFFENSIVE)
	assert_true(enemy_data.validate_behavior_pattern())
	
	enemy_data.set_deployment_pattern(GameEnums.EnemyDeploymentPattern.DEFENSIVE)
	assert_false(enemy_data.validate_behavior_pattern())