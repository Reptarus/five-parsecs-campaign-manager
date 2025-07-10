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
		var name = safe_get_property(character_data, "character_name", "Unknown")
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
## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_get_property(obj: Object, property: String, default_value: Variant = null) -> Variant:

	# Parameter validation - eliminates UNSAFE_CALL_ARGUMENT warnings
	if not is_instance_valid(self):
		return default_value
	var value = obj.get(property)
	return value if value != null else default_value
	return default_value
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null