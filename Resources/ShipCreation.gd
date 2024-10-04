
# ShipCreation.gd
class_name ShipCreation
extends Resource

const BASE_SHIP_POWER: int = 100
const BASE_SHIP_COST: int = 1000

var ship_components: Dictionary = {}

func _init() -> void:
	load_ship_components()

func load_ship_components() -> void:
	var file := FileAccess.open("res://data/ship_components.json", FileAccess.READ)
	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	if error == OK:
		ship_components = json.data
	else:
		push_error("JSON Parse Error: " + json.get_error_message())

func create_component_from_data(component_data: Dictionary) -> ShipComponent:
	var component_type: GlobalEnums.ComponentType = GlobalEnums.ComponentType[component_data.id.split("_")[0].to_upper()]
	match component_type:
		GlobalEnums.ComponentType.ENGINE:
			return EngineComponent.new(
				component_data.name,
				component_data.description,
				component_data.power_usage,
				component_data.health,
				component_data.weight,
				component_data.speed,
				component_data.fuel_efficiency
			)
		GlobalEnums.ComponentType.WEAPONS:
			return WeaponsComponent.new(
				component_data.name,
				component_data.description,
				component_data.power_usage,
				component_data.health,
				component_data.weight,
				component_data.damage,
				component_data.range
			)
		GlobalEnums.ComponentType.HULL:
			return HullComponent.new(
				component_data.name,
				component_data.description,
				component_data.power_usage,
				component_data.health,
				component_data.weight,
				component_data.armor
			)
		GlobalEnums.ComponentType.MEDICAL_BAY:
			return MedicalBayComponent.new(
				component_data.name,
				component_data.description,
				component_data.power_usage,
				component_data.health,
				component_data.weight,
				component_data.healing_capacity
			)
		_:
			return ShipComponent.new(
				component_data.name,
				component_data.description,
				component_type,
				component_data.power_usage,
				component_data.health,
				component_data.weight
			)

func create_ship(ship_name: String, components: Array[ShipComponent]) -> Ship:
	var new_ship := Ship.new()
	new_ship.name = ship_name
	new_ship.max_hull = calculate_max_hull(components)
	new_ship.current_hull = new_ship.max_hull
	new_ship.fuel = calculate_initial_fuel(components)
	
	for component in components:
		new_ship.add_component(component)
	
	return new_ship

func calculate_max_hull(components: Array[ShipComponent]) -> int:
	var hull_components := components.filter(func(c): return c is HullComponent) as Array[HullComponent]
	return hull_components.reduce(func(acc, component): return acc + component.armor, 0)

func calculate_initial_fuel(components: Array[ShipComponent]) -> int:
	var engine_component := components.filter(func(c): return c is EngineComponent).front() as EngineComponent
	return 100 if engine_component else 0  # Default fuel capacity, adjust as needed

func get_component_cost(component: ShipComponent) -> int:
	# Implement cost calculation logic here
	return 100  # Placeholder value

func get_total_ship_cost(components: Array[ShipComponent]) -> int:
	return BASE_SHIP_COST + components.reduce(func(acc, component): return acc + get_component_cost(component), 0)

func validate_ship_configuration(components: Array[ShipComponent]) -> bool:
	var has_engine := components.any(func(c): return c is EngineComponent)
	var has_hull := components.any(func(c): return c is HullComponent)
	var total_power_usage := components.reduce(func(acc, c): return acc + c.power_usage, 0) as int
	
	return has_engine and has_hull and total_power_usage <= BASE_SHIP_POWER
