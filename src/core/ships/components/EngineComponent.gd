# Scripts/ShipAndCrew/EngineComponent.gd
@tool
extends FPCM_ShipComponent
class_name EngineComponent

@export var speed: float = 5.0
@export var fuel_efficiency: float = 1.0
@export var maneuverability: float = 0.8
@export var reliability: float = 0.9
@export var emergency_boost: bool = false
@export var jump_capability: bool = false

func _init() -> void:
	super()
	name = "Engine"
	description = "Standard propulsion system"
	cost = 300
	power_draw = 5
	
func _apply_upgrade_effects() -> void:
	super()
	speed += 1.0
	fuel_efficiency += 0.1
	maneuverability += 0.05
	reliability += 0.05

func get_speed() -> float:
	return speed * get_efficiency()

func get_fuel_efficiency() -> float:
	return fuel_efficiency * get_efficiency()

func get_maneuverability() -> float:
	return maneuverability * get_efficiency()

func is_functional() -> bool:
	return is_active and durability > 0

func check_engine_failure() -> bool:
	# Additional engine-specific failure check
	var base_failure_chance = check_failure()
	var engine_specific_reliability = reliability * (float(durability) / float(max_durability))
	
	return base_failure_chance or (randf() > engine_specific_reliability)

func activate_emergency_boost() -> bool:
	if not emergency_boost or not is_functional():
		return false
		
	# Emergency boost causes wear
	increase_wear()
	return true

func perform_jump() -> bool:
	if not jump_capability or not is_functional():
		return false
		
	# Jumping causes stress on the engine
	if randf() < 0.3:
		increase_wear()
	return true

func serialize() -> Dictionary:
	var data = super()
	data["speed"] = speed
	data["fuel_efficiency"] = fuel_efficiency
	data["maneuverability"] = maneuverability
	data["reliability"] = reliability
	data["emergency_boost"] = emergency_boost
	data["jump_capability"] = jump_capability
	return data

# Factory method to create EngineComponent from data
static func create_from_data(data: Dictionary) -> EngineComponent:
	var component = EngineComponent.new()
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
	
	# Engine-specific properties
	component.speed = data.get("speed", 5.0)
	component.fuel_efficiency = data.get("fuel_efficiency", 1.0)
	component.maneuverability = data.get("maneuverability", 0.8)
	component.reliability = data.get("reliability", 0.9)
	component.emergency_boost = data.get("emergency_boost", false)
	component.jump_capability = data.get("jump_capability", false)
	
	return component

# Return serialized data with proper engine type
static func deserialize(data: Dictionary) -> Dictionary:
	var base_data = FPCM_ShipComponent.deserialize(data)
	base_data["component_type"] = "engine"
	base_data["speed"] = data.get("speed", 5.0)
	base_data["fuel_efficiency"] = data.get("fuel_efficiency", 1.0)
	base_data["maneuverability"] = data.get("maneuverability", 0.8)
	base_data["reliability"] = data.get("reliability", 0.9)
	base_data["emergency_boost"] = data.get("emergency_boost", false)
	base_data["jump_capability"] = data.get("jump_capability", false)
	return base_data
