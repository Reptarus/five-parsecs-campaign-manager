# Scripts/ShipAndCrew/EngineComponent.gd
class_name EngineComponent
extends ShipComponent

@export var speed: int = 0
@export var fuel_efficiency: float = 0.0

const MIN_SPEED: int = 1
const MAX_EFFICIENCY: float = 1.0

func _init(p_name: String = "", 
          p_description: String = "", 
          p_power_usage: int = 0, 
          p_health: int = 0, 
          p_weight: float = 1.0, 
          p_speed: int = 0, 
          p_fuel_efficiency: float = 0.0) -> void:
	super(p_name, p_description, GlobalEnums.ShipComponentType.ENGINE, p_power_usage, p_health, p_weight)
	speed = max(p_speed, MIN_SPEED)
	fuel_efficiency = clamp(p_fuel_efficiency, 0.0, MAX_EFFICIENCY)

func calculate_travel_time(distance: int) -> int:
	if distance < 0:
		push_error("Distance cannot be negative")
		return -1
		
	if health <= 0:
		return -1  # Unable to travel
		
	return int(ceil(float(distance) / speed))

func modify_fuel_cost(base_cost: int) -> int:
	if base_cost < 0:
		push_error("Base fuel cost cannot be negative")
		return 0
		
	return int(ceil(base_cost * (1.0 - fuel_efficiency)))

func serialize() -> Dictionary:
	var data = super.serialize()
	data["speed"] = speed
	data["fuel_efficiency"] = fuel_efficiency
	return data

static func deserialize(data: Dictionary) -> EngineComponent:
	var component = EngineComponent.new(
		data["name"],
		data["description"],
		data["power_usage"],
		data["health"],
		data["weight"],
		data["speed"],
		data["fuel_efficiency"]
	)
	component.max_health = data["max_health"]
	component.is_damaged = data["is_damaged"]
	return component

func repair(amount: int) -> void:
	super.repair(amount)
	if not is_damaged:
		print("Engine repaired and operational. Speed restored to: ", speed)

func take_damage(amount: int) -> void:
	super.take_damage(amount)
	if is_damaged:
		speed = max(1, speed / 2.0)  # Reduce speed by half when damaged, minimum 1
		print("Engine damaged. Speed reduced to: ", speed)
