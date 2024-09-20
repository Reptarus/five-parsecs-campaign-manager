class_name EngineComponent
extends "res://Scripts/ShipAndCrew/ShipComponent.gd"

@export var speed: int
@export var fuel_efficiency: float

func _init(p_name: String, p_description: String, p_component_type: GlobalEnums.ComponentType, p_power_usage: int, p_health: int, p_weight: float = 1.0, p_speed: int = 0, p_fuel_efficiency: float = 0.0) -> void:
	super(p_name, p_description, p_component_type, p_power_usage, p_health)
	weight = p_weight
	speed = p_speed
	fuel_efficiency = p_fuel_efficiency

func initialize(p_speed: int = 0, p_fuel_efficiency: float = 0.0) -> void:
	speed = p_speed
	fuel_efficiency = p_fuel_efficiency

func calculate_travel_time(distance: int) -> int:
	if health > 0:
		return distance / speed
	return -1  # Unable to travel

func serialize() -> Dictionary:
	var data = super.serialize()
	data.merge({
		"speed": speed,
		"fuel_efficiency": fuel_efficiency
	})
	return data

static func deserialize(data: Dictionary) -> EngineComponent:
	return EngineComponent.new(
		data["name"],
		data["description"],
		GlobalEnums.ComponentType.ENGINE,
		data["power_usage"],
		data["health"],
		data["weight"],
		data["speed"],
		data["fuel_efficiency"]
	)
