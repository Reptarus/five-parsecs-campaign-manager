@tool
class_name TestEnemyData
extends GutTest

## Enemy Data System Tests
##
## Tests enemy data functionality including:
## - Data initialization and validation
## - Stats and characteristics
## - Weapons and equipment
## - Loot tables and rewards
## - Experience and progression
## - Serialization and persistence

# Required type declarations
const Enemy: GDScript = preload("res://src/core/battle/enemy/Enemy.gd")
const EnemyData: GDScript = preload("res://src/core/rivals/EnemyData.gd")
# Type-safe script references
const GameWeapon: GDScript = preload("res://src/core/battle/items/Weapon.gd")

# Type-safe enums
enum EnemyType {
	NONE = 0,
	BASIC = 1,
	ELITE = 2,
	BOSS = 3
}

enum EnemyCategory {
	CRIMINAL_ELEMENTS = 0,
	HOSTILE_FAUNA = 1,
	MILITARY_FORCES = 2,
	ALIEN_THREATS = 3,
	ROBOTIC_ENTITIES = 4
}

enum EnemyBehavior {
	CAUTIOUS = 0,
	AGGRESSIVE = 1,
	DEFENSIVE = 2,
	TACTICAL = 3,
	UNPREDICTABLE = 4
}

enum CharacterStats {
	COMBAT_SKILL = 0,
	TOUGHNESS = 1,
	MOVEMENT = 2,
	COMMAND = 3
}

enum EnemyTrait {
	NONE = 0,
	ALERT = 1,
	ARMORED = 2,
	FAST = 3,
	REGENERATING = 4,
	STEALTHY = 5
}

# Type-safe test data
const TEST_LOOT_TABLES: Dictionary = {
	"Common Loot": {
		"name": "Credits" as String,
		"quantity": "1D6 x 10" as String,
		"chance": 30 as int
	},
	"Rare Loot": {
		"name": "Advanced Weapon" as String,
		"quantity": 1 as int,
		"chance": 20 as int
	},
	"Battlefield Finds": {
		"name": "Weapon" as String,
		"effect": "Roll on Weapon table" as String,
		"chance": 15 as int
	}
}

# Type-safe instance variables
var _enemy_data: EnemyData = null
var _test_weapon: Resource = null

# Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	await stabilize_engine()
	
	# Create test resources
	_enemy_data = EnemyData.new()
	assert_not_null(_enemy_data, "Should create enemy data")
	track_test_resource(_enemy_data)
	
	_test_weapon = _create_weapon_safe()
	assert_not_null(_test_weapon, "Should create test weapon")

func after_each() -> void:
	_enemy_data = null
	_cleanup_test_resources()
	await super.after_each()

# Helper Methods
func _create_weapon_safe() -> Resource:
	var weapon := GameWeapon.new() as Resource
	if not weapon:
		push_error("Failed to create weapon instance")
		return null
	
	track_test_resource(weapon)
	return weapon

func _verify_enemy_data_safe(data: Resource, message: String = "") -> void:
	if not data or not data is EnemyData:
		push_error("Invalid enemy data object")
		assert_false(true, "Invalid enemy data object: %s" % message)
		return
	
	assert_not_null(data, "Enemy data should not be null: %s" % message)
	assert_true(data is EnemyData, "Object should be EnemyData: %s" % message)

func _verify_loot_table_safe(table: Dictionary, category: String, loot: Dictionary, message: String = "") -> void:
	assert_has(table, category, "Loot table should have category '%s': %s" % [category, message])
	if not category in table:
		return
	
	var category_loot: Array = table[category]
	assert_has(category_loot, loot, "Category '%s' should have loot entry: %s" % [category, message])

# Initialization Tests
func test_enemy_data_initialization() -> void:
	_verify_enemy_data_safe(_enemy_data, "after initialization")
	
	# Verify default values
	assert_eq(_enemy_data.enemy_type, EnemyType.NONE,
		"Enemy type should default to NONE")
	assert_eq(_enemy_data.enemy_category, EnemyCategory.CRIMINAL_ELEMENTS,
		"Enemy category should default to CRIMINAL_ELEMENTS")
	assert_eq(_enemy_data.enemy_behavior, EnemyBehavior.CAUTIOUS,
		"Enemy behavior should default to CAUTIOUS")

# Stats Tests
func test_enemy_data_base_stats() -> void:
	_enemy_data = create_test_enemy_data("ELITE")
	_verify_enemy_data_safe(_enemy_data, "for base stats test")
	
	# Verify base stats
	assert_eq(_enemy_data.get_stat(CharacterStats.COMBAT_SKILL), 1,
		"Elite enemy should have combat skill 1")
	assert_eq(_enemy_data.get_stat(CharacterStats.TOUGHNESS), 4,
		"Elite enemy should have toughness 4")

func test_enemy_data_stat_modification() -> void:
	_enemy_data = create_test_enemy_data("ELITE")
	_verify_enemy_data_safe(_enemy_data, "for stat modification test")
	
	# Test stat modification
	var initial_skill: int = _enemy_data.get_stat(CharacterStats.COMBAT_SKILL)
	_enemy_data.set_stat(CharacterStats.COMBAT_SKILL, initial_skill + 1)
	assert_eq(_enemy_data.get_stat(CharacterStats.COMBAT_SKILL), initial_skill + 1,
		"Combat skill should be increased")

# Equipment Tests
func test_enemy_data_weapon_management() -> void:
	_verify_enemy_data_safe(_enemy_data, "for weapon management test")
	
	# Test adding weapon
	_enemy_data.add_weapon(_test_weapon)
	var weapons: Array = _enemy_data.get_weapons()
	assert_has(weapons, _test_weapon, "Should have added weapon")
	
	# Test removing weapon
	_enemy_data.remove_weapon(_test_weapon)
	weapons = _enemy_data.get_weapons()
	assert_does_not_have(weapons, _test_weapon, "Should have removed weapon")

# Characteristics Tests
func test_enemy_data_characteristics() -> void:
	_verify_enemy_data_safe(_enemy_data, "for characteristics test")
	
	var test_trait := EnemyTrait.ALERT
	
	# Test adding characteristic
	_enemy_data.add_characteristic(test_trait)
	assert_true(_enemy_data.has_characteristic(test_trait),
		"Should have added characteristic")
	
	# Test removing characteristic
	_enemy_data.remove_characteristic(test_trait)
	assert_false(_enemy_data.has_characteristic(test_trait),
		"Should have removed characteristic")

# Special Rules Tests
func test_enemy_data_special_rules() -> void:
	_verify_enemy_data_safe(_enemy_data, "for special rules test")
	
	var test_rule := "TEST_RULE"
	
	# Test adding rule
	_enemy_data.add_special_rule(test_rule)
	var rules: Array = _enemy_data.get_special_rules()
	assert_has(rules, test_rule, "Should have added special rule")
	
	# Test removing rule
	_enemy_data.remove_special_rule(test_rule)
	rules = _enemy_data.get_special_rules()
	assert_does_not_have(rules, test_rule, "Should have removed special rule")

# Loot System Tests
func test_enemy_data_loot_management() -> void:
	_verify_enemy_data_safe(_enemy_data, "for loot management test")
	
	# Test common loot
	var common_loot: Dictionary = TEST_LOOT_TABLES["Common Loot"]
	_enemy_data.add_loot_reward("Common Loot", common_loot)
	var loot_table: Dictionary = _enemy_data.get_loot_table()
	_verify_loot_table_safe(loot_table, "Common Loot", common_loot,
		"for common loot")

func test_enemy_data_rare_loot() -> void:
	_verify_enemy_data_safe(_enemy_data, "for rare loot test")
	
	# Test rare loot
	var rare_loot: Dictionary = TEST_LOOT_TABLES["Rare Loot"]
	_enemy_data.add_loot_reward("Rare Loot", rare_loot)
	var loot_table: Dictionary = _enemy_data.get_loot_table()
	_verify_loot_table_safe(loot_table, "Rare Loot", rare_loot,
		"for rare loot")

func test_enemy_data_battlefield_loot() -> void:
	_verify_enemy_data_safe(_enemy_data, "for battlefield loot test")
	
	# Test battlefield finds
	var battlefield_loot: Dictionary = TEST_LOOT_TABLES["Battlefield Finds"]
	_enemy_data.add_loot_reward("Battlefield Finds", battlefield_loot)
	var loot_table: Dictionary = _enemy_data.get_loot_table()
	_verify_loot_table_safe(loot_table, "Battlefield Finds", battlefield_loot,
		"for battlefield loot")

func test_enemy_data_loot_removal() -> void:
	_verify_enemy_data_safe(_enemy_data, "for loot removal test")
	
	# Add and remove loot
	var common_loot: Dictionary = TEST_LOOT_TABLES["Common Loot"]
	_enemy_data.add_loot_reward("Common Loot", common_loot)
	_enemy_data.remove_loot_reward("Common Loot", common_loot)
	
	var loot_table: Dictionary = _enemy_data.get_loot_table()
	var common_loot_array: Array = loot_table.get("Common Loot", [])
	assert_does_not_have(common_loot_array, common_loot,
		"Should have removed loot reward")

# Experience System Tests
func test_enemy_data_experience_value() -> void:
	_verify_enemy_data_safe(_enemy_data, "for experience value test")
	
	# Test base experience
	assert_eq(_enemy_data.get_experience_value(), 3,
		"Should have correct base experience value")

func test_enemy_data_experience_modification() -> void:
	_verify_enemy_data_safe(_enemy_data, "for experience modification test")
	
	# Test experience modification
	var new_value := 5
	_enemy_data.set_experience_value(new_value)
	assert_eq(_enemy_data.get_experience_value(), new_value,
		"Should update experience value")

# Serialization Tests
func test_enemy_data_serialization() -> void:
	_verify_enemy_data_safe(_enemy_data, "for serialization test")
	
	# Setup test data
	_enemy_data.enemy_type = EnemyType.ELITE
	_enemy_data.enemy_category = EnemyCategory.MILITARY_FORCES
	_enemy_data.add_characteristic(EnemyTrait.ARMORED)
	_enemy_data.add_weapon(_test_weapon)
	
	# Test serialization
	var serialized: Dictionary = _enemy_data.serialize()
	assert_not_null(serialized, "Should create serialized data")
	
	# Test deserialization
	var new_data := create_test_enemy_data()
	assert_not_null(new_data, "Should create new enemy data")
	new_data.deserialize(serialized)
	
	# Verify deserialized data
	assert_eq(new_data.enemy_type, EnemyType.ELITE,
		"Should restore enemy type")
	assert_eq(new_data.enemy_category, EnemyCategory.MILITARY_FORCES,
		"Should restore enemy category")
	assert_true(new_data.has_characteristic(EnemyTrait.ARMORED),
		"Should restore characteristics")
	assert_eq(new_data.get_weapons().size(), 1,
		"Should restore weapons")