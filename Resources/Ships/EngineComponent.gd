# Scripts/ShipAndCrew/EngineComponent.gd
class_name EngineComponent
extends Resource

const GameEnums = preload("res://Resources/Core/Systems/GlobalEnums.gd")

@export var name: String = ""
@export var description: String = ""
@export var speed: int = 0
@export var fuel_efficiency: float = 0.0
@export var power_usage: int = 0
@export var health: int = 100
@export var max_health: int = 100
@export var weight: float = 1.0
@export var is_damaged: bool = false

const MIN_SPEED: int = 1
const MAX_EFFICIENCY: float = 1.0

func _init(p_name: String = "", 
          p_description: String = "", 
          p_power_usage: int = 0, 
          p_health: int = 0, 
          p_weight: float = 1.0, 
          p_speed: int = 0, 
          p_fuel_efficiency: float = 0.0) -> void:
	name = p_name
	description = p_description
	power_usage = p_power_usage
	health = p_health
	max_health = p_health
	weight = p_weight
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
	return {
		"name": name,
		"description": description,
		"power_usage": power_usage,
		"health": health,
		"max_health": max_health,
		"weight": weight,
		"speed": speed,
		"fuel_efficiency": fuel_efficiency,
		"is_damaged": is_damaged
	}

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
	var old_health = health
	health = min(health + amount, max_health)
	is_damaged = health < max_health
	
	if not is_damaged and old_health < max_health:
		print("Engine repaired and operational. Speed restored to: ", speed)

func take_damage(amount: int) -> void:
	var old_health = health
	health = max(0, health - amount)
	is_damaged = health < max_health
	
	if is_damaged and not old_health < max_health:
		speed = max(1, speed / 2.0)  # Reduce speed by half when damaged, minimum 1
		print("Engine damaged. Speed reduced to: ", speed)
