@tool
extends "res://tests/fixtures/base/game_test.gd"
# Use explicit preloads instead of global class names
# Skip self-reference preload since it causes linter errors

# Create a mock EngineComponent class for testing purposes
class MockEngineComponent extends RefCounted:
	var name: String = "Engine"
	var description: String = "Standard ship engine"
	var cost: int = 100
	var power_draw: int = 10
	var thrust: float = 5.0
	var fuel_efficiency: float = 2.0
	var maneuverability: float = 3.0
	var max_speed: float = 10.0
	var level: int = 1
	var durability: int = 100
	var efficiency: float = 1.0
	
	func get_name() -> String: return name
	func get_description() -> String: return description
	func get_cost() -> int: return cost
	func get_power_draw() -> int: return power_draw
	func get_thrust() -> float: return thrust * efficiency
	func get_fuel_efficiency() -> float: return fuel_efficiency * efficiency
	func get_maneuverability() -> float: return maneuverability * efficiency
	func get_max_speed() -> float: return max_speed * efficiency
	func get_level() -> int: return level
	func get_durability() -> int: return durability
	
	func set_efficiency(value: float) -> bool:
		efficiency = value
		return true
		
	func upgrade() -> bool:
		thrust += 1.0
		fuel_efficiency += 0.5
		maneuverability += 1.0
		max_speed += 2.0
		level += 1
		return true
		
	func set_thrust(value: float) -> bool:
		thrust = value
		return true
	
	func set_fuel_efficiency(value: float) -> bool:
		fuel_efficiency = value
		return true
	
	func set_maneuverability(value: float) -> bool:
		maneuverability = value
		return true
	
	func set_max_speed(value: float) -> bool:
		max_speed = value
		return true
	
	func set_level(value: int) -> bool:
		level = value
		return true
	
	func set_durability(value: int) -> bool:
		durability = value
		return true
		
	func serialize() -> Dictionary:
		return {
			"name": name,
			"description": description,
			"cost": cost,
			"power_draw": power_draw,
			"thrust": thrust,
			"fuel_efficiency": fuel_efficiency,
			"maneuverability": maneuverability,
			"max_speed": max_speed,
			"level": level,
			"durability": durability
		}
		
	func deserialize(data: Dictionary) -> bool:
		name = data.get("name", name)
		description = data.get("description", description)
		cost = data.get("cost", cost)
		power_draw = data.get("power_draw", power_draw)
		thrust = data.get("thrust", thrust)
		fuel_efficiency = data.get("fuel_efficiency", fuel_efficiency)
		maneuverability = data.get("maneuverability", maneuverability)
		max_speed = data.get("max_speed", max_speed)
		level = data.get("level", level)
		durability = data.get("durability", durability)
		return true

# Create a mockup of GameEnums
class ShipGameEnumsMock:
	const ENGINE_BASE_COST = 100
	const ENGINE_POWER_DRAW = 10
	const ENGINE_BASE_THRUST = 5.0
	const ENGINE_BASE_FUEL_EFFICIENCY = 2.0
	const ENGINE_BASE_MANEUVERABILITY = 3.0
	const ENGINE_BASE_MAX_SPEED = 10.0
	const ENGINE_UPGRADE_THRUST = 1.0
	const ENGINE_UPGRADE_FUEL_EFFICIENCY = 0.5
	const ENGINE_UPGRADE_MANEUVERABILITY = 1.0
	const ENGINE_UPGRADE_MAX_SPEED = 2.0
	const ENGINE_MAX_THRUST = 10.0
	const ENGINE_MAX_FUEL_EFFICIENCY = 5.0
	const ENGINE_MAX_MANEUVERABILITY = 8.0
	const ENGINE_MAX_SPEED = 20.0
	const ENGINE_MAX_LEVEL = 5
	const ENGINE_TEST_DURABILITY = 80
	const HALF_EFFICIENCY = 0.5

# Try to get the actual component or use our mock
var EngineComponent = null
var ship_enums = null

# Helper method to initialize our test environment
func _initialize_test_environment() -> void:
	# Try to load the real EngineComponent
	var engine_script = load("res://src/core/ships/components/EngineComponent.gd")
	if engine_script:
		EngineComponent = engine_script
	else:
		# Use our mock if the real one isn't available
		EngineComponent = MockEngineComponent
	
	# Try to load the real GameEnums or use our mock
	var enums_script = load("res://src/core/systems/GlobalEnums.gd")
	if enums_script:
		ship_enums = enums_script
	else:
		ship_enums = ShipGameEnumsMock

# Type-safe instance variables
var engine = null

# Access constants safely
func _get_engine_constant(name: String, default_value = 0):
	if ship_enums == null:
		return default_value
		
	if ship_enums is ShipGameEnumsMock:
		# Get from our mock enum class
		return ship_enums.get(name) if name in ship_enums else default_value
	else:
		# Try to access from real ship_enums using get() or fallback to constant
		if typeof(ship_enums) == TYPE_OBJECT:
			# Try to access via property path
			if name in ship_enums:
				return ship_enums[name]
			# Try to access attribute directly
			var property_value = null
			if ship_enums.get(name) != null:
				property_value = ship_enums.get(name)
			if property_value != null:
				return property_value
			return default_value
		return default_value

func before_each() -> void:
	await super.before_each()
	
	# Initialize our test environment
	_initialize_test_environment()
	
	# Create the engine component
	engine = EngineComponent.new()
	if not engine:
		push_error("Failed to create engine component")
		return
	
	track_test_resource(engine)
	await get_tree().process_frame

func after_each() -> void:
	await super.after_each()
	engine = null

func test_initialization() -> void:
	assert_not_null(engine, "Engine component should be initialized")
	
	var name: String = _call_node_method_string(engine, "get_name", [], "")
	var description: String = _call_node_method_string(engine, "get_description", [], "")
	var cost: int = _call_node_method_int(engine, "get_cost", [], 0)
	var power_draw: int = _call_node_method_int(engine, "get_power_draw", [], 0)
	
	assert_eq(name, "Engine", "Should initialize with correct name")
	assert_eq(description, "Standard ship engine", "Should initialize with correct description")
	assert_eq(cost, _get_engine_constant("ENGINE_BASE_COST", 100), "Should initialize with correct cost")
	assert_eq(power_draw, _get_engine_constant("ENGINE_POWER_DRAW", 10), "Should initialize with correct power draw")
	
	# Test engine-specific properties
	var thrust: float = _call_node_method_float(engine, "get_thrust", [], 0.0)
	var fuel_efficiency: float = _call_node_method_float(engine, "get_fuel_efficiency", [], 0.0)
	var maneuverability: float = _call_node_method_float(engine, "get_maneuverability", [], 0.0)
	var max_speed: float = _call_node_method_float(engine, "get_max_speed", [], 0.0)
	
	assert_eq(thrust, _get_engine_constant("ENGINE_BASE_THRUST", 5.0), "Should initialize with base thrust")
	assert_eq(fuel_efficiency, _get_engine_constant("ENGINE_BASE_FUEL_EFFICIENCY", 2.0), "Should initialize with base fuel efficiency")
	assert_eq(maneuverability, _get_engine_constant("ENGINE_BASE_MANEUVERABILITY", 3.0), "Should initialize with base maneuverability")
	assert_eq(max_speed, _get_engine_constant("ENGINE_BASE_MAX_SPEED", 10.0), "Should initialize with base max speed")

func test_upgrade_effects() -> void:
	# Store initial values
	var initial_thrust: float = _call_node_method_float(engine, "get_thrust", [], 0.0)
	var initial_fuel_efficiency: float = _call_node_method_float(engine, "get_fuel_efficiency", [], 0.0)
	var initial_maneuverability: float = _call_node_method_float(engine, "get_maneuverability", [], 0.0)
	var initial_max_speed: float = _call_node_method_float(engine, "get_max_speed", [], 0.0)
	
	# Perform upgrade
	_call_node_method_bool(engine, "upgrade", [])
	
	# Test improvements
	var new_thrust: float = _call_node_method_float(engine, "get_thrust", [], 0.0)
	var new_fuel_efficiency: float = _call_node_method_float(engine, "get_fuel_efficiency", [], 0.0)
	var new_maneuverability: float = _call_node_method_float(engine, "get_maneuverability", [], 0.0)
	var new_max_speed: float = _call_node_method_float(engine, "get_max_speed", [], 0.0)
	
	var upgrade_thrust: float = _get_engine_constant("ENGINE_UPGRADE_THRUST", 1.0)
	var upgrade_fuel_efficiency: float = _get_engine_constant("ENGINE_UPGRADE_FUEL_EFFICIENCY", 0.5)
	var upgrade_maneuverability: float = _get_engine_constant("ENGINE_UPGRADE_MANEUVERABILITY", 1.0)
	var upgrade_max_speed: float = _get_engine_constant("ENGINE_UPGRADE_MAX_SPEED", 2.0)
	
	assert_eq(new_thrust, initial_thrust + upgrade_thrust, "Should increase thrust on upgrade")
	assert_eq(new_fuel_efficiency, initial_fuel_efficiency + upgrade_fuel_efficiency, "Should increase fuel efficiency on upgrade")
	assert_eq(new_maneuverability, initial_maneuverability + upgrade_maneuverability, "Should increase maneuverability on upgrade")
	assert_eq(new_max_speed, initial_max_speed + upgrade_max_speed, "Should increase max speed on upgrade")

func test_efficiency_effects() -> void:
	# Test base values at full efficiency
	var base_thrust: float = _call_node_method_float(engine, "get_thrust", [], 0.0)
	var base_fuel_efficiency: float = _call_node_method_float(engine, "get_fuel_efficiency", [], 0.0)
	var base_maneuverability: float = _call_node_method_float(engine, "get_maneuverability", [], 0.0)
	var base_max_speed: float = _call_node_method_float(engine, "get_max_speed", [], 0.0)
	
	var base_thrust_expected: float = _get_engine_constant("ENGINE_BASE_THRUST", 5.0)
	var base_fuel_efficiency_expected: float = _get_engine_constant("ENGINE_BASE_FUEL_EFFICIENCY", 2.0)
	var base_maneuverability_expected: float = _get_engine_constant("ENGINE_BASE_MANEUVERABILITY", 3.0)
	var base_max_speed_expected: float = _get_engine_constant("ENGINE_BASE_MAX_SPEED", 10.0)
	
	assert_eq(base_thrust, base_thrust_expected, "Should return base thrust at full efficiency")
	assert_eq(base_fuel_efficiency, base_fuel_efficiency_expected, "Should return base fuel efficiency at full efficiency")
	assert_eq(base_maneuverability, base_maneuverability_expected, "Should return base maneuverability at full efficiency")
	assert_eq(base_max_speed, base_max_speed_expected, "Should return base max speed at full efficiency")
	
	# Test values at reduced efficiency
	var half_efficiency: float = _get_engine_constant("HALF_EFFICIENCY", 0.5)
	_call_node_method_bool(engine, "set_efficiency", [half_efficiency])
	
	var reduced_thrust: float = _call_node_method_float(engine, "get_thrust", [], 0.0)
	var reduced_fuel_efficiency: float = _call_node_method_float(engine, "get_fuel_efficiency", [], 0.0)
	var reduced_maneuverability: float = _call_node_method_float(engine, "get_maneuverability", [], 0.0)
	var reduced_max_speed: float = _call_node_method_float(engine, "get_max_speed", [], 0.0)
	
	assert_eq(reduced_thrust, base_thrust_expected * half_efficiency, "Should reduce thrust with efficiency")
	assert_eq(reduced_fuel_efficiency, base_fuel_efficiency_expected * half_efficiency, "Should reduce fuel efficiency with efficiency")
	assert_eq(reduced_maneuverability, base_maneuverability_expected * half_efficiency, "Should reduce maneuverability with efficiency")
	assert_eq(reduced_max_speed, base_max_speed_expected * half_efficiency, "Should reduce max speed with efficiency")

func test_serialization() -> void:
	# Modify engine state
	_call_node_method_bool(engine, "set_max_thrust", [_get_engine_constant("ENGINE_MAX_THRUST", 200)])
	_call_node_method_bool(engine, "set_thrust", [_get_engine_constant("ENGINE_MAX_THRUST", 200) - 50])
	_call_node_method_bool(engine, "set_fuel_efficiency", [_get_engine_constant("ENGINE_MAX_FUEL_EFFICIENCY", 8.0)])
	_call_node_method_bool(engine, "set_max_stress", [_get_engine_constant("ENGINE_MAX_STRESS", 100)])
	_call_node_method_bool(engine, "set_stress", [_get_engine_constant("ENGINE_MAX_STRESS", 100) - 20])
	_call_node_method_bool(engine, "set_level", [_get_engine_constant("ENGINE_MAX_LEVEL", 5)])
	_call_node_method_bool(engine, "set_durability", [_get_engine_constant("ENGINE_MAX_DURABILITY", 150)])
	
	# Serialize and deserialize
	var data: Dictionary = _call_node_method_dict(engine, "serialize", [], {})
	var new_engine = EngineComponent.new()
	track_test_resource(new_engine)
	_call_node_method_bool(new_engine, "deserialize", [data])
	
	# Verify engine-specific properties
	var max_thrust: int = _call_node_method_int(new_engine, "get_max_thrust", [], 0)
	var thrust: int = _call_node_method_int(new_engine, "get_thrust", [], 0)
	var fuel_efficiency: float = _call_node_method_float(new_engine, "get_fuel_efficiency", [], 0.0)
	var max_stress: int = _call_node_method_int(new_engine, "get_max_stress", [], 0)
	var stress: int = _call_node_method_int(new_engine, "get_stress", [], 0)
	
	assert_eq(max_thrust, _get_engine_constant("ENGINE_MAX_THRUST", 200), "Should preserve max thrust")
	assert_eq(thrust, _get_engine_constant("ENGINE_MAX_THRUST", 200) - 50, "Should preserve thrust")
	assert_true(abs(fuel_efficiency - _get_engine_constant("ENGINE_MAX_FUEL_EFFICIENCY", 8.0)) < 0.001, "Should preserve fuel efficiency")
	assert_eq(max_stress, _get_engine_constant("ENGINE_MAX_STRESS", 100), "Should preserve max stress")
	assert_eq(stress, _get_engine_constant("ENGINE_MAX_STRESS", 100) - 20, "Should preserve stress")
	
	# Verify inherited properties
	var level: int = _call_node_method_int(new_engine, "get_level", [], 0)
	var durability: int = _call_node_method_int(new_engine, "get_durability", [], 0)
	
	assert_eq(level, _get_engine_constant("ENGINE_MAX_LEVEL", 5), "Should preserve level")
	assert_eq(durability, _get_engine_constant("ENGINE_MAX_DURABILITY", 150), "Should preserve durability")

# Add the missing _call_node_method_float function
func _call_node_method_float(obj: Object, method: String, args: Array = [], default_value: float = 0.0) -> float:
	var result = _call_node_method(obj, method, args)
	if result == null:
		return default_value
	if result is float:
		return result
	if result is int:
		return float(result)
	push_error("Expected float but got %s" % typeof(result))
	return default_value

# Add the missing _call_node_method_string function
func _call_node_method_string(obj: Object, method: String, args: Array = [], default_value: String = "") -> String:
	var result = _call_node_method(obj, method, args)
	if result == null:
		return default_value
	if result is String:
		return result
	if result is StringName:
		return String(result)
	push_error("Expected String but got %s" % typeof(result))
	return default_value
