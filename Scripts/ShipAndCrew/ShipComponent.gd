class_name ShipComponent
extends Resource

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

var name: String
var type: ComponentType
var power_usage: int
var durability: int
var is_damaged: bool

func _init(p_name: String, p_type: ComponentType, p_power_usage: int, p_durability: int, p_is_damaged: bool = false):
	name = p_name
	type = p_type
	power_usage = p_power_usage
	durability = p_durability
	is_damaged = p_is_damaged

static func deserialize(data: Dictionary) -> ShipComponent:
	var component = ShipComponent.new(
		data["name"],
		ComponentType[data["type"]],
		data["power_usage"],
		data["durability"],
		data["is_damaged"]
	)
	return component
