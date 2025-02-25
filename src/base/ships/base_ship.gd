@tool
extends Resource

## Base class for ship systems
##
## Provides core functionality for managing ships, components, and ship state.

signal component_added(component: Resource)
signal component_removed(component: Resource)
signal ship_damaged(amount: int)
signal ship_repaired(amount: int)
signal power_state_changed(available: int, required: int)

# Ship properties
@export var ship_name: String = ""
@export var description: String = ""
@export var ship_class: String = ""
@export var level: int = 1
@export var power_capacity: int = 10
@export var power_generation: int = 5
@export var hull_points: int = 100
@export var max_hull_points: int = 100

# Ship state
var is_powered: bool = true
var power_usage: int = 0
var components: Array[Resource] = []

func _init() -> void:
    pass

# Component management
func add_component(component: Resource) -> bool:
    if not component:
        push_error("Cannot add null component")
        return false
        
    if component in components:
        push_warning("Component already installed")
        return false
        
    components.append(component)
    update_power_state()
    component_added.emit(component)
    return true

func remove_component(component: Resource) -> bool:
    if not component:
        push_error("Cannot remove null component")
        return false
        
    if not component in components:
        push_warning("Component not found")
        return false
        
    components.erase(component)
    update_power_state()
    component_removed.emit(component)
    return true

# Ship state management
func take_damage(amount: int) -> void:
    hull_points = maxi(0, hull_points - amount)
    ship_damaged.emit(amount)
    update_power_state()

func repair(amount: int) -> void:
    hull_points = mini(max_hull_points, hull_points + amount)
    ship_repaired.emit(amount)
    update_power_state()

func update_power_state() -> void:
    var available_power = power_generation
    var required_power = calculate_power_usage()
    
    is_powered = available_power >= required_power
    power_state_changed.emit(available_power, required_power)

# Utility methods
func calculate_power_usage() -> int:
    return power_usage

func get_power_usage() -> int:
    return power_usage

func get_power_available() -> int:
    return power_generation

func get_component_count() -> int:
    return components.size()

func get_hull_percentage() -> float:
    return float(hull_points) / float(max_hull_points) * 100.0

# Serialization
func serialize() -> Dictionary:
    return {
        "ship_name": ship_name,
        "description": description,
        "ship_class": ship_class,
        "level": level,
        "power_capacity": power_capacity,
        "power_generation": power_generation,
        "hull_points": hull_points,
        "max_hull_points": max_hull_points,
        "is_powered": is_powered,
        "power_usage": power_usage
    }

func deserialize(data: Dictionary) -> void:
    ship_name = data.get("ship_name", "")
    description = data.get("description", "")
    ship_class = data.get("ship_class", "")
    level = data.get("level", 1)
    power_capacity = data.get("power_capacity", 10)
    power_generation = data.get("power_generation", 5)
    hull_points = data.get("hull_points", 100)
    max_hull_points = data.get("max_hull_points", 100)
    is_powered = data.get("is_powered", true)
    power_usage = data.get("power_usage", 0)