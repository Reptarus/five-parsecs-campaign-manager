extends GdUnitTestSuite
## Pins the 2026-06-01 canonical character-creation migration.
##
## CharacterGeneration.create_character() (the live in-campaign recruit path via
## CrewTaskComponent) must be book-faithful: Core Rules p.27 baseline + species
## modifiers + canonical D100 table bonuses, NOT the removed fabricated 2D6/3 roll
## or the deleted character_creation_data.json / character_backgrounds.json paths.
## Equipment must land in the canonical Character.equipment Array[String], not the
## fabricated personal_equipment property.

const CharGen = preload("res://src/core/character/CharacterGeneration.gd")


func test_recruit_is_book_faithful() -> void:
	for i in range(15):
		var c = CharGen.create_character({})
		assert_object(c).is_not_null()
		# Five Parsecs baseline floors (Core Rules p.27)
		assert_int(c.reactions).is_greater_equal(1)
		assert_int(c.speed).is_greater_equal(4)
		assert_int(c.toughness).is_greater_equal(3)
		assert_int(c.combat).is_greater_equal(0)
		assert_int(c.savvy).is_greater_equal(0)
		# No fabricated 2D6/3 overflow
		assert_int(c.speed).is_less_equal(10)
		assert_int(c.toughness).is_less_equal(8)
		assert_int(c.combat).is_less_equal(6)
		# Health == Toughness + 2
		assert_int(c.max_health).is_equal(c.toughness + 2)


func test_recruit_equipment_uses_canonical_array() -> void:
	var c = CharGen.create_character({})
	# Canonical sink is Character.equipment: Array[String], not personal_equipment.
	assert_array(c.equipment).is_not_empty()
	for item in c.equipment:
		assert_str(str(item)).is_not_empty()
