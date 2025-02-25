@tool
extends "res://src/core/character/Equipment/base/equipment.gd"

func _init() -> void:
	super._init()
	item_type = GameEnums.ItemType.MISC