# Scripts/ShipAndCrew/EngineComponent.gd
class_name EngineComponent
extends ShipComponent

@export var thrust: float = 1.0
@export var fuel_efficiency: float = 1.0
@export var maneuverability: float = 1.0
@export var max_speed: float = 100.0

func _init() -> void:
	super()
	name = "Engine"
	description = "Standard ship engine"
	cost = 200
	power_draw = 2

func _apply_upgrade_effects() -> void:
	super()
	thrust += 0.2
	fuel_efficiency += 0.1
	maneuverability += 0.15
	max_speed += 20.0

func get_thrust() -> float:
	return thrust * get_efficiency()

func get_fuel_efficiency() -> float:
	return fuel_efficiency * get_efficiency()

func get_maneuverability() -> float:
	return maneuverability * get_efficiency()

func get_max_speed() -> float:
	return max_speed * get_efficiency()

func serialize() -> Dictionary:
	var data = super()
	data["thrust"] = thrust
	data["fuel_efficiency"] = fuel_efficiency
	data["maneuverability"] = maneuverability
	data["max_speed"] = max_speed
	return data

static func deserialize(data: Dictionary) -> EngineComponent:
	var component = EngineComponent.new()
	var base_data = super.deserialize(data)
	component.name = base_data.name
	component.description = base_data.description
	component.cost = base_data.cost
	component.level = base_data.level
	component.max_level = base_data.max_level
	component.is_active = base_data.is_active
	component.upgrade_cost = base_data.upgrade_cost
	component.maintenance_cost = base_data.maintenance_cost
	component.durability = base_data.durability
	component.max_durability = base_data.max_durability
	component.efficiency = base_data.efficiency
	component.power_draw = base_data.power_draw
	component.status_effects = base_data.status_effects
	
	component.thrust = data.get("thrust", 1.0)
	component.fuel_efficiency = data.get("fuel_efficiency", 1.0)
	component.maneuverability = data.get("maneuverability", 1.0)
	component.max_speed = data.get("max_speed", 100.0)
	return component
