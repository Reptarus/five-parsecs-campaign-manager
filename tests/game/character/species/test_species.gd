
# tests/game/character/species/test_species.gd
extends GutTest

const KragSpecies = preload("res://src/game/character/species/KragSpecies.gd")
const SkulkerSpecies = preload("res://src/game/character/species/SkulkerSpecies.gd")
const Character = preload("res://src/core/character/Base/Character.gd") # Assuming base Character class

var mock_character: Character

func before_each():
    mock_character = Character.new()
    # Mock necessary methods if Character is not fully implemented for testing
    mock_character.set_script(null) # Remove script to avoid errors if Character has _ready or other methods
    mock_character.add_patron = funcref(self, "_mock_add_patron")
    mock_character.has_patron = funcref(self, "_mock_has_patron")
    mock_character.add_rival = funcref(self, "_mock_add_rival")
    mock_character.add_special_ability = funcref(self, "_mock_add_special_ability")

func _mock_add_patron():
    pass # Mock implementation

func _mock_has_patron() -> bool:
    return true # For testing rival addition

func _mock_add_rival():
    mock_character.rival_added = true # Simple flag for testing

func _mock_add_special_ability(ability_name: String):
    if not mock_character.has_node("special_abilities"):
        mock_character.add_child(Node.new())
        mock_character.get_node("Node").name = "special_abilities"
    mock_character.get_node("special_abilities").set_meta(ability_name, true)


func test_krag_species_apply_traits():
    var krag_species = KragSpecies.new()
    krag_species.apply_species_traits(mock_character)

    assert_false(mock_character.can_dash, "Krag should not be able to dash")
    assert_true(mock_character.get_node("special_abilities").get_meta("belligerent_reroll"), "Krag should have belligerent_reroll ability")
    assert_true(mock_character.rival_added, "Krag should add a rival if has patron")

func test_skulker_species_apply_traits():
    var skulker_species = SkulkerSpecies.new()
    skulker_species.apply_species_traits(mock_character)

    assert_true(mock_character.get_node("special_abilities").get_meta("ignore_difficult_ground"), "Skulker should ignore difficult ground")
    assert_true(mock_character.get_node("special_abilities").get_meta("flexible_armor_use"), "Skulker should have flexible_armor_use ability")
    assert_true(mock_character.get_node("special_abilities").get_meta("agile_movement"), "Skulker should have agile_movement ability")
    assert_true(mock_character.get_node("special_abilities").get_meta("biological_resistance"), "Skulker should have biological_resistance ability")

# Add tests for Updated Primary Alien Table, Krag Colony Worlds, Skulker Colony Worlds
# These would likely involve mocking GameDataManager or other systems that handle world generation and data tables.
# Example (conceptual):
# func test_updated_primary_alien_table():
#     var game_data_manager_mock = mock("res://src/core/data/GameDataManager.gd").make_double()
#     game_data_manager_mock.get_character_creation_data.returns({"alien_table": [KragSpecies, SkulkerSpecies, ...]})
#     # Then test that character generation uses this updated table
#     assert_true(true, "Placeholder for alien table test")

# func test_krag_colony_world_traits():
#     # Mock world generation and check for specific traits
#     assert_true(true, "Placeholder for Krag colony world traits test")

# func test_skulker_colony_world_traits():
#     # Mock world generation and check for specific traits
#     assert_true(true, "Placeholder for Skulker colony world traits test")
