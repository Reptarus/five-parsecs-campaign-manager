# This file should be referenced via preload
# Use explicit preloads instead of global class names
extends "res://src/core/character/Base/CharacterBox.gd"

const Self = preload("res://src/game/character/CharacterBox.gd")

## Game-specific character box implementation
##
## Extends the core character box with game-specific
## functionality for the Five Parsecs From Home implementation.

# Additional game-specific UI components
@onready var morale_value = $MarginContainer/HBoxContainer/InfoContainer/GameStatsContainer/MoraleValue
@onready var credits_value = $MarginContainer/HBoxContainer/InfoContainer/GameStatsContainer/CreditsValue
@onready var missions_value = $MarginContainer/HBoxContainer/InfoContainer/GameStatsContainer/MissionsValue

# Override _ready to initialize game-specific components
func _ready() -> void:
	super._ready()
	
	# Initialize game-specific UI components
	if character_data:
		update_game_specific_ui()

# Game-specific method to update UI elements
func update_game_specific_ui() -> void:
	if not is_instance_valid(morale_value) or not character_data:
		return
		
	if character_data.get("morale") != null:
		morale_value.text = str(character_data.morale)
	
	if is_instance_valid(credits_value) and character_data.get("credits_earned") != null:
		credits_value.text = str(character_data.credits_earned)
		
	if is_instance_valid(missions_value) and character_data.get("missions_completed") != null:
		missions_value.text = str(character_data.missions_completed)

# Override the update_ui method to include game-specific updates
func update_display(data: Resource) -> void:
	super.update_display(data)
	update_game_specific_ui()