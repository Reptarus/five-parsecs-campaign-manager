@tool
extends "res://tests/fixtures/specialized/campaign_test.gd"

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
    
    var name: String = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(ship, "get_name", []))
    var description: String = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(ship, "get_description", []))
    
    assert_eq(name, "", "Default name should be empty")
    assert_eq(description, "", "Default description should be empty")

func test_set_get_properties() -> void:
    var test_name: String = "Test Ship"
    var test_description: String = "Test Description"
    
    TypeSafeMixin._call_node_method_bool(ship, "set_name", [test_name])
    TypeSafeMixin._call_node_method_bool(ship, "set_description", [test_description])
    
    var name: String = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(ship, "get_name", []))
    var description: String = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(ship, "get_description", []))
    
    assert_eq(name, test_name, "Name should be set correctly")
    assert_eq(description, test_description, "Description should be set correctly")

func test_add_component() -> void:
    var component: Resource = Resource.new()
    component.set_meta("component_id", "test_component")
    component.set_meta("component_type", "engine")
    
    var result: bool = TypeSafeMixin._call_node_method_bool(ship, "add_component", [component])
    assert_true(result, "Should successfully add component")
    
    var components: Array = TypeSafeMixin._call_node_method_array(ship, "get_components", [])
    assert_eq(components.size(), 1, "Should have one component")

func test_remove_component() -> void:
    var component: Resource = Resource.new()
    component.set_meta("component_id", "test_component")
    component.set_meta("component_type", "engine")
    
    TypeSafeMixin._call_node_method_bool(ship, "add_component", [component])
    var result: bool = TypeSafeMixin._call_node_method_bool(ship, "remove_component", [component])
    assert_true(result, "Should successfully remove component")
    
    var components: Array = TypeSafeMixin._call_node_method_array(ship, "get_components", [])
    assert_eq(components.size(), 0, "Should have no components")

func test_get_component_by_id() -> void:
    var component: Resource = Resource.new()
    component.set_meta("component_id", "test_component")
    component.set_meta("component_type", "engine")
    
    TypeSafeMixin._call_node_method_bool(ship, "add_component", [component])
    var retrieved: Resource = TypeSafeMixin._call_node_method(ship, "get_component_by_id", ["test_component"]) as Resource
    
    assert_not_null(retrieved, "Should retrieve component by ID")
    assert_eq(retrieved.get_meta("component_id"), "test_component", "Should retrieve correct component")

func test_calculate_stats() -> void:
    var component1: Resource = Resource.new()
    component1.set_meta("component_id", "engine1")
    component1.set_meta("component_type", "engine")
    component1.set_meta("speed_bonus", 10)
    
    var component2: Resource = Resource.new()
    component2.set_meta("component_id", "engine2")
    component2.set_meta("component_type", "engine")
    component2.set_meta("speed_bonus", 20)
    
    TypeSafeMixin._call_node_method_bool(ship, "add_component", [component1])
    TypeSafeMixin._call_node_method_bool(ship, "add_component", [component2])
    
    var result: Dictionary = TypeSafeMixin._call_node_method_dict(ship, "calculate_stats", [])
    
    assert_true(result.has("speed"), "Stats should include speed")
    assert_ge(result["speed"], 30, "Speed should include component bonuses")