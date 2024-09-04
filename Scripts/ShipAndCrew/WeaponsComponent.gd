class_name WeaponsComponent
extends ShipComponent

@export var weapon_damage: int
@export var range: int
@export var accuracy: int

func _init(p_name: String, p_description: String, p_power_usage: int, p_health: int, p_weapon_damage: int, p_range: int, p_accuracy: int) -> void:
	super._init(p_name, p_description, ComponentType.WEAPONS, p_power_usage, p_health)
	weapon_damage = p_weapon_damage
	range = p_range
	accuracy = p_accuracy

func fire() -> int:
	if not is_damaged and health > 0:
		return weapon_damage
	return 0

func serialize() -> Dictionary:
	var data = super.serialize()
	data.merge({
		"weapon_damage": weapon_damage,
		"range": range,
		"accuracy": accuracy
	})
	return data

static func deserialize(data: Dictionary) -> WeaponsComponent:
	var component = WeaponsComponent.new(
		data["name"],
		data["description"],
		data["power_usage"],
		data["max_health"],
		data["weapon_damage"],
		data["range"],
		data["accuracy"]
	)
	component.health = data["health"]
	component.is_damaged = data["is_damaged"]
	return component
