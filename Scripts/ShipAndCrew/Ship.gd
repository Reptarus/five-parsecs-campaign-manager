# Scripts/ShipAndCrew/Ship.gd
class_name Ship extends Resource

signal component_added(component: ShipComponent)
signal component_removed(component: ShipComponent)
signal hull_changed(current_hull: int, max_hull: int)
signal fuel_changed(current_fuel: int)
signal crew_changed(crew: Array[Character])
signal ship_traveled(from: Location, to: Location)
signal travel_event_occurred(event: Dictionary)

@export var name: String
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
	inventory = ShipInventory.new()

func add_component(component: ShipComponent) -> void:
	components.append(component)
	component_added.emit(component)

func remove_component(component: ShipComponent) -> void:
	components.erase(component)
	component_removed.emit(component)

func get_component_by_type(type: GlobalEnums.ComponentType) -> ShipComponent:
	return components.filter(func(c): return c.component_type == type).front()

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
		amount = max(1, int(amount / 2.0))
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

func travel_to(destination: Location, game_state: GameState) -> bool:
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
		var event = game_state.starship_travel_events.generate_travel_event()
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

func serialize() -> Dictionary:
	var data = {
		"name": name,
		"max_hull": max_hull,
		"current_hull": current_hull,
		"fuel": fuel,
		"debt": debt,
		"components": components.map(func(c): return c.serialize()),
		"traits": traits,
		"inventory": inventory.serialize(),
		"crew": crew.map(func(c): return c.serialize()),
		"current_location": current_location.serialize() if current_location else null
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
	ship.crew = data["crew"].map(func(c): return Character.deserialize(c, ship))
	ship.current_location = Location.deserialize(data["current_location"]) if data["current_location"] else null
	return ship
