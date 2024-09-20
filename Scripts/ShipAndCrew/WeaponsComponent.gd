class_name WeaponsComponent
extends "res://Scripts/ShipAndCrew/ShipComponent.gd"

@export var weapon_damage: int
@export var weapon_range: int
@export var accuracy: int

func _init(p_name: String, p_description: String, p_component_type: GlobalEnums.ComponentType, p_power_usage: int, p_health: int, p_weight: float = 1.0, p_weapon_damage: int = 0, p_weapon_range: int = 0, p_accuracy: int = 0) -> void:
	super._init(p_name, p_description, p_component_type, p_power_usage, p_health, p_weight)
	weapon_damage = p_weapon_damage
	weapon_range = p_weapon_range
	accuracy = p_accuracy

func check_if_damaged() -> bool:
	return is_damaged

func fire() -> int:
	if not is_damaged:
		return weapon_damage
	return 0

func serialize() -> Dictionary:
	var data = super.serialize()
	data.merge({
		"weapon_damage": weapon_damage,
		"weapon_range": weapon_range,
		"accuracy": accuracy
	})
	return data

static func deserialize(data: Dictionary) -> WeaponsComponent:
	var component = WeaponsComponent.new(
		data["name"],
		data["description"],
		data["type"],
		data["power_usage"],
		data["health"],
		data["weight"],
		data["weapon_damage"],
		data["weapon_range"],
		data["accuracy"]
	)
	component.is_damaged = data["is_damaged"]
	return component
