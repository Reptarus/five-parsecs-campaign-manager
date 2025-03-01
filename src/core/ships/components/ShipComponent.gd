# Scripts/ShipAndCrew/ShipComponent.gd
extends Resource
class_name ShipComponent

@export var name: String = ""
@export var description: String = ""
@export var cost: int = 0
@export var level: int = 1
@export var max_level: int = 3
@export var is_active: bool = true
@export var upgrade_cost: int = 100
@export var maintenance_cost: int = 10
@export var durability: int = 100
@export var max_durability: int = 100
@export var efficiency: float = 1.0
@export var power_draw: int = 1
@export var status_effects: Array = []

func _init() -> void:
    name = ""
    description = ""
    cost = 0
    level = 1
    max_level = 3
    is_active = true
    upgrade_cost = 100
    maintenance_cost = 10
    durability = 100
    max_durability = 100
    efficiency = 1.0
    power_draw = 1
    status_effects = []

func can_upgrade() -> bool:
    return level < max_level

func upgrade() -> bool:
    if not can_upgrade():
        return false
    level += 1
    _apply_upgrade_effects()
    return true

func repair(amount: int) -> void:
    durability = mini(durability + amount, max_durability)

func take_damage(amount: int) -> void:
    durability = maxi(0, durability - amount)
    if durability == 0:
        deactivate()

func activate() -> void:
    is_active = true

func deactivate() -> void:
    is_active = false

func get_efficiency() -> float:
    var base_efficiency = efficiency * (float(durability) / float(max_durability))
    return base_efficiency * (1.0 + (level - 1) * 0.2)

func get_power_consumption() -> int:
    return power_draw * level

func get_maintenance_cost() -> int:
    return maintenance_cost * level

func get_upgrade_cost() -> int:
    return upgrade_cost * level

func add_status_effect(effect: Dictionary) -> void:
    if not status_effects.has(effect):
        status_effects.append(effect)

func remove_status_effect(effect: Dictionary) -> void:
    status_effects.erase(effect)

func clear_status_effects() -> void:
    status_effects.clear()

func _apply_upgrade_effects() -> void:
    efficiency += 0.2
    max_durability += 25
    durability = max_durability
    maintenance_cost = get_maintenance_cost()
    power_draw = get_power_consumption()

func serialize() -> Dictionary:
    return {
        "name": name,
        "description": description,
        "cost": cost,
        "level": level,
        "max_level": max_level,
        "is_active": is_active,
        "upgrade_cost": upgrade_cost,
        "maintenance_cost": maintenance_cost,
        "durability": durability,
        "max_durability": max_durability,
        "efficiency": efficiency,
        "power_draw": power_draw,
        "status_effects": status_effects
    }

static func deserialize(data: Dictionary) -> ShipComponent:
    var component = ShipComponent.new()
    component.name = data.get("name", "")
    component.description = data.get("description", "")
    component.cost = data.get("cost", 0)
    component.level = data.get("level", 1)
    component.max_level = data.get("max_level", 3)
    component.is_active = data.get("is_active", true)
    component.upgrade_cost = data.get("upgrade_cost", 100)
    component.maintenance_cost = data.get("maintenance_cost", 10)
    component.durability = data.get("durability", 100)
    component.max_durability = data.get("max_durability", 100)
    component.efficiency = data.get("efficiency", 1.0)
    component.power_draw = data.get("power_draw", 1)
    component.status_effects = data.get("status_effects", [])
    return component