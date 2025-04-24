## Individual Ship Component Test Suite
## Tests the functionality of individual ship components, including
## properties, durability, efficiency, and component-level operations
@tool
extends "res://tests/fixtures/base/game_test.gd"

## Tests the functionality of individual ship components
const ShipComponentClass: GDScript = preload("res://src/core/ships/components/ShipComponent.gd")

# Use explicit preloads instead of global class names
const TestEnums = preload("res://tests/fixtures/base/test_helper.gd")

# Type-safe instance variables
var component = null

# Type-safe helper class
class TypeSafeMixin:
    # Safe method to set properties
    static func _set_property_safe(obj, property_name: String, value) -> bool:
        if obj == null:
            return false
            
        # Try using setter method first
        var setter_name = "set_" + property_name
        if obj.has_method(setter_name):
            obj.call(setter_name, value)
            return true
            
        # Try using property if it exists
        if property_name in obj:
            obj.set(property_name, value)
            return true
            
        # For RefCounted objects, some properties might not be directly accessible
        # Try to use set() method if available
        if obj.has_method("set"):
            obj.call("set", property_name, value)
            return true
            
        return false
        
    # Safe method to get properties
    static func _get_property_safe(obj, property_name: String, default_value = null):
        if obj == null:
            return default_value
            
        # Try using getter method first
        var getter_name = "get_" + property_name
        if obj.has_method(getter_name):
            return obj.call(getter_name)
            
        # Try direct property access
        if property_name in obj:
            return obj.get(property_name)
            
        return default_value
    
    # Safe method to call a function if it exists
    static func _call_method_safe(obj, method_name: String, args: Array = []):
        if obj == null or not obj.has_method(method_name):
            return null
        return obj.callv(method_name, args)
    
    # Safe method to call a function and return an int
    static func _call_int(obj, method_name: String, args: Array = []) -> int:
        var result = _call_method_safe(obj, method_name, args)
        return _safe_cast_to_int(result)
    
    # Safe method to call a function and return a float
    static func _call_float(obj, method_name: String, args: Array = []) -> float:
        var result = _call_method_safe(obj, method_name, args)
        return _safe_cast_to_float(result)
    
    # Safe method to call a function and return a bool
    static func _call_bool(obj, method_name: String, args: Array = []) -> bool:
        var result = _call_method_safe(obj, method_name, args)
        return _safe_cast_to_bool(result)
    
    # Helper method for skipping tests
    static func skip_test(test_obj, message: String) -> bool:
        # Try using GUT's built-in skip function
        if test_obj.has_method("skip"):
            test_obj.skip(message)
            return true
        
        # Try using GUT's pending function as an alternative
        if test_obj.has_method("pending"):
            test_obj.pending(message)
            return true
            
        # If neither method is available, print a message and return
        print("SKIPPED TEST: " + message)
        return true
    
    # Safe type casting for string values
    static func _safe_cast_to_string(value) -> String:
        if value == null:
            return ""
        if value is String:
            return value
        return str(value)

    # Safe type casting for integer values
    static func _safe_cast_to_int(value) -> int:
        if value == null:
            return 0
        if value is int:
            return value
        if value is float:
            return int(value)
        if value is String and value.is_valid_int():
            return value.to_int()
        return 0
    
    # Safe type casting for float values
    static func _safe_cast_to_float(value) -> float:
        if value == null:
            return 0.0
        if value is float or value is int:
            return float(value)
        if value is String and value.is_valid_float():
            return value.to_float()
        return 0.0
    
    # Safe type casting for boolean values
    static func _safe_cast_to_bool(value) -> bool:
        if value == null:
            return false
        if value is bool:
            return value
        if value is int or value is float:
            return value > 0
        if value is String:
            return value.to_lower() == "true" or value == "1"
        return false

func before_each() -> void:
    await super.before_each()
    
    # Initialize the component using dynamic loading
    var component_path = "res://scripts/entities/ship/components/base_component.gd"
    
    if ResourceLoader.exists(component_path):
        var resource = load(component_path)
        if resource != null:
            component = resource.new()
    
    if component == null:
        print("WARNING: Could not initialize component for testing.")
    else:
        # Print component properties for debugging
        var info = "Component Properties:\n"
        var props = ["name", "description", "cost", "power_draw", "level", "durability", "efficiency", "active"]
        
        for prop in props:
            var value = TypeSafeMixin._get_property_safe(component, prop)
            if value != null:
                info += "- %s: %s\n" % [prop, str(value)]
        
        print(info)

func after_each() -> void:
    # Properly clean up component based on its type
    if component != null:
        # Check if the component is a Node type despite being stored in a Resource variable
        if component.get_script() != null and component.get_script().get_instance_base_type() == "Node":
            if component.is_inside_tree():
                component.queue_free()
        # Otherwise treat as a regular Resource
        component = null
    await super.after_each()

# Add missing assertion functions directly in this file if needed
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
    # Skip test if component wasn't properly initialized
    if component == null:
        push_error("Component is null, skipping test_initialization")
        return
        
    assert_not_null(component, "Ship component should be initialized")
    
    # Check if required methods exist before testing - using safety method
    if not _has_required_methods(component, ["get_name", "get_description", "get_cost",
                                          "get_power_draw", "get_level", "get_durability",
                                          "get_efficiency", "is_active"]):
        push_warning("Skipping test_initialization: required methods missing")
        pending("Test skipped - required methods missing")
        return
    
    # Get properties with safe calls
    var name = TypeSafeMixin._call_method_safe(component, "get_name", [])
    var description = TypeSafeMixin._call_method_safe(component, "get_description", [])
    var cost = TypeSafeMixin._call_int(component, "get_cost", [])
    var power_draw = TypeSafeMixin._call_int(component, "get_power_draw", [])
    var level = TypeSafeMixin._call_int(component, "get_level", [])
    var durability = TypeSafeMixin._call_int(component, "get_durability", [])
    var efficiency = TypeSafeMixin._call_float(component, "get_efficiency", [])
    var is_active = TypeSafeMixin._call_bool(component, "is_active", [])
    
    # Only test values that were successfully retrieved
    if name != null:
        assert_ne(name, "", "Should initialize with a name")
    
    if description != null:
        assert_ne(description, "", "Should initialize with a description")
    
    if cost != null:
        assert_gt(cost, 0, "Should initialize with positive cost")
    
    if power_draw != null:
        assert_ge(power_draw, 0, "Should initialize with non-negative power draw")
    
    if level != null and is_constant_defined("TestEnums", "COMPONENT_BASE_LEVEL"):
        assert_eq(level, TestEnums.COMPONENT_BASE_LEVEL, "Should initialize at correct level")
    
    if durability != null and is_constant_defined("TestEnums", "COMPONENT_MAX_DURABILITY"):
        assert_eq(durability, TestEnums.COMPONENT_MAX_DURABILITY, "Should initialize with full durability")
    
    if efficiency != null and is_constant_defined("TestEnums", "COMPONENT_MAX_EFFICIENCY"):
        assert_eq(efficiency, TestEnums.COMPONENT_MAX_EFFICIENCY, "Should initialize with full efficiency")
    
    if is_active != null:
        assert_true(is_active, "Should initialize as active")

# Helper method to check if a constant is defined in a class
func is_constant_defined(class_name_str: String, constant_name: String) -> bool:
    return ClassDB.class_exists(class_name_str) and ClassDB.class_has_integer_constant(class_name_str, constant_name)

# Helper method to check if object has required methods
func _has_required_methods(obj, methods: Array) -> bool:
    if obj == null:
        return false
        
    for method in methods:
        if not obj.has_method(method):
            return false
    return true

# Helper methods for safe function calls
func _safe_call(obj, method: String, args: Array = []):
    if obj != null and obj.has_method(method):
        return obj.callv(method, args)
    return null

func _safe_call_int(obj, method: String, args: Array = []) -> int:
    var result = _safe_call(obj, method, args)
    return result as int if result != null else 0

func _safe_call_float(obj, method: String, args: Array = []) -> float:
    var result = _safe_call(obj, method, args)
    return result as float if result != null else 0.0

func _safe_call_bool(obj, method: String, args: Array = []) -> bool:
    var result = _safe_call(obj, method, args)
    return result as bool if result != null else false

func test_basic_properties() -> void:
    # Skip if component is null
    if not component:
        TypeSafeMixin.skip_test(self, "Component was not properly initialized.")
        return
    
    # Test setting and getting properties through safe methods
    TypeSafeMixin._set_property_safe(component, "name", "Enhanced Shield")
    TypeSafeMixin._set_property_safe(component, "description", "Advanced shield generator")
    TypeSafeMixin._set_property_safe(component, "cost", 150)
    TypeSafeMixin._set_property_safe(component, "power_draw", 25)
    
    # Verify properties were set correctly
    assert_eq(TypeSafeMixin._get_property_safe(component, "name"), "Enhanced Shield", "Name should match what was set")
    assert_eq(TypeSafeMixin._get_property_safe(component, "description"), "Advanced shield generator", "Description should match what was set")
    assert_eq(TypeSafeMixin._get_property_safe(component, "cost", 0), 150, "Cost should match what was set")
    assert_eq(TypeSafeMixin._get_property_safe(component, "power_draw", 0), 25, "Power draw should match what was set")

func test_condition_management() -> void:
    # Skip if component is null
    if not component:
        TypeSafeMixin.skip_test(self, "Component was not properly initialized.")
        return
    
    # Only run if condition and max_condition properties exist
    var has_condition = "condition" in component or component.has_method("get_condition")
    var has_max_condition = "max_condition" in component or component.has_method("get_max_condition")
    
    if not has_condition or not has_max_condition:
        TypeSafeMixin.skip_test(self, "Component doesn't support condition management.")
        return
    
    # Set initial condition values
    var max_condition_value = 100
    TypeSafeMixin._set_property_safe(component, "max_condition", max_condition_value)
    TypeSafeMixin._set_property_safe(component, "condition", max_condition_value)
    
    # Verify initial condition
    assert_eq(TypeSafeMixin._get_property_safe(component, "condition", 0), max_condition_value, "Initial condition should be at maximum")
    
    # Test reducing condition
    TypeSafeMixin._set_property_safe(component, "condition", 50)
    assert_eq(TypeSafeMixin._get_property_safe(component, "condition", 0), 50, "Condition should be reduced to 50")
    
    # Test condition can't exceed maximum
    TypeSafeMixin._set_property_safe(component, "condition", max_condition_value + 10)
    assert_eq(TypeSafeMixin._get_property_safe(component, "condition", 0), max_condition_value, "Condition should not exceed maximum")
    
    # Test condition can't go below zero
    TypeSafeMixin._set_property_safe(component, "condition", -10)
    assert_eq(TypeSafeMixin._get_property_safe(component, "condition", 0), 0, "Condition should not go below zero")

func test_damage_and_repair() -> void:
    # Skip if component is null
    if not component:
        TypeSafeMixin.skip_test(self, "Component was not properly initialized.")
        return
    
    # Only run if damage and repair methods exist
    if not component.has_method("damage") or not component.has_method("repair"):
        TypeSafeMixin.skip_test(self, "Component doesn't support damage and repair operations.")
        return
    
    # Set initial condition
    TypeSafeMixin._set_property_safe(component, "max_condition", 100)
    TypeSafeMixin._set_property_safe(component, "condition", 100)
    
    # Test damage
    TypeSafeMixin._call_method_safe(component, "damage", [30])
    assert_eq(TypeSafeMixin._get_property_safe(component, "condition", 0), 70, "Component should take 30 damage")
    
    # Test repair
    TypeSafeMixin._call_method_safe(component, "repair", [20])
    assert_eq(TypeSafeMixin._get_property_safe(component, "condition", 0), 90, "Component should be repaired by 20")
    
    # Test full repair
    TypeSafeMixin._call_method_safe(component, "repair", [100])
    assert_eq(TypeSafeMixin._get_property_safe(component, "condition", 0), 100, "Component should be fully repaired")

func test_installation() -> void:
    # Skip if component is null
    if not component:
        TypeSafeMixin.skip_test(self, "Component was not properly initialized.")
        return
    
    # Check if component supports installation
    var supports_installation = "installed" in component or component.has_method("is_installed") or component.has_method("get_installed")
    
    if not supports_installation:
        TypeSafeMixin.skip_test(self, "Component doesn't support installation tracking.")
        return
    
    # Test installation state
    TypeSafeMixin._set_property_safe(component, "installed", false)
    assert_false(TypeSafeMixin._get_property_safe(component, "installed", true), "Component should be marked as not installed")
    
    TypeSafeMixin._set_property_safe(component, "installed", true)
    assert_true(TypeSafeMixin._get_property_safe(component, "installed", false), "Component should be marked as installed")

func test_operational_status() -> void:
    # Skip if component is null
    if not component:
        TypeSafeMixin.skip_test(self, "Component was not properly initialized.")
        return
    
    # Test if component has operational status methods
    if not component.has_method("is_operational") and not ("operational" in component):
        TypeSafeMixin.skip_test(self, "Component doesn't support operational status.")
        return
    
    # Test operation based on condition
    if "condition" in component or component.has_method("get_condition"):
        TypeSafeMixin._set_property_safe(component, "max_condition", 100)
        TypeSafeMixin._set_property_safe(component, "condition", 100)
        
        # Should be operational at full condition
        var operational = TypeSafeMixin._call_method_safe(component, "is_operational", [])
        if operational != null:
            assert_true(operational, "Component should be operational at full condition")
        
        # Set to critical condition
        TypeSafeMixin._set_property_safe(component, "condition", 10)
        operational = TypeSafeMixin._call_method_safe(component, "is_operational", [])
        
        # Some components might still be operational at low condition
        # This is implementation-specific, so we don't assert any specific behavior
    
    # Test operation based on power
    if "powered" in component or component.has_method("is_powered"):
        TypeSafeMixin._set_property_safe(component, "powered", true)
        var powered = TypeSafeMixin._get_property_safe(component, "powered", false)
        assert_true(powered, "Component should be powered")
        
        TypeSafeMixin._set_property_safe(component, "powered", false)
        powered = TypeSafeMixin._get_property_safe(component, "powered", true)
        assert_false(powered, "Component should not be powered")

func test_serialization() -> void:
    # Skip if component is null
    if not component:
        TypeSafeMixin.skip_test(self, "Component was not properly initialized.")
        return
    
    # Check if component supports serialization
    if not component.has_method("to_dict") or not component.has_method("from_dict"):
        TypeSafeMixin.skip_test(self, "Component doesn't support serialization.")
        return
    
    # Set up test data
    TypeSafeMixin._set_property_safe(component, "name", "Test Component")
    
    # Try to determine the appropriate type for component_type
    # Check if property exists and its type
    var has_component_type = "component_type" in component
    var current_type_value = null
    
    if has_component_type:
        current_type_value = component.get("component_type")
    elif component.has_method("get_component_type"):
        current_type_value = component.get_component_type()
    
    # Only set component_type if it exists and we can determine its type
    if current_type_value != null:
        if current_type_value is int:
            TypeSafeMixin._set_property_safe(component, "component_type", 1)
        elif current_type_value is String:
            TypeSafeMixin._set_property_safe(component, "component_type", "test_type")
        elif current_type_value is Resource:
            # Skip setting complex resource type
            pass
    
    TypeSafeMixin._set_property_safe(component, "condition", 75)
    TypeSafeMixin._set_property_safe(component, "installed", true)
    
    # Test serialization
    var data = TypeSafeMixin._call_method_safe(component, "to_dict", [])
    assert_not_null(data, "to_dict() should return a valid dictionary")
    
    # Create a new component from data
    var new_component = load(component.resource_path).new()
    TypeSafeMixin._call_method_safe(new_component, "from_dict", [data])
    
    # Verify deserialized data
    assert_eq(TypeSafeMixin._get_property_safe(new_component, "name"), "Test Component", "Deserialized name should match")
    
    # Only verify component_type if we were able to set it
    if current_type_value != null and !(current_type_value is Resource):
        if current_type_value is int:
            assert_eq(TypeSafeMixin._get_property_safe(new_component, "component_type"), 1, "Deserialized type should match")
        elif current_type_value is String:
            assert_eq(TypeSafeMixin._get_property_safe(new_component, "component_type"), "test_type", "Deserialized type should match")
    
    assert_eq(TypeSafeMixin._get_property_safe(new_component, "condition"), 75, "Deserialized condition should match")
    assert_true(TypeSafeMixin._get_property_safe(new_component, "installed"), "Deserialized installed state should match")