@tool
extends GameTest

## Ship Components Test Suite
## Tests the functionality of ship components and their management
##
## This test suite verifies:
## - Equipment slot management
## - Equipment stats and effects
## - Equipment requirements
## - Equipment durability
## - Signal handling and state tracking

# Type-safe script references
const Character: GDScript = preload("res://src/core/character/Base/Character.gd")

# Type-safe instance variables
var _character: Node = null

# Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	
	var character_instance: Node = Character.new()
	_character = character_instance
	if not _character:
		push_error("Failed to create character")
		return
	add_child_autofree(_character)
	track_test_node(_character)
	_setup_character()
	watch_signals(_character)
	await stabilize_engine(STABILIZE_TIME)

func after_each() -> void:
	_character = null
	await super.after_each()

func _setup_character() -> void:
	if not _character:
		push_error("Cannot setup character: character is null")
		return
	
	TypeSafeMixin._call_node_method_bool(_character, "set_character_name", ["Test Character"])
	TypeSafeMixin._call_node_method_bool(_character, "set_character_class", [GameEnums.CharacterClass.SOLDIER])

# Helper Functions
func _create_test_weapon(weapon_name: String) -> Resource:
	var weapon := Resource.new()
	weapon.set_meta("name", weapon_name)
	weapon.set_meta("damage", 5)
	weapon.set_meta("accuracy", 70)
	weapon.set_meta("range", 6)
	track_test_resource(weapon)
	return weapon

func _create_test_armor(armor_name: String) -> Resource:
	var armor := Resource.new()
	armor.set_meta("name", armor_name)
	armor.set_meta("defense", 3)
	armor.set_meta("mobility_penalty", 0)
	track_test_resource(armor)
	return armor

# Equipment Slot Tests
func test_equipment_slots() -> void:
	# Test initial state
	var weapons: Array = TypeSafeMixin._call_node_method_array(_character, "get_weapons", [])
	assert_eq(weapons.size(), 0, "Initial weapons array should be empty")
	
	var armor: Array = TypeSafeMixin._call_node_method_array(_character, "get_armor", [])
	assert_eq(armor.size(), 0, "Initial armor array should be empty")
	
	# Create test equipment
	var weapon := _create_test_weapon("Test Rifle")
	var armor_item := _create_test_armor("Test Armor")
	
	# Test adding equipment
	var add_weapon_result: bool = TypeSafeMixin._call_node_method_bool(_character, "add_item", [ {"type": "weapon", "data": weapon}])
	assert_true(add_weapon_result, "Should add weapon successfully")
	weapons = TypeSafeMixin._call_node_method_array(_character, "get_weapons", [])
	assert_eq(weapons.size(), 1, "Should have one weapon equipped")
	
	var add_armor_result: bool = TypeSafeMixin._call_node_method_bool(_character, "add_item", [ {"type": "armor", "data": armor_item}])
	assert_true(add_armor_result, "Should add armor successfully")
	armor = TypeSafeMixin._call_node_method_array(_character, "get_armor", [])
	assert_eq(armor.size(), 1, "Should have one armor equipped")
	
	# Test removing equipment
	var remove_weapon_result: bool = TypeSafeMixin._call_node_method_bool(_character, "remove_item", [ {"type": "weapon", "data": weapon}])
	assert_true(remove_weapon_result, "Should remove weapon successfully")
	weapons = TypeSafeMixin._call_node_method_array(_character, "get_weapons", [])
	assert_eq(weapons.size(), 0, "Weapons array should be empty after removal")
	
	var remove_armor_result: bool = TypeSafeMixin._call_node_method_bool(_character, "remove_item", [ {"type": "armor", "data": armor_item}])
	assert_true(remove_armor_result, "Should remove armor successfully")
	armor = TypeSafeMixin._call_node_method_array(_character, "get_armor", [])
	assert_eq(armor.size(), 0, "Armor array should be empty after removal")

# Equipment Stats Tests
func test_equipment_stats() -> void:
	var weapon := _create_test_weapon("Combat Rifle")
	weapon.set_meta("damage", 10)
	weapon.set_meta("accuracy", 75)
	
	var armor_item := _create_test_armor("Combat Armor")
	armor_item.set_meta("defense", 5)
	armor_item.set_meta("mobility_penalty", -1)
	
	# Add equipment
	TypeSafeMixin._call_node_method_bool(_character, "add_item", [ {"type": "weapon", "data": weapon}])
	TypeSafeMixin._call_node_method_bool(_character, "add_item", [ {"type": "armor", "data": armor_item}])
	
	# Test stat modifications
	var combat_stats: Dictionary = TypeSafeMixin._call_node_method_dict(_character, "get_combat_stats", [])
	assert_not_null(combat_stats, "Combat stats should not be null")
	assert_eq(combat_stats.base_damage, 10, "Base damage should match weapon damage")
	assert_eq(combat_stats.accuracy, 75, "Accuracy should match weapon accuracy")
	assert_eq(combat_stats.defense, 5, "Defense should match armor defense")
	
	var base_mobility: int = TypeSafeMixin._call_node_method_int(_character, "get_base_mobility", [])
	assert_eq(combat_stats.mobility, base_mobility - 1, "Mobility should be base + penalty")

# Equipment Requirements Tests
func test_equipment_requirements() -> void:
	var heavy_weapon := _create_test_weapon("Heavy Weapon")
	heavy_weapon.set_meta("strength_requirement", 4)
	
	# Test equipping with insufficient stats
	TypeSafeMixin._call_node_method_bool(_character, "set_toughness", [3])
	var can_equip: bool = TypeSafeMixin._call_node_method_bool(_character, "can_equip_item", [ {"type": "weapon", "data": heavy_weapon}])
	assert_false(can_equip, "Should not be able to equip with insufficient stats")
	
	# Test equipping with sufficient stats
	TypeSafeMixin._call_node_method_bool(_character, "set_toughness", [4])
	can_equip = TypeSafeMixin._call_node_method_bool(_character, "can_equip_item", [ {"type": "weapon", "data": heavy_weapon}])
	assert_true(can_equip, "Should be able to equip with sufficient stats")

# Equipment Effects Tests
func test_equipment_effects() -> void:
	var weapon := _create_test_weapon("Effect Weapon")
	weapon.set_meta("effects", [
		{
			"type": GameEnums.ArmorCharacteristic.SHIELD,
			"value": 2
		},
		{
			"type": GameEnums.ArmorCharacteristic.POWERED,
			"value": 1
		}
	])
	
	TypeSafeMixin._call_node_method_bool(_character, "add_item", [ {"type": "weapon", "data": weapon}])
	var weapon_effects: Dictionary = TypeSafeMixin._call_node_method_dict(_character, "get_weapon_effects", [])
	
	assert_not_null(weapon_effects, "Weapon effects should not be null")
	assert_true(weapon_effects.has(GameEnums.ArmorCharacteristic.SHIELD), "Should have shield effect")
	assert_true(weapon_effects.has(GameEnums.ArmorCharacteristic.POWERED), "Should have powered effect")
	assert_eq(weapon_effects[GameEnums.ArmorCharacteristic.SHIELD], 2, "Shield effect should have correct value")
	assert_eq(weapon_effects[GameEnums.ArmorCharacteristic.POWERED], 1, "Powered effect should have correct value")

# Equipment Durability Tests
func test_equipment_durability() -> void:
	var weapon := _create_test_weapon("Durability Test Weapon")
	weapon.set_meta("max_durability", 100)
	weapon.set_meta("current_durability", 100)
	
	TypeSafeMixin._call_node_method_bool(_character, "add_item", [ {"type": "weapon", "data": weapon}])
	
	# Test durability loss
	var damage_result: bool = TypeSafeMixin._call_node_method_bool(_character, "damage_item", [ {"type": "weapon", "data": weapon}, 10])
	assert_true(damage_result, "Should damage item successfully")
	assert_eq(weapon.get_meta("current_durability"), 90, "Durability should decrease by damage amount")
	
	# Test breaking point
	damage_result = TypeSafeMixin._call_node_method_bool(_character, "damage_item", [ {"type": "weapon", "data": weapon}, 90])
	assert_true(damage_result, "Should damage item successfully")
	assert_eq(weapon.get_meta("current_durability"), 0, "Durability should not go below 0")
	
	var is_broken: bool = TypeSafeMixin._call_node_method_bool(weapon, "is_broken", [])
	assert_true(is_broken, "Weapon should be broken at 0 durability")
	
	# Test weapon effectiveness when broken
	var combat_stats: Dictionary = TypeSafeMixin._call_node_method_dict(_character, "get_combat_stats", [])
	assert_not_null(combat_stats, "Combat stats should not be null")
	assert_true(combat_stats.damage_penalty < 0, "Broken weapon should apply damage penalty")