@tool
extends "res://src/core/character/Equipment/base/equipment.gd"
class_name BaseGear

func _init() -> void:
	super._init()
	# Set the item type using the parent's GameEnums
	if "item_type" in self:
		self.item_type = GameEnums.ItemType.MISC