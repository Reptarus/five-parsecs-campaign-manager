class_name WeaponsComponent
extends ShipComponent

@export var damage: int
@export var range: int
@export var accuracy: int

func _init() -> void:
	type = ComponentType.WEAPONS

func fire() -> int:
	if is_active and health > 0:
		return damage
	return 0

func to_dict() -> Dictionary:
	var data := super.to_dict()
	data["damage"] = damage
	data["range"] = range
	data["accuracy"] = accuracy
	return data

static func from_dict(data: Dictionary) -> WeaponsComponent:
	var component := WeaponsComponent.new()
	component.damage = data["damage"]
	component.range = data["range"]
	component.accuracy = data["accuracy"]
	return component
