# Scripts/ShipAndCrew/WeaponsComponent.gd
@tool
extends "res://src/core/ships/components/ShipComponent.gd"
class_name WeaponsComponent

@export var weapon_damage: int = 10
@export var range: float = 500.0
@export var accuracy: float = 0.75
@export var fire_rate: float = 1.0
@export var energy_cost: int = 1
@export var weapon_type: int = 0
@export var additional_effects: Array = []

func _init() -> void:
	super ()
	name = "Weapons"
	description = "Standard weapon system"
	cost = 250
	power_draw = 3

func _apply_upgrade_effects() -> void:
	super ()
	weapon_damage += 2
	accuracy += 0.05
	fire_rate += 0.1

func get_damage() -> int:
	return int(weapon_damage * get_efficiency())

func get_accuracy() -> float:
	return accuracy * get_efficiency()

func get_fire_rate() -> float:
	return fire_rate * get_efficiency()

func is_functional() -> bool:
	return is_active and durability > 0

func can_fire() -> bool:
	return is_functional()

func serialize() -> Dictionary:
	var data = super ()
	data["weapon_damage"] = weapon_damage
	data["range"] = range
	data["accuracy"] = accuracy
	data["fire_rate"] = fire_rate
	data["energy_cost"] = energy_cost
	data["weapon_type"] = weapon_type
	data["additional_effects"] = additional_effects
	return data

# Factory method to create WeaponsComponent from data
static func create_from_data(data: Dictionary) -> WeaponsComponent:
	var component = WeaponsComponent.new()
	var base_data = FPCM_ShipComponent.deserialize(data)
	
	# Copy base data
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
	
	# Weapons-specific properties
	component.weapon_damage = data.get("weapon_damage", 10)
	if data.has("damage"): # For backward compatibility
		component.weapon_damage = data.get("damage", 10)
	component.range = data.get("range", 500.0)
	component.accuracy = data.get("accuracy", 0.75)
	component.fire_rate = data.get("fire_rate", 1.0)
	component.energy_cost = data.get("energy_cost", 1)
	component.weapon_type = data.get("weapon_type", 0)
	component.additional_effects = data.get("additional_effects", [])
	
	return component

# Return serialized data with proper weapons type
static func deserialize(data: Dictionary) -> Dictionary:
	var base_data = FPCM_ShipComponent.deserialize(data)
	base_data["component_type"] = "weapons"
	base_data["weapon_damage"] = data.get("weapon_damage", 10)
	if data.has("damage"): # For backward compatibility
		base_data["weapon_damage"] = data.get("damage", 10)
	base_data["range"] = data.get("range", 500.0)
	base_data["accuracy"] = data.get("accuracy", 0.75)
	base_data["fire_rate"] = data.get("fire_rate", 1.0)
	base_data["energy_cost"] = data.get("energy_cost", 1)
	base_data["weapon_type"] = data.get("weapon_type", 0)
	base_data["additional_effects"] = data.get("additional_effects", [])
	return base_data
