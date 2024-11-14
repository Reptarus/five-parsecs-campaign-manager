# Scripts/ShipAndCrew/HullComponent.gd
class_name HullComponent
extends ShipComponent

@export var armor: int

func _init(p_name: String, p_description: String, p_power_usage: int, p_health: int, p_weight: float = 1.0, p_armor: int = 0):
	super(p_name, p_description, GlobalEnums.ShipComponentType.HULL, p_power_usage, p_health, p_weight)
	armor = p_armor

func take_damage(amount: int) -> void:
	super.take_damage(amount)
	if is_damaged:
		armor = max(0, armor - 1)  # Reduce armor by 1 when damaged, minimum 0
		push_warning("Hull damaged. Armor reduced to: %d" % armor)

func serialize() -> Dictionary:
	var data = super.serialize()
	data["armor"] = armor
	return data

static func deserialize(data: Dictionary) -> HullComponent:
	var component = HullComponent.new(
		data["name"],
		data["description"],
		data["power_usage"],
		data["health"],
		data["weight"],
		data["armor"]
	)
	component.max_health = data["max_health"]
	component.is_damaged = data["is_damaged"]
	return component

func repair(amount: int) -> void:
	super.repair(amount)
	if not is_damaged:
		push_warning("Hull repaired. Armor integrity restored to: %d" % armor)
