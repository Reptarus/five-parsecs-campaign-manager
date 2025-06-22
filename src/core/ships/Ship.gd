# Scripts/ShipAndCrew/Ship.gd
@tool
extends Node
class_name Ship

## Basic ship class for Five Parsecs campaign
## Manages ship components, stats, and functionality

signal ship_updated()
signal component_changed(component_name: String)
signal damage_taken(amount: int)

## Ship properties
var ship_name: String = "Unknown Ship"
var ship_class: String = "Transport"
var hull_points: int = 100
var max_hull_points: int = 100
var fuel: int = 100
var max_fuel: int = 100

## Ship components
var components: Dictionary = {}

func _init() -> void:
	_initialize_default_components()

func _initialize_default_components() -> void:
	components = {
		"hull": {
			"durability": 100,
			"is_active": true,
			"max_durability": 100
		},
		"engine": {
			"efficiency": 1.0,
			"is_active": true
		},
		"life_support": {
			"capacity": 8,
			"is_active": true
		}
	}

func get_component(component_name: String) -> Dictionary:
	return components.get(component_name, {})

func set_component(component_name: String, component_data: Dictionary) -> void:
	components[component_name] = component_data
	component_changed.emit(component_name)
	ship_updated.emit()

func take_damage(amount: int) -> void:
	hull_points = max(0, hull_points - amount)
	damage_taken.emit(amount)
	ship_updated.emit()

func repair(amount: int) -> void:
	hull_points = min(max_hull_points, hull_points + amount)
	ship_updated.emit()

func use_fuel(amount: int) -> bool:
	if fuel >= amount:
		fuel -= amount
		ship_updated.emit()
		return true
	return false

func refuel(amount: int) -> void:
	fuel = min(max_fuel, fuel + amount)
	ship_updated.emit()

func serialize() -> Dictionary:
	return {
		"ship_name": ship_name,
		"ship_class": ship_class,
		"hull_points": hull_points,
		"max_hull_points": max_hull_points,
		"fuel": fuel,
		"max_fuel": max_fuel,
		"components": components.duplicate(true)
	}

func deserialize(data: Dictionary) -> void:
	ship_name = data.get("ship_name", "Unknown Ship")
	ship_class = data.get("ship_class", "Transport")
	hull_points = data.get("hull_points", 100)
	max_hull_points = data.get("max_hull_points", 100)
	fuel = data.get("fuel", 100)
	max_fuel = data.get("max_fuel", 100)
	components = data.get("components", {}).duplicate(true)
	ship_updated.emit()
