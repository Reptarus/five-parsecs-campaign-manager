@tool
extends "res://tests/fixtures/base/game_test.gd"
# Use explicit preloads instead of global class names

# Type definitions
const ShipCreationScript: GDScript = preload("res://src/core/managers/ShipCreation.gd")
const ShipScript: GDScript = preload("res://src/core/ships/Ship.gd")
const TestEnums = preload("res://tests/fixtures/base/test_helper.gd")

# Test variables with explicit types
var creator: Node = null

func before_each() -> void:
	await super.before_each()
	creator = ShipCreationScript.new()
	if not creator:
		push_error("Failed to create ship creator")
		return
		
	add_child_autofree(creator)
	await get_tree().process_frame

func after_each() -> void:
	await super.after_each()
	creator = null

func test_initial_setup() -> void:
	assert_not_null(creator, "Ship creator should be initialized")
	if not creator:
		return
		
	assert_true(TypeSafeMixin._call_node_method_bool(creator, "has_method", ["create_ship"]), "Should have create_ship method")
	assert_true(TypeSafeMixin._call_node_method_bool(creator, "has_method", ["create_component"]), "Should have create_component method")

func test_ship_creation() -> void:
	if not creator:
		assert_not_null(creator, "Ship creator should be initialized")
		return
		
	var ship_data: Dictionary = {
		"name": "Test Ship",
		"ship_class": "Frigate",
		"hull_points": 100,
		"shield_points": 50,
		"components": []
	}
	
	var ship = TypeSafeMixin._call_node_method(creator, "create_ship", [ship_data])
	assert_not_null(ship, "Should create ship instance")
	if not ship:
		return
	
	# Use get_property_safe with default values
	var ship_name = TypeSafeMixin._get_property_safe(ship, "name", "")
	var ship_class = TypeSafeMixin._get_property_safe(ship, "ship_class", "")
	var hull_points = TypeSafeMixin._get_property_safe(ship, "hull_points", 0)
	var shield_points = TypeSafeMixin._get_property_safe(ship, "shield_points", 0)
	
	assert_eq(ship_name, "Test Ship", "Ship name should match")
	assert_eq(ship_class, "Frigate", "Ship class should match")
	assert_eq(hull_points, 100, "Hull points should match")
	assert_eq(shield_points, 50, "Shield points should match")

func test_component_creation() -> void:
	if not creator:
		assert_not_null(creator, "Ship creator should be initialized")
		return
		
	var component_data: Dictionary = {
		"type": TestEnums.ComponentType.WEAPON,
		"name": "Test Weapon",
		"damage": 25,
		"range": 100
	}
	
	var component = TypeSafeMixin._call_node_method(creator, "create_component", [component_data])
	assert_not_null(component, "Should create component instance")
	if not component:
		return
	
	# Use get_property_safe with default values
	var type = TypeSafeMixin._get_property_safe(component, "type", 0)
	var name = TypeSafeMixin._get_property_safe(component, "name", "")
	var damage = TypeSafeMixin._get_property_safe(component, "damage", 0)
	var range_val = TypeSafeMixin._get_property_safe(component, "range", 0)
	
	assert_eq(type, TestEnums.ComponentType.WEAPON, "Component type should match")
	assert_eq(name, "Test Weapon", "Component name should match")
	assert_eq(damage, 25, "Component damage should match")
	assert_eq(range_val, 100, "Component range should match")

func test_ship_with_components() -> void:
	if not creator:
		assert_not_null(creator, "Ship creator should be initialized")
		return
		
	var component_data: Dictionary = {
		"type": TestEnums.ComponentType.WEAPON,
		"name": "Test Weapon",
		"damage": 25,
		"range": 100
	}
	
	var ship_data: Dictionary = {
		"name": "Armed Ship",
		"ship_class": "Destroyer",
		"hull_points": 150,
		"shield_points": 75,
		"components": [component_data]
	}
	
	var ship = TypeSafeMixin._call_node_method(creator, "create_ship", [ship_data])
	assert_not_null(ship, "Should create ship instance")
	if not ship:
		return
	
	var components = TypeSafeMixin._call_node_method_array(ship, "get_components", [], [])
	assert_eq(components.size(), 1, "Ship should have one component")
	if components.size() <= 0:
		return
		
	var component = components[0]
	if not component:
		assert_not_null(component, "Component should exist")
		return
		
	var type = TypeSafeMixin._get_property_safe(component, "type", 0)
	var name = TypeSafeMixin._get_property_safe(component, "name", "")
	
	assert_eq(type, TestEnums.ComponentType.WEAPON, "Component type should match")
	assert_eq(name, "Test Weapon", "Component name should match")

func test_invalid_ship_data() -> void:
	if not creator:
		assert_not_null(creator, "Ship creator should be initialized")
		return
		
	var invalid_data: Dictionary = {
		"name": "Invalid Ship"
		# Missing required fields
	}
	
	var ship = TypeSafeMixin._call_node_method(creator, "create_ship", [invalid_data])
	assert_null(ship, "Should not create ship with invalid data")

func test_invalid_component_data() -> void:
	if not creator:
		assert_not_null(creator, "Ship creator should be initialized")
		return
		
	var invalid_data: Dictionary = {
		"name": "Invalid Component"
		# Missing required type field
	}
	
	var component = TypeSafeMixin._call_node_method(creator, "create_component", [invalid_data])
	assert_null(component, "Should not create component with invalid data")

func test_component_validation() -> void:
	if not creator:
		assert_not_null(creator, "Ship creator should be initialized")
		return
		
	var invalid_type_data: Dictionary = {
		"type": 999, # Invalid type
		"name": "Invalid Component"
	}
	
	var component = TypeSafeMixin._call_node_method(creator, "create_component", [invalid_type_data])
	assert_null(component, "Should not create component with invalid type")
	
	var invalid_values_data: Dictionary = {
		"type": TestEnums.ComponentType.WEAPON,
		"name": "Invalid Values",
		"damage": - 25, # Negative damage
		"range": - 100 # Negative range
	}
	
	component = TypeSafeMixin._call_node_method(creator, "create_component", [invalid_values_data])
	assert_null(component, "Should not create component with invalid values")

func test_ship_validation() -> void:
	if not creator:
		assert_not_null(creator, "Ship creator should be initialized")
		return
		
	var invalid_class_data: Dictionary = {
		"name": "Invalid Class Ship",
		"ship_class": "Invalid", # Unknown ship class
		"hull_points": 100,
		"shield_points": 50
	}
	
	var ship = TypeSafeMixin._call_node_method(creator, "create_ship", [invalid_class_data])
	assert_null(ship, "Should not create ship with invalid class")
	
	var invalid_values_data: Dictionary = {
		"name": "Invalid Values Ship",
		"ship_class": "Frigate",
		"hull_points": - 100, # Negative hull points
		"shield_points": - 50 # Negative shield points
	}
	
	ship = TypeSafeMixin._call_node_method(creator, "create_ship", [invalid_values_data])
	assert_null(ship, "Should not create ship with invalid values")

func test_component_limits() -> void:
	if not creator:
		assert_not_null(creator, "Ship creator should be initialized")
		return
		
	var component_data: Dictionary = {
		"type": TestEnums.ComponentType.WEAPON,
		"name": "Test Weapon",
		"damage": 25,
		"range": 100
	}
	
	var ship_data: Dictionary = {
		"name": "Component Test Ship",
		"ship_class": "Cruiser",
		"hull_points": 200,
		"shield_points": 100,
		"components": []
	}
	
	var ship = TypeSafeMixin._call_node_method(creator, "create_ship", [ship_data])
	assert_not_null(ship, "Should create ship instance")
	if not ship:
		return
	
	# Add maximum allowed components
	var max_components = TypeSafeMixin._call_node_method_int(ship, "get_max_components", [], 0)
	for i in range(max_components):
		var result = TypeSafeMixin._call_node_method_bool(ship, "add_component", [component_data])
		assert_true(result, "Should add component %d" % i)
	
	# Try to add one more component
	var result = TypeSafeMixin._call_node_method_bool(ship, "add_component", [component_data])
	assert_false(result, "Should not add component beyond limit")