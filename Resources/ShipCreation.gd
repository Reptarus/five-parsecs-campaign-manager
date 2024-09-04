class_name ShipCreation
extends Node

const BASE_SHIP_POWER: int = 100
const BASE_SHIP_COST: int = 1000

var game_state: GameState

func _init(_game_state: GameState):
	game_state = _game_state

func generate_starter_ship() -> Ship:
	var ship := Ship.new()
	ship.name = "Starter Ship"
	ship.total_power = BASE_SHIP_POWER
	ship.available_power = BASE_SHIP_POWER

	var hull := HullComponent.new(int)
	hull.type = HullComponent.ComponentType.HULL
	hull.name = "Basic Hull"
	hull.health = 100
	hull.max_health = 100
	hull.power_usage = 0

	var engine := EngineComponent.new(self)
	engine.name = "Standard Engine"
	engine.speed = 5
	engine.fuel_efficiency = 1.0
	engine.power_usage = 20

	var weapons := WeaponsComponent.new()
	weapons.name = "Basic Laser"
	weapons.damage = 10
	weapons.range = 5
	weapons.accuracy = 70
	weapons.power_usage = 30

	var medical_bay := MedicalBayComponent.new()
	medical_bay.name = "Basic Med Bay"
	medical_bay.healing_capacity = 2
	medical_bay.power_usage = 15

	ship.add_component(hull)
	ship.add_component(engine)
	ship.add_component(weapons)
	ship.add_component(medical_bay)

	return ship

func customize_ship(ship: Ship, component_changes: Dictionary) -> bool:
	var total_cost := 0

	for component_type in component_changes:
		var new_component: ShipComponent = component_changes[component_type]
		var old_component := ship.get_component(component_type)
		
		if old_component:
			total_cost += new_component.cost - old_component.cost
			ship.remove_component(old_component)
		else:
			total_cost += new_component.cost

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
				ship.add_component(component_changes[component_type])
		return false

func get_ship_cost(ship: Ship) -> int:
	var total_cost := BASE_SHIP_COST
	for component in ship.components:
		total_cost += component.cost
	return total_cost
