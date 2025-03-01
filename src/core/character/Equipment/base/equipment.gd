@tool
extends "res://src/base/items/equipment.gd"
class_name BaseEquipment

## Core implementation of base equipment
##
## Extends the base equipment with core-specific functionality.

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
func get_display_name() -> String:
	var display_name = super.get_display_name()
	if is_damaged():
		display_name += " (Damaged)"
	return display_name

## Override get_description to include durability info
func get_description() -> String:
	var desc = super.get_description()
	desc += "\nDurability: %d/100" % durability
	if requires_proficiency:
		desc += "\nRequires Proficiency"
	return desc