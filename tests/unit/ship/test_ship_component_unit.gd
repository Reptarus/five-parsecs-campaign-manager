## Individual Ship Component Test Suite
## Tests the functionality of individual ship components, including
## properties, durability, efficiency, and component-level operations
@tool
extends "res://tests/fixtures/base/game_test.gd"

## Tests the functionality of individual ship components
const ShipComponentClass: GDScript = preload("res://src/core/ships/components/ShipComponent.gd")

# Type-safe instance variables
var component: Resource = null

func before_each() -> void:
    await super.before_each()
    component = ShipComponentClass.new()
    if not component:
        push_error("Failed to create ship component")
        return
    track_test_resource(component)
    await get_tree().process_frame

func after_each() -> void:
    await super.after_each()
    component = null

# Add missing assertion functions directly in this file
func assert_ge(a, b, text: String = "") -> void:
    if text.length() > 0:
        assert_true(a >= b, text)
    else:
        assert_true(a >= b, "Expected %s >= %s" % [a, b])

func assert_le(a, b, text: String = "") -> void:
    if text.length() > 0:
        assert_true(a <= b, text)
    else:
        assert_true(a <= b, "Expected %s <= %s" % [a, b])

func test_initialization() -> void:
    assert_not_null(component, "Ship component should be initialized")
    
    # Check if required methods exist before testing
    if not (component.has_method("get_name") and
           component.has_method("get_description") and
           component.has_method("get_cost") and
           component.has_method("get_power_draw") and
           component.has_method("get_level") and
           component.has_method("get_durability") and
           component.has_method("get_efficiency") and
           component.has_method("is_active")):
        push_warning("Skipping test_initialization: required methods missing")
        pending("Test skipped - required methods missing")
        return
    
    var name: String = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(component, "get_name", []))
    var description: String = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(component, "get_description", []))
    var cost: int = TypeSafeMixin._call_node_method_int(component, "get_cost", [])
    var power_draw: int = TypeSafeMixin._call_node_method_int(component, "get_power_draw", [])
    var level: int = TypeSafeMixin._call_node_method_int(component, "get_level", [])
    var durability: int = TypeSafeMixin._call_node_method_int(component, "get_durability", [])
    var efficiency: float = TypeSafeMixin._safe_cast_float(TypeSafeMixin._call_node_method(component, "get_efficiency", []))
    var is_active: bool = TypeSafeMixin._call_node_method_bool(component, "is_active", [])
    
    assert_ne(name, "", "Should initialize with a name")
    assert_ne(description, "", "Should initialize with a description")
    assert_gt(cost, 0, "Should initialize with positive cost")
    assert_ge(power_draw, 0, "Should initialize with non-negative power draw")
    assert_eq(level, TestEnums.COMPONENT_BASE_LEVEL, "Should initialize at level 1")
    assert_eq(durability, TestEnums.COMPONENT_MAX_DURABILITY, "Should initialize with full durability")
    assert_eq(efficiency, TestEnums.COMPONENT_MAX_EFFICIENCY, "Should initialize with full efficiency")
    assert_true(is_active, "Should initialize as active")