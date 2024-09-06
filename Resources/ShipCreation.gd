# ShipCreation.gd
extends Node

const BASE_SHIP_POWER: int = 100
const BASE_SHIP_COST: int = 1000

var game_state: GameState
var ship_components: Dictionary

func _init(_game_state: GameState):
	game_state = _game_state
	load_ship_components()

func load_ship_components() -> void:
	var file = FileAccess.open("res://data/ship_components.json", FileAccess.READ)
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	if error == OK:
		ship_components = json.data
	else:
		print("JSON Parse Error: ", json.get_error_message())

func generate_starter_ship() -> Ship:
	var ship := Ship.new()
	ship.name = "Starter Ship"
	ship.total_power = BASE_SHIP_POWER
	ship.available_power = BASE_SHIP_POWER

	var hull = create_component_from_data(ship_components.hull_components[0])
	var engine = create_component_from_data(ship_components.engine_components[0])
	var weapons = create_component_from_data(ship_components.weapon_components[0])
	var medical_bay = create_component_from_data(ship_components.medical_components[0])

	ship.add_component(hull)
	ship.add_component(engine)
	ship.add_component(weapons)
	ship.add_component(medical_bay)

	return ship

func create_component_from_data(component_data: Dictionary) -> ShipComponent:
	match component_data.id.split("_")[0]:
		"hull":
			return HullComponent.new(
				component_data.name,
				"A ship hull component",
				ShipComponent.ComponentType.HULL,
				component_data.power_usage,
				component_data.health,
				component_data.armor
			)
		"engine":
			return EngineComponent.new(
				component_data.name,
				"A ship engine component",
				component_data.power_usage,
				component_data.health,
				component_data.speed,
				component_data.fuel_efficiency
			)
		"laser", "missile":  # Assuming these are weapon types
			return WeaponsComponent.new(
				component_data.name,
				"A ship weapon component",
				component_data.power_usage,
				component_data.health,
				component_data.damage,
				component_data.range,
				component_data.accuracy
			)
		"med":
			return MedicalBayComponent.new(
				component_data.name,
				"A ship medical bay component",
				component_data.power_usage,
				component_data.health,
				component_data.healing_capacity
			)
		_:
			push_error("Unknown component type: " + component_data.id)
			return null

func customize_ship(ship: Ship, component_changes: Dictionary) -> bool:
	var total_cost := 0

	for component_type in component_changes:
		var new_component_data = component_changes[component_type]
		var new_component = create_component_from_data(new_component_data)
		var old_component := ship.get_component(new_component.type)
		
		if old_component:
			total_cost += new_component_data.cost - old_component.cost
			ship.remove_component(old_component)
		else:
			total_cost += new_component_data.cost

		ship.add_component(new_component)

	if game_state.current_crew.credits >= total_cost:
		game_state.current_crew.remove_credits(total_cost)
		return true
	else:
		# Revert changes if not enough credits
		for component_type in component_changes:
			var old_component := ship.get_component(component_type)
			ship.remove_component(old_component)
			if component_changes[component_type] != null:
				ship.add_component(create_component_from_data(component_changes[component_type]))
		return false

func get_ship_cost(ship: Ship) -> int:
	var total_cost := BASE_SHIP_COST
	for component in ship.components:
		total_cost += get_component_cost(component)
	return total_cost

func get_component_cost(component: ShipComponent) -> int:
	for category in ship_components:
		for comp_data in ship_components[category]:
			if comp_data.name == component.name:
				return comp_data.cost
	return 0

func upgrade_component(ship: Ship, component_type: ShipComponent.ComponentType, new_component_data: Dictionary) -> bool:
	var old_component = ship.get_component(component_type)
	if old_component:
		var upgrade_cost = new_component_data.cost - get_component_cost(old_component)
		if game_state.current_crew.credits >= upgrade_cost:
			game_state.current_crew.remove_credits(upgrade_cost)
			ship.remove_component(old_component)
			ship.add_component(create_component_from_data(new_component_data))
			return true
	return false

func repair_ship(ship: Ship, amount: int) -> void:
	var hull = ship.get_component(ShipComponent.ComponentType.HULL) as HullComponent
	if hull:
		hull.repair(amount)

func calculate_maintenance_cost(ship: Ship) -> int:
	var maintenance_cost := 0
	for component in ship.components:
		maintenance_cost += component.power_usage  # Assuming power usage correlates with maintenance cost
	return maintenance_cost

func generate_random_component(component_type: ShipComponent.ComponentType) -> ShipComponent:
	var category = get_category_for_component_type(component_type)
	var random_index = randi() % ship_components[category].size()
	return create_component_from_data(ship_components[category][random_index])

func get_category_for_component_type(component_type: ShipComponent.ComponentType) -> String:
	match component_type:
		ShipComponent.ComponentType.HULL:
			return "hull_components"
		ShipComponent.ComponentType.ENGINE:
			return "engine_components"
		ShipComponent.ComponentType.WEAPONS:
			return "weapon_components"
		ShipComponent.ComponentType.MEDICAL_BAY:
			return "medical_components"
		_:
			push_error("Unknown component type")
			return ""

func save_ship_design(ship: Ship, design_name: String) -> void:
	var design_data = {
		"name": design_name,
		"components": []
	}
	for component in ship.components:
		design_data.components.append({
			"type": ShipComponent.ComponentType.keys()[component.type],
			"name": component.name
		})
	
	var file = FileAccess.open("user://ship_designs.json", FileAccess.READ_WRITE)
	var json_string = JSON.stringify(design_data)
	file.store_line(json_string)
	file.close()

func load_ship_design(design_name: String) -> Ship:
	var file = FileAccess.open("user://ship_designs.json", FileAccess.READ)
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	file.close()
	
	if error == OK:
		var design_data = json.data
		if design_data.name == design_name:
			var ship = Ship.new()
			ship.name = design_name
			for component_data in design_data.components:
				var component_type = ShipComponent.ComponentType[component_data.type]
				var category = get_category_for_component_type(component_type)
				for comp in ship_components[category]:
					if comp.name == component_data.name:
						ship.add_component(create_component_from_data(comp))
						break
			return ship
	
	push_error("Failed to load ship design: " + design_name)
	return null
