@tool
extends "res://src/base/items/equipment.gd"
# This file should be referenced via preload
# Use explicit preloads instead of global class names

const Self = preload("res://src/core/character/Equipment/base/equipment.gd")

## Core implementation of base equipment
##
## Extends the base equipment with core-specific functionality.
## This class adds durability and proficiency requirements
## to the base equipment functionality.

# Core-specific properties
var durability: int = 100
var requires_proficiency: bool = false

func _init() -> void:
	super._init()

## Core-specific method to check if item is damaged
func is_damaged() -> bool:
	return durability < 50

## Core-specific method to repair item
func repair() -> void:
	durability = 100

## Override get_display_name to include durability info
## This extends the base method from equipment.gd
func get_display_name() -> String:
	# Call the parent implementation first
	var display_name = super.get_display_name()
	# Then add our modifications
	if is_damaged():
		display_name += " (Damaged)"
	return display_name

## Override get_description to include durability info
## This extends the base method from equipment.gd
func get_description() -> String:
	# Call the parent implementation first
	var desc = super.get_description()
	# Then add our modifications
	desc += "\nDurability: %d/100" % durability
	if requires_proficiency:
		desc += "\nRequires Proficiency"
	return desc