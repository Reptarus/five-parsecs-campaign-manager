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

func test_initialization() -> void:
    assert_not_null(component, "Ship component should be initialized")
    
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
    assert_eq(level, GameEnums.COMPONENT_BASE_LEVEL, "Should initialize at level 1")
    assert_eq(durability, GameEnums.COMPONENT_MAX_DURABILITY, "Should initialize with full durability")
    assert_eq(efficiency, GameEnums.COMPONENT_MAX_EFFICIENCY, "Should initialize with full efficiency")
    assert_true(is_active, "Should initialize as active")
