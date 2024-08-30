class_name EngineComponent
extends ShipComponent

@export var speed: int
@export var fuel_efficiency: float

func _init() -> void:
	type = ComponentType.ENGINE

func calculate_travel_time(distance: int) -> int:
	if is_active and health > 0:
		return distance / speed
	return -1  # Unable to travel

func to_dict() -> Dictionary:
	var data := super.to_dict()
	data["speed"] = speed
	data["fuel_efficiency"] = fuel_efficiency
	return data

static func from_dict(data: Dictionary) -> EngineComponent:
	var component := EngineComponent.new()
	component.speed = data["speed"]
	component.fuel_efficiency = data["fuel_efficiency"]
	return component
