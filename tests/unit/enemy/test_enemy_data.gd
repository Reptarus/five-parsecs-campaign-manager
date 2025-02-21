@tool
extends GameTest

# Type-safe constants with explicit typing
const GameWeapon: GDScript = preload("res://src/core/systems/items/Weapon.gd")
const FiveParsecsEnemyData: GDScript = preload("res://src/core/rivals/EnemyData.gd")

# Type-safe enums
enum EnemyType {
	NONE = 0,
	MINION = 1,
	ELITE = 2,
	BOSS = 3,
	RIVAL = 4
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
var _enemy_data: Resource = null
var _test_weapon: Resource = null

# Type-safe lifecycle methods
func before_each() -> void:
	await super.before_each()
	
	# Create enemy data with type safety
	_enemy_data = _create_enemy_data_safe()
	if not _enemy_data:
		push_error("Failed to create enemy data")
		return
	
	# Create test weapon with type safety
	_test_weapon = _create_weapon_safe()
	if not _test_weapon:
		push_error("Failed to create test weapon")
		return

func after_each() -> void:
	_cleanup_test_resources()
	await super.after_each()

# Type-safe cleanup methods
func _cleanup_test_resources() -> void:
	if _enemy_data and not _enemy_data.is_queued_for_deletion():
		_enemy_data.free()
	_enemy_data = null
	
	if _test_weapon and not _test_weapon.is_queued_for_deletion():
		_test_weapon.free()
	_test_weapon = null

# Type-safe helper methods
func _create_enemy_data_safe(enemy_type: int = EnemyType.NONE) -> Resource:
	var data := FiveParsecsEnemyData.new() as Resource
	if not data:
		push_error("Failed to create enemy data instance")
		return null
	
	data.enemy_type = enemy_type
	data.enemy_category = EnemyCategory.CRIMINAL_ELEMENTS
	data.enemy_behavior = EnemyBehavior.CAUTIOUS
	
	return data

func _create_weapon_safe() -> Resource:
	var weapon := GameWeapon.new() as Resource
	if not weapon:
		push_error("Failed to create weapon instance")
		return null
	
	return weapon

func _verify_enemy_data_safe(data: Resource, message: String = "") -> void:
	if not data or not data is FiveParsecsEnemyData:
		push_error("Invalid enemy data object")
		assert_false(true, "Invalid enemy data object: %s" % message)
		return
	
	assert_not_null(data, "Enemy data should not be null: %s" % message)
	assert_true(data is FiveParsecsEnemyData, "Object should be FiveParsecsEnemyData: %s" % message)

func _verify_loot_table_safe(table: Dictionary, category: String, loot: Dictionary, message: String = "") -> void:
	assert_has(table, category, "Loot table should have category '%s': %s" % [category, message])
	if not category in table:
		return
	
	var category_loot: Array = table[category]
	assert_has(category_loot, loot, "Category '%s' should have loot entry: %s" % [category, message])

# Type-safe test cases
func test_enemy_data_initialization() -> void:
	_verify_enemy_data_safe(_enemy_data, "after initialization")
	
	# Verify default values
	assert_eq(_enemy_data.enemy_type, EnemyType.NONE,
		"Enemy type should default to NONE")
	assert_eq(_enemy_data.enemy_category, EnemyCategory.CRIMINAL_ELEMENTS,
		"Enemy category should default to CRIMINAL_ELEMENTS")
	assert_eq(_enemy_data.enemy_behavior, EnemyBehavior.CAUTIOUS,
		"Enemy behavior should default to CAUTIOUS")

func test_enemy_data_stats() -> void:
	_enemy_data = _create_enemy_data_safe(EnemyType.ELITE)
	_verify_enemy_data_safe(_enemy_data, "for stats test")
	
	# Verify base stats
	assert_eq(_enemy_data.get_stat(CharacterStats.COMBAT_SKILL), 1,
		"Elite enemy should have combat skill 1")
	assert_eq(_enemy_data.get_stat(CharacterStats.TOUGHNESS), 4,
		"Elite enemy should have toughness 4")
	
	# Test stat modification
	_enemy_data.set_stat(CharacterStats.COMBAT_SKILL, 2)
	assert_eq(_enemy_data.get_stat(CharacterStats.COMBAT_SKILL), 2,
		"Combat skill should be updated")

func test_enemy_data_weapons() -> void:
	_verify_enemy_data_safe(_enemy_data, "for weapons test")
	
	# Test weapon management
	_enemy_data.add_weapon(_test_weapon)
	var weapons: Array = _enemy_data.get_weapons()
	assert_has(weapons, _test_weapon, "Weapon should be added to enemy data")
	
	_enemy_data.remove_weapon(_test_weapon)
	weapons = _enemy_data.get_weapons()
	assert_does_not_have(weapons, _test_weapon, "Weapon should be removed from enemy data")

func test_enemy_data_characteristics() -> void:
	_verify_enemy_data_safe(_enemy_data, "for characteristics test")
	
	var test_trait := EnemyTrait.ALERT
	
	# Test characteristic management
	_enemy_data.add_characteristic(test_trait)
	assert_true(_enemy_data.has_characteristic(test_trait),
		"Enemy should have added characteristic")
	
	_enemy_data.remove_characteristic(test_trait)
	assert_false(_enemy_data.has_characteristic(test_trait),
		"Enemy should not have removed characteristic")

func test_enemy_data_special_rules() -> void:
	_verify_enemy_data_safe(_enemy_data, "for special rules test")
	
	var test_rule := "TEST_RULE"
	
	# Test special rule management
	_enemy_data.add_special_rule(test_rule)
	var rules: Array = _enemy_data.get_special_rules()
	assert_has(rules, test_rule, "Enemy should have added special rule")
	
	_enemy_data.remove_special_rule(test_rule)
	rules = _enemy_data.get_special_rules()
	assert_does_not_have(rules, test_rule, "Enemy should not have removed special rule")

func test_enemy_data_loot() -> void:
	_verify_enemy_data_safe(_enemy_data, "for loot test")
	
	# Test common loot
	var common_loot: Dictionary = TEST_LOOT_TABLES["Common Loot"]
	_enemy_data.add_loot_reward("Common Loot", common_loot)
	var loot_table: Dictionary = _enemy_data.get_loot_table()
	_verify_loot_table_safe(loot_table, "Common Loot", common_loot,
		"for common loot")
	
	# Test rare loot
	var rare_loot: Dictionary = TEST_LOOT_TABLES["Rare Loot"]
	_enemy_data.add_loot_reward("Rare Loot", rare_loot)
	loot_table = _enemy_data.get_loot_table()
	_verify_loot_table_safe(loot_table, "Rare Loot", rare_loot,
		"for rare loot")
	
	# Test battlefield finds
	var battlefield_loot: Dictionary = TEST_LOOT_TABLES["Battlefield Finds"]
	_enemy_data.add_loot_reward("Battlefield Finds", battlefield_loot)
	loot_table = _enemy_data.get_loot_table()
	_verify_loot_table_safe(loot_table, "Battlefield Finds", battlefield_loot,
		"for battlefield loot")
	
	# Test removing loot
	_enemy_data.remove_loot_reward("Common Loot", common_loot)
	loot_table = _enemy_data.get_loot_table()
	var common_loot_array: Array = loot_table.get("Common Loot", [])
	assert_does_not_have(common_loot_array, common_loot,
		"Loot table should not contain removed reward")

func test_enemy_data_experience() -> void:
	_verify_enemy_data_safe(_enemy_data, "for experience test")
	
	# Test experience value
	assert_eq(_enemy_data.get_experience_value(), 3,
		"Boss enemy should have correct experience value")
	
	_enemy_data.set_experience_value(5)
	assert_eq(_enemy_data.get_experience_value(), 5,
		"Experience value should be updated")

func test_enemy_data_serialization() -> void:
	_verify_enemy_data_safe(_enemy_data, "for serialization test")
	
	# Serialize
	var serialized: Dictionary = _enemy_data.serialize()
	
	# Create new data and deserialize
	var new_data := _create_enemy_data_safe()
	_verify_enemy_data_safe(new_data, "for deserialization test")
	
	new_data.deserialize(serialized)
	
	# Verify serialization preserved all data
	assert_eq(new_data.enemy_type, _enemy_data.enemy_type,
		"Enemy type should be preserved")
	assert_eq(new_data.enemy_category, _enemy_data.enemy_category,
		"Enemy category should be preserved")
	assert_eq(new_data.enemy_behavior, _enemy_data.enemy_behavior,
		"Enemy behavior should be preserved")
	
	var original_weapons: Array = _enemy_data.get_weapons()
	var new_weapons: Array = new_data.get_weapons()
	assert_eq(new_weapons.size(), original_weapons.size(),
		"Weapons should be preserved")
	
	var original_chars: Array = _enemy_data.get_characteristics()
	var new_chars: Array = new_data.get_characteristics()
	assert_eq(new_chars, original_chars,
		"Characteristics should be preserved")
	
	var original_rules: Array = _enemy_data.get_special_rules()
	var new_rules: Array = new_data.get_special_rules()
	assert_eq(new_rules, original_rules,
		"Special rules should be preserved")
	
	var original_loot: Dictionary = _enemy_data.get_loot_table()
	var new_loot: Dictionary = new_data.get_loot_table()
	assert_eq(new_loot, original_loot,
		"Loot table should be preserved")

func test_enemy_data_type_validation() -> void:
	_verify_enemy_data_safe(_enemy_data, "for type validation test")
	
	# Test invalid enemy type
	var invalid_type: int = 999
	_enemy_data.enemy_type = invalid_type
	assert_eq(_enemy_data.enemy_type, EnemyType.NONE,
		"Invalid enemy type should default to NONE")
	
	# Test invalid category
	var invalid_category: int = 999
	_enemy_data.enemy_category = invalid_category
	assert_eq(_enemy_data.enemy_category, EnemyCategory.CRIMINAL_ELEMENTS,
		"Invalid category should default to CRIMINAL_ELEMENTS")
	
	# Test invalid behavior
	var invalid_behavior: int = 999
	_enemy_data.enemy_behavior = invalid_behavior
	assert_eq(_enemy_data.enemy_behavior, EnemyBehavior.CAUTIOUS,
		"Invalid behavior should default to CAUTIOUS")

func test_enemy_data_stat_validation() -> void:
	_verify_enemy_data_safe(_enemy_data, "for stat validation test")
	
	# Test invalid stat type
	var invalid_stat: int = 999
	_enemy_data.set_stat(invalid_stat, 5)
	assert_eq(_enemy_data.get_stat(invalid_stat), 0,
		"Invalid stat type should return default value")
	
	# Test invalid stat value
	_enemy_data.set_stat(CharacterStats.COMBAT_SKILL, -1)
	assert_eq(_enemy_data.get_stat(CharacterStats.COMBAT_SKILL), 0,
		"Invalid stat value should be clamped to valid range")

func test_enemy_data_trait_validation() -> void:
	_verify_enemy_data_safe(_enemy_data, "for trait validation test")
	
	# Test invalid trait
	var invalid_trait: int = 999
	_enemy_data.add_characteristic(invalid_trait)
	assert_false(_enemy_data.has_characteristic(invalid_trait),
		"Invalid trait should not be added")
	
	# Test duplicate trait
	_enemy_data.add_characteristic(EnemyTrait.ALERT)
	_enemy_data.add_characteristic(EnemyTrait.ALERT)
	var traits: Array = _enemy_data.get_characteristics()
	var alert_count := traits.count(EnemyTrait.ALERT)
	assert_eq(alert_count, 1, "Duplicate trait should not be added")

func test_enemy_data_weapon_validation() -> void:
	_verify_enemy_data_safe(_enemy_data, "for weapon validation test")
	
	# Test null weapon
	_enemy_data.add_weapon(null)
	var weapons: Array = _enemy_data.get_weapons()
	assert_eq(weapons.size(), 0, "Null weapon should not be added")
	
	# Test invalid weapon type
	var invalid_weapon := Node.new()
	_enemy_data.add_weapon(invalid_weapon)
	weapons = _enemy_data.get_weapons()
	assert_eq(weapons.size(), 0, "Invalid weapon type should not be added")
	invalid_weapon.free()

func test_enemy_data_loot_validation() -> void:
	_verify_enemy_data_safe(_enemy_data, "for loot validation test")
	
	# Test invalid loot category
	var test_loot: Dictionary = TEST_LOOT_TABLES["Common Loot"]
	_enemy_data.add_loot_reward("Invalid Category", test_loot)
	var loot_table: Dictionary = _enemy_data.get_loot_table()
	assert_false("Invalid Category" in loot_table,
		"Invalid loot category should not be added")
	
	# Test invalid loot data
	var invalid_loot: Dictionary = {
		"invalid_key": "invalid_value"
	}
	_enemy_data.add_loot_reward("Common Loot", invalid_loot)
	loot_table = _enemy_data.get_loot_table()
	var common_loot: Array = loot_table.get("Common Loot", [])
	assert_false(common_loot.has(invalid_loot),
		"Invalid loot data should not be added")

func test_enemy_data_serialization_validation() -> void:
	_verify_enemy_data_safe(_enemy_data, "for serialization validation test")
	
	# Test invalid serialization data
	var invalid_data: Dictionary = {
		"invalid_key": "invalid_value"
	}
	_enemy_data.deserialize(invalid_data)
	assert_eq(_enemy_data.enemy_type, EnemyType.NONE,
		"Invalid serialization data should not affect enemy type")
	
	# Test partial serialization data
	var partial_data: Dictionary = {
		"enemy_type": EnemyType.ELITE
	}
	_enemy_data.deserialize(partial_data)
	assert_eq(_enemy_data.enemy_type, EnemyType.ELITE,
		"Partial serialization should update valid fields")
	assert_eq(_enemy_data.enemy_category, EnemyCategory.CRIMINAL_ELEMENTS,
		"Partial serialization should not affect unspecified fields")