@tool
extends "res://tests/fixtures/base_test.gd"

const Character = preload("res://src/core/character/Base/Character.gd")

var _character: FiveParsecsCharacter

func before_each() -> void:
	await super.before_each()
	_character = FiveParsecsCharacter.new()
	_character.character_name = "Test Character"
	_character.character_class = GameEnums.CharacterClass.SOLDIER

func after_each() -> void:
	await super.after_each()
	_character = null

func test_equipment_slots() -> void:
	# Test initial state
	assert_eq(_character.weapons.size(), 0)
	assert_eq(_character.armor.size(), 0)
	
	# Create test equipment
	var weapon = _create_test_weapon("Test Rifle")
	var armor = _create_test_armor("Test Armor")
	
	# Test adding equipment
	_character.add_item({"type": "weapon", "data": weapon})
	assert_eq(_character.weapons.size(), 1)
	
	_character.add_item({"type": "armor", "data": armor})
	assert_eq(_character.armor.size(), 1)
	
	# Test removing equipment
	_character.remove_item({"type": "weapon", "data": weapon})
	assert_eq(_character.weapons.size(), 0)
	
	_character.remove_item({"type": "armor", "data": armor})
	assert_eq(_character.armor.size(), 0)

func test_equipment_stats() -> void:
	var weapon = _create_test_weapon("Combat Rifle")
	weapon.damage = 10
	weapon.accuracy = 75
	
	var armor = _create_test_armor("Combat Armor")
	armor.defense = 5
	armor.mobility_penalty = -1
	
	# Add equipment
	_character.add_item({"type": "weapon", "data": weapon})
	_character.add_item({"type": "armor", "data": armor})
	
	# Test stat modifications
	var combat_stats = _character.get_combat_stats()
	assert_eq(combat_stats.base_damage, weapon.damage)
	assert_eq(combat_stats.accuracy, weapon.accuracy)
	assert_eq(combat_stats.defense, armor.defense)
	assert_eq(combat_stats.mobility, _character.base_mobility + armor.mobility_penalty)

func test_equipment_requirements() -> void:
	var heavy_weapon = _create_test_weapon("Heavy Weapon")
	heavy_weapon.strength_requirement = 4
	
	# Test equipping with insufficient stats
	_character.toughness = 3
	var can_equip = _character.can_equip_item({"type": "weapon", "data": heavy_weapon})
	assert_false(can_equip)
	
	# Test equipping with sufficient stats
	_character.toughness = 4
	can_equip = _character.can_equip_item({"type": "weapon", "data": heavy_weapon})
	assert_true(can_equip)

func test_equipment_effects() -> void:
	var weapon = _create_test_weapon("Effect Weapon")
	weapon.effects = [
		{
			"type": GameEnums.ArmorCharacteristic.SHIELD,
			"value": 2
		},
		{
			"type": GameEnums.ArmorCharacteristic.POWERED,
			"value": 1
		}
	]
	
	_character.add_item({"type": "weapon", "data": weapon})
	var weapon_effects = _character.get_weapon_effects()
	
	assert_true(weapon_effects.has(GameEnums.ArmorCharacteristic.SHIELD))
	assert_true(weapon_effects.has(GameEnums.ArmorCharacteristic.POWERED))
	assert_eq(weapon_effects[GameEnums.ArmorCharacteristic.SHIELD], 2)
	assert_eq(weapon_effects[GameEnums.ArmorCharacteristic.POWERED], 1)

func test_equipment_durability() -> void:
	var weapon = _create_test_weapon("Durability Test Weapon")
	weapon.max_durability = 100
	weapon.current_durability = 100
	
	_character.add_item({"type": "weapon", "data": weapon})
	
	# Test durability loss
	_character.damage_item({"type": "weapon", "data": weapon}, 10)
	assert_eq(weapon.current_durability, 90)
	
	# Test breaking point
	_character.damage_item({"type": "weapon", "data": weapon}, 90)
	assert_eq(weapon.current_durability, 0)
	assert_true(weapon.is_broken())
	
	# Test weapon effectiveness when broken
	var combat_stats = _character.get_combat_stats()
	assert_true(combat_stats.damage_penalty < 0)

# Helper function to create test weapons
func _create_test_weapon(weapon_name: String) -> Resource:
	var weapon = Resource.new()
	weapon.set_meta("name", weapon_name)
	weapon.set_meta("damage", 5)
	weapon.set_meta("accuracy", 70)
	weapon.set_meta("range", 6)
	return weapon

# Helper function to create test armor
func _create_test_armor(armor_name: String) -> Resource:
	var armor = Resource.new()
	armor.set_meta("name", armor_name)
	armor.set_meta("defense", 3)
	armor.set_meta("mobility_penalty", 0)
	return armor