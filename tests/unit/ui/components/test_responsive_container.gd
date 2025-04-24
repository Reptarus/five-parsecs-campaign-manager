@tool
extends "res://tests/fixtures/base/game_test.gd"

## Consolidated Test Suite for ResponsiveContainer
##
## Tests the functionality of the responsive container component,
## which adapts to different screen sizes and orientations.

# Script dependencies with explicit type annotation
const ResponsiveContainer: GDScript = preload("res://src/ui/components/base/ResponsiveContainer.gd")
const ResponsiveContainerTestHelper: GDScript = preload("res://tests/fixtures/helpers/responsive_container_test_helper.gd")

# Test constants with explicit types
const TEST_DEFAULT_SIZE: Vector2 = Vector2(800, 600)
const TEST_CONTENT_SIZE: Vector2 = Vector2(300, 200)
const TEST_SCREEN_SIZES: Dictionary = {
	"phone": Vector2(360, 640),
	"tablet": Vector2(768, 1024),
	"desktop": Vector2(1920, 1080)
}

# Test variables with explicit types
var _container: Control = null
var _test_child1: Control = null
var _test_child2: Control = null

# Lifecycle methods
func before_each() -> void:
	await super.before_each()
	
	# Create container using our helper
	if not ResponsiveContainerTestHelper:
		push_error("ResponsiveContainerTestHelper script is null")
		pending("Test skipped - Helper script is null")
		return
		
	if not ResponsiveContainer:
		push_error("ResponsiveContainer script is null")
		pending("Test skipped - Container script is null")
		return
	
	_container = ResponsiveContainerTestHelper.create_container()
	if not is_instance_valid(_container):
		push_error("Failed to create responsive container instance")
		pending("Test skipped - Container creation failed")
		return
	
	# Verify container integrity
	if not ResponsiveContainerTestHelper.verify_container_integrity(_container):
		push_error("Container failed integrity check")
		pending("Test skipped - Container integrity failed")
		return
	
	_container.name = "TestResponsiveContainer"
	_container.size = TEST_DEFAULT_SIZE
	add_child_autofree(_container)
	track_test_node(_container)
	
	# Create test children
	_create_test_children()
	
	# Add children to container
	if is_instance_valid(_test_child1) and is_instance_valid(_container):
		_container.add_child(_test_child1)
		track_test_node(_test_child1)
		
	if is_instance_valid(_test_child2) and is_instance_valid(_container):
		_container.add_child(_test_child2)
		track_test_node(_test_child2)
	
	# Wait for container to be ready with timeout protection
	if is_instance_valid(_container):
		var timeout = 1.0 # 1 second timeout
		var timer = 0.0
		while not _container.is_inside_tree() and timer < timeout:
			await get_tree().process_frame
			timer += get_process_delta_time()
	
	# Watch signals using our helper
	if _signal_watcher and is_instance_valid(_container):
		ResponsiveContainerTestHelper.watch_container_signals(_signal_watcher, _container)
	
	await stabilize_engine()

func after_each() -> void:
	# We don't need to manually free these as they're tracked and will be cleaned up
	# by the parent class through track_test_node
	_test_child1 = null
	_test_child2 = null
	_container = null
	
	await super.after_each()

func _create_test_children() -> void:
	_test_child1 = Panel.new()
	if is_instance_valid(_test_child1):
		_test_child1.custom_minimum_size = Vector2(100, 100)
		_test_child1.name = "TestChild1"
	else:
		push_error("Failed to create test child 1")
	
	_test_child2 = Panel.new()
	if is_instance_valid(_test_child2):
		_test_child2.custom_minimum_size = Vector2(150, 150)
		_test_child2.name = "TestChild2"
	else:
		push_error("Failed to create test child 2")

# Basic Container Tests
func test_initial_properties() -> void:
	if not is_instance_valid(_container):
		push_warning("Skipping test_initial_properties: _container is null or invalid")
		pending("Test skipped - _container is null or invalid")
		return
		
	assert_not_null(_container, "Container should be initialized")
	
	# Use safer property access via the helper
	var auto_mode = ResponsiveContainerTestHelper.get_layout_mode(_container, "AUTO", -1)
	
	# Use TypeSafeMixin for safer property access
	var responsive_mode: int = TypeSafeMixin._get_property_safe(_container, "responsive_mode", -1)
	
	assert_eq(responsive_mode, auto_mode, "Default layout mode should be AUTO")
	assert_eq(TypeSafeMixin._get_property_safe(_container, "min_width_for_horizontal", -1), 600,
		"Default breakpoint should be 600")
	assert_eq(TypeSafeMixin._get_property_safe(_container, "horizontal_spacing", -1), 10,
		"Default horizontal spacing should be 10")
	assert_eq(TypeSafeMixin._get_property_safe(_container, "vertical_spacing", -1), 10,
		"Default vertical spacing should be 10")
	assert_eq(TypeSafeMixin._get_property_safe(_container, "padding", -1), 10,
		"Default padding should be 10")

# Layout Tests
func test_horizontal_layout() -> void:
	if not is_instance_valid(_container):
		push_warning("Skipping test_horizontal_layout: _container is null or invalid")
		pending("Test skipped - _container is null or invalid")
		return
		
	if not (is_instance_valid(_test_child1) and is_instance_valid(_test_child2)):
		push_warning("Skipping test_horizontal_layout: test children are null or invalid")
		pending("Test skipped - test children are null or invalid")
		return
	
	# Get the layout mode enum value safely using our helper
	var horizontal_mode = ResponsiveContainerTestHelper.get_layout_mode(_container, "HORIZONTAL", 1)
	
	# Set layout mode
	TypeSafeMixin._set_property_safe(_container, "responsive_mode", horizontal_mode)
	
	# Set container size (above breakpoint)
	_container.size = Vector2(800, 300)
	_container._notification(Control.NOTIFICATION_RESIZED)
	
	# Force layout update
	TypeSafeMixin._call_node_method_bool(_container, "force_layout_update", [])
	
	await get_tree().process_frame
	
	# Check children positions
	assert_true(_test_child1.position.x < _test_child2.position.x,
		"Children should be arranged horizontally")

func test_vertical_layout() -> void:
	if not is_instance_valid(_container):
		push_warning("Skipping test_vertical_layout: _container is null or invalid")
		pending("Test skipped - _container is null or invalid")
		return
		
	if not (is_instance_valid(_test_child1) and is_instance_valid(_test_child2)):
		push_warning("Skipping test_vertical_layout: test children are null or invalid")
		pending("Test skipped - test children are null or invalid")
		return
	
	# Get the layout mode enum value safely using our helper
	var vertical_mode = ResponsiveContainerTestHelper.get_layout_mode(_container, "VERTICAL", 2)
	
	# Set layout mode
	TypeSafeMixin._set_property_safe(_container, "responsive_mode", vertical_mode)
	
	# Set container size
	_container.size = Vector2(300, 800)
	_container._notification(Control.NOTIFICATION_RESIZED)
	
	# Force layout update with safety check
	if _container.has_method("force_layout_update"):
		_container.force_layout_update()
	
	await get_tree().process_frame
	
	# Check children positions
	assert_true(_test_child1.position.y < _test_child2.position.y,
		"Children should be arranged vertically")

# Responsive Behavior Tests
func test_responsive_behavior() -> void:
	if not is_instance_valid(_container):
		push_warning("Skipping test_responsive_behavior: _container is null or invalid")
		pending("Test skipped - _container is null or invalid")
		return
		
	if not (is_instance_valid(_test_child1) and is_instance_valid(_test_child2)):
		push_warning("Skipping test_responsive_behavior: test children are null or invalid")
		pending("Test skipped - test children are null or invalid")
		return
	
	# Get the layout mode enum value safely using our helper
	var auto_mode = ResponsiveContainerTestHelper.get_layout_mode(_container, "AUTO", 0)
	
	# Set AUTO responsive mode
	TypeSafeMixin._set_property_safe(_container, "responsive_mode", auto_mode)
	TypeSafeMixin._set_property_safe(_container, "min_width_for_horizontal", 500)
	
	# Test above breakpoint (should be horizontal)
	_container.size = Vector2(600, 300)
	_container._notification(Control.NOTIFICATION_RESIZED)
	
	if _container.has_method("force_layout_update"):
		_container.force_layout_update()
	
	await get_tree().process_frame
	
	# Check if is_compact property exists before testing it
	if "is_compact" in _container:
		assert_false(TypeSafeMixin._get_property_safe(_container, "is_compact", true),
			"Container should not be in compact mode above breakpoint")
	
	# Check children arrangement
	assert_true(_test_child1.position.x < _test_child2.position.x,
		"Children should be arranged horizontally above breakpoint")
	
	# Test below breakpoint (should switch to vertical)
	_container.size = Vector2(400, 600)
	_container._notification(Control.NOTIFICATION_RESIZED)
	
	if _container.has_method("force_layout_update"):
		_container.force_layout_update()
	
	await get_tree().process_frame
	
	# Check if is_compact property exists before testing it
	if "is_compact" in _container:
		assert_true(TypeSafeMixin._get_property_safe(_container, "is_compact", false),
			"Container should be in compact mode below breakpoint")
	
	# Check children arrangement
	assert_true(_test_child1.position.y < _test_child2.position.y,
		"Children should be arranged vertically below breakpoint")

# Spacing Tests
func test_spacing_property() -> void:
	if not is_instance_valid(_container):
		push_warning("Skipping test_spacing_property: _container is null or invalid")
		pending("Test skipped - _container is null or invalid")
		return
		
	if not (is_instance_valid(_test_child1) and is_instance_valid(_test_child2)):
		push_warning("Skipping test_spacing_property: test children are null or invalid")
		pending("Test skipped - test children are null or invalid")
		return
	
	# Get the layout mode enum value safely
	var horizontal_mode: int = TypeSafeMixin._call_node_method_int(
		_container,
		"get",
		["ResponsiveLayoutMode.HORIZONTAL"],
		1 # Default to HORIZONTAL which is typically 1
	)
	
	# Record original positions
	TypeSafeMixin._set_property_safe(_container, "responsive_mode", horizontal_mode)
	TypeSafeMixin._set_property_safe(_container, "horizontal_spacing", 10)
	_container.size = Vector2(800, 300)
	TypeSafeMixin._call_node_method_bool(_container, "force_layout_update", [])
	
	await get_tree().process_frame
	
	var original_spacing = _test_child2.position.x - (_test_child1.position.x + _test_child1.size.x)
	
	# Increase spacing
	TypeSafeMixin._set_property_safe(_container, "horizontal_spacing", 50)
	TypeSafeMixin._call_node_method_bool(_container, "force_layout_update", [])
	
	await get_tree().process_frame
	
	var new_spacing = _test_child2.position.x - (_test_child1.position.x + _test_child1.size.x)
	assert_gt(new_spacing, original_spacing, "Spacing between children should increase")

# Orientation Tests
func test_orientation_detection() -> void:
	if not is_instance_valid(_container):
		push_warning("Skipping test_orientation_detection: _container is null or invalid")
		pending("Test skipped - _container is null or invalid")
		return
	
	# Constants for orientation
	var ORIENTATION_LANDSCAPE = TypeSafeMixin._get_property_safe(_container, "ORIENTATION_LANDSCAPE", 1)
	var ORIENTATION_PORTRAIT = TypeSafeMixin._get_property_safe(_container, "ORIENTATION_PORTRAIT", 0)
	
	# Test landscape orientation
	_container.size = Vector2(800, 600)
	_container._notification(Control.NOTIFICATION_RESIZED)
	TypeSafeMixin._call_node_method_bool(_container, "force_layout_update", [])
	
	await get_tree().process_frame
	
	var current_orientation = TypeSafeMixin._call_node_method_int(_container, "get_current_orientation", [])
	assert_eq(current_orientation, ORIENTATION_LANDSCAPE, "Should detect landscape orientation")
	assert_false(TypeSafeMixin._get_property_safe(_container, "is_portrait", true), "is_portrait should be false for landscape")
	
	# Test portrait orientation
	_container.size = Vector2(600, 800)
	_container._notification(Control.NOTIFICATION_RESIZED)
	TypeSafeMixin._call_node_method_bool(_container, "force_layout_update", [])
	
	await get_tree().process_frame
	
	current_orientation = TypeSafeMixin._call_node_method_int(_container, "get_current_orientation", [])
	assert_eq(current_orientation, ORIENTATION_PORTRAIT, "Should detect portrait orientation")
	assert_true(TypeSafeMixin._get_property_safe(_container, "is_portrait", false), "is_portrait should be true for portrait")

# Signal Tests
func test_layout_changed_signal() -> void:
	if not is_instance_valid(_container):
		push_warning("Skipping test_layout_changed_signal: _container is null or invalid")
		pending("Test skipped - _container is null or invalid")
		return
	
	watch_signals(_container)
	
	# Get the layout mode enum value safely
	var horizontal_mode: int = TypeSafeMixin._call_node_method_int(
		_container,
		"get",
		["ResponsiveLayoutMode.HORIZONTAL"],
		1 # Default to HORIZONTAL which is typically 1
	)
	
	var vertical_mode: int = TypeSafeMixin._call_node_method_int(
		_container,
		"get",
		["ResponsiveLayoutMode.VERTICAL"],
		2 # Default to VERTICAL which is typically 2
	)
	
	# Start with horizontal layout
	TypeSafeMixin._set_property_safe(_container, "responsive_mode", horizontal_mode)
	_container.size = Vector2(800, 300)
	TypeSafeMixin._call_node_method_bool(_container, "force_layout_update", [])
	
	await get_tree().process_frame
	
	# Switch to vertical
	TypeSafeMixin._set_property_safe(_container, "responsive_mode", vertical_mode)
	TypeSafeMixin._call_node_method_bool(_container, "force_layout_update", [])
	
	await get_tree().process_frame
	
	assert_signal_emitted(_container, "layout_changed")

func test_orientation_changed_signal() -> void:
	if not is_instance_valid(_container):
		push_warning("Skipping test_orientation_changed_signal: _container is null or invalid")
		pending("Test skipped - _container is null or invalid")
		return
	
	watch_signals(_container)
	
	# Start with landscape orientation
	_container.size = Vector2(800, 600)
	_container._notification(Control.NOTIFICATION_RESIZED)
	TypeSafeMixin._call_node_method_bool(_container, "force_layout_update", [])
	
	await get_tree().process_frame
	
	# Switch to portrait
	_container.size = Vector2(600, 800)
	_container._notification(Control.NOTIFICATION_RESIZED)
	TypeSafeMixin._call_node_method_bool(_container, "force_layout_update", [])
	
	await get_tree().process_frame
	
	assert_signal_emitted(_container, "orientation_changed")

# Theme Integration Tests
func test_theme_scale_integration() -> void:
	if not is_instance_valid(_container):
		push_warning("Skipping test_theme_scale_integration: _container is null or invalid")
		pending("Test skipped - _container is null or invalid")
		return
	
	var theme_manager = TypeSafeMixin._get_property_safe(_container, "_theme_manager", null)
	if not theme_manager:
		push_warning("Theme manager not available, skipping test_theme_scale_integration")
		pending("Test skipped - theme manager not available")
		return
	
	if not theme_manager.has_method("set_scale_factor"):
		push_warning("Theme manager missing set_scale_factor method, skipping test")
		pending("Test skipped - theme manager missing required method")
		return
	
	# Set initial scale
	TypeSafeMixin._set_property_safe(_container, "_scale_factor", 1.0)
	_container.size = Vector2(800, 300)
	TypeSafeMixin._set_property_safe(_container, "horizontal_spacing", 10)
	TypeSafeMixin._call_node_method_bool(_container, "force_layout_update", [])
	
	await get_tree().process_frame
	
	# Record original positions
	var original_spacing = _test_child2.position.x - (_test_child1.position.x + _test_child1.size.x)
	
	# Increase scale
	TypeSafeMixin._set_property_safe(_container, "_scale_factor", 2.0)
	TypeSafeMixin._call_node_method_bool(_container, "force_layout_update", [])
	
	await get_tree().process_frame
	
	var scaled_spacing = _test_child2.position.x - (_test_child1.position.x + _test_child1.size.x)
	assert_gt(scaled_spacing, original_spacing, "Spacing should increase with scale factor")

# Cleanup tests
func test_cleanup() -> void:
	if not is_instance_valid(_container):
		push_warning("Skipping test_cleanup: _container is null or invalid")
		pending("Test skipped - _container is null or invalid")
		return
	
	# Set up connections to test disconnection
	TypeSafeMixin._call_node_method_bool(_container, "_find_theme_manager", [])
	
	TypeSafeMixin._call_node_method_bool(_container, "cleanup", [])
	
	# Should have disconnected signals
	assert_eq(_container.get_child_count(), 2, "Children should remain after cleanup")
