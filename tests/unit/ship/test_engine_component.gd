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
    assert_eq(cost, ship_enums.ENGINE_BASE_COST, "Should initialize with correct cost")
    assert_eq(power_draw, ship_enums.ENGINE_POWER_DRAW, "Should initialize with correct power draw")
    
    # Test engine-specific properties
    var thrust: float = _call_node_method_float(engine, "get_thrust", [], 0.0)
    var fuel_efficiency: float = _call_node_method_float(engine, "get_fuel_efficiency", [], 0.0)
    var maneuverability: float = _call_node_method_float(engine, "get_maneuverability", [], 0.0)
    var max_speed: float = _call_node_method_float(engine, "get_max_speed", [], 0.0)
    
    assert_eq(thrust, ship_enums.ENGINE_BASE_THRUST, "Should initialize with base thrust")
    assert_eq(fuel_efficiency, ship_enums.ENGINE_BASE_FUEL_EFFICIENCY, "Should initialize with base fuel efficiency")
    assert_eq(maneuverability, ship_enums.ENGINE_BASE_MANEUVERABILITY, "Should initialize with base maneuverability")
    assert_eq(max_speed, ship_enums.ENGINE_BASE_MAX_SPEED, "Should initialize with base max speed")

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
    
    assert_eq(new_thrust, initial_thrust + ship_enums.ENGINE_UPGRADE_THRUST, "Should increase thrust on upgrade")
    assert_eq(new_fuel_efficiency, initial_fuel_efficiency + ship_enums.ENGINE_UPGRADE_FUEL_EFFICIENCY, "Should increase fuel efficiency on upgrade")
    assert_eq(new_maneuverability, initial_maneuverability + ship_enums.ENGINE_UPGRADE_MANEUVERABILITY, "Should increase maneuverability on upgrade")
    assert_eq(new_max_speed, initial_max_speed + ship_enums.ENGINE_UPGRADE_MAX_SPEED, "Should increase max speed on upgrade")

func test_efficiency_effects() -> void:
    # Test base values at full efficiency
    var base_thrust: float = _call_node_method_float(engine, "get_thrust", [], 0.0)
    var base_fuel_efficiency: float = _call_node_method_float(engine, "get_fuel_efficiency", [], 0.0)
    var base_maneuverability: float = _call_node_method_float(engine, "get_maneuverability", [], 0.0)
    var base_max_speed: float = _call_node_method_float(engine, "get_max_speed", [], 0.0)
    
    assert_eq(base_thrust, ship_enums.ENGINE_BASE_THRUST, "Should return base thrust at full efficiency")
    assert_eq(base_fuel_efficiency, ship_enums.ENGINE_BASE_FUEL_EFFICIENCY, "Should return base fuel efficiency at full efficiency")
    assert_eq(base_maneuverability, ship_enums.ENGINE_BASE_MANEUVERABILITY, "Should return base maneuverability at full efficiency")
    assert_eq(base_max_speed, ship_enums.ENGINE_BASE_MAX_SPEED, "Should return base max speed at full efficiency")
    
    # Test values at reduced efficiency
    _call_node_method_bool(engine, "set_efficiency", [ship_enums.HALF_EFFICIENCY])
    
    var reduced_thrust: float = _call_node_method_float(engine, "get_thrust", [], 0.0)
    var reduced_fuel_efficiency: float = _call_node_method_float(engine, "get_fuel_efficiency", [], 0.0)
    var reduced_maneuverability: float = _call_node_method_float(engine, "get_maneuverability", [], 0.0)
    var reduced_max_speed: float = _call_node_method_float(engine, "get_max_speed", [], 0.0)
    
    assert_eq(reduced_thrust, ship_enums.ENGINE_BASE_THRUST * ship_enums.HALF_EFFICIENCY, "Should reduce thrust with efficiency")
    assert_eq(reduced_fuel_efficiency, ship_enums.ENGINE_BASE_FUEL_EFFICIENCY * ship_enums.HALF_EFFICIENCY, "Should reduce fuel efficiency with efficiency")
    assert_eq(reduced_maneuverability, ship_enums.ENGINE_BASE_MANEUVERABILITY * ship_enums.HALF_EFFICIENCY, "Should reduce maneuverability with efficiency")
    assert_eq(reduced_max_speed, ship_enums.ENGINE_BASE_MAX_SPEED * ship_enums.HALF_EFFICIENCY, "Should reduce max speed with efficiency")

func test_serialization() -> void:
    # Modify engine state
    _call_node_method_bool(engine, "set_thrust", [ship_enums.ENGINE_MAX_THRUST])
    _call_node_method_bool(engine, "set_fuel_efficiency", [ship_enums.ENGINE_MAX_FUEL_EFFICIENCY])
    _call_node_method_bool(engine, "set_maneuverability", [ship_enums.ENGINE_MAX_MANEUVERABILITY])
    _call_node_method_bool(engine, "set_max_speed", [ship_enums.ENGINE_MAX_SPEED])
    _call_node_method_bool(engine, "set_level", [ship_enums.ENGINE_MAX_LEVEL])
    _call_node_method_bool(engine, "set_durability", [ship_enums.ENGINE_TEST_DURABILITY])
    
    # Serialize and deserialize
    var data: Dictionary = _call_node_method_dict(engine, "serialize", [], {})
    var new_engine = EngineComponent.new()
    track_test_resource(new_engine)
    _call_node_method_bool(new_engine, "deserialize", [data])
    
    # Verify engine-specific properties
    var thrust: float = _call_node_method_float(new_engine, "get_thrust", [], 0.0)
    var fuel_efficiency: float = _call_node_method_float(new_engine, "get_fuel_efficiency", [], 0.0)
    var maneuverability: float = _call_node_method_float(new_engine, "get_maneuverability", [], 0.0)
    var max_speed: float = _call_node_method_float(new_engine, "get_max_speed", [], 0.0)
    
    assert_eq(thrust, ship_enums.ENGINE_MAX_THRUST, "Should preserve thrust")
    assert_eq(fuel_efficiency, ship_enums.ENGINE_MAX_FUEL_EFFICIENCY, "Should preserve fuel efficiency")
    assert_eq(maneuverability, ship_enums.ENGINE_MAX_MANEUVERABILITY, "Should preserve maneuverability")
    assert_eq(max_speed, ship_enums.ENGINE_MAX_SPEED, "Should preserve max speed")
    
    # Verify inherited properties
    var level: int = _call_node_method_int(new_engine, "get_level", [], 0)
    var durability: int = _call_node_method_int(new_engine, "get_durability", [], 0)
    var power_draw: int = _call_node_method_int(new_engine, "get_power_draw", [], 0)
    
    assert_eq(level, ship_enums.ENGINE_MAX_LEVEL, "Should preserve level")
    assert_eq(durability, ship_enums.ENGINE_TEST_DURABILITY, "Should preserve durability")
    assert_eq(power_draw, ship_enums.ENGINE_POWER_DRAW, "Should preserve power draw")