@tool
extends Resource
class_name GameShipComponent

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

var component_type: int = GameEnums.ShipComponentType.NONE
var component_name: String = ""
var component_description: String = ""
var component_cost: int = 0
var level: int = 1
var max_level: int = 3
var power_draw: int = 1
var is_active: bool = true

func _init() -> void:
	pass

func upgrade() -> bool:
	if level < max_level:
		level += 1
		return true
	return false

func serialize() -> Dictionary:
	return {
		"component_type": component_type,
		"component_name": component_name,
		"component_description": component_description,
		"component_cost": component_cost,
		"level": level,
		"max_level": max_level,
		"power_draw": power_draw,
		"is_active": is_active
	}

static func deserialize(data: Dictionary) -> Dictionary:
	return {
		"component_type": data.get("component_type", GameEnums.ShipComponentType.NONE),
		"component_name": data.get("component_name", ""),
		"component_description": data.get("component_description", ""),
		"component_cost": data.get("component_cost", 0),
		"level": data.get("level", 1),
		"max_level": data.get("max_level", 3),
		"power_draw": data.get("power_draw", 1),
		"is_active": data.get("is_active", true)
	}