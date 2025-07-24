@tool
extends RefCounted
class_name PsionicSystem

## Five Parsecs Psionic System Implementation
##
## Handles psionic powers, projection mechanics, and character abilities
## following Five Parsecs From Home Core Rules.

const Character = preload("res://src/core/character/Character.gd")
const PsionicPower = preload("res://src/game/character/psionics/PsionicPower.gd")
const PsionicCharacter = preload("res://src/game/character/psionics/PsionicCharacter.gd")
const DiceSystem = preload("res://src/core/systems/DiceSystem.gd")

signal psionic_power_used(character: Character, power: PsionicPower, result: bool)

func determine_starting_powers(dice_system: FPCM_DiceSystem = null) -> Array[PsionicPower]:
    var powers: Array[PsionicPower]
    var power_enum_values = PsionicPower.PowerType.values()
    
    # Use provided dice system or create a new one
    var dice: FPCM_DiceSystem = dice_system if dice_system else FPCM_DiceSystem.new()

    for i in range(2):
        var roll = dice.roll_d10("Psionic Power Generation")
        var power_type = power_enum_values[roll - 1] # D10 roll is 1-10, enum is 0-9
        var new_power = PsionicPower.new(power_type)

        # Handle rolling the same power twice
        if powers.has(new_power):
            var original_index = power_enum_values.find(power_type)
            if original_index + 1 < power_enum_values.size():
                power_type = power_enum_values[original_index + 1]
            elif original_index - 1 >= 0:
                power_type = power_enum_values[original_index - 1]
            new_power = PsionicPower.new(power_type)

        powers.append(new_power)
    return powers

func resolve_psionic_projection(psionic_character: PsionicCharacter, power: PsionicPower, target_position: Vector2, target_character: Character = null, dice_system: FPCM_DiceSystem = null) -> bool:
    if not psionic_character.can_use_power(power, target_character):
        return false

    # Use provided dice system or create a new one
    var dice: FPCM_DiceSystem = dice_system if dice_system else FPCM_DiceSystem.new()

    var projection_roll = dice.roll_2d6("Psionic Projection")
    var range_needed = psionic_character.global_position.distance_to(target_position) # Assuming global_position for characters

    var total_range = projection_roll
    var strained = false

    if total_range < range_needed:
        # This would typically involve a UI prompt for the player to decide to strain
        # For scaffolding, we'll assume strain is always attempted if needed
        var strain_roll = dice.roll_d6("Psionic Strain")
        total_range += strain_roll
        strained = true

        # Resolve strain effects (simplified for scaffolding)
        if strain_roll == 4 or strain_roll == 5:
            psionic_character.add_stun_marker() # Assuming a method to add stun markers
            print("Psionic strained and is Stunned.")
        elif strain_roll == 6:
            psionic_character.add_stun_marker()
            print("Psionic strained, is Stunned, and power failed.")
            psionic_power_used.emit(psionic_character, power, false)
            return false

    var success = total_range >= range_needed
    if success:
        # Apply power effects (placeholder)
        print(str("Psionic power ", power.power_type, " used successfully!"))
    else:
        print(str("Psionic power ", power.power_type, " failed to reach target."))

    psionic_power_used.emit(psionic_character, power, success)
    return success

func acquire_psionic_power(psionic_character: PsionicCharacter) -> bool:
    # Logic for acquiring new psionic power with XP
    # This would involve rolling D10 and handling duplicates
    return true

func enhance_psionic_power(psionic_character: PsionicCharacter, power: PsionicPower) -> bool:
    # Logic for enhancing psionic power with XP
    return true
