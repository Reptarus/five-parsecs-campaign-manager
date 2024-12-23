# Scripts/ShipAndCrew/Ship.gd
class_name Ship
extends Resource

const ShipComponent = preload("res://src/core/ships/components/ShipComponent.gd")
const EngineComponent = preload("res://src/core/ships/components/EngineComponent.gd")
const MedicalBayComponent = preload("res://src/core/ships/components/MedicalBayComponent.gd")
const HullComponent = preload("res://src/core/ships/components/HullComponent.gd")
const WeaponsComponent = preload("res://src/core/ships/components/WeaponsComponent.gd")

signal component_added(component: ShipComponent)
signal component_removed(component: ShipComponent)
signal component_upgraded(component: ShipComponent)
signal ship_damaged(amount: int)
signal ship_repaired(amount: int)
signal power_state_changed(available: int, required: int)

@export var name: String = ""
@export var description: String = ""
@export var ship_class: String = ""
@export var level: int = 1
@export var power_capacity: int = 10
@export var power_generation: int = 5

# Core components
@export var hull_component: HullComponent
@export var engine_component: EngineComponent
@export var medical_component: MedicalBayComponent
@export var weapons_component: WeaponsComponent

# Ship state
var is_powered: bool = true
var power_usage: int = 0
var components: Array[ShipComponent] = []

func _init() -> void:
	# Initialize core components
	hull_component = HullComponent.new()
	engine_component = EngineComponent.new()
	medical_component = MedicalBayComponent.new()
	weapons_component = WeaponsComponent.new()
	
	# Add core components
	add_component(hull_component)
	add_component(engine_component)
	add_component(medical_component)
	add_component(weapons_component)
	
	# Initial power check
	update_power_state()

func add_component(component: ShipComponent) -> bool:
	if component == null:
		push_error("Cannot add null component")
		return false
		
	if component in components:
		push_warning("Component already installed")
		return false
		
	components.append(component)
	power_usage += component.power_draw
	update_power_state()
	component_added.emit(component)
	return true

func remove_component(component: ShipComponent) -> bool:
	if component == null:
		push_error("Cannot remove null component")
		return false
		
	if not component in components:
		push_warning("Component not found")
		return false
		
	components.erase(component)
	power_usage -= component.power_draw
	update_power_state()
	component_removed.emit(component)
	return true

func upgrade_component(component: ShipComponent) -> bool:
	if component == null or not component in components:
		return false
		
	if not component.can_upgrade():
		return false
		
	if component.upgrade():
		power_usage = calculate_power_usage()
		update_power_state()
		component_upgraded.emit(component)
		return true
	return false

func take_damage(amount: int) -> void:
	hull_component.take_damage(amount)
	ship_damaged.emit(amount)
	update_power_state()

func repair(amount: int) -> void:
	hull_component.repair(amount)
	ship_repaired.emit(amount)
	update_power_state()

func update_power_state() -> void:
	var available_power = power_generation
	var required_power = calculate_power_usage()
	
	is_powered = available_power >= required_power
	
	if not is_powered:
		# Disable non-essential components
		for component in components:
			if component != hull_component:  # Keep hull systems online
				component.deactivate()
	else:
		# Re-enable components
		for component in components:
			component.activate()
	
	power_state_changed.emit(available_power, required_power)

func calculate_power_usage() -> int:
	var total = 0
	for component in components:
		if component.is_active:
			total += component.power_draw
	return total

func get_power_usage() -> int:
	return power_usage

func get_power_available() -> int:
	return power_generation

func get_component_count() -> int:
	return components.size()

func get_active_components() -> Array[ShipComponent]:
	var active = []
	for component in components:
		if component.is_active:
			active.append(component)
	return active

func get_inactive_components() -> Array[ShipComponent]:
	var inactive = []
	for component in components:
		if not component.is_active:
			inactive.append(component)
	return inactive

func get_maintenance_cost() -> int:
	var total = 0
	for component in components:
		total += component.get_maintenance_cost()
	return total

func serialize() -> Dictionary:
	return {
		"name": name,
		"description": description,
		"ship_class": ship_class,
		"level": level,
		"power_capacity": power_capacity,
		"power_generation": power_generation,
		"is_powered": is_powered,
		"power_usage": power_usage,
		"hull_component": hull_component.serialize(),
		"engine_component": engine_component.serialize(),
		"medical_component": medical_component.serialize(),
		"weapons_component": weapons_component.serialize()
	}

static func deserialize(data: Dictionary) -> Ship:
	var ship = Ship.new()
	ship.name = data.get("name", "")
	ship.description = data.get("description", "")
	ship.ship_class = data.get("ship_class", "")
	ship.level = data.get("level", 1)
	ship.power_capacity = data.get("power_capacity", 10)
	ship.power_generation = data.get("power_generation", 5)
	ship.is_powered = data.get("is_powered", true)
	ship.power_usage = data.get("power_usage", 0)
	
	# Deserialize components
	ship.hull_component = HullComponent.deserialize(data.get("hull_component", {}))
	ship.engine_component = EngineComponent.deserialize(data.get("engine_component", {}))
	ship.medical_component = MedicalBayComponent.deserialize(data.get("medical_component", {}))
	ship.weapons_component = WeaponsComponent.deserialize(data.get("weapons_component", {}))
	
	# Re-add components to ensure proper initialization
	ship.components.clear()
	ship.add_component(ship.hull_component)
	ship.add_component(ship.engine_component)
	ship.add_component(ship.medical_component)
	ship.add_component(ship.weapons_component)
	
	return ship
