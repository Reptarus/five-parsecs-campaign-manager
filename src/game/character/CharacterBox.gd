class_name FPCM_CharacterBox
extends "res://src/core/character/Base/CharacterBox.gd"

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
	if morale_value and character_data:
		morale_value.text = str(character_data.morale)
	
	if credits_value and character_data:
		credits_value.text = str(character_data.credits_earned)
		
	if missions_value and character_data:
		missions_value.text = str(character_data.missions_completed)

# Override the update_ui method to include game-specific updates
func update_display(data: Resource) -> void:
	super.update_display(data)
	update_game_specific_ui()