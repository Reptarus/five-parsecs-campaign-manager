@tool
extends "res://tests/fixtures/specialized/campaign_test.gd"

# Load scripts safely - handles missing files gracefully
const Compatibility = preload("res://tests/fixtures/helpers/test_compatibility_helper.gd")
var ShipScript = load("res://src/core/ships/Ship.gd") if ResourceLoader.exists("res://src/core/ships/Ship.gd") else null

# Enum for ship component types
enum ShipComponentType {WEAPON = 0, ENGINE = 1, SHIELD = 2, ARMOR = 3}

var ship: Node = null
var _ship_name: String = ""
var _ship_description: String = ""
var _components: Array = []

func before_each() -> void:
	await super.before_each()
	ship = _setup_ship()
	assert_not_null(ship, "Ship instance should not be null")

func after_each() -> void:
	_cleanup_ship()
	await super.after_each()

func _setup_ship() -> Node:
	if not ShipScript:
		fail_test("ShipScript is null - cannot run tests")
		return null
		
	var ship_instance = ShipScript.new()
	if not ship_instance:
		fail_test("Failed to create ship instance")
		return null
		
	# Check if we have a node or resource
	if ship_instance is Node:
		add_child_autofree(ship_instance)
		track_test_node(ship_instance)
		return ship_instance
	elif ship_instance is Resource:
		# Create a node wrapper
		var node_wrapper = Node.new()
		node_wrapper.name = "ShipWrapper"
		node_wrapper.set_meta("ship_resource", ship_instance)
		add_child_autofree(node_wrapper)
		track_test_node(node_wrapper)
		track_test_resource(ship_instance)
		return node_wrapper
	else:
		fail_test("Ship instance is neither a Node nor a Resource")
		return null

func _cleanup_ship() -> void:
	ship = null
	_components.clear()
	
# Test functions
func test_ship_initialization() -> void:
	assert_not_null(ship, "Ship should be initialized")
	if not ship:
		return
	
	# Check if required methods exist
	var has_required_methods = ship.has_method("get_name") and ship.has_method("get_description") and ship.has_method("get_components")
	if not has_required_methods:
		push_warning("Skipping test_ship_initialization: required methods missing")
		pending("Test skipped - required methods missing")
		return
	
	var name: String = _get_property_safe(ship, "name", "")
	var description: String = _get_property_safe(ship, "description", "")
	
	assert_eq(name, "", "Default name should be empty")
	assert_eq(description, "", "Default description should be empty")
	
	var components: Array = _call_method_safe(ship, "get_components", []) or []
	assert_true(components.is_empty(), "Ship should have no components initially")

func test_ship_properties() -> void:
	assert_not_null(ship, "Ship should be initialized")
	if not ship:
		return
	
	# Check if required methods exist
	var has_required_methods = ship.has_method("get_name") and ship.has_method("get_description")
	if not has_required_methods:
		push_warning("Skipping test_ship_properties: required methods missing")
		pending("Test skipped - required methods missing")
		return
	
	var test_name: String = "Test Ship"
	var test_description: String = "Test Description"
	
	_set_property_safe(ship, "name", test_name)
	_set_property_safe(ship, "description", test_description)
	
	var name: String = _get_property_safe(ship, "name", "")
	var description: String = _get_property_safe(ship, "description", "")
	
	assert_eq(name, test_name, "Name should be set correctly")
	assert_eq(description, test_description, "Description should be set correctly")

func test_add_component() -> void:
	assert_not_null(ship, "Ship should be initialized")
	if not ship:
		return
	
	# Check if required methods and signals exist
	var has_required_methods = ship.has_method("add_component") and ship.has_method("get_components")
	var has_required_signals = ship.has_signal("component_added")
	if not has_required_methods or not has_required_signals:
		push_warning("Skipping test_add_component: required methods or signals missing")
		pending("Test skipped - required methods or signals missing")
		return
	
	watch_signals(ship)
	
	var component = Resource.new()
	if not component:
		fail_test("Failed to create component")
		return
		
	component.set_meta("id", "test_component")
	component.set_meta("component_type", "engine")
	track_test_resource(component)
	
	var result: bool = _call_method_safe(ship, "add_component", [component]) or false
	assert_true(result, "Should add component successfully")
	
	var components: Array = _call_method_safe(ship, "get_components", []) or []
	
	# Check if component is in array using manual iteration
	var component_found = false
	for c in components:
		if c == component:
			component_found = true
			break
	assert_true(component_found, "Ship should contain the added component")
	assert_signal_emitted(ship, "component_added")

func test_remove_component() -> void:
	assert_not_null(ship, "Ship should be initialized")
	if not ship:
		return
	
	# Check if required methods and signals exist
	if not (ship.has_method("add_component") and ship.has_method("remove_component") and
	       ship.has_method("get_components") and ship.has_signal("component_removed")):
		push_warning("Skipping test_remove_component: required methods or signals missing")
		pending("Test skipped - required methods or signals missing")
		return
	
	watch_signals(ship)
	
	var component = Resource.new()
	if not component:
		fail_test("Failed to create component")
		return
		
	component.set_meta("id", "test_component")
	component.set_meta("component_type", "engine")
	track_test_resource(component)
	
	Compatibility.call_node_method_bool(ship, "add_component", [component])
	var result: bool = Compatibility.call_node_method_bool(ship, "remove_component", [component])
	assert_true(result, "Should remove component successfully")
	
	var components: Array = Compatibility.call_node_method_array(ship, "get_components", [])
	
	# Check that component is not in array using manual iteration
	var component_found = false
	if components is Array:
		for c in components:
			if c == component:
				component_found = true
				break
	assert_false(component_found, "Ship should not contain the removed component")
	assert_signal_emitted(ship, "component_removed")

func test_get_component_by_id() -> void:
	assert_not_null(ship, "Ship should be initialized")
	if not ship:
		return
	
	# Check if required methods exist
	if not (ship.has_method("add_component") and ship.has_method("get_component_by_id")):
		push_warning("Skipping test_get_component_by_id: required methods missing")
		pending("Test skipped - required methods missing")
		return
	
	var component = Resource.new()
	if not component:
		fail_test("Failed to create component")
		return
		
	component.set_meta("id", "test_component")
	component.set_meta("component_type", "engine")
	track_test_resource(component)
	
	Compatibility.call_node_method_bool(ship, "add_component", [component])
	var retrieved: Resource = Compatibility.call_method(ship, "get_component_by_id", ["test_component"]) as Resource
	
	assert_not_null(retrieved, "Should retrieve component by ID")
	assert_eq(retrieved, component, "Retrieved component should match original")

func test_get_component_by_type() -> void:
	assert_not_null(ship, "Ship should be initialized")
	if not ship:
		return
	
	# Check if required methods exist
	if not (ship.has_method("add_component") and ship.has_method("get_component_by_type")):
		push_warning("Skipping test_get_component_by_type: required methods missing")
		pending("Test skipped - required methods missing")
		return
	
	var component = Resource.new()
	if not component:
		fail_test("Failed to create component")
		return
		
	component.set_meta("id", "test_component")
	track_test_resource(component)
	
	if component.has_method("set_type"):
		Compatibility.call_node_method_bool(component, "set_type", [ShipComponentType.WEAPON])
		Compatibility.call_node_method_bool(ship, "add_component", [component])
		
		var found: Resource = Compatibility.call_node_method_resource(ship, "get_component_by_type", [ShipComponentType.WEAPON])
		assert_eq(found, component, "Should find component by type")
	else:
		push_warning("Skipping part of test_get_component_by_type: component.set_type method missing")
		pending("Component is missing set_type method")

func test_calculate_stats() -> void:
	assert_not_null(ship, "Ship should be initialized")
	if not ship:
		return
	
	# Check if required methods exist
	if not (ship.has_method("add_component") and ship.has_method("calculate_stats")):
		push_warning("Skipping test_calculate_stats: required methods missing")
		pending("Test skipped - required methods missing")
		return
	
	var component1 = Resource.new()
	if not component1:
		fail_test("Failed to create component1")
		return
		
	component1.set_meta("id", "component1")
	track_test_resource(component1)
	
	var component2 = Resource.new()
	if not component2:
		fail_test("Failed to create component2")
		return
		
	component2.set_meta("id", "component2")
	track_test_resource(component2)
	
	if not (component1.has_method("set_stat_modifier") and component2.has_method("set_stat_modifier")):
		push_warning("Skipping part of test_calculate_stats: set_stat_modifier method missing")
		pending("Components are missing set_stat_modifier method")
		return
	
	Compatibility.call_node_method_bool(component1, "set_stat_modifier", ["speed", 5])
	Compatibility.call_node_method_bool(component2, "set_stat_modifier", ["speed", 10])
	
	Compatibility.call_node_method_bool(ship, "add_component", [component1])
	Compatibility.call_node_method_bool(ship, "add_component", [component2])
	
	var result: Dictionary = Compatibility.call_node_method_dict(ship, "calculate_stats", [])
	assert_true("speed" in result, "Stats should include speed")
	assert_eq(result["speed"], 15, "Speed should be sum of component modifiers")

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

# Type-safe helper methods for setting and getting properties
func _set_property_safe(obj, property_name: String, value) -> bool:
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

# Type-safe helper method to get properties
func _get_property_safe(obj, property_name: String, default_value = null):
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

# Type-safe helper method to call methods
func _call_method_safe(obj, method_name: String, args: Array = []):
	if obj == null or not obj.has_method(method_name):
		return null
	return obj.callv(method_name, args)
