@tool
extends "res://src/game/ships/components/ShipComponent.gd"

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

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

static func deserialize(data: Dictionary) -> Resource:
    var component = MedicalBayComponent.new()
    var base_data = super.deserialize(data)
    for key in base_data:
        component.set(key, base_data[key])
    component.healing_rate = data.get("healing_rate", 1)
    component.capacity = data.get("capacity", 2)
    return component 