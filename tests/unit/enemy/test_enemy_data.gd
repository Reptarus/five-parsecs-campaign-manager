@tool
extends "res://tests/fixtures/specialized/enemy_test.gd"

const GameWeapon: GDScript = preload("res://src/core/systems/items/Weapon.gd")

enum EnemyType {
	GRUNT,
	ELITE,
	BOSS
}

# Type-safe instance variables
var _test_enemy_data: EnemyData = null

## Core tests for enemy data functionality:
## - Data initialization and validation
## - Enemy stats and characteristics
## - Weapons and equipment
## - Loot tables and rewards
## - Experience and progression
## - Serialization

func before_each() -> void:
	await super.before_each()
	_test_enemy_data = create_test_enemy_data()
	assert_not_null(_test_enemy_data, "Enemy data should be created")

func after_each() -> void:
	_test_enemy_data = null
	await super.after_each()

func test_basic_initialization() -> void:
	# Test initialization
	var enemy_id: String = _call_node_method_string(_test_enemy_data, "get_id", [])
	assert_not_null(enemy_id, "Enemy ID should not be null")
	
	var enemy_name: String = _call_node_method_string(_test_enemy_data, "get_name", [])
	assert_not_null(enemy_name, "Enemy name should not be null")

func test_stats_configuration() -> void:
	# Test stats configuration
	var health: int = TypeSafeMixin._call_node_method_int(_test_enemy_data, "get_max_health", [])
	assert_gt(health, 0, "Health should be positive")
	
	var speed: int = TypeSafeMixin._call_node_method_int(_test_enemy_data, "get_speed", [])
	assert_gt(speed, 0, "Speed should be positive")
	
	var defense: int = TypeSafeMixin._call_node_method_int(_test_enemy_data, "get_defense", [])
	assert_ge(defense, 0, "Defense should be non-negative")

func test_equipment_handling() -> void:
	# Test equipment handling
	var weapons: Array = TypeSafeMixin._call_node_method(_test_enemy_data, "get_weapons", []) as Array
	assert_true(weapons is Array, "Weapons should be an array")
	
	if weapons.size() > 0:
		var first_weapon = weapons[0]
		assert_true(first_weapon is GameWeapon, "Weapon should be GameWeapon type")
		
		var weapon_damage: int = TypeSafeMixin._call_node_method_int(first_weapon, "get_damage", [])
		assert_gt(weapon_damage, 0, "Weapon damage should be positive")
	else:
		# Add a test weapon if none exists
		var test_weapon = GameWeapon.new()
		TypeSafeMixin._call_node_method_bool(test_weapon, "set_name", ["Test Blaster"])
		TypeSafeMixin._call_node_method_bool(test_weapon, "set_damage", [5])
		
		TypeSafeMixin._call_node_method_bool(_test_enemy_data, "add_weapon", [test_weapon])
		
		weapons = TypeSafeMixin._call_node_method(_test_enemy_data, "get_weapons", []) as Array
		assert_eq(weapons.size(), 1, "Should have added one weapon")
	
	# Test armor
	var has_armor: bool = TypeSafeMixin._call_node_method_bool(_test_enemy_data, "has_armor", [])
	if has_armor:
		var armor_value: int = TypeSafeMixin._call_node_method_int(_test_enemy_data, "get_armor_value", [])
		assert_gt(armor_value, 0, "Armor value should be positive if has_armor is true")

func test_enemy_type_behaviors() -> void:
	# Test enemy type behaviors
	for enemy_type in EnemyType.values():
		TypeSafeMixin._call_node_method_bool(_test_enemy_data, "set_type", [enemy_type])
		var set_type: int = TypeSafeMixin._call_node_method_int(_test_enemy_data, "get_type", [])
		assert_eq(set_type, enemy_type, "Enemy type should be set correctly")
		
		# Check type-specific properties
		var power_level: int = TypeSafeMixin._call_node_method_int(_test_enemy_data, "get_power_level", [])
		match enemy_type:
			EnemyType.GRUNT:
				assert_lt(power_level, 5, "Grunt should have low power level")
			EnemyType.ELITE:
				assert_gt(power_level, 5, "Elite should have higher power level")
				assert_lt(power_level, 10, "Elite should have power level below boss")
			EnemyType.BOSS:
				assert_gt(power_level, 10, "Boss should have highest power level")

func test_loot_tables() -> void:
	# Test loot tables
	var loot_table: Dictionary = TypeSafeMixin._call_node_method(_test_enemy_data, "get_loot_table", []) as Dictionary
	assert_true(loot_table is Dictionary, "Loot table should be a Dictionary")
	
	# Add test loot if none exists
	if loot_table.is_empty():
		var test_loot := {
			"credits": {"min": 10, "max": 50},
			"items": [
				{"name": "Medpack", "chance": 0.5},
				{"name": "Ammo", "chance": 0.8}
			]
		}
		
		TypeSafeMixin._call_node_method_bool(_test_enemy_data, "set_loot_table", [test_loot])
		loot_table = TypeSafeMixin._call_node_method(_test_enemy_data, "get_loot_table", []) as Dictionary
	
	# Test loot generation
	var generated_loot: Array = TypeSafeMixin._call_node_method(_test_enemy_data, "generate_loot", []) as Array
	assert_true(generated_loot is Array, "Generated loot should be an Array")

func test_experience_rewards() -> void:
	# Test experience rewards
	var xp_reward: int = TypeSafeMixin._call_node_method_int(_test_enemy_data, "get_xp_reward", [])
	assert_gt(xp_reward, 0, "XP reward should be positive")
	
	# Test relationship between enemy type and XP
	TypeSafeMixin._call_node_method_bool(_test_enemy_data, "set_type", [EnemyType.GRUNT])
	var grunt_xp: int = TypeSafeMixin._call_node_method_int(_test_enemy_data, "get_xp_reward", [])
	
	TypeSafeMixin._call_node_method_bool(_test_enemy_data, "set_type", [EnemyType.BOSS])
	var boss_xp: int = TypeSafeMixin._call_node_method_int(_test_enemy_data, "get_xp_reward", [])
	
	assert_gt(boss_xp, grunt_xp, "Boss should give more XP than Grunt")

func test_enemy_traits() -> void:
	# Test enemy traits
	var traits: Array = TypeSafeMixin._call_node_method(_test_enemy_data, "get_traits", []) as Array
	assert_true(traits is Array, "Traits should be an Array")
	
	# Add a test trait if none exists
	if traits.is_empty():
		TypeSafeMixin._call_node_method_bool(_test_enemy_data, "add_trait", ["aggressive"])
		traits = TypeSafeMixin._call_node_method(_test_enemy_data, "get_traits", []) as Array
	
	assert_false(traits.is_empty(), "Should have at least one trait")
	
	# Test trait effects
	var has_trait: bool = TypeSafeMixin._call_node_method_bool(_test_enemy_data, "has_trait", [traits[0]])
	assert_true(has_trait, "Should confirm trait exists")
	
	var non_existent_trait: bool = TypeSafeMixin._call_node_method_bool(_test_enemy_data, "has_trait", ["nonexistent"])
	assert_false(non_existent_trait, "Should not have nonexistent trait")

func test_serialization() -> void:
	# Test save/load functionality
	# Save to dictionary
	var save_data: Dictionary = TypeSafeMixin._call_node_method_dict(_test_enemy_data, "save_to_dictionary", [])
	assert_gt(save_data.size(), 0, "Save data should not be empty")
	
	# Load in a new instance
	var new_enemy_data: EnemyData = EnemyData.new()
	TypeSafeMixin._call_node_method_bool(new_enemy_data, "load_from_dictionary", [save_data])
	
	# Verify loaded data
	var original_id: String = _call_node_method_string(_test_enemy_data, "get_id", [])
	var loaded_id: String = _call_node_method_string(new_enemy_data, "get_id", [])
	assert_eq(loaded_id, original_id, "Loaded enemy should have same ID")
	
	var original_type: int = TypeSafeMixin._call_node_method_int(_test_enemy_data, "get_type", [])
	var loaded_type: int = TypeSafeMixin._call_node_method_int(new_enemy_data, "get_type", [])
	assert_eq(loaded_type, original_type, "Loaded enemy should have same type")

func test_enemy_abilities() -> void:
	# Test enemy abilities
	var abilities: Array = TypeSafeMixin._call_node_method(_test_enemy_data, "get_abilities", []) as Array
	assert_true(abilities is Array, "Abilities should be an Array")
	
	# Add a test ability if none exists
	if abilities.is_empty():
		TypeSafeMixin._call_node_method_bool(_test_enemy_data, "add_ability", ["regeneration"])
		abilities = TypeSafeMixin._call_node_method(_test_enemy_data, "get_abilities", []) as Array
	
	assert_false(abilities.is_empty(), "Should have at least one ability")
	
	# Test ability existence
	var has_ability: bool = TypeSafeMixin._call_node_method_bool(_test_enemy_data, "has_ability", [abilities[0]])
	assert_true(has_ability, "Should confirm ability exists")
	
	# Test ability parameters
	if has_ability:
		var ability_params: Dictionary = TypeSafeMixin._call_node_method(_test_enemy_data, "get_ability_parameters", [abilities[0]]) as Dictionary
		assert_true(ability_params is Dictionary, "Ability parameters should be a Dictionary")

func test_validation() -> void:
	# Test basic validation
	var is_valid: bool = TypeSafeMixin._call_node_method_bool(_test_enemy_data, "validate", [])
	assert_true(is_valid, "Properly initialized enemy data should be valid")
	
	# Test validation with invalid data
	var invalid_data: EnemyData = EnemyData.new()
	var invalid_result: bool = TypeSafeMixin._call_node_method_bool(invalid_data, "validate", [])
	assert_false(invalid_result, "Uninitialized enemy data should be invalid")

# Helper method to create test enemy data
func create_test_enemy_data() -> EnemyData:
	var data = EnemyData.new()
	data.set_id("test_enemy_" + str(randi() % 1000))
	data.set_name("Test Enemy")
	data.set_health(100)
	data.set_damage(10)
	data.set_defense(5)
	data.set_speed(3)
	return data

# Helper method to check if an object has a specific method
func assert_has_method(obj: Object, method_name: String, message: String = "") -> void:
	assert_true(obj.has_method(method_name), message if message else "Object should have method '%s'" % method_name)