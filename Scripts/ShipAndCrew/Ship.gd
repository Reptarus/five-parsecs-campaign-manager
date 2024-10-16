class_name Ship
extends Resource

signal component_damaged(component: ShipComponent)
signal component_repaired(component: ShipComponent)
signal power_changed(available_power: int)

@export var name: String
<<<<<<< HEAD
@export var components: Array[ShipComponent] = []
@export var crew: Array[Character] = []
@export var inventory: ShipInventory
@export var total_power: int
@export var available_power: int

func _init():
=======
@export var max_hull: int
@export var current_hull: int
@export var fuel: int
@export var debt: int
@export var components: Array[ShipComponent] = []
@export var traits: Array[String] = []

var inventory: ShipInventory
var crew: Array[Character] = []
var current_location: Location

func _init() -> void:
>>>>>>> parent of 1efa334 (worldphase functionality)
	inventory = ShipInventory.new()

func add_component(component: ShipComponent) -> void:
	components.append(component)
	available_power -= component.power_usage
	power_changed.emit(available_power)

func remove_component(component: ShipComponent) -> void:
	components.erase(component)
	available_power += component.power_usage
	power_changed.emit(available_power)

func get_component(type: ShipComponent.ComponentType) -> ShipComponent:
	return components.filter(func(c): return c.type == type).front()

func take_damage(amount: int) -> void:
	var hull := get_component(ShipComponent.ComponentType.HULL) as HullComponent
	if hull:
		hull.take_damage(amount)
		component_damaged.emit(hull)

func repair_component(component: ShipComponent, amount: int) -> void:
	component.repair(amount)
	component_repaired.emit(component)

<<<<<<< HEAD
func calculate_maintenance_cost(economy_manager: EconomyManager) -> int:
	var base_cost = components.reduce(func(acc, comp): return acc + comp.maintenance_cost, 0)
	return int(base_cost * economy_manager.global_economic_modifier)
=======
func add_fuel(amount: int) -> void:
	fuel += amount
	fuel_changed.emit(fuel)

func use_fuel(amount: int) -> bool:
	if fuel >= amount:
		fuel -= amount
		fuel_changed.emit(fuel)
		return true
	return false

func travel_to(destination: Location) -> bool:
	if not current_location:
		push_error("Ship has no current location set")
		return false
	
	var distance = current_location.distance_to(destination)
	var fuel_cost = calculate_fuel_cost(distance)
	
	if use_fuel(fuel_cost):
		var previous_location = current_location
		current_location = destination
		ship_traveled.emit(previous_location, current_location)
		
		# Trigger travel event
		var event = GameStateManager.starship_travel_events.generate_travel_event()
		travel_event_occurred.emit(event)
		
		return true
	return false

func calculate_fuel_cost(distance: float) -> int:
	var base_cost = ceil(distance / 10)
	var engine = get_engine()
	if engine:
		base_cost = engine.modify_fuel_cost(base_cost)
	return base_cost

func add_crew_member(character: Character) -> void:
	crew.append(character)
	crew_changed.emit(crew)

func remove_crew_member(character: Character) -> void:
	crew.erase(character)
	crew_changed.emit(crew)

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

func get_ship_stash() -> Array[Equipment]:
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
>>>>>>> parent of 1efa334 (worldphase functionality)

func serialize() -> Dictionary:
	return {
		"name": name,
		"components": components.map(func(c): return c.serialize()),
		"crew": crew.map(func(c): return c.serialize()),
<<<<<<< HEAD
		"inventory": inventory.serialize(),
		"total_power": total_power,
		"available_power": available_power
=======
		"current_location": current_location.serialize() if current_location else {}
>>>>>>> parent of 1efa334 (worldphase functionality)
	}

static func deserialize(data: Dictionary) -> Ship:
	var ship = Ship.new()
	ship.name = data["name"]
	ship.components = data["components"].map(func(c): return ShipComponent.deserialize(c))
	ship.crew = data["crew"].map(func(c): return Character.deserialize(c))
<<<<<<< HEAD
	ship.inventory = ShipInventory.deserialize(data["inventory"])
	ship.total_power = data["total_power"]
	ship.available_power = data["available_power"]
=======
	ship.current_location = Location.deserialize(data["current_location"]) if data["current_location"] else null
>>>>>>> parent of 1efa334 (worldphase functionality)
	return ship
