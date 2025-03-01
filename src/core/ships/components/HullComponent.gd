# Scripts/ShipAndCrew/HullComponent.gd
extends ShipComponent
class_name HullComponent

@export var armor: int = 10
@export var shield: int = 0
@export var cargo_capacity: int = 100
@export var crew_capacity: int = 4
@export var shield_recharge_rate: float = 0.1

var current_shield: int = 0
var current_cargo: int = 0
var current_crew: int = 0

func _init() -> void:
	super()
	name = "Hull"
	description = "Standard ship hull"
	cost = 500
	power_draw = 1
	current_shield = shield

func _apply_upgrade_effects() -> void:
	super()
	armor += 5
	shield += 5
	cargo_capacity += 25
	crew_capacity += 1
	shield_recharge_rate += 0.05
	current_shield = shield

func get_armor() -> int:
	return ceili(armor * get_efficiency())

func get_shield() -> int:
	return ceili(shield * get_efficiency())

func get_cargo_capacity() -> int:
	return ceili(cargo_capacity * get_efficiency())

func get_crew_capacity() -> int:
	return crew_capacity

func get_shield_recharge_rate() -> float:
	return shield_recharge_rate * get_efficiency()

func take_damage(amount: int) -> void:
	var remaining_damage = amount
	
	# Shield absorbs damage first
	if current_shield > 0:
		var shield_damage = mini(current_shield, remaining_damage)
		current_shield -= shield_damage
		remaining_damage -= shield_damage
	
	# Remaining damage affects durability
	if remaining_damage > 0:
		super.take_damage(remaining_damage)

func recharge_shield(delta: float) -> void:
	if current_shield < shield and is_active:
		current_shield = mini(shield, current_shield + ceili(shield_recharge_rate * delta))

func add_cargo(amount: int) -> bool:
	if current_cargo + amount <= get_cargo_capacity():
		current_cargo += amount
		return true
	return false

func remove_cargo(amount: int) -> bool:
	if current_cargo >= amount:
		current_cargo -= amount
		return true
	return false

func add_crew(amount: int) -> bool:
	if current_crew + amount <= get_crew_capacity():
		current_crew += amount
		return true
	return false

func remove_crew(amount: int) -> bool:
	if current_crew >= amount:
		current_crew -= amount
		return true
	return false

func get_cargo_space_available() -> int:
	return get_cargo_capacity() - current_cargo

func get_crew_space_available() -> int:
	return get_crew_capacity() - current_crew

func serialize() -> Dictionary:
	var data = super()
	data["armor"] = armor
	data["shield"] = shield
	data["cargo_capacity"] = cargo_capacity
	data["crew_capacity"] = crew_capacity
	data["shield_recharge_rate"] = shield_recharge_rate
	data["current_shield"] = current_shield
	data["current_cargo"] = current_cargo
	data["current_crew"] = current_crew
	return data

static func deserialize(data: Dictionary) -> HullComponent:
	var component = HullComponent.new()
	var base_data = super.deserialize(data)
	component.name = base_data.name
	component.description = base_data.description
	component.cost = base_data.cost
	component.level = base_data.level
	component.max_level = base_data.max_level
	component.is_active = base_data.is_active
	component.upgrade_cost = base_data.upgrade_cost
	component.maintenance_cost = base_data.maintenance_cost
	component.durability = base_data.durability
	component.max_durability = base_data.max_durability
	component.efficiency = base_data.efficiency
	component.power_draw = base_data.power_draw
	component.status_effects = base_data.status_effects
	
	component.armor = data.get("armor", 10)
	component.shield = data.get("shield", 0)
	component.cargo_capacity = data.get("cargo_capacity", 100)
	component.crew_capacity = data.get("crew_capacity", 4)
	component.shield_recharge_rate = data.get("shield_recharge_rate", 0.1)
	component.current_shield = data.get("current_shield", component.shield)
	component.current_cargo = data.get("current_cargo", 0)
	component.current_crew = data.get("current_crew", 0)
	return component
