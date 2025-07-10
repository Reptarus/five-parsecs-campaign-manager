class_name FPCM_CharacterStats
extends "res://src/core/character/Base/CharacterStats.gd"

## Game-specific character stats implementation
##
## Extends the core character stats with game-specific 
## functionality for the Five Parsecs From Home implementation.

# Game-specific properties
var morale_bonus: int = 0
var leadership_bonus: int = 0
var xp_multiplier: float = 1.0

func _init() -> void:
	super._init()

## Calculate bonus health based on game-specific rules

func calculate_bonus_health() -> int:
	var bonus: int = 0
	if morale_bonus > 0:
		bonus += morale_bonus
	if leadership_bonus > 0:
		bonus += leadership_bonus
	return bonus

## Override get_effective_stat to include game-specific bonuses
func get_effective_stat(stat_name: String) -> int:
	var base_value = super.get_effective_stat(stat_name)

	# Add game-specific bonuses
	if stat_name == "toughness" and morale_bonus > 0:
		base_value += 1

	return base_value

## Game-specific method to apply experience with multiplier
func add_experience(amount: int) -> void:
	# Apply experience with the game-specific multiplier
	var adjusted_amount = int(amount * xp_multiplier)

	# Track experience in this class if parent doesn't have the method
	print("Adding %d experience (adjusted from %d)" % [adjusted_amount, amount])

