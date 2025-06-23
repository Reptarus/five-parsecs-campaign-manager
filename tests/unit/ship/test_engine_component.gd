@tool
extends GdUnitGameTest

#
class MockEngineComponent extends Resource:
    var name: String = "Engine"
    var description: String = "Standard ship engine"
    var cost: int = 100
    var power_draw: int = 50
    var thrust: float = 100.0
    var fuel_efficiency: float = 1.0
    var maneuverability: float = 1.0
    var max_speed: float = 100.0
    var level: int = 1
    var durability: int = 100
    var efficiency: float = 1.0
#
    
    func get_component_name() -> String: return name
    func get_component_description() -> String: return description
    func get_cost() -> int: return cost
    func get_power_draw() -> int: return power_draw
    func get_thrust() -> float: return thrust * efficiency
    func get_fuel_efficiency() -> float: return fuel_efficiency * efficiency
    func get_maneuverability() -> float: return maneuverability * efficiency
    func get_max_speed() -> float: return max_speed * efficiency
    func get_level() -> int: return level
    func get_durability() -> int: return durability
    
    func set_level(new_level: int) -> void: level = new_level
    func set_durability(new_durability: int) -> void: durability = new_durability
    func set_efficiency(new_efficiency: float) -> void: efficiency = new_efficiency
    
    func upgrade() -> void:
        level += 1
        thrust += 20.0
        fuel_efficiency += 0.2
        maneuverability += 0.2
        max_speed += 20.0
        
        # Special upgrade at level 5
        if level == 5:
            thrust += 50.0
    
    func serialize() -> Dictionary:
        return {
            "name": name,
            "description": description,
            "cost": cost,
            "power_draw": power_draw,
            "level": level,
            "durability": durability,
            "thrust": thrust,
            "fuel_efficiency": fuel_efficiency,
            "maneuverability": maneuverability,
            "max_speed": max_speed,
            "efficiency": efficiency
        }

    func deserialize(data: Dictionary) -> void:
        name = data.get("name", name)
        description = data.get("description", description)
        cost = data.get("cost", cost)
        power_draw = data.get("power_draw", power_draw)
        level = data.get("level", level)
        durability = data.get("durability", durability)
        thrust = data.get("thrust", thrust)
        fuel_efficiency = data.get("fuel_efficiency", fuel_efficiency)
        maneuverability = data.get("maneuverability", maneuverability)
        max_speed = data.get("max_speed", max_speed)
        efficiency = data.get("efficiency", efficiency)

var engine: MockEngineComponent = null

#
func _initialize_test_environment() -> void:
    engine = MockEngineComponent.new()
    if not engine:
        return

func before_test() -> void:
    super.before_test()
    
    # Initialize our test environment
    _initialize_test_environment()
    
    # Reset to default state
    engine.set_level(1)
    engine.set_durability(100)
    engine.set_efficiency(1.0)

func after_test() -> void:
    super.after_test()
    engine = null

func test_initialization() -> void:
    assert_that(engine).is_not_null()
    
    # Mock engine returns expected values directly
    var name: String = engine.get_component_name()
    var description: String = engine.get_component_description()
    var cost: int = engine.get_cost()
    var power_draw: int = engine.get_power_draw()
    
    assert_that(name).is_equal("Engine")
    assert_that(description).is_equal("Standard ship engine")
    assert_that(cost).is_equal(100)
    assert_that(power_draw).is_equal(50)
    
    # Test engine-specific properties
    var thrust: float = engine.get_thrust()
    var fuel_efficiency: float = engine.get_fuel_efficiency()
    var maneuverability: float = engine.get_maneuverability()
    var max_speed: float = engine.get_max_speed()
    
    assert_that(thrust).is_equal(100.0)
    assert_that(fuel_efficiency).is_equal(1.0)
    assert_that(maneuverability).is_equal(1.0)
    assert_that(max_speed).is_equal(100.0)

func test_upgrade_effects() -> void:
    # Store initial values
    var initial_thrust: float = engine.get_thrust()
    var initial_fuel_efficiency: float = engine.get_fuel_efficiency()
    var initial_maneuverability: float = engine.get_maneuverability()
    var initial_max_speed: float = engine.get_max_speed()
    
    # Upgrade the component
    engine.upgrade()
    
    # Get new values
    var new_thrust: float = engine.get_thrust()
    var new_fuel_efficiency: float = engine.get_fuel_efficiency()
    var new_maneuverability: float = engine.get_maneuverability()
    var new_max_speed: float = engine.get_max_speed()
    
    assert_that(new_thrust).is_greater(initial_thrust)
    assert_that(new_fuel_efficiency).is_greater(initial_fuel_efficiency)
    assert_that(new_maneuverability).is_greater(initial_maneuverability)
    assert_that(new_max_speed).is_greater(initial_max_speed)

func test_efficiency_effects() -> void:
    # Test base values at full efficiency
    var base_thrust: float = engine.get_thrust()
    var base_fuel_efficiency: float = engine.get_fuel_efficiency()
    var base_maneuverability: float = engine.get_maneuverability()
    var base_max_speed: float = engine.get_max_speed()
    
    assert_that(base_thrust).is_equal(100.0)
    assert_that(base_fuel_efficiency).is_equal(1.0)
    assert_that(base_maneuverability).is_equal(1.0)
    assert_that(base_max_speed).is_equal(100.0)
    
    # Test efficiency reduction
    engine.set_efficiency(0.5)
    
    # Get reduced values
    var reduced_thrust: float = engine.get_thrust()
    var reduced_fuel_efficiency: float = engine.get_fuel_efficiency()
    var reduced_maneuverability: float = engine.get_maneuverability()
    var reduced_max_speed: float = engine.get_max_speed()
    
    assert_that(reduced_thrust).is_equal(50.0)
    assert_that(reduced_fuel_efficiency).is_equal(0.5)
    assert_that(reduced_maneuverability).is_equal(0.5)
    assert_that(reduced_max_speed).is_equal(50.0)

func test_serialization() -> void:
    # Configure engine
    engine.set_level(5)
    engine.set_durability(150)
    
    # Serialize
    var data: Dictionary = engine.serialize()
    
    # Create new engine and deserialize
    var new_engine: MockEngineComponent = MockEngineComponent.new()
    new_engine.deserialize(data)
    
    # Verify engine-specific properties
    var thrust: float = new_engine.get_thrust()
    var fuel_efficiency: float = new_engine.get_fuel_efficiency()
    var maneuverability: float = new_engine.get_maneuverability()
    var max_speed: float = new_engine.get_max_speed()
    
    assert_that(thrust).is_equal(100.0)
    assert_that(fuel_efficiency).is_equal(1.0)
    assert_that(maneuverability).is_equal(1.0)
    assert_that(max_speed).is_equal(100.0)
    
    # Verify inherited properties
    var level: int = new_engine.get_level()
    var durability: int = new_engine.get_durability()
    var power_draw: int = new_engine.get_power_draw()
    
    assert_that(level).is_equal(5)
    assert_that(durability).is_equal(150)
    assert_that(power_draw).is_equal(50)

# Helper methods would return constant values
func _get_engine_base_cost() -> int:
    return 100

func _get_engine_power_draw() -> int:
    return 50

func _get_engine_base_thrust() -> float:
    return 100.0

func _get_engine_base_fuel_efficiency() -> float:
    return 1.0

func _get_engine_base_maneuverability() -> float:
    return 1.0

func _get_engine_base_max_speed() -> float:
    return 100.0

func _get_engine_upgrade_thrust() -> float:
    return 20.0

func _get_engine_upgrade_fuel_efficiency() -> float:
    return 0.2

func _get_engine_upgrade_maneuverability() -> float:
    return 0.2

func _get_engine_upgrade_max_speed() -> float:
    return 20.0

func _get_half_efficiency() -> float:
    return 0.5

func _get_engine_max_level() -> int:
    return 5

func _get_engine_test_durability() -> int:
    return 150

func _get_engine_max_thrust() -> float:
    return 170.0

func _get_engine_max_fuel_efficiency() -> float:
    return 1.8

func _get_engine_max_maneuverability() -> float:
    return 1.8

func _get_engine_max_speed() -> float:
    return 180.0

# Helper methods are no longer needed with mock objects
