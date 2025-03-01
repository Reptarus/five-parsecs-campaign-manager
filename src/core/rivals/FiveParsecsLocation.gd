@tool
extends Resource
class_name FiveParsecsLocation

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

@export var location_name: String = ""
@export var location_type: int = GameEnums.LocationType.NONE
@export var prosperity_level: int = 1
@export var security_level: int = 1
@export var population_density: int = 1
@export var is_starter_location: bool = false

func _init(name: String = "", type: int = GameEnums.LocationType.NONE) -> void:
	location_name = name
	location_type = type

func serialize() -> Dictionary:
	return {
		"location_name": location_name,
		"location_type": location_type,
		"prosperity_level": prosperity_level,
		"security_level": security_level,
		"population_density": population_density,
		"is_starter_location": is_starter_location
	}

func deserialize(data: Dictionary) -> void:
	location_name = data.get("location_name", "")
	location_type = data.get("location_type", GameEnums.LocationType.NONE)
	prosperity_level = data.get("prosperity_level", 1)
	security_level = data.get("security_level", 1)
	population_density = data.get("population_density", 1)
	is_starter_location = data.get("is_starter_location", false)