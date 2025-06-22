@tool
extends Control
class_name BaseCharacterBox

## Base character box implementation
##
## Provides basic functionality for character display UI components

# Base UI references
@onready var character_name_label: Label
@onready var character_stats_container: Container

# Character data reference
var character_data: Resource

signal character_selected(character: Resource)
signal character_updated(character: Resource)

func _ready() -> void:
	_initialize_ui()

func _initialize_ui() -> void:
	# Override in subclasses for specific UI setup
	pass

## Update the display with character data
func update_display(data: Resource) -> void:
	character_data = data
	_refresh_display()

## Refresh the display elements
func _refresh_display() -> void:
	# Override in subclasses for specific display logic
	if character_name_label and character_data:
		var name = character_data.get("character_name") if character_data.has("character_name") else "Unknown"
		character_name_label.text = name

## Set character data
func set_character_data(data: Resource) -> void:
	character_data = data
	character_updated.emit(character_data) # warning: return value discarded (intentional)
	_refresh_display()

## Get character data
func get_character_data() -> Resource:
	return character_data

## Handle character selection
func _on_character_selected() -> void:
	if character_data:
		character_selected.emit(character_data) # warning: return value discarded (intentional)