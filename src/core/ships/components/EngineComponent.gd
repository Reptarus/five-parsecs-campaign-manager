# Scripts/ShipAndCrew/EngineComponent.gd
@tool
extends "res://src/core/ships/components/ShipComponent.gd"
class_name EngineComponent

# Remove duplicate properties from parent class (renamed to engine_speed)
@export var engine_speed: float = 5.0
@export var fuel_efficiency: float = 1.0
@export var maneuverability: float = 3.0
# Removed reliability as it exists in parent class
@export var emergency_boost: bool = false
@export var jump_capability: bool = false

func _init() -> void:
	super ()
	name = "Engine"
	description = "Standard propulsion system"
	cost = 300
	power_draw = 5
	type = 1 # Set ENGINE type from parent class
	damage = 0 # Initialize damage (even though engines don't use it)
	
func _apply_upgrade_effects() -> void:
	super ()
	engine_speed += 1.0
	fuel_efficiency += 0.5
	maneuverability += 0.5
	
# Get effective speed with current efficiency
func get_speed() -> float:
	return engine_speed * get_efficiency()
	
# Get fuel usage per lightyear
func get_fuel_usage_rate() -> float:
	return 10.0 / (fuel_efficiency * get_efficiency())
	
# Get maneuverability rating
func get_maneuverability() -> float:
	return maneuverability * get_efficiency()
	
# Calculate odds of engine failure during high-stress events
func get_failure_chance() -> float:
	var base_chance = 0.1 / get_efficiency()
	return base_chance * (1.0 - get_efficiency() * 0.5)
	
# Perform emergency boost
func activate_emergency_boost() -> bool:
	if not emergency_boost or not is_active:
		return false
		
	# Apply status effect
	var effect = {
		"id": "emergency_boost",
		"name": "Emergency Boost",
		"duration": 2,
		"effect": "increased_speed",
		"value": 2.0
	}
	add_status_effect(effect)
	
	return true
	
# Attempt FTL jump
func activate_jump() -> bool:
	if not jump_capability or not is_active:
		return false
		
	# Apply wear to the engine - use damage method from parent
	apply_damage_wrapper(10)
	
	# Chance of jump failure based on efficiency
	if randf() > get_efficiency():
		# Jump failed
		var strain_effect = {
			"id": "engine_strain",
			"name": "Engine Strain",
			"duration": 3,
			"effect": "reduced_efficiency",
			"value": 0.7
		}
		add_status_effect(strain_effect)
		return false
		
	return true

# Wrapper function for applying damage to avoid confusion with damage property
func apply_damage_wrapper(amount: float) -> float:
	return apply_damage(amount)

# Getter for damage property
func get_damage() -> int:
	return damage

# Setter for damage property
func set_damage(value: int) -> bool:
	damage = value
	return true

func serialize() -> Dictionary:
	var data = super ()
	data["engine_speed"] = engine_speed
	data["fuel_efficiency"] = fuel_efficiency
	data["maneuverability"] = maneuverability
	data["emergency_boost"] = emergency_boost
	data["jump_capability"] = jump_capability
	return data
	
# Create EngineComponent from serialized data
static func create_from_data(data: Dictionary) -> EngineComponent:
	var component = EngineComponent.new()
	component.deserialize(data)
	return component

# Return serialized data with proper engine type
static func deserialize(data: Dictionary) -> Dictionary:
	var base_data = FPCM_ShipComponent.deserialize(data)
	base_data["component_type"] = "engine"
	base_data["engine_speed"] = data.get("engine_speed", 5.0)
	base_data["fuel_efficiency"] = data.get("fuel_efficiency", 1.0)
	base_data["maneuverability"] = data.get("maneuverability", 3.0)
	base_data["emergency_boost"] = data.get("emergency_boost", false)
	base_data["jump_capability"] = data.get("jump_capability", false)
	# Ensure type is correctly set for the get_stats method in the parent class
	base_data["type"] = 1 # ENGINE type from parent class
	return base_data
