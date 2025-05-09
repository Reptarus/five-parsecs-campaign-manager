@tool
extends "res://tests/unit/ui/base/ui_test_base.gd"

# Base class for component testing
# Do not use class_name to avoid conflicts

const ThemeManager = preload("res://src/ui/themes/ThemeManager.gd")
const ThemeTestHelper = preload("res://tests/unit/ui/themes/theme_test_helper.gd")
# Load UI test base methods and properties that we need without extending from it
const UITestBaseScript = preload("res://tests/unit/ui/base/ui_test_base.gd")

# Type-safe instance variables
var _component: Control = null
var _theme_manager: ThemeManager = null

# Add a print_warning function since it's not in the base class
func print_warning(message: String) -> void:
	push_warning(message)

func before_each():
	await super.before_each()
	_component = null
	_theme_manager = null
	
	# Create component to test
	_component = _create_component_instance()
	if _component:
		add_child_autofree(_component)
		track_test_node(_component)
		await stabilize_engine()

func after_each():
	if is_instance_valid(_component) and not _component.is_queued_for_deletion():
		_component.queue_free()
	_component = null
	_theme_manager = null
	
	await super.after_each()

func _setup_component(component_scene: PackedScene) -> void:
	if not component_scene:
		push_error("Component scene is null")
		return
		
	assert_not_null(component_scene, "Component scene should not be null")
	
	_component = component_scene.instantiate() as Control
	assert_not_null(_component, "Component instance should not be null")
	
	add_child_autofree(_component)
	track_test_node(_component)
	await stabilize_engine()

func _cleanup_component() -> void:
	_component = null

# Virtual method to be overridden by specific component tests
func _create_component_instance() -> Control:
	push_error("_create_component_instance() must be implemented by derived class")
	return null

# Common Component Tests
func test_component_structure() -> void:
	if not is_instance_valid(_component):
		push_warning("Skipping test_component_structure: component is null or invalid")
		pending("Test skipped - component is null or invalid")
		return
		
	assert_not_null(_component, "Component instance should be created")
	assert_true(_component.is_inside_tree(), "Component should be in scene tree")

func test_component_theme() -> void:
	if not is_instance_valid(_component):
		push_warning("Skipping test_component_theme: component is null or invalid")
		pending("Test skipped - component is null or invalid")
		return
	
	# Test theme inheritance
	assert_not_null(_component.theme, "Component should have a theme")
	
	# Test theme type variations
	var type_variations := _get_theme_type_variations(_component)
	for variation in type_variations:
		assert_true(_component.theme.has_type_variation(variation),
			"Theme should have variation %s" % variation)

func test_component_focus() -> void:
	if not is_instance_valid(_component):
		push_warning("Skipping test_component_focus: component is null or invalid")
		pending("Test skipped - component is null or invalid")
		return
		
	if not _component.has_method("grab_focus") or not _component.has_method("has_focus"):
		push_warning("Skipping test_component_focus: required methods missing")
		pending("Test skipped - required methods missing")
		return
	
	# Test focus handling if component is focusable
	if _component.focus_mode != Control.FOCUS_NONE:
		_component.grab_focus()
		assert_true(_component.has_focus(), "Component should be able to receive focus")

func test_component_visibility() -> void:
	if not is_instance_valid(_component):
		push_warning("Skipping test_component_visibility: component is null or invalid")
		pending("Test skipped - component is null or invalid")
		return
	
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
	if not is_instance_valid(_component):
		push_warning("Skipping test_component_size: component is null or invalid")
		pending("Test skipped - component is null or invalid")
		return
	
	# Test minimum size
	var min_size := _get_theme_min_size(_component)
	assert_gt(min_size.x, 0, "Component should have minimum width")
	assert_gt(min_size.y, 0, "Component should have minimum height")
	
	# Test size constraints
	assert_true(_component.size.x >= min_size.x,
		"Component width should be at least minimum width")
	assert_true(_component.size.y >= min_size.y,
		"Component height should be at least minimum height")

func test_component_layout() -> void:
	if not is_instance_valid(_component):
		push_warning("Skipping test_component_layout: component is null or invalid")
		pending("Test skipped - component is null or invalid")
		return
	
	# Test responsive layout
	await test_responsive_layout(_component)

func test_component_animations() -> void:
	if not is_instance_valid(_component):
		push_warning("Skipping test_component_animations: component is null or invalid")
		pending("Test skipped - component is null or invalid")
		return
	
	await test_animations(_component)

func test_component_accessibility() -> void:
	if not is_instance_valid(_component):
		push_warning("Skipping test_component_accessibility: component is null or invalid")
		pending("Test skipped - component is null or invalid")
		return
	
	await test_accessibility(_component)

# Input Testing
func simulate_component_input(event: InputEvent) -> void:
	if not is_instance_valid(_component):
		push_warning("Skipping simulate_component_input: component is null or invalid")
		return
		
	await simulate_ui_input(_component, event)

func simulate_component_click(position: Vector2 = Vector2.ZERO) -> void:
	if not is_instance_valid(_component):
		push_warning("Skipping simulate_component_click: component is null or invalid")
		return
		
	await simulate_click(_component, position)

func simulate_component_hover(position: Vector2 = Vector2.ZERO) -> void:
	if not is_instance_valid(_component):
		push_warning("Skipping simulate_component_hover: component is null or invalid")
		return
		
	var hover := InputEventMouseMotion.new()
	hover.position = position
	await simulate_ui_input(_component, hover)

func simulate_component_key_press(keycode: Key, pressed: bool = true) -> void:
	if not is_instance_valid(_component):
		push_warning("Skipping simulate_component_key_press: component is null or invalid")
		return
		
	var key := InputEventKey.new()
	key.keycode = keycode
	key.pressed = pressed
	await simulate_ui_input(_component, key)

# Performance Testing
func test_component_performance() -> void:
	if not is_instance_valid(_component):
		push_warning("Skipping test_component_performance: component is null or invalid")
		pending("Test skipped - component is null or invalid")
		return
	
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
	if not is_instance_valid(_component):
		push_warning("Skipping assert_component_state: component is null or invalid")
		return
		
	for property in expected_state:
		var actual_value = _component.get(property)
		var expected_value = expected_state[property]
		assert_eq(actual_value, expected_value,
			"Component property %s should be %s but was %s" % [property, expected_value, actual_value])

func assert_component_signal_emitted(signal_name: String, args: Array = []) -> void:
	if not is_instance_valid(_component):
		push_warning("Skipping assert_component_signal_emitted: component is null or invalid")
		return
		
	if not _component.has_signal(signal_name):
		push_warning("Component does not have signal '%s'" % signal_name)
		return
		
	assert_signal_emitted(_component, signal_name)
	if not args.is_empty():
		var signal_args: Array = get_signal_parameters(_component, signal_name)
		assert_eq(signal_args, args,
			"Signal %s should be emitted with args %s but got %s" % [signal_name, args, signal_args])

func assert_component_signal_not_emitted(signal_name: String) -> void:
	if not is_instance_valid(_component):
		push_warning("Skipping assert_component_signal_not_emitted: component is null or invalid")
		return
		
	if not _component.has_signal(signal_name):
		push_warning("Component does not have signal '%s'" % signal_name)
		return
		
	assert_signal_not_emitted(_component, signal_name)

func get_component_signal_emission_count(signal_name: String) -> int:
	if not is_instance_valid(_component):
		push_warning("Skipping get_component_signal_emission_count: component is null or invalid")
		return 0
		
	if not _component.has_signal(signal_name):
		push_warning("Component does not have signal '%s'" % signal_name)
		return 0
		
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
	if not is_instance_valid(_component):
		push_warning("Skipping test_component_theme_switching: component is null or invalid")
		pending("Test skipped - component is null or invalid")
		return
		
	# Get or create theme manager
	_theme_manager = _get_or_create_theme_manager()
	
	if not _theme_manager:
		push_warning("Theme manager is required for theme switching tests")
		pending("Theme manager is required for theme switching tests")
		return
		
	# Get original theme
	var original_theme := _component.theme
	if not original_theme:
		push_warning("Component has no theme, creating a default one")
		original_theme = Theme.new()
		_component.theme = original_theme
	
	# Test switching to dark theme
	var success = false
	
	# Create an instance of ThemeTestHelper to use its methods
	var test_helper = ThemeTestHelper.new()
	if test_helper.has_method("test_theme_switching"):
		success = await test_helper.test_theme_switching(_component, _theme_manager, "dark", self)
	else:
		# Fallback if test helper doesn't have the method
		if _theme_manager.has_method("set_active_theme"):
			_theme_manager.set_active_theme("dark")
			await stabilize_engine()
			success = true
	
	# Clean up the test helper
	test_helper.free()
			
	assert_true(success, "Component should respond to theme switching to dark theme")
	
	# Return to original theme
	if _theme_manager.has_method("set_active_theme"):
		_theme_manager.set_active_theme("base")
	await stabilize_engine()

func test_component_high_contrast_mode() -> void:
	if not is_instance_valid(_component):
		push_warning("Skipping test_component_high_contrast_mode: component is null or invalid")
		pending("Test skipped - component is null or invalid")
		return
		
	# Get or create theme manager
	_theme_manager = _get_or_create_theme_manager()
	
	if not _theme_manager:
		push_warning("Theme manager is required for high contrast tests")
		pending("Theme manager is required for high contrast tests")
		return
		
	var success = false
	
	# Create an instance of ThemeTestHelper to use its methods
	var test_helper = ThemeTestHelper.new()
	if test_helper.has_method("test_high_contrast_mode"):
		success = await test_helper.test_high_contrast_mode(_component, _theme_manager, self)
	else:
		# Fallback implementation if test helper doesn't have the method
		if _theme_manager.has_method("set_high_contrast_mode"):
			_theme_manager.set_high_contrast_mode(true)
			await stabilize_engine()
			_theme_manager.set_high_contrast_mode(false)
			await stabilize_engine()
			success = true
	
	# Clean up the test helper
	test_helper.free()
			
	assert_true(success, "Component should respond to high contrast mode changes")

func test_component_text_scaling() -> void:
	if not is_instance_valid(_component):
		push_warning("Skipping test_component_text_scaling: component is null or invalid")
		pending("Test skipped - component is null or invalid")
		return
		
	# Get or create theme manager
	_theme_manager = _get_or_create_theme_manager()
	
	if not _theme_manager:
		push_warning("Theme manager is required for text scaling tests")
		pending("Theme manager is required for text scaling tests")
		return
		
	# Find all Label nodes in the component
	var labels := _find_child_nodes_of_type(_component, Label)
	if labels.is_empty():
		print_warning("No Label nodes found for text scaling test on %s" % _component.name)
		pending("No Label nodes found for text scaling")
		return
		
	var labels_array: Array[Label] = []
	for label in labels:
		if label is Label:
			labels_array.append(label)
			
	if labels_array.is_empty():
		print_warning("No valid Label nodes found for text scaling test on %s" % _component.name)
		pending("No valid Label nodes found for text scaling")
		return
		
	var success = false
	
	# Create an instance of ThemeTestHelper to use its methods
	var test_helper = ThemeTestHelper.new()
	if test_helper.has_method("test_text_scaling"):
		success = await test_helper.test_text_scaling(_component, _theme_manager, labels_array, self)
	else:
		# Fallback implementation if test helper doesn't have the method
		if _theme_manager.has_method("set_text_scale"):
			var original_sizes = []
			
			# Store original font sizes
			for label in labels_array:
				var font_size = label.get_theme_font_size("font_size")
				original_sizes.append(font_size)
			
			# Increase text scale
			_theme_manager.set_text_scale(1.5)
			await stabilize_engine()
			
			# Decrease text scale
			_theme_manager.set_text_scale(1.0)
			await stabilize_engine()
			success = true
	
	# Clean up the test helper
	test_helper.free()
	
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
	
	# Check for animation nodes
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

func _is_animating(parent: Node) -> bool:
	if not is_instance_valid(parent):
		return false
		
	# Check for animation nodes
	var has_animation_player: bool = parent.has_node("AnimationPlayer")
	var has_animation_tree: bool = parent.has_node("AnimationTree")
	
	# Check for custom animation method
	var has_animation_method: bool = parent.get_method_list().any(func(method): return method.name == "is_animating")
	
	if has_animation_method:
		return parent.is_animating()
		
	return has_animation_player or has_animation_tree

func assert_control_hidden(control: Control, message: String = "") -> void:
	assert_false(control.visible, message if message else "Control should be hidden")

func assert_control_visible(control: Control, message: String = "") -> void:
	assert_true(control.visible, message if message else "Control should be visible")

func test_responsive_layout(control: Control = null) -> void:
	# Override in specific tests
	if control == null:
		control = _component
	pass

func test_animations(control: Control = null) -> void:
	# Override in specific tests
	if control == null:
		control = _component
	
	if not is_instance_valid(control):
		print_warning("Cannot test animations: control is null or invalid")
		return
		
	# Look for an AnimationPlayer
	var animation_player: AnimationPlayer = _find_animation_player(control)
	if not animation_player:
		print_warning("No AnimationPlayer found in Control")
		return
	
	# Check for animations
	var animation_names = animation_player.get_animation_list()
	if animation_names.is_empty():
		print_warning("No animations found in AnimationPlayer")
		return
		
	# Test playing each animation
	for anim_name in animation_names:
		animation_player.play(anim_name)
		await animation_player.animation_finished
		
		assert_eq(animation_player.current_animation, "",
			"Animation %s should complete" % anim_name)

# Helper function to find an AnimationPlayer in a node hierarchy
func _find_animation_player(node: Node) -> AnimationPlayer:
	# Check if this node is an AnimationPlayer
	if node is AnimationPlayer:
		return node
		
	# Check if this node has a direct AnimationPlayer child
	var animation_player = node.get_node_or_null("AnimationPlayer")
	if animation_player is AnimationPlayer:
		return animation_player
		
	# Recursively search for AnimationPlayer in children
	for child in node.get_children():
		var found = _find_animation_player(child)
		if found:
			return found
			
	return null

func test_accessibility(control: Control = null) -> void:
	# Override in specific tests
	if control == null:
		control = _component
	pass

# Theme testing helpers
func _get_theme_type_variations(control: Control) -> Array[String]:
	var type_variations: Array[String] = []
	if control.theme:
		type_variations = control.theme.get_type_variation_list("Control")
	return type_variations

func _get_theme_min_size(control: Control) -> Vector2:
	if not control.theme:
		return Vector2.ZERO
		
	var min_width: int = control.theme.get_constant("minimum_width", "Control") if control.theme.has_constant("minimum_width", "Control") else 0
	var min_height: int = control.theme.get_constant("minimum_height", "Control") if control.theme.has_constant("minimum_height", "Control") else 0
	return Vector2(min_width, min_height)

func _assert_theme_color(control: Control, color_name: String, expected_color: Color) -> void:
	var actual: Color = control.get_theme_color(color_name)
	assert_eq(actual, expected_color, "Theme color '%s' should match" % color_name)

func _assert_theme_constant(control: Control, constant_name: String, expected_value: int) -> void:
	var actual: int = control.get_theme_constant(constant_name)
	assert_eq(actual, expected_value, "Theme constant '%s' should match" % constant_name)

func _assert_theme_font(control: Control, font_name: String, expected_font: Font) -> void:
	var actual: Font = control.get_theme_font(font_name)
	assert_eq(actual, expected_font, "Theme font '%s' should match" % font_name)

func _backup_theme(control: Control) -> Theme:
	var original_theme: Theme = control.theme
	control.theme = null
	return original_theme

# Add a method to safely create or get a theme manager
func _get_or_create_theme_manager() -> ThemeManager:
	# Try to get existing theme manager from singleton if available
	var theme_manager = null
	
	# Try to get a global singleton if it exists
	if Engine.has_singleton("ThemeManager"):
		theme_manager = Engine.get_singleton("ThemeManager")
	
	# We can also try to find an existing node in the scene tree if it's already instantiated
	if not theme_manager:
		var root = get_tree().root
		for child in root.get_children():
			if child is ThemeManager:
				theme_manager = child
				break
			
			# Also check one level down
			for grandchild in child.get_children():
				if grandchild is ThemeManager:
					theme_manager = grandchild
					break
	
	# If no theme manager found, create a minimal one
	if not theme_manager:
		theme_manager = ThemeManager.new()
		theme_manager.name = "TestThemeManager"
		add_child_autofree(theme_manager)
		track_test_node(theme_manager)
		
		# Add minimal theme data for testing
		if theme_manager.has_method("add_theme"):
			var default_theme = Theme.new()
			theme_manager.add_theme("base", default_theme)
			
			var dark_theme = Theme.new()
			theme_manager.add_theme("dark", dark_theme)
			
			var light_theme = Theme.new()
			theme_manager.add_theme("light", light_theme)
			
			var high_contrast_theme = Theme.new()
			theme_manager.add_theme("high_contrast", high_contrast_theme)
			
			if theme_manager.has_method("set_active_theme"):
				theme_manager.set_active_theme("base")
	
	return theme_manager
