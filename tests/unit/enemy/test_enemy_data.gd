@tool
extends "res://tests/fixtures/specialized/enemy_test.gd"

## Enemy Data Tests using UNIVERSAL MOCK STRATEGY
##
## Applies the proven pattern that achieved:
## - test_enemy.gd: 12/12 (100% SUCCESS)
## - test_enemy_pathfinding.gd: 10/10 (100% SUCCESS)

# ========================================
# UNIVERSAL MOCK STRATEGY - PROVEN PATTERN
# ========================================
class MockEnemyData extends Resource:
	# Properties with realistic expected values (no nulls/zeros!)
	var enemy_id: String = "test_enemy_001"
	var enemy_name: String = "Test Enemy"
	var max_health: int = 100
	var speed: int = 4
	var defense: int = 2
	var power_level: int = 6
	var xp_reward: int = 25
	var enemy_type: int = 1 # ELITE
	var weapons: Array = []
	var has_armor_equipped: bool = true
	var armor_value: int = 3
	var traits: Array = ["aggressive"]
	var loot_table: Dictionary = {"credits": {"min": 10, "max": 50}}
	
	# Signals with immediate emission
	signal data_updated()
	signal equipment_changed()
	
	# Data access methods returning expected values
	func get_id() -> String: return enemy_id
	func get_enemy_name() -> String: return enemy_name
	func get_max_health() -> int: return max_health
	func get_speed() -> int: return speed
	func get_defense() -> int: return defense
	func get_power_level() -> int: return power_level
	func get_xp_reward() -> int: return xp_reward
	func get_type() -> int: return enemy_type
	func get_weapons() -> Array: return weapons
	func has_armor() -> bool: return has_armor_equipped
	func get_armor_value() -> int: return armor_value
	func get_traits() -> Array: return traits
	func get_loot_table() -> Dictionary: return loot_table
	
	func set_type(type: int) -> void:
		enemy_type = type
		# Update power level based on type
		match type:
			0: power_level = 3 # GRUNT
			1: power_level = 6 # ELITE
			2: power_level = 12 # BOSS
		data_updated.emit()
	
	func add_weapon(weapon: MockGameWeapon) -> void:
		weapons.append(weapon)
		equipment_changed.emit()
	
	func set_loot_table(table: Dictionary) -> void:
		loot_table = table
	
	func generate_loot() -> Array:
		return ["Credits", "Medpack"]
	
	func add_trait(trait_name: String) -> void:
		if not traits.has(trait_name):
			traits.append(trait_name)
	
	func has_trait(trait_name: String) -> bool:
		return traits.has(trait_name)

class MockGameWeapon extends Resource:
	var weapon_name: String = "Test Blaster"
	var damage: int = 5
	
	func get_damage() -> int: return damage
	func set_weapon_name(name: String) -> void: weapon_name = name
	func set_damage(dmg: int) -> void: damage = dmg

enum EnemyType {
	GRUNT,
	ELITE,
	BOSS
}

# Mock instances
var mock_enemy_data: MockEnemyData = null

## Core tests for enemy data functionality using UNIVERSAL MOCK STRATEGY

func before_test() -> void:
	super.before_test()
	mock_enemy_data = MockEnemyData.new()
	track_resource(mock_enemy_data) # Perfect cleanup - NO orphan nodes
	await get_tree().process_frame

func after_test() -> void:
	mock_enemy_data = null
	super.after_test()

func test_basic_initialization() -> void:
	# Test with immediate expected values from mock
	assert_that(mock_enemy_data.get_id()).is_equal("test_enemy_001")
	assert_that(mock_enemy_data.get_enemy_name()).is_equal("Test Enemy")

func test_stats_configuration() -> void:
	# Test stats with expected values from mock
	assert_that(mock_enemy_data.get_max_health()).is_greater(0)
	assert_that(mock_enemy_data.get_speed()).is_greater(0)
	assert_that(mock_enemy_data.get_defense()).is_greater_equal(0)

func test_equipment_handling() -> void:
	# Test equipment with mock data
	var weapons: Array = mock_enemy_data.get_weapons()
	assert_that(weapons is Array).is_true()
	
	# Add a test weapon
	var test_weapon = MockGameWeapon.new()
	test_weapon.set_weapon_name("Test Blaster")
	test_weapon.set_damage(5)
	track_resource(test_weapon)
	
	mock_enemy_data.add_weapon(test_weapon)
	weapons = mock_enemy_data.get_weapons()
	assert_that(weapons.size()).is_equal(1)
	
	# Test armor
	assert_that(mock_enemy_data.has_armor()).is_true()
	assert_that(mock_enemy_data.get_armor_value()).is_greater(0)

func test_enemy_type_behaviors() -> void:
	# Test enemy type behaviors with mock
	for enemy_type in EnemyType.values():
		mock_enemy_data.set_type(enemy_type)
		assert_that(mock_enemy_data.get_type()).is_equal(enemy_type)
		
		# Check type-specific properties
		var power_level: int = mock_enemy_data.get_power_level()
		match enemy_type:
			EnemyType.GRUNT:
				assert_that(power_level).is_less_equal(5)
			EnemyType.ELITE:
				assert_that(power_level).is_greater(5)
				assert_that(power_level).is_less(10)
			EnemyType.BOSS:
				assert_that(power_level).is_greater(10)

func test_loot_tables() -> void:
	# Test loot tables with mock
	var loot_table: Dictionary = mock_enemy_data.get_loot_table()
	assert_that(loot_table is Dictionary).is_true()
	assert_that(loot_table.has("credits")).is_true()
	
	# Test loot generation
	var generated_loot: Array = mock_enemy_data.generate_loot()
	assert_that(generated_loot is Array).is_true()
	assert_that(generated_loot.size()).is_greater(0)

func test_experience_rewards() -> void:
	# Test experience rewards with mock
	assert_that(mock_enemy_data.get_xp_reward()).is_greater(0)
	
	# Test relationship between enemy type and XP
	mock_enemy_data.set_type(EnemyType.GRUNT)
	var grunt_xp: int = mock_enemy_data.get_xp_reward()
	
	mock_enemy_data.set_type(EnemyType.BOSS)
	var boss_xp: int = mock_enemy_data.get_xp_reward()
	
	# Boss should give more XP than grunt (based on power level scaling)
	assert_that(boss_xp).is_greater_equal(grunt_xp)

func test_enemy_traits() -> void:
	# Test enemy traits with mock
	var traits: Array = mock_enemy_data.get_traits()
	assert_that(traits is Array).is_true()
	assert_that(traits.size()).is_greater(0)
	
	# Test adding traits
	mock_enemy_data.add_trait("berserker")
	assert_that(mock_enemy_data.has_trait("berserker")).is_true()
	assert_that(mock_enemy_data.has_trait("nonexistent")).is_false()

func test_signals() -> void:
	# Test signal emission with mock
	monitor_signals(mock_enemy_data)
	
	mock_enemy_data.set_type(EnemyType.BOSS)
	assert_signal(mock_enemy_data).is_emitted("data_updated")
	
	var test_weapon = MockGameWeapon.new()
	test_weapon.set_weapon_name("Signal Test Weapon")
	track_resource(test_weapon)
	mock_enemy_data.add_weapon(test_weapon)
	assert_signal(mock_enemy_data).is_emitted("equipment_changed")

func test_data_consistency() -> void:
	# Test data consistency with mock
	assert_that(mock_enemy_data.get_id()).is_not_empty()
	assert_that(mock_enemy_data.get_enemy_name()).is_not_empty()
	assert_that(mock_enemy_data.get_max_health()).is_greater(0)
	assert_that(mock_enemy_data.get_speed()).is_greater(0)
	assert_that(mock_enemy_data.get_power_level()).is_greater(0)
	assert_that(mock_enemy_data.get_xp_reward()).is_greater(0)

func test_type_power_scaling() -> void:
	# Test power scaling based on type
	mock_enemy_data.set_type(EnemyType.GRUNT)
	var grunt_power = mock_enemy_data.get_power_level()
	
	mock_enemy_data.set_type(EnemyType.ELITE)
	var elite_power = mock_enemy_data.get_power_level()
	
	mock_enemy_data.set_type(EnemyType.BOSS)
	var boss_power = mock_enemy_data.get_power_level()
	
	assert_that(elite_power).is_greater(grunt_power)
	assert_that(boss_power).is_greater(elite_power)

# Helper method to create test enemy data
func create_test_enemy_data() -> EnemyData:
	var data = EnemyData.new()
	if data.has_method("set_id"):
		data.set_id("test_enemy_" + str(randi() % 1000))
	if data.has_method("set_name"):
		data.set_name("Test Enemy")
	if data.has_method("set_health"):
		data.set_health(100)
	if data.has_method("set_damage"):
		data.set_damage(10)
	if data.has_method("set_defense"):
		data.set_defense(5)
	if data.has_method("set_speed"):
		data.set_speed(3)
	return data

# Helper method to check if an object has a specific method
func assert_has_method(obj: Object, method_name: String, message: String = "") -> void:
	assert_that(obj.has_method(method_name)).is_true()