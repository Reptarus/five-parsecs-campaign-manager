# Scripts/ShipAndCrew/ShipComponent.gd
class_name ShipComponent
extends Resource

const GameEnums = preload("res://Resources/Core/Systems/GlobalEnums.gd")

signal component_state_changed
signal component_repaired
signal component_damaged

@export var name: String = ""
@export var description: String = ""
@export var component_type: GlobalEnums.ShipComponentType = GlobalEnums.ShipComponentType.HULL
@export var power_usage: int = 0
@export var health: int = 0
@export var max_health: int = 0
@export var is_damaged: bool = false
@export var weight: float = 1.0

func _init(p_name: String = "", 
          p_description: String = "", 
          p_component_type: GlobalEnums.ShipComponentType = GlobalEnums.ShipComponentType.HULL, 
          p_power_usage: int = 0, 
          p_health: int = 0, 
          p_weight: float = 1.0) -> void:
    name = p_name
    description = p_description
    component_type = p_component_type
    power_usage = p_power_usage
    health = p_health
    max_health = p_health
    weight = p_weight

func take_damage(amount: int) -> void:
    if amount < 0:
        push_error("Damage amount cannot be negative")
        return
        
    health = max(0, health - amount)
    if health == 0:
        damage()
    component_state_changed.emit()

func repair(amount: int) -> void:
    if amount < 0:
        push_error("Repair amount cannot be negative")
        return
        
    health = min(max_health, health + amount)
    if health > 0 and is_damaged:
        is_damaged = false
        component_repaired.emit()
    component_state_changed.emit()

func damage() -> void:
    if not is_damaged:
        is_damaged = true
        component_damaged.emit()

func get_effectiveness() -> float:
    return 1.0 if not is_damaged else 0.5

func serialize() -> Dictionary:
    return {
        "name": name,
        "description": description,
        "component_type": GlobalEnums.ShipComponentType.keys()[component_type],
        "power_usage": power_usage,
        "health": health,
        "max_health": max_health,
        "is_damaged": is_damaged,
        "weight": weight
    }

static func deserialize(data: Dictionary) -> ShipComponent:
    var component = ShipComponent.new(
        data["name"],
        data["description"],
        GlobalEnums.ShipComponentType[data["component_type"]],
        data["power_usage"],
        data["health"],
        data["weight"]
    )
    component.max_health = data["max_health"]
    component.is_damaged = data["is_damaged"]
    return component

func _to_string() -> String:
    return "%s (%s, Health: %d/%d)" % [name, GlobalEnums.ShipComponentType.keys()[component_type], health, max_health]