class_name ResourceManager
extends Node

const GlobalEnums = preload("res://Resources/GameData/GlobalEnums.gd")

signal resource_changed(type: GlobalEnums.ResourceType, amount: int)
signal resource_depleted(type: GlobalEnums.ResourceType)

const STARTING_RESOURCES = {
    GlobalEnums.ResourceType.CREDITS: 1000,
    GlobalEnums.ResourceType.FUEL: 100,
    GlobalEnums.ResourceType.SUPPLIES: 50,
    GlobalEnums.ResourceType.MATERIALS: 25,
    GlobalEnums.ResourceType.INFORMATION: 0
}

var resources: Dictionary = {}
var consumption_rates: Dictionary = {}

func _init() -> void:
    reset_resources()

func reset_resources() -> void:
    resources = STARTING_RESOURCES.duplicate()
    for type in GlobalEnums.ResourceType.values():
        consumption_rates[type] = 0.0

func modify_resource(type: GlobalEnums.ResourceType, amount: int) -> bool:
    if not resources.has(type):
        push_error("Invalid resource type")
        return false
        
    resources[type] = max(0, resources[type] + amount)
    resource_changed.emit(type, resources[type])
    
    if resources[type] <= 0:
        resource_depleted.emit(type)
    return true

func has_sufficient_resources(requirements: Dictionary) -> bool:
    for type in requirements:
        if not resources.has(type) or resources[type] < requirements[type]:
            return false
    return true
