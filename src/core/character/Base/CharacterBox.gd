@tool
extends Control
class_name BaseCharacterBox

## Base character box implementation
##
## Provides basic functionality for character display UI components

# Dependencies
const Godot4Utils = preload("res://src/utils/Godot4Utils.gd")

# Base UI references
@onready var character_name_label: Label
@onready var character_stats_container: Container

# Character data reference
var character_data: Resource

signal character_selected(character: Resource)
signal character_updated(character: Resource)

# Additional game-specific UI components
@onready var morale_value: Label = $"MarginContainer/HBoxContainer/InfoContainer/GameStatsContainer/MoraleValue"
@onready var credits_value: Label = $"MarginContainer/HBoxContainer/InfoContainer/GameStatsContainer/CreditsValue"
@onready var missions_value: Label = $"MarginContainer/HBoxContainer/InfoContainer/GameStatsContainer/MissionsValue"

func _ready() -> void:
	_initialize_ui()

func _initialize_ui() -> void:
	# Override in subclasses for specific UI setup
	pass

## Update the display with character data
func update_display(data: Resource) -> void:
	character_data = data
	_refresh_display()
	update_game_specific_ui()

## Refresh the display elements
func _refresh_display() -> void:
	# Override in subclasses for specific display logic
	if character_name_label and character_data:
		var name = Godot4Utils.safe_get_property(character_data, "character_name", "Unknown")
		character_name_label.text = name

## Set character data
func set_character_data(data: Resource) -> void:
	character_data = data
	character_updated.emit(character_data)
	_refresh_display()

## Get character data
func get_character_data() -> Resource:
	return character_data

## Handle character selection
func _on_character_selected() -> void:
	if character_data:
		character_selected.emit(character_data)

# Game-specific method to update UI elements
func update_game_specific_ui() -> void:
	if morale_value and character_data:
		morale_value.text = str(character_data.morale)

	if credits_value and character_data:
		credits_value.text = str(character_data.credits_earned)

	if missions_value and character_data:
		missions_value.text = str(character_data.missions_completed)

