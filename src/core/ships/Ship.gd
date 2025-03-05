# Scripts/ShipAndCrew/Ship.gd
extends Resource
class_name Ship

const FPCM_ShipComponent = preload("res://src/core/ships/components/ShipComponent.gd")
const EngineComponent = preload("res://src/core/ships/components/EngineComponent.gd")
const MedicalBayComponent = preload("res://src/core/ships/components/MedicalBayComponent.gd")
const HullComponent = preload("res://src/core/ships/components/HullComponent.gd")
const WeaponsComponent = preload("res://src/core/ships/components/WeaponsComponent.gd")
const FiveParsecsShipRoles = preload("res://src/game/ships/FiveParsecsShipRoles.gd")

signal component_added(component: FPCM_ShipComponent)
signal component_removed(component: FPCM_ShipComponent)
signal component_upgraded(component: FPCM_ShipComponent)
signal ship_damaged(amount: int)
signal ship_repaired(amount: int)
signal power_state_changed(available: int, required: int)
signal maintenance_performed(cost: int)
signal ship_class_changed(old_class: String, new_class: String)

@export var name: String = ""
@export var description: String = ""
@export var ship_class: String = ""
@export var level: int = 1
@export var power_capacity: int = 10
@export var power_generation: int = 5

# Five Parsecs ship attributes
@export var cargo_capacity: int = 10
@export var crew_capacity: int = 6
@export var luxury_level: int = 1
@export var fuel_efficiency: float = 1.0
@export var maintenance_cost: int = 5

# Core components
@export var hull_component: HullComponent
@export var engine_component: EngineComponent
@export var medical_component: MedicalBayComponent
@export var weapons_component: WeaponsComponent

# Ship state
var is_powered: bool = true
var power_usage: int = 0
var components: Array[FPCM_ShipComponent] = []
var ship_roles: FiveParsecsShipRoles

# Five Parsecs Ship Classes (based on rulebook p.75-76)
enum ShipClass {
	STARTER,
	FIGHTER,
	HAULER,
	TRANSPORT,
	PATROL_BOAT,
	LUXURY_YACHT,
	RESEARCH_VESSEL,
	MILITARY_SURPLUS
}

# Ship class templates from the rulebook
var ship_class_templates = {
	ShipClass.STARTER: {
		"name": "Starter Ship",
		"cargo_capacity": 10,
		"crew_capacity": 6,
		"luxury_level": 1,
		"fuel_efficiency": 1.0,
		"maintenance_cost": 5,
		"power_capacity": 10,
		"power_generation": 5,
		"components": {
			"hull": {"durability": 10, "armor": 2},
			"engine": {"speed": 3, "reliability": 3},
			"medical": {"capacity": 2, "tech_level": 2},
			"weapons": {"attack": 2, "damage": 2}
		}
	},
	ShipClass.FIGHTER: {
		"name": "Fighter",
		"cargo_capacity": 6,
		"crew_capacity": 4,
		"luxury_level": 1,
		"fuel_efficiency": 1.2,
		"maintenance_cost": 8,
		"power_capacity": 12,
		"power_generation": 6,
		"components": {
			"hull": {"durability": 8, "armor": 4},
			"engine": {"speed": 5, "reliability": 3},
			"medical": {"capacity": 1, "tech_level": 1},
			"weapons": {"attack": 4, "damage": 4}
		}
	},
	ShipClass.HAULER: {
		"name": "Hauler",
		"cargo_capacity": 20,
		"crew_capacity": 5,
		"luxury_level": 1,
		"fuel_efficiency": 0.8,
		"maintenance_cost": 7,
		"power_capacity": 15,
		"power_generation": 7,
		"components": {
			"hull": {"durability": 15, "armor": 3},
			"engine": {"speed": 2, "reliability": 4},
			"medical": {"capacity": 2, "tech_level": 2},
			"weapons": {"attack": 2, "damage": 2}
		}
	},
	ShipClass.TRANSPORT: {
		"name": "Transport",
		"cargo_capacity": 15,
		"crew_capacity": 8,
		"luxury_level": 2,
		"fuel_efficiency": 0.9,
		"maintenance_cost": 9,
		"power_capacity": 14,
		"power_generation": 7,
		"components": {
			"hull": {"durability": 12, "armor": 3},
			"engine": {"speed": 3, "reliability": 4},
			"medical": {"capacity": 3, "tech_level": 3},
			"weapons": {"attack": 3, "damage": 3}
		}
	},
	ShipClass.PATROL_BOAT: {
		"name": "Patrol Boat",
		"cargo_capacity": 8,
		"crew_capacity": 6,
		"luxury_level": 2,
		"fuel_efficiency": 1.1,
		"maintenance_cost": 10,
		"power_capacity": 13,
		"power_generation": 7,
		"components": {
			"hull": {"durability": 10, "armor": 4},
			"engine": {"speed": 4, "reliability": 4},
			"medical": {"capacity": 2, "tech_level": 3},
			"weapons": {"attack": 5, "damage": 4}
		}
	},
	ShipClass.LUXURY_YACHT: {
		"name": "Luxury Yacht",
		"cargo_capacity": 12,
		"crew_capacity": 8,
		"luxury_level": 4,
		"fuel_efficiency": 0.7,
		"maintenance_cost": 15,
		"power_capacity": 16,
		"power_generation": 8,
		"components": {
			"hull": {"durability": 10, "armor": 2},
			"engine": {"speed": 4, "reliability": 5},
			"medical": {"capacity": 4, "tech_level": 4},
			"weapons": {"attack": 2, "damage": 2}
		}
	},
	ShipClass.RESEARCH_VESSEL: {
		"name": "Research Vessel",
		"cargo_capacity": 14,
		"crew_capacity": 7,
		"luxury_level": 3,
		"fuel_efficiency": 0.9,
		"maintenance_cost": 12,
		"power_capacity": 18,
		"power_generation": 9,
		"components": {
			"hull": {"durability": 8, "armor": 2},
			"engine": {"speed": 3, "reliability": 4},
			"medical": {"capacity": 5, "tech_level": 5},
			"weapons": {"attack": 2, "damage": 2}
		}
	},
	ShipClass.MILITARY_SURPLUS: {
		"name": "Military Surplus",
		"cargo_capacity": 10,
		"crew_capacity": 7,
		"luxury_level": 1,
		"fuel_efficiency": 1.0,
		"maintenance_cost": 11,
		"power_capacity": 14,
		"power_generation": 7,
		"components": {
			"hull": {"durability": 12, "armor": 5},
			"engine": {"speed": 3, "reliability": 3},
			"medical": {"capacity": 2, "tech_level": 2},
			"weapons": {"attack": 4, "damage": 5}
		}
	}
}

func _init() -> void:
	# Initialize core components
	hull_component = HullComponent.new()
	engine_component = EngineComponent.new()
	medical_component = MedicalBayComponent.new()
	weapons_component = WeaponsComponent.new()
	
	# Set up ship roles
	ship_roles = FiveParsecsShipRoles.new()
	
	# Add core components
	add_component(hull_component)
	add_component(engine_component)
	add_component(medical_component)
	add_component(weapons_component)
	
	# Initial power check
	update_power_state()
	
	# Default to starter ship class
	set_ship_class(ShipClass.STARTER)

# Set the ship class and apply the corresponding template
func set_ship_class(new_class: ShipClass) -> void:
	var old_class = ship_class
	
	if new_class in ship_class_templates:
		var template = ship_class_templates[new_class]
		
		# Apply template values
		name = template.name
		cargo_capacity = template.cargo_capacity
		crew_capacity = template.crew_capacity
		luxury_level = template.luxury_level
		fuel_efficiency = template.fuel_efficiency
		maintenance_cost = template.maintenance_cost
		power_capacity = template.power_capacity
		power_generation = template.power_generation
		
		# Configure components
		if "hull" in template.components:
			var hull_config = template.components.hull
			hull_component.durability = hull_config.durability
			hull_component.armor = hull_config.armor
			
		if "engine" in template.components:
			var engine_config = template.components.engine
			engine_component.speed = engine_config.speed
			engine_component.reliability = engine_config.reliability
			
		if "medical" in template.components:
			var medical_config = template.components.medical
			medical_component.capacity = medical_config.capacity
			medical_component.tech_level = medical_config.tech_level
			
		if "weapons" in template.components:
			var weapons_config = template.components.weapons
			if "attack" in weapons_config:
				weapons_component.weapon_damage = weapons_config.attack
			else:
				weapons_component.weapon_damage = weapons_config.damage
		
		# Set the class
		ship_class = str(new_class) # Store as string for serialization
		
		# Notify of change
		ship_class_changed.emit(old_class, ship_class)
		
		# Update power state
		update_power_state()

func add_component(component: FPCM_ShipComponent) -> bool:
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

func remove_component(component: FPCM_ShipComponent) -> bool:
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

func upgrade_component(component: FPCM_ShipComponent) -> bool:
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
			if component != hull_component: # Keep hull systems online
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

func get_active_components() -> Array[FPCM_ShipComponent]:
	var active = []
	for component in components:
		if component.is_active:
			active.append(component)
	return active

func get_inactive_components() -> Array[FPCM_ShipComponent]:
	var inactive = []
	for component in components:
		if not component.is_active:
			inactive.append(component)
	return inactive

# Get the maintenance cost based on ship class and components
func get_maintenance_cost() -> int:
	var total = maintenance_cost # Base cost from ship class
	
	# Add component maintenance costs
	for component in components:
		total += component.get_maintenance_cost()
		
	return total

# Perform regular maintenance on the ship - returns the credit cost
func perform_maintenance() -> int:
	var cost = get_maintenance_cost()
	
	# Repair all components to full
	for component in components:
		component.repair_full()
		
	# Hull gets full repair
	hull_component.repair_full()
	
	# Reset wear and tear
	for component in components:
		component.reset_wear()
		
	maintenance_performed.emit(cost)
	return cost

# Calculate fuel consumption for travel based on ship class and efficiency
func calculate_fuel_consumption(distance: int) -> int:
	var base_consumption = distance
	
	# Apply ship's fuel efficiency 
	var adjusted_consumption = int(base_consumption * fuel_efficiency)
	
	# Get modifier from crew roles
	if ship_roles:
		adjusted_consumption = ship_roles.process_travel_effects(adjusted_consumption)
	
	# Ensure minimum fuel consumption
	return max(1, adjusted_consumption)

# Get battle bonuses from ship systems and crew roles
func get_battle_bonuses() -> Dictionary:
	var bonuses = {
		"attack": weapons_component.weapon_damage,
		"damage": weapons_component.weapon_damage,
		"defense": hull_component.armor,
		"medical": medical_component.tech_level
	}
	
	# Apply crew role bonuses
	if ship_roles:
		var role_effects = ship_roles.process_battle_effects()
		bonuses.attack += role_effects.accuracy_bonus
		bonuses.medical += role_effects.medical_bonus
	
	return bonuses

# Add a new custom method to upgrade the ship class
func upgrade_ship_class(new_class: ShipClass) -> bool:
	# Ships can only upgrade to a better class
	if int(new_class) <= int(ship_class):
		return false
		
	# Apply the new ship class
	set_ship_class(new_class)
	return true

# Custom method to get the ship roles manager
func get_ship_roles() -> FiveParsecsShipRoles:
	return ship_roles

# Integrate with character manager for crew assignment
func setup_roles(character_manager) -> void:
	if ship_roles:
		ship_roles.setup(character_manager)

# Enhanced serialization to include Five Parsecs specific attributes
func serialize() -> Dictionary:
	var data = {
		"name": name,
		"description": description,
		"ship_class": ship_class,
		"level": level,
		"power_capacity": power_capacity,
		"power_generation": power_generation,
		"is_powered": is_powered,
		"power_usage": power_usage,
		"cargo_capacity": cargo_capacity,
		"crew_capacity": crew_capacity,
		"luxury_level": luxury_level,
		"fuel_efficiency": fuel_efficiency,
		"maintenance_cost": maintenance_cost,
		"hull_component": hull_component.serialize(),
		"engine_component": engine_component.serialize(),
		"medical_component": medical_component.serialize(),
		"weapons_component": weapons_component.serialize()
	}
	
	# Include ship roles data if available
	if ship_roles:
		data["ship_roles"] = ship_roles.serialize()
	
	return data

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
	
	# Five Parsecs specific attributes
	ship.cargo_capacity = data.get("cargo_capacity", 10)
	ship.crew_capacity = data.get("crew_capacity", 6)
	ship.luxury_level = data.get("luxury_level", 1)
	ship.fuel_efficiency = data.get("fuel_efficiency", 1.0)
	ship.maintenance_cost = data.get("maintenance_cost", 5)
	
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
	
	# Restore ship roles if available
	if data.has("ship_roles"):
		ship.ship_roles.deserialize(data.get("ship_roles", {}))
	
	return ship
        