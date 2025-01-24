extends "res://addons/gut/test.gd"

var engine: EngineComponent

func before_each() -> void:
    engine = EngineComponent.new()

func after_each() -> void:
    engine = null

func test_initialization() -> void:
    assert_eq(engine.name, "Engine", "Should initialize with correct name")
    assert_eq(engine.description, "Standard ship engine", "Should initialize with correct description")
    assert_eq(engine.cost, 200, "Should initialize with correct cost")
    assert_eq(engine.power_draw, 2, "Should initialize with correct power draw")
    
    # Test engine-specific properties
    assert_eq(engine.thrust, 1.0, "Should initialize with base thrust")
    assert_eq(engine.fuel_efficiency, 1.0, "Should initialize with base fuel efficiency")
    assert_eq(engine.maneuverability, 1.0, "Should initialize with base maneuverability")
    assert_eq(engine.max_speed, 100.0, "Should initialize with base max speed")

func test_upgrade_effects() -> void:
    # Store initial values
    var initial_thrust = engine.thrust
    var initial_fuel_efficiency = engine.fuel_efficiency
    var initial_maneuverability = engine.maneuverability
    var initial_max_speed = engine.max_speed
    
    # Perform upgrade
    engine.upgrade()
    
    # Test improvements
    assert_eq(engine.thrust, initial_thrust + 0.2, "Should increase thrust on upgrade")
    assert_eq(engine.fuel_efficiency, initial_fuel_efficiency + 0.1, "Should increase fuel efficiency on upgrade")
    assert_eq(engine.maneuverability, initial_maneuverability + 0.15, "Should increase maneuverability on upgrade")
    assert_eq(engine.max_speed, initial_max_speed + 20.0, "Should increase max speed on upgrade")

func test_efficiency_effects() -> void:
    # Test base values at full efficiency
    assert_eq(engine.get_thrust(), 1.0, "Should return base thrust at full efficiency")
    assert_eq(engine.get_fuel_efficiency(), 1.0, "Should return base fuel efficiency at full efficiency")
    assert_eq(engine.get_maneuverability(), 1.0, "Should return base maneuverability at full efficiency")
    assert_eq(engine.get_max_speed(), 100.0, "Should return base max speed at full efficiency")
    
    # Test values at reduced efficiency
    engine.take_damage(50) # 50% efficiency
    assert_eq(engine.get_thrust(), 0.5, "Should reduce thrust with efficiency")
    assert_eq(engine.get_fuel_efficiency(), 0.5, "Should reduce fuel efficiency with efficiency")
    assert_eq(engine.get_maneuverability(), 0.5, "Should reduce maneuverability with efficiency")
    assert_eq(engine.get_max_speed(), 50.0, "Should reduce max speed with efficiency")

func test_serialization() -> void:
    # Modify engine state
    engine.thrust = 1.5
    engine.fuel_efficiency = 1.2
    engine.maneuverability = 1.3
    engine.max_speed = 120.0
    engine.level = 2
    engine.durability = 75
    
    # Serialize and deserialize
    var data = engine.serialize()
    var new_engine = EngineComponent.deserialize(data)
    
    # Verify engine-specific properties
    assert_eq(new_engine.thrust, engine.thrust, "Should preserve thrust")
    assert_eq(new_engine.fuel_efficiency, engine.fuel_efficiency, "Should preserve fuel efficiency")
    assert_eq(new_engine.maneuverability, engine.maneuverability, "Should preserve maneuverability")
    assert_eq(new_engine.max_speed, engine.max_speed, "Should preserve max speed")
    
    # Verify inherited properties
    assert_eq(new_engine.level, engine.level, "Should preserve level")
    assert_eq(new_engine.durability, engine.durability, "Should preserve durability")
    assert_eq(new_engine.power_draw, engine.power_draw, "Should preserve power draw")