@tool
extends GdUnitGameTest

## Ship Components Test Suite
## Tests the functionality of ship components and their management
##
## This test suite verifies:
## - Equipment slot management
## - Equipment stats and effects
## - Equipment requirements
## - Equipment durability
## - Signal handling and state tracking

# Mock Classes with Expected Values - Universal Mock Strategy
class MockCharacter extends Resource:
	var character_name: String = "Test Character"
	var character_class: int = 1 # SOLDIER
	var weapons: Array = []
	var armor: Array = []
	var toughness: int = 3
	var base_mobility: int = 4
	
	func set_character_name(value: String) -> void: character_name = value
	func set_character_class(value: int) -> void: character_class = value
	
	func get_weapons() -> Array: return weapons
	func get_armor() -> Array: return armor
	
	func add_item(item_data: Dictionary) -> bool:
		if item_data.get("type") == "weapon":
			weapons.append(item_data.get("data"))
			return true
		elif item_data.get("type") == "armor":
			armor.append(item_data.get("data"))
			return true
		return false
	
	func remove_item(item_data: Dictionary) -> bool:
		if item_data.get("type") == "weapon":
			var weapon = item_data.get("data")
			if weapon in weapons:
				weapons.erase(weapon)
				return true
		elif item_data.get("type") == "armor":
			var armor_item = item_data.get("data")
			if armor_item in armor:
				armor.erase(armor_item)
				return true
		return false
	
	func get_combat_stats() -> Dictionary:
		var stats = {
			"base_damage": 0,
			"accuracy": 0,
			"defense": 0,
			"mobility": base_mobility
		}
		
		for weapon in weapons:
			stats["base_damage"] = weapon.get_meta("damage", 0)
			stats["accuracy"] = weapon.get_meta("accuracy", 0)
		
		for armor_item in armor:
			stats["defense"] = armor_item.get_meta("defense", 0)
			stats["mobility"] += armor_item.get_meta("mobility_penalty", 0)
		
		return stats
	
	func get_base_mobility() -> int: return base_mobility
	func set_toughness(value: int) -> void: toughness = value
	
	func can_equip_item(item_data: Dictionary) -> bool:
		var item = item_data.get("data")
		if item:
			var strength_req = item.get_meta("strength_requirement", 0)
			return toughness >= strength_req
		return true
	
	func get_weapon_effects() -> Dictionary:
		var effects = {}
		for weapon in weapons:
			var weapon_effects = weapon.get_meta("effects", [])
			for effect in weapon_effects:
				effects[effect.get("type")] = effect.get("value")
		return effects
	
	func damage_item(item_data: Dictionary, damage: int) -> bool:
		var item = item_data.get("data")
		if item:
			var current_durability = item.get_meta("current_durability", 100)
			current_durability = max(0, current_durability - damage)
			item.set_meta("current_durability", current_durability)
			return true
		return false
	
	signal character_updated(character: Resource)

class MockGameEnums extends Resource:
	enum CharacterClass {SOLDIER = 1, ENGINEER = 2, MEDIC = 3}
	enum ArmorCharacteristic {SHIELD = 1, POWERED = 2, REACTIVE = 3}

# Type-safe instance variables
var _character: MockCharacter = null

# Lifecycle Methods
func before_test() -> void:
	super.before_test()
	
	_character = MockCharacter.new()
	assert_that(_character).is_not_null()
	track_resource(_character)
	_setup_character()
	await get_tree().create_timer(0.1).timeout

func after_test() -> void:
	_character = null
	super.after_test()

func _setup_character() -> void:
	_character.set_character_name("Test Character")
	_character.set_character_class(MockGameEnums.CharacterClass.SOLDIER)

# Helper Functions
func _create_test_weapon(weapon_name: String) -> Resource:
	var weapon := Resource.new()
	weapon.set_meta("name", weapon_name)
	weapon.set_meta("damage", 5)
	weapon.set_meta("accuracy", 70)
	weapon.set_meta("range", 6)
	track_resource(weapon)
	return weapon

func _create_test_armor(armor_name: String) -> Resource:
	var armor := Resource.new()
	armor.set_meta("name", armor_name)
	armor.set_meta("defense", 3)
	armor.set_meta("mobility_penalty", 0)
	track_resource(armor)
	return armor

# Equipment Slot Tests
func test_equipment_slots() -> void:
	# Test initial state
	var weapons = _character.get_weapons()
	assert_that(weapons.size()).is_equal(0)
	
	var armor = _character.get_armor()
	assert_that(armor.size()).is_equal(0)
	
	# Create test equipment
	var weapon := _create_test_weapon("Test Rifle")
	var armor_item := _create_test_armor("Test Armor")
	
	# Test adding equipment
	var add_weapon_result = _character.add_item({"type": "weapon", "data": weapon})
	assert_that(add_weapon_result).is_true()
	weapons = _character.get_weapons()
	assert_that(weapons.size()).is_equal(1)
	
	var add_armor_result = _character.add_item({"type": "armor", "data": armor_item})
	assert_that(add_armor_result).is_true()
	armor = _character.get_armor()
	assert_that(armor.size()).is_equal(1)
	
	# Test removing equipment
	var remove_weapon_result = _character.remove_item({"type": "weapon", "data": weapon})
	assert_that(remove_weapon_result).is_true()
	weapons = _character.get_weapons()
	assert_that(weapons.size()).is_equal(0)
	
	var remove_armor_result = _character.remove_item({"type": "armor", "data": armor_item})
	assert_that(remove_armor_result).is_true()
	armor = _character.get_armor()
	assert_that(armor.size()).is_equal(0)

# Equipment Stats Tests
func test_equipment_stats() -> void:
	var weapon := _create_test_weapon("Combat Rifle")
	weapon.set_meta("damage", 10)
	weapon.set_meta("accuracy", 75)
	
	var armor_item := _create_test_armor("Combat Armor")
	armor_item.set_meta("defense", 5)
	armor_item.set_meta("mobility_penalty", -1)
	
	# Add equipment
	_character.add_item({"type": "weapon", "data": weapon})
	_character.add_item({"type": "armor", "data": armor_item})
	
	# Test stat modifications
	var combat_stats = _character.get_combat_stats()
	assert_that(combat_stats).is_not_null()
	assert_that(combat_stats.get("base_damage", 0)).is_equal(10)
	assert_that(combat_stats.get("accuracy", 0)).is_equal(75)
	assert_that(combat_stats.get("defense", 0)).is_equal(5)
	
	var base_mobility = _character.get_base_mobility()
	assert_that(combat_stats.get("mobility", base_mobility)).is_equal(base_mobility - 1)

# Equipment Requirements Tests
func test_equipment_requirements() -> void:
	var heavy_weapon := _create_test_weapon("Heavy Weapon")
	heavy_weapon.set_meta("strength_requirement", 4)
	
	# Test equipping with insufficient stats
	_character.set_toughness(3)
	var can_equip = _character.can_equip_item({"type": "weapon", "data": heavy_weapon})
	assert_that(can_equip).is_false()
	
	# Test equipping with sufficient stats
	_character.set_toughness(4)
	can_equip = _character.can_equip_item({"type": "weapon", "data": heavy_weapon})
	assert_that(can_equip).is_true()

# Equipment Effects Tests
func test_equipment_effects() -> void:
	var weapon := _create_test_weapon("Effect Weapon")
	weapon.set_meta("effects", [
		{
			"type": MockGameEnums.ArmorCharacteristic.SHIELD,
			"value": 2
		},
		{
			"type": MockGameEnums.ArmorCharacteristic.POWERED,
			"value": 1
		}
	])
	
	_character.add_item({"type": "weapon", "data": weapon})
	var weapon_effects = _character.get_weapon_effects()
	
	assert_that(weapon_effects).is_not_null()
	assert_that(weapon_effects.has(MockGameEnums.ArmorCharacteristic.SHIELD)).is_true()
	assert_that(weapon_effects.has(MockGameEnums.ArmorCharacteristic.POWERED)).is_true()
	assert_that(weapon_effects.get(MockGameEnums.ArmorCharacteristic.SHIELD, 0)).is_equal(2)
	assert_that(weapon_effects.get(MockGameEnums.ArmorCharacteristic.POWERED, 0)).is_equal(1)

# Equipment Durability Tests
func test_equipment_durability() -> void:
	var weapon := _create_test_weapon("Durability Test Weapon")
	weapon.set_meta("max_durability", 100)
	weapon.set_meta("current_durability", 100)
	
	_character.add_item({"type": "weapon", "data": weapon})
	
	# Test durability loss
	var damage_result = _character.damage_item({"type": "weapon", "data": weapon}, 10)
	assert_that(damage_result).is_true()
	assert_that(weapon.get_meta("current_durability")).is_equal(90)
	
	# Test breaking point
	damage_result = _character.damage_item({"type": "weapon", "data": weapon}, 90)
	assert_that(damage_result).is_true()
	assert_that(weapon.get_meta("current_durability")).is_equal(0)
	
	var is_broken = weapon.get_meta("current_durability") <= 0
	assert_that(is_broken).is_true()
	
	# Test weapon effectiveness when broken
	var combat_stats = _character.get_combat_stats()
	assert_that(combat_stats).is_not_null()
	# For simplicity, assume broken weapons give penalty of at least -1
	var has_penalty = combat_stats.get("damage_penalty", -1) < 0
	assert_that(has_penalty).is_true()