@tool
extends "res://tests/fixtures/base/game_test_mock_extension.gd"

## Five Parsecs Campaign Manager - Mock Testing Example
## Tests demonstrating the proper usage of the mock testing framework
## 
## This test file shows how to create and use mock objects, how to use
## type-safe method calls, and how to test UI components safely.

# -----------------------------------------------------------------------------
# Setup / Teardown
# -----------------------------------------------------------------------------

# Test resources to use across multiple tests
var resource_manager = null
var test_character = null
var test_control = null

# Configuration verification
func test_verify_test_setup():
	assert_true(TypeSafeMixin != null, "TypeSafeMixin should be loaded")
	assert_true(has_method("create_mock"), "Should have create_mock method from parent class")
	assert_true(has_method("create_mock_manager"), "Should have create_mock_manager method")
	var test_obj = create_mock({"test_method": true})
	assert_not_null(test_obj, "Should be able to create mock objects")

# Called before each test
func before_each():
	await super.before_each()
	
	# Create mock manager
	resource_manager = create_mock_manager("ResourceManager")
	
	# Create a test character with custom methods
	test_character = create_mock({
		"get_health": 100,
		"get_name": "Test Character",
		"is_alive": true,
		"take_damage": func(amount: int):
			var current_health = test_character.get_mock_value("health", 100)
			var new_health = max(0, current_health - amount)
			test_character.set_mock_value("health", new_health)
			if new_health <= 0:
				test_character.set_mock_value("is_alive", false)
			return new_health
	})
	
	# Create a test UI control
	test_control = create_test_control()
	test_control.set_mock_value("get_value", "Test Value")
	
	await get_tree().process_frame

# Called after each test
func after_each():
	resource_manager = null
	test_character = null
	test_control = null
	await super.after_each()

# -----------------------------------------------------------------------------
# Type-Safe Method Call Tests
# -----------------------------------------------------------------------------

# Example test using type-safe method calls
func test_character_health():
	# Use type-safe method calls
	var health = TypeSafeMixin._call_node_method_int(test_character, "get_health")
	var is_alive = TypeSafeMixin._call_node_method_bool(test_character, "is_alive")
	
	assert_eq(health, 100, "Character should start with full health")
	assert_true(is_alive, "Character should be alive")
	
	# Call a method that changes state
	var new_health = TypeSafeMixin._call_node_method_int(test_character, "take_damage", [30])
	assert_eq(new_health, 70, "Health should be reduced after taking damage")
	
	# Test character death
	TypeSafeMixin._call_node_method(test_character, "take_damage", [100])
	is_alive = TypeSafeMixin._call_node_method_bool(test_character, "is_alive")
	assert_false(is_alive, "Character should be dead after taking too much damage")

# -----------------------------------------------------------------------------
# Resource Manager Tests
# -----------------------------------------------------------------------------

# Example test using resource manager mock
func test_resource_manager():
	# Get resources using type-safe method
	var resources = TypeSafeMixin._call_node_method_dict(resource_manager, "get_all_resources")
	
	# Check if specific resources exist
	assert_true("credits" in resources, "Credits should exist in resources")
	assert_true("fuel" in resources, "Fuel should exist in resources")
	
	# Check resource values
	var credits = resources.get("credits", {}).get("amount", 0)
	assert_eq(credits, 1000, "Should start with 1000 credits")
	
	# Test UI control
	var test_value = TypeSafeMixin._call_node_method_string(test_control, "get_value")
	assert_eq(test_value, "Test Value", "Should get the correct value from UI control")

# -----------------------------------------------------------------------------
# Property Access Tests
# -----------------------------------------------------------------------------

# Example using property access
func test_property_access():
	# Set a property safely
	var set_result = TypeSafeMixin._set_property_safe(test_character, "custom_property", "Custom Value")
	assert_true(set_result, "Should be able to set property")
	
	# Get the property back
	var value = TypeSafeMixin._get_property_safe(test_character, "custom_property", "Default")
	assert_eq(value, "Custom Value", "Should get back the value we set")
	
	# Try getting a non-existent property with default
	var missing_value = TypeSafeMixin._get_property_safe(test_character, "non_existent", "Default Value")
	assert_eq(missing_value, "Default Value", "Should get default value for missing property")

# -----------------------------------------------------------------------------
# UI Testing
# -----------------------------------------------------------------------------

# Example using make_testable
func test_make_testable():
	# Create a basic control
	var control = Control.new()
	add_child_autofree(control)
	
	# Make it testable
	var testable_control = make_testable(control)
	assert_not_null(testable_control, "Should create testable control")
	
	# Test that it now has mock methods
	var has_ui_method = testable_control.has_method("set_ui_enabled")
	assert_true(has_ui_method, "Testable control should have UI methods")