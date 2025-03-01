@tool
extends "res://src/game/ships/components/ShipComponent.gd"

var healing_rate: int = 1
var capacity: int = 2

func _init() -> void:
    component_type = GameEnums.ShipComponentType.MEDICAL_BASIC
    self.component_name = "Basic Medical Bay"
    self.component_description = "Standard medical facility for treating crew injuries"
    self.component_cost = 150
    self.power_draw = 2
    healing_rate = 1
    capacity = 2

func upgrade() -> bool:
    if super.upgrade():
        healing_rate += 1
        capacity += 1
        return true
    return false

func serialize() -> Dictionary:
    var data = super.serialize()
    data["healing_rate"] = healing_rate
    data["capacity"] = capacity
    return data

static func deserialize(data: Dictionary) -> Dictionary:
    var base_data = GameShipComponent.deserialize(data)
    
    # Add medical bay specific properties
    base_data["healing_rate"] = data.get("healing_rate", 1)
    base_data["capacity"] = data.get("capacity", 2)
    
    return base_data