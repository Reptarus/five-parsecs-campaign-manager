@tool
extends Node

# Explicit references to all equipment classes
const BaseEquipment = preload("res://src/base/items/equipment.gd")
const CoreEquipment = preload("res://src/core/character/Equipment/base/equipment.gd")
const Gear = preload("res://src/core/character/Equipment/base/gear.gd")

func _ready() -> void:
	print("Running equipment test...")
	
	# Test base equipment
	var base_item = BaseEquipment.new()
	base_item.item_name = "Base Item"
	base_item.description = "A basic equipment item"
	print("Base item name: ", base_item.get_display_name())
	print("Base item description: ", base_item.get_description())
	
	# Test core equipment
	var core_item = CoreEquipment.new()
	core_item.item_name = "Core Item"
	core_item.description = "A core equipment item"
	core_item.durability = 50
	print("Core item name: ", core_item.get_display_name())
	print("Core item description: ", core_item.get_description())
	
	# Test gear
	var gear_item = Gear.new()
	gear_item.item_name = "Gear Item"
	gear_item.description = "A gear item"
	gear_item.durability = 75
	print("Gear item name: ", gear_item.get_display_name())
	print("Gear item description: ", gear_item.get_description())
	
	print("Equipment test completed!")