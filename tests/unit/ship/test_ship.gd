@tool
extends "res://tests/fixtures/base/game_test.gd"

const Ship = preload("res://src/core/ships/Ship.gd")

var ship: Ship = null

func before_each() -> void:
    await super.before_each()
    ship = Ship.new()
    if not ship:
        push_error("Failed to create ship")
        return
    track_test_resource(ship)
    await get_tree().process_frame

func after_each() -> void:
    await super.after_each()
    ship = null

func test_initialization() -> void:
    assert_not_null(ship, "Ship should be initialized")
    
    var name: String = TypeSafeMixin._safe_method_call_string(ship, "get_name", [], "")
    var description: String = TypeSafeMixin._safe_method_call_string(ship, "get_description", [], "")
    var cost: int = TypeSafeMixin._safe_method_call_int(ship, "get_cost", [], 0)
    var power: int = TypeSafeMixin._safe_method_call_int(ship, "get_power", [], 0)
    var max_power: int = TypeSafeMixin._safe_method_call_int(ship, "get_max_power", [], 0)
    var components: Array = TypeSafeMixin._safe_method_call_array(ship, "get_components", [], [])
    
    assert_ne(name, "", "Should initialize with a name")
    assert_ne(description, "", "Should initialize with a description")
    assert_gt(cost, GameEnums.SHIP_MIN_COST, "Should initialize with positive cost")
    assert_eq(power, max_power, "Should initialize with full power")
    assert_gt(max_power, GameEnums.SHIP_MIN_POWER, "Should initialize with positive max power")
    assert_gt(components.size(), 0, "Should initialize with core components")

func test_component_management() -> void:
    # Test initial components
    var components: Array = TypeSafeMixin._safe_method_call_array(ship, "get_components", [], [])
    var initial_count = components.size()
    assert_gt(initial_count, 0, "Should have initial components")
    
    # Test removing component
    var component = ship.hull_component
    assert_not_null(component, "Should have hull component")
    var success = TypeSafeMixin._safe_method_call_bool(ship, "remove_component", [component], false)
    assert_true(success, "Should successfully remove component")
    
    components = TypeSafeMixin._safe_method_call_array(ship, "get_components", [], [])
    assert_eq(components.size(), initial_count - 1, "Should remove component from tracking")
    
    # Test re-adding component
    success = TypeSafeMixin._safe_method_call_bool(ship, "add_component", [component], false)
    assert_true(success, "Should successfully re-add component")
    
    components = TypeSafeMixin._safe_method_call_array(ship, "get_components", [], [])
    assert_eq(components.size(), initial_count, "Should restore component count")

func test_power_management() -> void:
    # Test power consumption
    var initial_power = TypeSafeMixin._safe_method_call_int(ship, "get_power", [], 0)
    var component = ship.engine_component
    assert_not_null(component, "Should have engine component")
    
    # Deactivate engine to reduce power
    TypeSafeMixin._safe_method_call_bool(component, "deactivate", [])
    var new_power = TypeSafeMixin._safe_method_call_int(ship, "get_power", [], 0)
    assert_gt(initial_power, new_power, "Should reduce power when component is deactivated")
    
    # Reactivate engine
    TypeSafeMixin._safe_method_call_bool(component, "activate", [])
    new_power = TypeSafeMixin._safe_method_call_int(ship, "get_power", [], 0)
    assert_eq(new_power, initial_power, "Should restore power when component is reactivated")

func test_damage_system() -> void:
    var hull = ship.hull_component
    assert_not_null(hull, "Should have hull component")
    
    var initial_durability = TypeSafeMixin._safe_method_call_int(hull, "get_durability", [], 0)
    assert_gt(initial_durability, 0, "Should have positive initial durability")
    
    # Test taking damage
    TypeSafeMixin._safe_method_call_bool(ship, "take_damage", [10])
    var new_durability = TypeSafeMixin._safe_method_call_int(hull, "get_durability", [], 0)
    assert_lt(new_durability, initial_durability, "Should reduce durability when damaged")
    
    # Test repair
    TypeSafeMixin._safe_method_call_bool(ship, "repair", [5])
    new_durability = TypeSafeMixin._safe_method_call_int(hull, "get_durability", [], 0)
    assert_gt(new_durability, initial_durability - 10, "Should increase durability when repaired")

func test_serialization() -> void:
    # Setup ship state
    TypeSafeMixin._safe_method_call_bool(ship, "set_name", ["Test Ship"])
    TypeSafeMixin._safe_method_call_bool(ship, "set_description", ["Test Description"])
    
    # Serialize and deserialize
    var data = TypeSafeMixin._safe_method_call_dict(ship, "serialize", [], {})
    var new_ship = Ship.new()
    track_test_resource(new_ship)
    TypeSafeMixin._safe_method_call_bool(new_ship, "deserialize", [data])
    
    # Verify ship properties
    var name = TypeSafeMixin._safe_method_call_string(new_ship, "get_name", [], "")
    var description = TypeSafeMixin._safe_method_call_string(new_ship, "get_description", [], "")
    var components = TypeSafeMixin._safe_method_call_array(new_ship, "get_components", [], [])
    
    assert_eq(name, "Test Ship", "Should preserve name")
    assert_eq(description, "Test Description", "Should preserve description")
    assert_gt(components.size(), 0, "Should preserve components")