# SkulkerSpecies.gd
class_name SkulkerSpecies extends Resource

func _init():
    pass

func apply_species_traits(character: Character) -> void:
    # Skulker special rules implementation
    # During character creation, any table result of 1D6 Credits grants only 1D3 Credits instead.
    # This would be handled in the character creation process, not here.

    # During character creation, ignore the first instance in which the Skulker rolls a Rival.
    # This would be handled in the character creation process, not here.

    # Due to their agility, Skulkers do not suffer movement reductions due to difficult ground
    character.add_special_ability("ignore_difficult_ground")

    # Can use all armor and equipment designed for playable species without significant adaptation
    character.add_special_ability("flexible_armor_use")

    # When moving, they may ignore any obstacle up to 1” in height and do not count the first 1” of any climb
    character.add_special_ability("agile_movement")

    # Strong biological resistance
    character.add_special_ability("biological_resistance")

    # Respond extremely well to genetic immunization therapies (handled by other systems)