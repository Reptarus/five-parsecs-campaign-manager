extends GdUnitTestSuite
## Implant system on the LIVE Character resource (Core Rules p.55, p.19, p.132).
##
## These 21 cases were extracted from tests/unit/test_equipment_classes.gd on
## 2026-09-04. That suite's other 46 cases drove GameWeapon / GameArmor / GameGear /
## ConsolidatedArmor — a Resource-based item model the app abandoned for the
## Dictionary model owned by EquipmentTransferService, and all four were deleted as
## production-dead. The implant block never belonged to that model: it exercises
## src/core/character/Character.gd (the canonical class), which is very much live.
## Splitting it out is what kept this coverage when the equipment suite went.

const CharacterClass := preload("res://src/core/character/Character.gd")

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

func test_character_max_implants_bio_upgrade_is_four():
	# Core Rules p.23: Bio-upgrade may have up to 4 implants
	var character := CharacterClass.new()
	character.species_id = "bio_upgrade"
	assert_that(character.get_max_implants()).is_equal(4)

func test_character_max_implants_empath_is_zero():
	# Core Rules p.23: Empath cannot be given implants without losing ability
	var character := CharacterClass.new()
	character.species_id = "empath"
	assert_that(character.get_max_implants()).is_equal(0)

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
