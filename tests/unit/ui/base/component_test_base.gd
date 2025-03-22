@tool
extends "res://tests/unit/ui/base/ui_test_base.gd"

# Base class for component testing
# Do not use class_name to avoid conflicts

const ThemeManager = preload("res://src/ui/themes/ThemeManager.gd")
const ThemeTestHelper = preload("res://tests/unit/ui/themes/theme_test_helper.gd")
# Load UI test base methods and properties that we need without extending from it
const UITestBaseScript = preload("res://tests/unit/ui/base/ui_test_base.gd")

# Type-safe instance variables
var _component: Control
var _theme_manager: ThemeManager

# Add a print_warning function since it's not in the base class
func print_warning(message: String) -> void:
	push_warning(message)

func before_each() -> void:
	await super.before_each()
	
	# Create theme manager if needed
	_theme_manager = ThemeManager.new()
	add_child_autofree(_theme_manager)
	
	_setup_component()

func after_each() -> void:
	_cleanup_component()
	await super.after_each()

func _setup_component() -> void:
	_component = _create_component_instance()
	if not _component:
		return
		
	add_child_autofree(_component)
	track_test_node(_component)
	await stabilize_engine()
	
	# Register component with theme manager for theme-aware testing
	if _theme_manager:
		_theme_manager.register_themeable(_component)
		await stabilize_engine()

func _cleanup_component() -> void:
	_component = null

# Virtual method to be overridden by specific component tests
func _create_component_instance() -> Control:
	push_error("_create_component_instance() must be implemented by derived class")
	return null

# Common Component Tests
func test_component_structure() -> void:
	assert_not_null(_component, "Component instance should be created")
	assert_true(_component.is_inside_tree(), "Component should be in scene tree")

func test_component_theme() -> void:
	# Test theme inheritance
	assert_not_null(_component.theme, "Component should have a theme")
	
	# Test theme type variations
	var type_variations := _component.theme.get_type_variation_list(_component.get_class())
	for variation in type_variations:
		assert_true(_component.theme.has_type_variation(variation),
			"Theme should have variation %s" % variation)

func test_component_focus() -> void:
	# Test focus handling if component is focusable
	if _component.focus_mode != Control.FOCUS_NONE:
		_component.grab_focus()
		assert_true(_component.has_focus(), "Component should be able to receive focus")

func test_component_visibility() -> void:
	# Test show/hide
	_component.hide()
	assert_control_hidden(_component)
	
	_component.show()
	assert_control_visible(_component)
	
	# Test modulation
	_component.modulate.a = 0.0
	assert_control_hidden(_component)
	
	_component.modulate.a = 1.0
	assert_control_visible(_component)

func test_component_size() -> void:
	# Test minimum size
	var min_size := _component.get_combined_minimum_size()
	assert_gt(min_size.x, 0, "Component should have minimum width")
	assert_gt(min_size.y, 0, "Component should have minimum height")
	
	# Test size constraints
	assert_true(_component.size.x >= min_size.x,
		"Component width should be at least minimum width")
	assert_true(_component.size.y >= min_size.y,
		"Component height should be at least minimum height")

func test_component_layout() -> void:
	# Test responsive layout
	await test_responsive_layout(_component)

func test_component_animations() -> void:
	await test_animations(_component)

func test_component_accessibility() -> void:
	await test_accessibility(_component)

# Input Testing
func simulate_component_input(event: InputEvent) -> void:
	await simulate_ui_input(_component, event)

func simulate_component_click(position: Vector2 = Vector2.ZERO) -> void:
	await simulate_click(_component, position)

func simulate_component_hover(position: Vector2 = Vector2.ZERO) -> void:
	var hover := InputEventMouseMotion.new()
	hover.position = position
	await simulate_ui_input(_component, hover)

func simulate_component_key_press(keycode: Key, pressed: bool = true) -> void:
	var key := InputEventKey.new()
	key.keycode = keycode
	key.pressed = pressed
	await simulate_ui_input(_component, key)

# Performance Testing
func test_component_performance() -> void:
	start_performance_monitoring()
	
	# Perform standard component operations
	_component.hide()
	_component.show()
	_component.size *= 1.5
	_component.size /= 1.5
	
	var metrics := stop_performance_monitoring()
	assert_performance_metrics(metrics, {
		"layout_updates": 10,
		"draw_calls": 5,
		"theme_lookups": 20
	})

# Helper Methods
func assert_component_state(expected_state: Dictionary) -> void:
	for property in expected_state:
		var actual_value = _component.get(property)
		var expected_value = expected_state[property]
		assert_eq(actual_value, expected_value,
			"Component property %s should be %s but was %s" % [property, expected_value, actual_value])

func assert_component_signal_emitted(signal_name: String, args: Array = []) -> void:
	assert_signal_emitted(_component, signal_name)
	if not args.is_empty():
		var signal_args := get_signal_parameters(_component, signal_name)
		assert_eq(signal_args, args,
			"Signal %s should be emitted with args %s but got %s" % [signal_name, args, signal_args])

func assert_component_signal_not_emitted(signal_name: String) -> void:
	assert_signal_not_emitted(_component, signal_name)

func get_component_signal_emission_count(signal_name: String) -> int:
	return get_signal_emit_count(_component, signal_name)

# Mouse Position Utilities
func get_local_mouse_position(global_position: Vector2) -> Vector2:
	return _component.get_local_mouse_position()

func get_global_mouse_position(local_position: Vector2) -> Vector2:
	return _component.get_global_mouse_position()

# Theme Testing
func assert_component_theme_override(property: String, value: Variant) -> void:
	assert_true(_component.has_theme_override(property),
		"Component should have theme override for %s" % property)
	assert_eq(_component.get_theme_override(property), value,
		"Theme override value should match expected")

func assert_component_theme_constant(constant: String, type: String = "") -> void:
	var actual := _component.get_theme_constant(constant, type)
	assert_gt(actual, 0, "Theme constant %s should be greater than 0" % constant)

func assert_component_theme_color(color_name: String, type: String = "") -> void:
	var color := _component.get_theme_color(color_name, type)
	assert_not_null(color, "Theme color %s should exist" % color_name)
	assert_gt(color.a, 0, "Theme color %s should not be fully transparent" % color_name)

func assert_component_theme_font(font_name: String, type: String = "") -> void:
	var font := _component.get_theme_font(font_name, type)
	assert_not_null(font, "Theme font %s should exist" % font_name)

# Enhanced Theme Testing
func test_component_theme_switching() -> void:
	if not _theme_manager:
		push_error("Theme manager is required for theme switching tests")
		return
		
	# Get original theme
	var original_theme := _component.theme
	assert_not_null(original_theme, "Component should have an initial theme")
	
	# Test switching to dark theme
	var success = await ThemeTestHelper.test_theme_switching(_component, _theme_manager, "dark", self)
	assert_true(success, "Component should respond to theme switching to dark theme")
	
	# Test switching to light theme
	success = await ThemeTestHelper.test_theme_switching(_component, _theme_manager, "light", self)
	assert_true(success, "Component should respond to theme switching to light theme")
	
	# Test switching to high contrast theme
	success = await ThemeTestHelper.test_theme_switching(_component, _theme_manager, "high_contrast", self)
	assert_true(success, "Component should respond to theme switching to high contrast theme")
	
	# Return to original theme
	_theme_manager.set_active_theme("base")
	await stabilize_engine()

func test_component_high_contrast_mode() -> void:
	if not _theme_manager:
		push_error("Theme manager is required for high contrast tests")
		return
		
	var success = await ThemeTestHelper.test_high_contrast_mode(_component, _theme_manager, self)
	assert_true(success, "Component should respond to high contrast mode changes")

func test_component_text_scaling() -> void:
	if not _theme_manager:
		push_error("Theme manager is required for text scaling tests")
		return
		
	# Find all Label nodes in the component
	var labels := _find_child_nodes_of_type(_component, Label)
	if labels.is_empty():
		print_warning("No Label nodes found for text scaling test on %s" % _component.name)
		return
		
	var labels_array: Array[Label] = []
	for label in labels:
		labels_array.append(label)
		
	var success = await ThemeTestHelper.test_text_scaling(_component, _theme_manager, labels_array, self)
	assert_true(success, "Component should respond to text scaling changes")

func test_component_animation_settings() -> void:
	if not _theme_manager:
		push_error("Theme manager is required for animation settings tests")
		return
		
	# Find nodes with animations
	var animated_nodes := _find_animated_nodes(_component)
	if animated_nodes.is_empty():
		print_warning("No animated nodes found for animation settings test on %s" % _component.name)
		return
		
	var nodes_array: Array[Node] = []
	for node in animated_nodes:
		nodes_array.append(node)
		
	var success = await ThemeTestHelper.test_animation_settings(_component, _theme_manager, nodes_array, self)
	assert_true(success, "Component should respond to animation settings changes")

# Helper method to find child nodes of a specific type
func _find_child_nodes_of_type(parent: Node, type_class) -> Array:
	var result := []
	
	if is_instance_of(parent, type_class):
		result.append(parent)
		
	for child in parent.get_children():
		var child_results := _find_child_nodes_of_type(child, type_class)
		result.append_array(child_results)
		
	return result

# Helper method to find nodes with animations
func _find_animated_nodes(parent: Node) -> Array:
	var result := []
	
	# Check if this node has animation properties
	if parent.has_node("AnimationPlayer") or parent.has_node("AnimationTree") or parent.has_method("is_animating"):
		result.append(parent)
		
	# Check for animation properties in children
	for child in parent.get_children():
		var child_results := _find_animated_nodes(child)
		result.append_array(child_results)
		
	return result

# Helper method to wait for theme changes to propagate
func await_theme_propagation() -> void:
	await get_tree().process_frame
	await get_tree().process_frame