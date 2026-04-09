extends GdUnitTestSuite
## Tests for Equipment System: GameWeapon, GameArmor, GameGear, ConsolidatedArmor, Implants
## Covers 6 NOT_TESTED mechanics from QA_CORE_RULES_TEST_PLAN.md §4
## Core Rules Reference: Weapons (p.40), Armor (p.44), Gear (p.45), Implants (p.132)

const GameWeaponClass := preload("res://src/core/systems/items/GameWeapon.gd")
const GameArmorClass := preload("res://src/core/systems/items/GameArmor.gd")
const GameGearClass := preload("res://src/core/economy/loot/GameGear.gd")
const ConsolidatedArmorClass := preload("res://src/core/character/Equipment/ConsolidatedArmor.gd")
const CharacterClass := preload("res://src/core/character/Character.gd")

# ============================================================================
# GameWeapon Tests (Core Rules p.40)
# ============================================================================

func test_weapon_construction():
	var weapon := GameWeaponClass.new()
	assert_that(weapon).is_not_null()
	assert_that(weapon.weapon_id).is_equal("")

func test_weapon_initialize_from_data():
	var weapon := GameWeaponClass.new()
	var data := {
		"id": "handgun_01",
		"name": "Colony Pistol",
		"category": "Pistol",
		"damage": {"dice": 1, "die_type": 6, "bonus": 0},
		"range": {"short": 6, "medium": 12, "long": 18},
		"traits": ["Light"],
		"cost": {"credits": 50, "rarity": "Common"}
	}
	var result: bool = weapon.initialize_from_data(data)
	assert_that(result).is_true()

func test_weapon_get_damage_string():
	var weapon := GameWeaponClass.new()
	weapon.weapon_damage = {"dice": 2, "die_type": 6, "bonus": 1}
	var dmg_str: String = weapon.get_damage_string()
	assert_that(dmg_str).is_not_empty()

func test_weapon_get_range_string():
	var weapon := GameWeaponClass.new()
	weapon.weapon_range = {"short": 6, "medium": 12, "long": 18}
	var range_str: String = weapon.get_range_string()
	assert_that(range_str).is_not_empty()

func test_weapon_is_melee():
	var weapon := GameWeaponClass.new()
	weapon.weapon_category = "Melee"
	assert_that(weapon.is_melee()).is_true()

func test_weapon_is_ranged():
	var weapon := GameWeaponClass.new()
	weapon.weapon_category = "Pistol"
	assert_that(weapon.is_ranged()).is_true()

func test_weapon_has_trait():
	var weapon := GameWeaponClass.new()
	weapon.weapon_traits = ["Heavy", "Armor_Piercing"]
	assert_that(weapon.has_trait("Heavy")).is_true()
	assert_that(weapon.has_trait("Light")).is_false()

func test_weapon_has_tag():
	var weapon := GameWeaponClass.new()
	weapon.weapon_tags = ["military", "rare"]
	assert_that(weapon.has_tag("military")).is_true()
	assert_that(weapon.has_tag("civilian")).is_false()

func test_weapon_ammo_system():
	var weapon := GameWeaponClass.new()
	weapon.weapon_ammo = {"type": "standard", "capacity": 6, "current": 6}
	assert_that(weapon.get_current_ammo()).is_equal(6)
	assert_that(weapon.get_ammo_capacity()).is_equal(6)

func test_weapon_fire_consumes_ammo():
	var weapon := GameWeaponClass.new()
	weapon.weapon_ammo = {"type": "standard", "capacity": 6, "current": 6}
	weapon.fire(1)
	assert_that(weapon.get_current_ammo()).is_equal(5)

func test_weapon_reload():
	var weapon := GameWeaponClass.new()
	weapon.weapon_ammo = {"type": "standard", "capacity": 6, "current": 2}
	weapon.reload()
	assert_that(weapon.get_current_ammo()).is_equal(6)

func test_weapon_get_cost():
	var weapon := GameWeaponClass.new()
	weapon.weapon_cost = {"credits": 100, "rarity": "Common"}
	assert_that(weapon.get_cost()).is_equal(100)

func test_weapon_serialize_roundtrip():
	var weapon := GameWeaponClass.new()
	weapon.weapon_id = "test_wpn"
	weapon.weapon_name = "Test Weapon"
	weapon.weapon_category = "Rifle"
	weapon.weapon_damage = {"dice": 1, "die_type": 8, "bonus": 0}
	var data: Dictionary = weapon.serialize()
	assert_that(data).is_not_null()
	var weapon2 := GameWeaponClass.new()
	weapon2.deserialize(data)
	assert_that(weapon2.weapon_name).is_equal("Test Weapon")

func test_weapon_get_combat_value():
	var weapon := GameWeaponClass.new()
	weapon.weapon_damage = {"dice": 2, "die_type": 6, "bonus": 1}
	weapon.weapon_range = {"short": 6, "medium": 12, "long": 18}
	var value: int = weapon.get_combat_value()
	assert_that(value).is_greater(0)

func test_weapon_get_weapon_profile():
	var weapon := GameWeaponClass.new()
	weapon.weapon_id = "profile_test"
	weapon.weapon_name = "Profile Gun"
	var profile: Dictionary = weapon.get_weapon_profile()
	assert_that(profile).is_not_null()

# ============================================================================
# GameArmor Tests (Core Rules p.44)
# ============================================================================

func test_armor_construction():
	var armor := GameArmorClass.new()
	assert_that(armor).is_not_null()
	assert_that(armor.armor_id).is_equal("")

func test_armor_initialize_from_data():
	var armor := GameArmorClass.new()
	var data := {
		"id": "flak_armor",
		"name": "Flak Screen",
		"category": "Light",
		"armor_save": 5,
		"encumbrance": 0,
		"coverage": ["torso"],
		"traits": [],
		"cost": {"credits": 30, "rarity": "Common"}
	}
	var result: bool = armor.initialize_from_data(data)
	assert_that(result).is_true()

func test_armor_get_armor_save():
	var armor := GameArmorClass.new()
	armor.armor_save = 5
	assert_that(armor.get_armor_save()).is_equal(5)

func test_armor_covers_location():
	var armor := GameArmorClass.new()
	armor.armor_coverage = ["torso", "arms"]
	assert_that(armor.covers_location("torso")).is_true()
	assert_that(armor.covers_location("legs")).is_false()

func test_armor_has_trait():
	var armor := GameArmorClass.new()
	armor.armor_traits = ["Heavy", "Sealed"]
	assert_that(armor.has_trait("Sealed")).is_true()

func test_armor_is_sealed():
	var armor := GameArmorClass.new()
	armor.armor_traits = ["Sealed"]
	assert_that(armor.is_sealed()).is_true()

func test_armor_is_not_sealed():
	var armor := GameArmorClass.new()
	armor.armor_traits = ["Light"]
	assert_that(armor.is_sealed()).is_false()

func test_armor_get_cost():
	var armor := GameArmorClass.new()
	armor.armor_cost = {"credits": 75, "rarity": "Uncommon"}
	assert_that(armor.get_cost()).is_equal(75)

func test_armor_get_protection_value():
	var armor := GameArmorClass.new()
	armor.armor_save = 5
	var value: int = armor.get_protection_value()
	assert_that(value).is_greater_equal(0)

func test_armor_serialize_roundtrip():
	var armor := GameArmorClass.new()
	armor.armor_id = "test_armor"
	armor.armor_name = "Test Armor"
	armor.armor_save = 4
	var data: Dictionary = armor.serialize()
	assert_that(data).is_not_null()
	var armor2 := GameArmorClass.new()
	armor2.deserialize(data)
	assert_that(armor2.armor_name).is_equal("Test Armor")

func test_armor_get_armor_profile():
	var armor := GameArmorClass.new()
	armor.armor_id = "profile_test"
	armor.armor_name = "Profile Armor"
	var profile: Dictionary = armor.get_armor_profile()
	assert_that(profile).is_not_null()

# ============================================================================
# ConsolidatedArmor Tests (Core Rules p.44)
# ============================================================================

func test_consolidated_armor_construction():
	var armor := ConsolidatedArmorClass.new()
	assert_that(armor).is_not_null()

func test_consolidated_armor_effective_value():
	var armor := ConsolidatedArmorClass.new()
	armor.armor_save = 5
	armor.damage_resistance = 1
	var effective: int = armor.get_effective_armor_value()
	assert_that(effective).is_equal(6)

func test_consolidated_armor_durability():
	var armor := ConsolidatedArmorClass.new()
	armor.durability = 10
	armor.current_durability = 10
	armor.take_damage(3)
	assert_that(armor.current_durability).is_less(10)

func test_consolidated_armor_is_damaged():
	var armor := ConsolidatedArmorClass.new()
	armor.durability = 10
	armor.current_durability = 7
	assert_that(armor.is_damaged()).is_true()

func test_consolidated_armor_is_not_damaged():
	var armor := ConsolidatedArmorClass.new()
	armor.durability = 10
	armor.current_durability = 10
	assert_that(armor.is_damaged()).is_false()

func test_consolidated_armor_repair():
	var armor := ConsolidatedArmorClass.new()
	armor.durability = 10
	armor.current_durability = 5
	armor.repair(3)
	assert_that(armor.current_durability).is_greater(5)

func test_consolidated_armor_is_broken():
	var armor := ConsolidatedArmorClass.new()
	armor.durability = 10
	armor.current_durability = 0
	assert_that(armor.is_broken()).is_true()

func test_consolidated_armor_characteristics():
	var armor := ConsolidatedArmorClass.new()
	armor.add_characteristic(1)
	assert_that(armor.has_characteristic(1)).is_true()
	assert_that(armor.has_characteristic(2)).is_false()

func test_consolidated_armor_remove_characteristic():
	var armor := ConsolidatedArmorClass.new()
	armor.add_characteristic(1)
	armor.remove_characteristic(1)
	assert_that(armor.has_characteristic(1)).is_false()

func test_consolidated_armor_calculate_repair_cost():
	var armor := ConsolidatedArmorClass.new()
	armor.durability = 10
	armor.current_durability = 5
	armor.cost = 100
	var repair_cost: int = armor.calculate_repair_cost()
	assert_that(repair_cost).is_greater_equal(0)

func test_consolidated_armor_serialize_roundtrip():
	var armor := ConsolidatedArmorClass.new()
	armor.armor_id = "test_ca"
	armor.armor_name = "Test Consolidated"
	armor.armor_save = 4
	armor.damage_resistance = 1
	var data: Dictionary = armor.serialize()
	assert_that(data).is_not_null()

# ============================================================================
# GameGear Tests (Core Rules p.45)
# ============================================================================

func test_gear_construction():
	var gear := GameGearClass.new()
	assert_that(gear).is_not_null()
	assert_that(gear.gear_id).is_equal("")

func test_gear_initialize_from_data():
	var gear := GameGearClass.new()
	var data := {
		"id": "medkit_01",
		"name": "Medi-Kit",
		"category": "Medical",
		"description": "Basic medical supplies",
		"effects": [{"type": "heal", "value": 3}],
		"traits": ["Consumable"],
		"cost": {"credits": 25, "rarity": "Common"},
		"tags": ["medical"]
	}
	var result: bool = gear.initialize_from_data(data)
	assert_that(result).is_true()

func test_gear_has_trait():
	var gear := GameGearClass.new()
	gear.gear_traits = ["Consumable", "Medical"]
	assert_that(gear.has_trait("Consumable")).is_true()
	assert_that(gear.has_trait("Weapon")).is_false()

func test_gear_has_tag():
	var gear := GameGearClass.new()
	gear.gear_tags = ["utility", "rare"]
	assert_that(gear.has_tag("utility")).is_true()

func test_gear_get_cost():
	var gear := GameGearClass.new()
	gear.gear_cost = {"credits": 40, "rarity": "Uncommon"}
	assert_that(gear.get_cost()).is_equal(40)

func test_gear_get_effects():
	var gear := GameGearClass.new()
	gear.gear_effects = [{"type": "stat_boost", "stat": "speed", "value": 1}]
	var effects: Array = gear.get_effects()
	assert_that(effects.size()).is_equal(1)

func test_gear_get_value():
	var gear := GameGearClass.new()
	gear.gear_cost = {"credits": 50, "rarity": "Uncommon"}
	gear.gear_effects = [{"type": "stat_boost", "stat": "speed", "value": 1}]
	var value: int = gear.get_value()
	assert_that(value).is_greater(0)

func test_gear_serialize_roundtrip():
	var gear := GameGearClass.new()
	gear.gear_id = "test_gear"
	gear.gear_name = "Test Gear"
	gear.gear_category = "Utility"
	var data: Dictionary = gear.serialize()
	assert_that(data).is_not_null()
	var gear2 := GameGearClass.new()
	gear2.deserialize(data)
	assert_that(gear2.gear_name).is_equal("Test Gear")

func test_gear_get_gear_profile():
	var gear := GameGearClass.new()
	gear.gear_id = "profile_test"
	gear.gear_name = "Profile Gear"
	var profile: Dictionary = gear.get_gear_profile()
	assert_that(profile).is_not_null()

# ============================================================================
# Implant System Tests (Core Rules p.55)
# ============================================================================

func test_character_implants_initially_empty():
	var character := CharacterClass.new()
	assert_that(character.implants.size()).is_equal(0)

func test_character_max_implants_default_is_two():
	# Core Rules p.55: "A character may have up to 2 implants" (standard)
	var character := CharacterClass.new()
	assert_that(character.get_max_implants()).is_equal(2)

func test_character_max_implants_de_converted_is_three():
	# Core Rules p.19: De-converted can have up to 3 implants
	var character := CharacterClass.new()
	character.species_id = "de_converted"
	assert_that(character.get_max_implants()).is_equal(3)

func test_implant_types_has_eleven_entries():
	# Core Rules p.55 lists exactly 11 implants
	# Implants now loaded from JSON (data/implants.json), not a const array
	CharacterClass._ensure_implants_loaded()
	assert_that(CharacterClass._implants_data.size()).is_equal(11)

func test_create_implant_from_type_body_wire():
	var implant: Dictionary = CharacterClass.create_implant_from_type("BODY_WIRE")
	assert_that(implant).is_not_null()
	assert_that(implant.has("name")).is_true()
	assert_that(implant["name"]).is_equal("Body Wire")
	assert_that(implant["stat_bonus"].get("reactions", 0)).is_equal(1)

func test_create_implant_from_type_boosted_leg():
	var implant: Dictionary = CharacterClass.create_implant_from_type("BOOSTED_LEG")
	assert_that(implant).is_not_null()
	assert_that(implant["name"]).is_equal("Boosted Leg")
	assert_that(implant["stat_bonus"].get("speed", 0)).is_equal(1)

func test_create_implant_from_type_ai_companion():
	var implant: Dictionary = CharacterClass.create_implant_from_type("AI_COMPANION")
	assert_that(implant).is_not_null()
	assert_that(implant["name"]).is_equal("AI Companion")

func test_create_implant_from_type_boosted_arm():
	var implant: Dictionary = CharacterClass.create_implant_from_type("BOOSTED_ARM")
	assert_that(implant).is_not_null()
	assert_that(implant["name"]).is_equal("Boosted Arm")

func test_create_implant_from_type_cyber_hand():
	var implant: Dictionary = CharacterClass.create_implant_from_type("CYBER_HAND")
	assert_that(implant).is_not_null()
	assert_that(implant["name"]).is_equal("Cyber Hand")

func test_create_implant_from_type_neural_optimization():
	var implant: Dictionary = CharacterClass.create_implant_from_type("NEURAL_OPTIMIZATION")
	assert_that(implant).is_not_null()
	assert_that(implant["name"]).is_equal("Neural Optimization")

func test_create_implant_from_loot_body_wire():
	var implant: Dictionary = CharacterClass.create_implant_from_loot("Body Wire")
	assert_that(implant).is_not_null()
	assert_that(implant.has("stat_bonus")).is_true()
	assert_that(implant["stat_bonus"].get("reactions", 0)).is_equal(1)

func test_create_implant_from_loot_boosted_arm():
	var implant: Dictionary = CharacterClass.create_implant_from_loot("Boosted Arm")
	assert_that(implant).is_not_null()
	assert_that(implant["name"]).is_equal("Boosted Arm")

func test_create_implant_from_loot_all_eleven():
	# All 11 book implant names should map correctly via LOOT_TO_IMPLANT_MAP
	var loot_names: Array = ["AI Companion", "Body Wire", "Boosted Arm", "Boosted Leg",
		"Cyber Hand", "Genetic Defenses", "Health Boost", "Nerve Adjuster",
		"Neural Optimization", "Night Sight", "Pain Suppressor"]
	for loot_name in loot_names:
		var implant: Dictionary = CharacterClass.create_implant_from_loot(loot_name)
		assert_that(implant.is_empty()).is_false()

func test_add_implant_success():
	var character := CharacterClass.new()
	var implant: Dictionary = CharacterClass.create_implant_from_type("BODY_WIRE")
	var result: bool = character.add_implant(implant)
	assert_that(result).is_true()
	assert_that(character.implants.size()).is_equal(1)

func test_add_implant_max_two():
	# Core Rules p.55: max 2 implants
	var character := CharacterClass.new()
	character.add_implant(CharacterClass.create_implant_from_type("BODY_WIRE"))
	character.add_implant(CharacterClass.create_implant_from_type("BOOSTED_LEG"))
	var third: Dictionary = CharacterClass.create_implant_from_type("NIGHT_SIGHT")
	var result: bool = character.add_implant(third)
	assert_that(result).is_false()
	assert_that(character.implants.size()).is_equal(2)

func test_remove_implant():
	var character := CharacterClass.new()
	character.add_implant(CharacterClass.create_implant_from_type("BODY_WIRE"))
	assert_that(character.implants.size()).is_equal(1)
	character.remove_implant(0)
	assert_that(character.implants.size()).is_equal(0)

func test_get_implant_bonuses():
	var character := CharacterClass.new()
	character.add_implant(CharacterClass.create_implant_from_type("BODY_WIRE"))
	character.add_implant(CharacterClass.create_implant_from_type("BOOSTED_LEG"))
	var bonuses: Dictionary = character.get_implant_bonuses()
	assert_that(bonuses).is_not_null()
	assert_that(bonuses.get("reactions", 0)).is_equal(1)
	assert_that(bonuses.get("speed", 0)).is_equal(1)

func test_get_effective_stat_with_implant():
	var character := CharacterClass.new()
	character.reaction = 2
	character.add_implant(CharacterClass.create_implant_from_type("BODY_WIRE"))
	var effective: int = character.get_effective_stat("reactions")
	assert_that(effective).is_equal(3)

func test_implant_no_duplicate_types():
	"""Cannot add two implants of the same type"""
	var character := CharacterClass.new()
	character.add_implant(CharacterClass.create_implant_from_type("BODY_WIRE"))
	var duplicate: Dictionary = CharacterClass.create_implant_from_type("BODY_WIRE")
	var result: bool = character.add_implant(duplicate)
	assert_that(result).is_false()
	assert_that(character.implants.size()).is_equal(1)
