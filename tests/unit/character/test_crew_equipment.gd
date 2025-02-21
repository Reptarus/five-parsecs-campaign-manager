@tool
extends GameTest

const FiveParsecsCharacter = preload("res://src/core/character/Base/Character.gd")

var _character: FiveParsecsCharacter

func before_each() -> void:
	await super.before_each()
	_character = FiveParsecsCharacter.new()
	track_test_resource(_character)
	_setup_character()

func after_each() -> void:
	_character = null
	await super.after_each()

func _setup_character() -> void:
	if not _character:
		return
		
	_set_character_property("character_name", "Test Character")
	_set_character_property("character_class", GameEnums.CharacterClass.SOLDIER)

## Safe Property Access Methods
func _get_character_property(property: String, default_value = null) -> Variant:
	if not _character:
		push_error("Trying to access property '%s' on null character" % property)
		return default_value
	if not property in _character:
		push_error("Character missing required property: %s" % property)
		return default_value
	return _character.get(property)

func _set_character_property(property: String, value: Variant) -> void:
	if not _character:
		push_error("Trying to set property '%s' on null character" % property)
		return
	if not property in _character:
		push_error("Character missing required property: %s" % property)
		return
	_character.set(property, value)

func _get_equipment_array(type: String) -> Array:
	match type:
		"weapon":
			return _get_character_property("weapons", [])
		"armor":
			return _get_character_property("armor", [])
		_:
			push_error("Invalid equipment type: %s" % type)
			return []

func test_equipment_slots() -> void:
	# Test initial state
	assert_eq(_get_equipment_array("weapon").size(), 0, "Initial weapons array should be empty")
	assert_eq(_get_equipment_array("armor").size(), 0, "Initial armor array should be empty")
	
	# Create test equipment
	var weapon = _create_test_weapon("Test Rifle")
	var armor = _create_test_armor("Test Armor")
	
	# Test adding equipment
	_character.add_item({"type": "weapon", "data": weapon})
	assert_eq(_get_equipment_array("weapon").size(), 1, "Should have one weapon equipped")
	
	_character.add_item({"type": "armor", "data": armor})
	assert_eq(_get_equipment_array("armor").size(), 1, "Should have one armor equipped")
	
	# Test removing equipment
	_character.remove_item({"type": "weapon", "data": weapon})
	assert_eq(_get_equipment_array("weapon").size(), 0, "Weapons array should be empty after removal")
	
	_character.remove_item({"type": "armor", "data": armor})
	assert_eq(_get_equipment_array("armor").size(), 0, "Armor array should be empty after removal")

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
	assert_not_null(combat_stats, "Combat stats should not be null")
	assert_eq(combat_stats.base_damage, weapon.damage, "Base damage should match weapon damage")
	assert_eq(combat_stats.accuracy, weapon.accuracy, "Accuracy should match weapon accuracy")
	assert_eq(combat_stats.defense, armor.defense, "Defense should match armor defense")
	
	var base_mobility = _get_character_property("base_mobility", 0)
	assert_eq(combat_stats.mobility, base_mobility + armor.mobility_penalty, "Mobility should be base + penalty")

func test_equipment_requirements() -> void:
	var heavy_weapon = _create_test_weapon("Heavy Weapon")
	heavy_weapon.strength_requirement = 4
	
	# Test equipping with insufficient stats
	_set_character_property("toughness", 3)
	var can_equip = _character.can_equip_item({"type": "weapon", "data": heavy_weapon})
	assert_false(can_equip, "Should not be able to equip with insufficient stats")
	
	# Test equipping with sufficient stats
	_set_character_property("toughness", 4)
	can_equip = _character.can_equip_item({"type": "weapon", "data": heavy_weapon})
	assert_true(can_equip, "Should be able to equip with sufficient stats")

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
	
	assert_not_null(weapon_effects, "Weapon effects should not be null")
	assert_true(weapon_effects.has(GameEnums.ArmorCharacteristic.SHIELD), "Should have shield effect")
	assert_true(weapon_effects.has(GameEnums.ArmorCharacteristic.POWERED), "Should have powered effect")
	assert_eq(weapon_effects[GameEnums.ArmorCharacteristic.SHIELD], 2, "Shield effect should have correct value")
	assert_eq(weapon_effects[GameEnums.ArmorCharacteristic.POWERED], 1, "Powered effect should have correct value")

func test_equipment_durability() -> void:
	var weapon = _create_test_weapon("Durability Test Weapon")
	weapon.max_durability = 100
	weapon.current_durability = 100
	
	_character.add_item({"type": "weapon", "data": weapon})
	
	# Test durability loss
	_character.damage_item({"type": "weapon", "data": weapon}, 10)
	assert_eq(weapon.current_durability, 90, "Durability should decrease by damage amount")
	
	# Test breaking point
	_character.damage_item({"type": "weapon", "data": weapon}, 90)
	assert_eq(weapon.current_durability, 0, "Durability should not go below 0")
	assert_true(weapon.is_broken(), "Weapon should be broken at 0 durability")
	
	# Test weapon effectiveness when broken
	var combat_stats = _character.get_combat_stats()
	assert_not_null(combat_stats, "Combat stats should not be null")
	assert_true(combat_stats.damage_penalty < 0, "Broken weapon should apply damage penalty")

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