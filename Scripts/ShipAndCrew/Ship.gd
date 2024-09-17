class_name Ship
extends Resource

signal component_damaged(component: ShipComponent)
signal component_repaired(component: ShipComponent)
signal power_changed(available_power: int)

@export var name: String
@export var max_hull: int
@export var current_hull: int
@export var fuel: int
@export var debt: int
@export var components: Array[ShipComponent] = []
@export var traits: Array[String]

func add_component(component: ShipComponent) -> void:
	components.append(component)

func remove_component(component: ShipComponent) -> void:
	components.erase(component)

func get_component_by_type(type: ShipComponent.ComponentType) -> ShipComponent:
	for component in components:
		if component.type == type:
			return component
	return null

func has_trait(trait: String) -> bool:
	return trait in traits

func repair(amount: int) -> void:
	current_hull = min(current_hull + amount, max_hull)

func take_damage(amount: int) -> void:
	current_hull = max(current_hull - amount, 0)

func is_destroyed() -> bool:
	return current_hull <= 0

func add_fuel(amount: int) -> void:
	fuel += amount

func use_fuel(amount: int) -> bool:
	if fuel >= amount:
		fuel -= amount
		return true
	return false

func serialize() -> Dictionary:
	return {
		"name": name,
		"max_hull": max_hull,
		"current_hull": current_hull,
		"fuel": fuel,
		"debt": debt,
		"components": components.map(func(c): return c.serialize()),
		"traits": traits
	}

static func deserialize(data: Dictionary) -> Ship:
	var ship = Ship.new()
	ship.name = data["name"]
	ship.max_hull = data["max_hull"]
	ship.current_hull = data["current_hull"]
	ship.fuel = data["fuel"]
	ship.debt = data["debt"]
	ship.components = data["components"].map(func(c): return ShipComponent.deserialize(c))
	ship.traits = data["traits"]
	return ship

func get_total_power_consumption() -> int:
	var total_power = 0
	for component in components:
		if not component.is_damaged:
			total_power += component.power_usage
	return total_power
