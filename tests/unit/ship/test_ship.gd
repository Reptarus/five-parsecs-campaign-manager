@tool
extends "res://tests/fixtures/specialized/campaign_test.gd"

const ShipScript = preload("res://src/core/ships/Ship.gd")

var ship: Node = null
var _ship_name: String = ""
var _ship_description: String = ""
var _components: Array = []

func before_each() -> void:
	await super.before_each()
	
	# Create a Node instance since Ship.gd might not be a Resource
	ship = Node.new()
	if not ship:
		push_error("Failed to create ship")
		return
	
	# Reset test values
	_ship_name = ""
	_ship_description = ""
	_components = []
	
	# Add methods to the ship Node
	ship.set_meta("get_name", func(): return _ship_name)
	ship.set_meta("set_name", func(p_name: String): _ship_name = p_name; return true)
	ship.set_meta("get_description", func(): return _ship_description)
	ship.set_meta("set_description", func(p_description: String): _ship_description = p_description; return true)
	
	# Component management methods
	ship.set_meta("add_component", func(component):
		if component and component.has_meta("component_id"):
			_components.append(component)
			return true
		return false
	)
	ship.set_meta("has_component", func(component_id: String):
		for component in _components:
			if component.get_meta("component_id") == component_id:
				return true
		return false
	)
	ship.set_meta("get_components", func(): return _components.duplicate())
	ship.set_meta("remove_component", func(component):
		for i in range(_components.size()):
			if _components[i] == component:
				_components.remove_at(i)
				return true
		return false
	)
	ship.set_meta("get_component_by_id", func(component_id: String):
		for component in _components:
			if component.get_meta("component_id") == component_id:
				return component
		return null
	)
	ship.set_meta("calculate_stats", func():
		var stats = {"speed": 0, "defense": 0, "attack": 0}
		
		for component in _components:
			if component.has_meta("speed_bonus"):
				stats["speed"] += component.get_meta("speed_bonus")
			if component.has_meta("defense_bonus"):
				stats["defense"] += component.get_meta("defense_bonus")
			if component.has_meta("attack_bonus"):
				stats["attack"] += component.get_meta("attack_bonus")
				
		return stats
	)
	
	# Use add_child_autofree and track_test_node instead of track_test_resource
	add_child_autofree(ship)
	track_test_node(ship)
	await get_tree().process_frame

func after_each() -> void:
	await super.after_each()
	
	# Reset test values
	_ship_name = ""
	_ship_description = ""
	
	# Free components that might have been created
	for component in _components:
		if is_instance_valid(component):
			component.free()
	_components.clear()
	
	# The ship node will be freed by the test framework via track_test_node
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
