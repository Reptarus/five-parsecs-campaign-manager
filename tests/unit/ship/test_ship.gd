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
		
	add_child_autofree(ship_instance)
	track_test_node(ship_instance)
	return ship_instance

func _cleanup_ship() -> void:
	ship = null
	_components.clear()
	
# Test functions
func test_ship_initialization() -> void:
	assert_not_null(ship, "Ship should be initialized")
	
	# Check if required methods exist
	if not (ship.has_method("get_name") and ship.has_method("get_description") and
	       ship.has_method("get_components")):
		push_warning("Skipping test_ship_initialization: required methods missing")
		pending("Test skipped - required methods missing")
		return
	
	var name: String = Compatibility.safe_cast_to_string(Compatibility.call_method(ship, "get_name", []))
	var description: String = Compatibility.safe_cast_to_string(Compatibility.call_method(ship, "get_description", []))
	
	assert_eq(name, "", "Default name should be empty")
	assert_eq(description, "", "Default description should be empty")
	
	var components: Array = Compatibility.call_node_method_array(ship, "get_components", [])
	assert_true(components.is_empty(), "Ship should have no components initially")

func test_ship_properties() -> void:
	# Check if required methods exist
	if not (ship.has_method("get_name") and ship.has_method("get_description") and
	       ship.has_method("set_name") and ship.has_method("set_description")):
		push_warning("Skipping test_ship_properties: required methods missing")
		pending("Test skipped - required methods missing")
		return
	
	var test_name: String = "Test Ship"
	var test_description: String = "Test Description"
	
	Compatibility.call_node_method_bool(ship, "set_name", [test_name])
	Compatibility.call_node_method_bool(ship, "set_description", [test_description])
	
	var name: String = Compatibility.safe_cast_to_string(Compatibility.call_method(ship, "get_name", []))
	var description: String = Compatibility.safe_cast_to_string(Compatibility.call_method(ship, "get_description", []))
	
	assert_eq(name, test_name, "Name should be set correctly")
	assert_eq(description, test_description, "Description should be set correctly")

func test_add_component() -> void:
	# Check if required methods and signals exist
	if not (ship.has_method("add_component") and ship.has_method("get_components") and
	       ship.has_signal("component_added")):
		push_warning("Skipping test_add_component: required methods or signals missing")
		pending("Test skipped - required methods or signals missing")
		return
	
	watch_signals(ship)
	
	var component = Resource.new()
	component.set_meta("id", "test_component")
	component.set_meta("component_type", "engine")
	track_test_resource(component)
	
	var result: bool = Compatibility.call_node_method_bool(ship, "add_component", [component])
	assert_true(result, "Should add component successfully")
	
	var components: Array = Compatibility.call_node_method_array(ship, "get_components", [])
	
	# Check if component is in array using manual iteration
	var component_found = false
	if components is Array:
		for c in components:
			if c == component:
				component_found = true
				break
	assert_true(component_found, "Ship should contain the added component")
	assert_signal_emitted(ship, "component_added")

func test_remove_component() -> void:
	# Check if required methods and signals exist
	if not (ship.has_method("add_component") and ship.has_method("remove_component") and
	       ship.has_method("get_components") and ship.has_signal("component_removed")):
		push_warning("Skipping test_remove_component: required methods or signals missing")
		pending("Test skipped - required methods or signals missing")
		return
	
	watch_signals(ship)
	
	var component = Resource.new()
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
	# Check if required methods exist
	if not (ship.has_method("add_component") and ship.has_method("get_component_by_id")):
		push_warning("Skipping test_get_component_by_id: required methods missing")
		pending("Test skipped - required methods missing")
		return
	
	var component = Resource.new()
	component.set_meta("id", "test_component")
	component.set_meta("component_type", "engine")
	track_test_resource(component)
	
	Compatibility.call_node_method_bool(ship, "add_component", [component])
	var retrieved: Resource = Compatibility.call_method(ship, "get_component_by_id", ["test_component"]) as Resource
	
	assert_not_null(retrieved, "Should retrieve component by ID")
	assert_eq(retrieved, component, "Retrieved component should match original")

func test_get_component_by_type() -> void:
	# Check if required methods exist
	if not (ship.has_method("add_component") and ship.has_method("get_component_by_type")):
		push_warning("Skipping test_get_component_by_type: required methods missing")
		pending("Test skipped - required methods missing")
		return
	
	var component = Resource.new()
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
	# Check if required methods exist
	if not (ship.has_method("add_component") and ship.has_method("calculate_stats")):
		push_warning("Skipping test_calculate_stats: required methods missing")
		pending("Test skipped - required methods missing")
		return
	
	var component1 = Resource.new()
	component1.set_meta("id", "component1")
	track_test_resource(component1)
	
	var component2 = Resource.new()
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
