@tool
extends "res://tests/fixtures/base/game_test.gd"

const EngineComponent: GDScript = preload("res://src/core/ships/components/EngineComponent.gd")

var engine: EngineComponent = null

func before_each() -> void:
    await super.before_each()
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
    
    var name: String = TypeSafeMixin._safe_method_call_string(engine, "get_name", [], "")
    var description: String = TypeSafeMixin._safe_method_call_string(engine, "get_description", [], "")
    var cost: int = TypeSafeMixin._safe_method_call_int(engine, "get_cost", [], 0)
    var power_draw: int = TypeSafeMixin._safe_method_call_int(engine, "get_power_draw", [], 0)
    
    assert_eq(name, "Engine", "Should initialize with correct name")
    assert_eq(description, "Standard ship engine", "Should initialize with correct description")
    assert_eq(cost, GameEnums.ENGINE_BASE_COST, "Should initialize with correct cost")
    assert_eq(power_draw, GameEnums.ENGINE_POWER_DRAW, "Should initialize with correct power draw")
    
    # Test engine-specific properties
    var thrust: float = TypeSafeMixin._safe_method_call_float(engine, "get_thrust", [], 0.0)
    var fuel_efficiency: float = TypeSafeMixin._safe_method_call_float(engine, "get_fuel_efficiency", [], 0.0)
    var maneuverability: float = TypeSafeMixin._safe_method_call_float(engine, "get_maneuverability", [], 0.0)
    var max_speed: float = TypeSafeMixin._safe_method_call_float(engine, "get_max_speed", [], 0.0)
    
    assert_eq(thrust, GameEnums.ENGINE_BASE_THRUST, "Should initialize with base thrust")
    assert_eq(fuel_efficiency, GameEnums.ENGINE_BASE_FUEL_EFFICIENCY, "Should initialize with base fuel efficiency")
    assert_eq(maneuverability, GameEnums.ENGINE_BASE_MANEUVERABILITY, "Should initialize with base maneuverability")
    assert_eq(max_speed, GameEnums.ENGINE_BASE_MAX_SPEED, "Should initialize with base max speed")

func test_upgrade_effects() -> void:
    # Store initial values
    var initial_thrust: float = TypeSafeMixin._safe_method_call_float(engine, "get_thrust", [], 0.0)
    var initial_fuel_efficiency: float = TypeSafeMixin._safe_method_call_float(engine, "get_fuel_efficiency", [], 0.0)
    var initial_maneuverability: float = TypeSafeMixin._safe_method_call_float(engine, "get_maneuverability", [], 0.0)
    var initial_max_speed: float = TypeSafeMixin._safe_method_call_float(engine, "get_max_speed", [], 0.0)
    
    # Perform upgrade
    TypeSafeMixin._safe_method_call_bool(engine, "upgrade", [])
    
    # Test improvements
    var new_thrust: float = TypeSafeMixin._safe_method_call_float(engine, "get_thrust", [], 0.0)
    var new_fuel_efficiency: float = TypeSafeMixin._safe_method_call_float(engine, "get_fuel_efficiency", [], 0.0)
    var new_maneuverability: float = TypeSafeMixin._safe_method_call_float(engine, "get_maneuverability", [], 0.0)
    var new_max_speed: float = TypeSafeMixin._safe_method_call_float(engine, "get_max_speed", [], 0.0)
    
    assert_eq(new_thrust, initial_thrust + GameEnums.ENGINE_UPGRADE_THRUST, "Should increase thrust on upgrade")
    assert_eq(new_fuel_efficiency, initial_fuel_efficiency + GameEnums.ENGINE_UPGRADE_FUEL_EFFICIENCY, "Should increase fuel efficiency on upgrade")
    assert_eq(new_maneuverability, initial_maneuverability + GameEnums.ENGINE_UPGRADE_MANEUVERABILITY, "Should increase maneuverability on upgrade")
    assert_eq(new_max_speed, initial_max_speed + GameEnums.ENGINE_UPGRADE_MAX_SPEED, "Should increase max speed on upgrade")

func test_efficiency_effects() -> void:
    # Test base values at full efficiency
    var base_thrust: float = TypeSafeMixin._safe_method_call_float(engine, "get_thrust", [], 0.0)
    var base_fuel_efficiency: float = TypeSafeMixin._safe_method_call_float(engine, "get_fuel_efficiency", [], 0.0)
    var base_maneuverability: float = TypeSafeMixin._safe_method_call_float(engine, "get_maneuverability", [], 0.0)
    var base_max_speed: float = TypeSafeMixin._safe_method_call_float(engine, "get_max_speed", [], 0.0)
    
    assert_eq(base_thrust, GameEnums.ENGINE_BASE_THRUST, "Should return base thrust at full efficiency")
    assert_eq(base_fuel_efficiency, GameEnums.ENGINE_BASE_FUEL_EFFICIENCY, "Should return base fuel efficiency at full efficiency")
    assert_eq(base_maneuverability, GameEnums.ENGINE_BASE_MANEUVERABILITY, "Should return base maneuverability at full efficiency")
    assert_eq(base_max_speed, GameEnums.ENGINE_BASE_MAX_SPEED, "Should return base max speed at full efficiency")
    
    # Test values at reduced efficiency
    TypeSafeMixin._safe_method_call_bool(engine, "set_efficiency", [GameEnums.HALF_EFFICIENCY])
    
    var reduced_thrust: float = TypeSafeMixin._safe_method_call_float(engine, "get_thrust", [], 0.0)
    var reduced_fuel_efficiency: float = TypeSafeMixin._safe_method_call_float(engine, "get_fuel_efficiency", [], 0.0)
    var reduced_maneuverability: float = TypeSafeMixin._safe_method_call_float(engine, "get_maneuverability", [], 0.0)
    var reduced_max_speed: float = TypeSafeMixin._safe_method_call_float(engine, "get_max_speed", [], 0.0)
    
    assert_eq(reduced_thrust, GameEnums.ENGINE_BASE_THRUST * GameEnums.HALF_EFFICIENCY, "Should reduce thrust with efficiency")
    assert_eq(reduced_fuel_efficiency, GameEnums.ENGINE_BASE_FUEL_EFFICIENCY * GameEnums.HALF_EFFICIENCY, "Should reduce fuel efficiency with efficiency")
    assert_eq(reduced_maneuverability, GameEnums.ENGINE_BASE_MANEUVERABILITY * GameEnums.HALF_EFFICIENCY, "Should reduce maneuverability with efficiency")
    assert_eq(reduced_max_speed, GameEnums.ENGINE_BASE_MAX_SPEED * GameEnums.HALF_EFFICIENCY, "Should reduce max speed with efficiency")

func test_serialization() -> void:
    # Modify engine state
    TypeSafeMixin._safe_method_call_bool(engine, "set_thrust", [GameEnums.ENGINE_MAX_THRUST])
    TypeSafeMixin._safe_method_call_bool(engine, "set_fuel_efficiency", [GameEnums.ENGINE_MAX_FUEL_EFFICIENCY])
    TypeSafeMixin._safe_method_call_bool(engine, "set_maneuverability", [GameEnums.ENGINE_MAX_MANEUVERABILITY])
    TypeSafeMixin._safe_method_call_bool(engine, "set_max_speed", [GameEnums.ENGINE_MAX_SPEED])
    TypeSafeMixin._safe_method_call_bool(engine, "set_level", [GameEnums.ENGINE_MAX_LEVEL])
    TypeSafeMixin._safe_method_call_bool(engine, "set_durability", [GameEnums.ENGINE_TEST_DURABILITY])
    
    # Serialize and deserialize
    var data: Dictionary = TypeSafeMixin._safe_method_call_dict(engine, "serialize", [], {})
    var new_engine: EngineComponent = EngineComponent.new()
    track_test_resource(new_engine)
    TypeSafeMixin._safe_method_call_bool(new_engine, "deserialize", [data])
    
    # Verify engine-specific properties
    var thrust: float = TypeSafeMixin._safe_method_call_float(new_engine, "get_thrust", [], 0.0)
    var fuel_efficiency: float = TypeSafeMixin._safe_method_call_float(new_engine, "get_fuel_efficiency", [], 0.0)
    var maneuverability: float = TypeSafeMixin._safe_method_call_float(new_engine, "get_maneuverability", [], 0.0)
    var max_speed: float = TypeSafeMixin._safe_method_call_float(new_engine, "get_max_speed", [], 0.0)
    
    assert_eq(thrust, GameEnums.ENGINE_MAX_THRUST, "Should preserve thrust")
    assert_eq(fuel_efficiency, GameEnums.ENGINE_MAX_FUEL_EFFICIENCY, "Should preserve fuel efficiency")
    assert_eq(maneuverability, GameEnums.ENGINE_MAX_MANEUVERABILITY, "Should preserve maneuverability")
    assert_eq(max_speed, GameEnums.ENGINE_MAX_SPEED, "Should preserve max speed")
    
    # Verify inherited properties
    var level: int = TypeSafeMixin._safe_method_call_int(new_engine, "get_level", [], 0)
    var durability: int = TypeSafeMixin._safe_method_call_int(new_engine, "get_durability", [], 0)
    var power_draw: int = TypeSafeMixin._safe_method_call_int(new_engine, "get_power_draw", [], 0)
    
    assert_eq(level, GameEnums.ENGINE_MAX_LEVEL, "Should preserve level")
    assert_eq(durability, GameEnums.ENGINE_TEST_DURABILITY, "Should preserve durability")
    assert_eq(power_draw, GameEnums.ENGINE_POWER_DRAW, "Should preserve power draw")