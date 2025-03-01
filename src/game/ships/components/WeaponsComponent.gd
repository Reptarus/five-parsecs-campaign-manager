@tool
extends "res://src/game/ships/components/ShipComponent.gd"

var damage: int = 2
var range: int = 3
var accuracy: float = 0.7

func _init() -> void:
    component_type = GameEnums.ShipComponentType.WEAPON_BASIC_LASER
    self.component_name = "Basic Laser Weapon"
    self.component_description = "Standard ship weapon system"
    self.component_cost = 300
    self.power_draw = 3
    damage = 2
    range = 3
    accuracy = 0.7

func upgrade() -> bool:
    if super.upgrade():
        damage += 1
        accuracy += 0.1
        return true
    return false

func serialize() -> Dictionary:
    var data = super.serialize()
    data["damage"] = damage
    data["range"] = range
    data["accuracy"] = accuracy
    return data

static func deserialize(data: Dictionary) -> Dictionary:
    var base_data = GameShipComponent.deserialize(data)
    
    # Add weapon-specific properties
    base_data["damage"] = data.get("damage", 2)
    base_data["range"] = data.get("range", 3)
    base_data["accuracy"] = data.get("accuracy", 0.7)
    
    return base_data