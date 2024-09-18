class_name EngineComponent
extends "res://Scripts/ShipAndCrew/ShipComponent.gd"

@export var description: String

@export var speed: int
@export var fuel_efficiency: float

func _init(p_name: String, p_component_type: ComponentType, p_power_usage: int, p_health: int, p_is_damaged: bool, p_description: String, p_speed: int = 0, p_fuel_efficiency: float = 0.0) -> void:
	super._init(p_name, p_component_type, p_power_usage, p_health, p_is_damaged)
	description = p_description
	speed = p_speed
	fuel_efficiency = p_fuel_efficiency

func calculate_travel_time(distance: int) -> int:
	if not is_damaged and self.health > 0:
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
			data.name,
			ComponentType.ENGINE,
			data.power_usage,
			data.max_health,
			data.is_damaged,
			data.description,
			data.speed,
			data.fuel_efficiency
	)
