@tool
extends Character
class_name PsionicCharacter

## Five Parsecs Psionic Character Implementation
##
## Extends the base Character class with psionic abilities and restrictions
## following Five Parsecs From Home Core Rules.

const PsionicPower = preload("res://src/game/character/psionics/PsionicPower.gd")

@export var psionic_powers: Array[PsionicPower]

func _init():
    super._init()
    # Psionics cannot increase Combat Skill through Experience Points
    add_trait("Combat Skill Cap")
    # Psionics can only ever use weapons that have either the Pistol or Melee traits.
    add_trait("Psionic Weapon Restriction")
    # Psionics lose their abilities permanently if they are given any type of implant
    add_trait("Implant Vulnerability")

func add_power(power: PsionicPower):
    psionic_powers.append(power)

func use_power(power: PsionicPower, target_position: Vector2) -> bool:
    # Placeholder for power usage logic
    # This would involve a Projection roll, range check, and strain mechanics
    return true

func can_use_power(power: PsionicPower, target_character: Character = null) -> bool:
    # Check if the power can affect the target (e.g., robotic targets)
    if target_character and not power.affects_robotic_targets:
        # Check if target_character is robotic using trait system
        if target_character.has_trait("Robotic") or target_character.has_trait("Bot"):
            return false
    return true

## Add stun marker for psionic strain effects
func add_stun_marker() -> void:
    add_trait("Stunned")
    # Apply stunned status effect
    apply_status_effect({
        "id": "stunned",
        "type": "debuff",
        "duration": 1,
        "effects": {
            "actions": - 1
        }
    })
