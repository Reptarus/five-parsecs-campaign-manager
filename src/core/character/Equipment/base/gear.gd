@tool
extends "res://src/core/character/Equipment/base/equipment.gd"
# This file should be referenced via preload
# Use explicit preloads instead of global class names

# Use a different constant name to avoid conflicts with parent's Self constant
const GearSelf = preload("res://src/core/character/Equipment/base/gear.gd")

func _init() -> void:
	super._init()
	item_type = GameEnums.ItemType.MISC
	
## Override get_display_name to show gear-specific information
func get_display_name() -> String:
	var display_name = super.get_display_name()
	# Add gear-specific notation if needed (e.g., "[G]" prefix for gear)
	return "[G] " + display_name
	
## Override get_description to include gear-specific information
func get_description() -> String:
	var desc = super.get_description()
	desc += "\nEquipment Type: Gear"
	return desc
