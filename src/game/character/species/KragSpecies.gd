# KragSpecies.gd
class_name KragSpecies extends Resource

func _init():
    pass

func apply_species_traits(character: Character) -> void:
    # Krag special rules implementation
    character.can_dash = false  # Cannot take Dash moves
    character.add_special_ability("belligerent_reroll") # Custom ability for rerolling 1s against Rivals
    # If character has patron, add a rival (simplified for scaffolding)
    # This logic would typically be in a character creation manager
    if character.has_patron():
        character.add_rival()

    # Campaign considerations (armor, etc.) would be handled by other systems
    # or in a dedicated character manager.