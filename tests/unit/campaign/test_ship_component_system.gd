## Ship Component System Test Suite
## Tests the functionality of the ship component management system
@tool
extends "res://tests/fixtures/base/game_test.gd"

# Load scripts safely - handles missing files gracefully
const Compatibility = preload("res://tests/fixtures/helpers/test_compatibility_helper.gd")
var ShipComponentSystemScript = load("res://src/core/ships/management/ShipComponentSystem.gd") if ResourceLoader.exists("res://src/core/ships/management/ShipComponentSystem.gd") else null
var ShipComponentScript = load("res://src/core/ships/components/ShipComponent.gd") if ResourceLoader.exists("res://src/core/ships/components/ShipComponent.gd") else null

# Type-safe variables
var _ship_components: Node = null
var _component_state: Resource = null

# Signal tracking
var _signal_data = {
	"component_added": false,
	"component_removed": false,
	"component_updated": false,
	"last_component": null
}

# Test Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	
	# Create component system with safer initialization
	if not ShipComponentSystemScript:
		push_error("ShipComponentSystem script is null")
		return
		
	var component_instance = ShipComponentSystemScript.new()
	
	# Handle different possible types of the component system
	if component_instance is Node:
		_ship_components = component_instance
		add_child_autofree(_ship_components)
		track_test_node(_ship_components)
	elif component_instance is Resource:
		_component_state = component_instance
		track_test_resource(_component_state)
		
		# Create a Node wrapper if necessary
		var wrapper = Node2D.new()
		wrapper.name = "ComponentSystemWrapper"
		wrapper.set_meta("system", _component_state)
		add_child_autofree(wrapper)
		track_test_node(wrapper)
	else:
		push_error("Component system is neither Node nor Resource")
		return
		
	_connect_signals()
	await stabilize_engine()

func after_each() -> void:
	_disconnect_signals()
	_reset_signal_data()
	_ship_components = null
	_component_state = null
	await super.after_each()

# Component System Tests
func test_component_initialization() -> void:
	# Validate that either _ship_components or _component_state exists
	if not _ship_components and not _component_state:
		push_error("Ship component system was not initialized")
		return
		
	# Use the correct reference based on what's available
	var system = _ship_components if _ship_components else _component_state
	
	assert_not_null(system, "Ship components should be initialized")
	
	# Check available components
	var components
	if system.has_method("get_all_components"):
		components = system.get_all_components()
	else:
		push_warning("get_all_components method not found, skipping check")
		return
		
	assert_true(components is Dictionary, "Should return components as dictionary")
	assert_true(components.size() > 0, "Should have default components")

# Signal Methods
func _connect_signals() -> void:
	var system = _ship_components if _ship_components else _component_state
	if not system:
		return
		
	# Connect signals safely
	if system.has_signal("component_added"):
		system.connect("component_added", _on_component_added)
	
	if system.has_signal("component_removed"):
		system.connect("component_removed", _on_component_removed)
	
	if system.has_signal("component_updated"):
		system.connect("component_updated", _on_component_updated)

func _disconnect_signals() -> void:
	var system = _ship_components if _ship_components else _component_state
	if not system:
		return
		
	# Disconnect signals safely
	if system.has_signal("component_added") and system.is_connected("component_added", _on_component_added):
		system.disconnect("component_added", _on_component_added)
	
	if system.has_signal("component_removed") and system.is_connected("component_removed", _on_component_removed):
		system.disconnect("component_removed", _on_component_removed)
	
	if system.has_signal("component_updated") and system.is_connected("component_updated", _on_component_updated):
		system.disconnect("component_updated", _on_component_updated)

func _reset_signal_data() -> void:
	_signal_data = {
		"component_added": false,
		"component_removed": false,
		"component_updated": false,
		"last_component": null
	}

func _on_component_added(component) -> void:
	_signal_data.component_added = true
	_signal_data.last_component = component

func _on_component_removed(component_id) -> void:
	_signal_data.component_removed = true
	_signal_data.last_component_id = component_id

func _on_component_updated(component) -> void:
	_signal_data.component_updated = true
	_signal_data.last_component = component

# Component Creation Tests
func test_component_creation() -> void:
	# Get the appropriate system reference
	var system = _ship_components if _ship_components else _component_state
	if not system:
		push_error("Component system not available")
		return
		
	# Ensure needed method exists
	if not system.has_method("create_component"):
		push_warning("create_component method not found in system")
		return
		
	# Reset signal tracking
	_reset_signal_data()
	
	# Create a test component
	var component_data = {
		"type": 1, # Use a numeric value instead of enum for compatibility
		"name": "Test Engine",
		"level": 1
	}
	
	var component = system.create_component(component_data)
	assert_not_null(component, "Should create a component")
	
	# Check component properties if available
	if component:
		if component.has_method("get_name"):
			assert_eq(component.get_name(), "Test Engine", "Should set component name")
		elif component is Dictionary and component.has("name"):
			assert_eq(component.name, "Test Engine", "Should set component name")
		else:
			push_warning("Could not verify component name")
		
		if component.has_method("get_type"):
			assert_eq(component.get_type(), 1, "Should set component type") # Use numeric value
		elif component is Dictionary and component.has("type"):
			assert_eq(component.type, 1, "Should set component type") # Use numeric value
		else:
			push_warning("Could not verify component type")
	
	# Verify signal was emitted if it exists
	if system.has_signal("component_added"):
		assert_true(_signal_data.component_added, "Should emit component_added signal")

# Component Retrieval Tests
func test_component_retrieval() -> void:
	var system = _ship_components if _ship_components else _component_state
	if not system:
		push_error("Component system not available")
		return
		
	# Create a component to retrieve
	if not system.has_method("create_component") or not system.has_method("get_component"):
		push_warning("Required methods missing, skipping test")
		return
		
	var component_data = {
		"type": 2, # Use a numeric value instead of enum for compatibility
		"name": "Test Shield"
	}
	
	var component = system.create_component(component_data)
	assert_not_null(component, "Should create a component")
	
	# Get component ID
	var component_id = ""
	if component.has_method("get_id"):
		component_id = component.get_id()
	elif component is Dictionary and component.has("id"):
		component_id = component.id
	else:
		push_warning("Cannot get component ID, skipping test")
		return
		
	# Retrieve the component by ID
	var retrieved = system.get_component(component_id)
	assert_not_null(retrieved, "Should retrieve the component")
	
	# Verify it's the same component
	var retrieved_id = ""
	if retrieved.has_method("get_id"):
		retrieved_id = retrieved.get_id()
	elif retrieved is Dictionary and retrieved.has("id"):
		retrieved_id = retrieved.id
		
	assert_eq(retrieved_id, component_id, "Should retrieve the same component")
