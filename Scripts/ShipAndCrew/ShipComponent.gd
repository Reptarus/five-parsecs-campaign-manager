class_name ShipComponent
extends Node

# Add your ShipComponent properties and methods here

enum ComponentType { 
    ENGINE,
    WEAPONS,
    SHIELDS,
    LIFE_SUPPORT,
    SENSORS,
    COMMUNICATIONS,
    CARGO_HOLD,
    MEDICAL_BAY,
    REACTOR,
    NAVIGATION
}

var component_name: String
var type: ComponentType
var power_usage: int
var health: int
var max_health: int
var is_damaged: bool

func _init(p_name: String, p_type: ComponentType, p_power_usage: int, p_health: int, p_is_damaged: bool) -> void:
	component_name = p_name
	type = p_type
	power_usage = p_power_usage
	max_health = p_health
	health = p_health
	is_damaged = p_is_damaged

# Add other common methods here
