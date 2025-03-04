# Scripts/ShipAndCrew/LifeSupportComponent.gd
@tool
extends "res://src/core/ships/components/ShipComponent.gd"
class_name FPCM_LifeSupportComponent

const ShipComponentClass = preload("res://src/core/ships/components/ShipComponent.gd")

@export var oxygen_generation: float = 1.0
@export var crew_capacity: int = 6
@export var life_support_quality: float = 1.0
@export var air_recycling_efficiency: float = 0.8
@export var temperature_control: float = 1.0
@export var has_emergency_systems: bool = false
@export var radiation_protection: float = 0.7

func _init() -> void:
	super()
	name = "Life Support"
	description = "Basic life support system"
	cost = 250
	power_draw = 4
	
func _apply_upgrade_effects() -> void:
	super()
	oxygen_generation += 0.2
	life_support_quality += 0.15
	air_recycling_efficiency += 0.05
	temperature_control += 0.1
	radiation_protection += 0.05

func get_oxygen_generation() -> float:
	return oxygen_generation * get_efficiency()

func get_effective_capacity() -> int:
	var base_capacity = crew_capacity
	if has_emergency_systems:
		base_capacity += 2
	return base_capacity

func get_life_quality_rating() -> float:
	return life_support_quality * get_efficiency()

func get_recycling_rating() -> float:
	return air_recycling_efficiency * get_efficiency()

func get_temperature_rating() -> float:
	return temperature_control * get_efficiency()

func get_radiation_protection() -> float:
	return radiation_protection * get_efficiency()

func is_functional() -> bool:
	return is_active and durability > 0

func check_life_support_failure() -> bool:
	var base_failure = check_failure()
	
	# Critical system - additional safety check
	if base_failure and has_emergency_systems:
		# Emergency systems give a second chance
		return randf() < 0.3 # 30% chance of failure even with emergency systems
	
	return base_failure

func handle_environmental_hazard(hazard_type: int, hazard_level: float) -> float:
	var damage_reduction = 0.0
	
	if not is_functional():
		return 0.0
	
	match hazard_type:
		0: # Radiation
			damage_reduction = get_radiation_protection()
		1: # Temperature (heat/cold)
			damage_reduction = get_temperature_rating() * 0.8
		2: # Toxic atmosphere
			damage_reduction = get_oxygen_generation() * 0.7
		3: # Pressure issues
			damage_reduction = get_recycling_rating() * 0.5
	
	# Reduce hazard by the calculated amount
	var reduced_hazard = max(0.0, hazard_level - (damage_reduction * hazard_level))
	
	# Life support takes wear from handling hazards
	if hazard_level > 0.5:
		increase_wear()
	
	return reduced_hazard

func serialize() -> Dictionary:
	var data = super()
	data["oxygen_generation"] = oxygen_generation
	data["crew_capacity"] = crew_capacity
	data["life_support_quality"] = life_support_quality
	data["air_recycling_efficiency"] = air_recycling_efficiency
	data["temperature_control"] = temperature_control
	data["has_emergency_systems"] = has_emergency_systems
	data["radiation_protection"] = radiation_protection
	return data

# Factory method to create LifeSupportComponent from data
static func create_from_data(data: Dictionary) -> Resource:
	# Use direct instantiation
	var component = new()
	var base_data = ShipComponentClass.deserialize(data)
	
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
	
	# Life support-specific properties
	component.oxygen_generation = data.get("oxygen_generation", 1.0)
	component.crew_capacity = data.get("crew_capacity", 6)
	component.life_support_quality = data.get("life_support_quality", 1.0)
	component.air_recycling_efficiency = data.get("air_recycling_efficiency", 0.8)
	component.temperature_control = data.get("temperature_control", 1.0)
	component.has_emergency_systems = data.get("has_emergency_systems", false)
	component.radiation_protection = data.get("radiation_protection", 0.7)
	
	return component

# Return serialized data with proper life support type
static func deserialize(data: Dictionary) -> Dictionary:
	var base_data = ShipComponentClass.deserialize(data)
	base_data["component_type"] = "life_support"
	base_data["oxygen_generation"] = data.get("oxygen_generation", 1.0)
	base_data["crew_capacity"] = data.get("crew_capacity", 6)
	base_data["life_support_quality"] = data.get("life_support_quality", 1.0)
	base_data["air_recycling_efficiency"] = data.get("air_recycling_efficiency", 0.8)
	base_data["temperature_control"] = data.get("temperature_control", 1.0)
	base_data["has_emergency_systems"] = data.get("has_emergency_systems", false)
	base_data["radiation_protection"] = data.get("radiation_protection", 0.7)
	return base_data