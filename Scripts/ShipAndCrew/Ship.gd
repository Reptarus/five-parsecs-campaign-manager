class_name Ship
extends Resource

signal component_added(component: ShipComponent)
signal component_removed(component: ShipComponent)
signal hull_changed(current_hull: int, max_hull: int)
signal fuel_changed(current_fuel: int)

@export var name: String
@export var max_hull: int
@export var current_hull: int
@export var fuel: int
@export var debt: int
@export var components: Array[ShipComponent] = []
@export var traits: Array[String] = []

var inventory: ShipInventory

func _init():
	inventory = ShipInventory.new()

func add_component(component: ShipComponent) -> void:
	components.append(component)
	component_added.emit(component)

func remove_component(component: ShipComponent) -> void:
	components.erase(component)
	component_removed.emit(component)

func get_component_by_type(type: GlobalEnums.ComponentType) -> ShipComponent:
	for component in components:
		if component.component_type == type:
			return component
	return null

func set_initial_traits(initial_traits: Array[String]) -> void:
	traits = initial_traits.duplicate()

func get_traits() -> Array[String]:
	return traits.duplicate()

func has_trait(search_string: String) -> bool:
	return traits.has(search_string)

func repair(amount: int) -> void:
	current_hull = min(current_hull + amount, max_hull)
	hull_changed.emit(current_hull, max_hull)

func take_damage(amount: int, game_state: GameState) -> void:
	if game_state.is_tutorial_active:
		amount = max(1, amount / 2.0)
	current_hull = max(current_hull - amount, 0)
	hull_changed.emit(current_hull, max_hull)

func is_destroyed() -> bool:
	return current_hull <= 0

func add_fuel(amount: int) -> void:
	fuel += amount
	fuel_changed.emit(fuel)

func use_fuel(amount: int) -> bool:
	if fuel >= amount:
		fuel -= amount
		fuel_changed.emit(fuel)
		return true
	return false

func setup_tutorial_ship() -> void:
	name = "Tutorial Vessel"
	max_hull = 10
	current_hull = 10
	fuel = 5
	debt = 0
	components = [
		EngineComponent.new("Basic Engine", "A simple engine for tutorial purposes", GlobalEnums.ComponentType.ENGINE, 1, 5, 1.0, 1, 1.0),
		WeaponsComponent.new("Basic Laser", "A basic laser weapon for tutorial purposes", GlobalEnums.ComponentType.WEAPONS, 1, 5, 1.0, 1, 1, 70)
	]
	traits = ["Tutorial"]

func serialize() -> Dictionary:
	var data = {
		"name": name,
		"max_hull": max_hull,
		"current_hull": current_hull,
		"fuel": fuel,
		"debt": debt,
		"components": components.map(func(c): return c.serialize()),
		"traits": traits,
		"inventory": inventory.serialize()
	}
	return data

static func deserialize(data: Dictionary) -> Ship:
	var ship = Ship.new()
	ship.name = data["name"]
	ship.max_hull = data["max_hull"]
	ship.current_hull = data["current_hull"]
	ship.fuel = data["fuel"]
	ship.debt = data["debt"]
	ship.components = data["components"].map(func(c):
		match c["type"]:
			GlobalEnums.ComponentType.ENGINE:
				return EngineComponent.deserialize(c)
			GlobalEnums.ComponentType.WEAPONS:
				return WeaponsComponent.deserialize(c)
			GlobalEnums.ComponentType.HULL:
				return HullComponent.deserialize(c)
			GlobalEnums.ComponentType.MEDICAL_BAY:
				return MedicalBayComponent.deserialize(c)
			_:
				return ShipComponent.deserialize(c)
	)
	ship.traits = data["traits"]
	ship.inventory = ShipInventory.deserialize(data["inventory"])
	return ship

func get_total_power_consumption() -> int:
	return components.reduce(func(acc, component): return acc + (0 if component.is_damaged else component.power_usage), 0)

func get_total_armor() -> int:
	return components.reduce(func(acc, component): return acc + (component.armor if component is HullComponent else 0), 0)

func get_total_weight() -> float:
	return components.reduce(func(acc, component): return acc + component.weight, 0.0)

func add_to_ship_stash(item: Gear) -> bool:
	return inventory.add_item(item)

func remove_from_ship_stash(item: Gear) -> bool:
	return inventory.remove_item(item)

func get_ship_stash() -> Array[Gear]:
	return inventory.get_items()

func sort_ship_stash(sort_type: String) -> void:
	inventory.sort_items(sort_type)

func get_engine() -> EngineComponent:
	return get_component_by_type(GlobalEnums.ComponentType.ENGINE) as EngineComponent

func get_weapons() -> Array[WeaponsComponent]:
	return components.filter(func(c): return c is WeaponsComponent)

func get_medical_bay() -> MedicalBayComponent:
	return get_component_by_type(GlobalEnums.ComponentType.MEDICAL_BAY) as MedicalBayComponent

func get_hull_components() -> Array[HullComponent]:
	return components.filter(func(c): return c is HullComponent)
