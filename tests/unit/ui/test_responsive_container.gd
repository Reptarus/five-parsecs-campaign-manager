@tool
extends "res://tests/unit/ui/base/component_test_base.gd"

const ResponsiveContainer := preload("res://src/ui/components/ResponsiveContainer.gd")
const ThemeManagerScript := preload("res://src/ui/themes/ThemeManager.gd")

# Type-safe instance variables
var _main_container: Container
var _orientation_changed_count: int = 0
var _last_orientation_portrait: bool = false
var _scale_changed_count: int = 0
var _theme_manager: ThemeManagerScript

# Override _create_component_instance to provide the specific component
func _create_component_instance() -> Control:
	return ResponsiveContainer.new()

func before_each() -> void:
	await super.before_each()
	
	# Create and setup theme manager
	_theme_manager = ThemeManagerScript.new()
	add_child_autofree(_theme_manager)
	
	_setup_container()
	_reset_state()
	_connect_signals()
	
	# Connect to theme manager
	if _component != null and _component.has_method("connect_theme_manager"):
		_component.connect_theme_manager(_theme_manager)

func after_each() -> void:
	_reset_state()
	await super.after_each()

func _setup_container() -> void:
	_main_container = Container.new()
	_main_container.name = "MainContainer"
	_component.add_child(_main_container)
	track_test_node(_main_container)

func _reset_state() -> void:
	_orientation_changed_count = 0
	_last_orientation_portrait = false
	_scale_changed_count = 0

func _connect_signals() -> void:
	if _component != null:
		if _component.has_signal("orientation_changed"):
			_component.orientation_changed.connect(_on_orientation_changed)
		
		if _component.has_signal("scale_changed"):
			_component.scale_changed.connect(_on_scale_changed)

func _on_orientation_changed(is_portrait: bool) -> void:
	_orientation_changed_count += 1
	_last_orientation_portrait = is_portrait

func _on_scale_changed(new_scale: float) -> void:
	_scale_changed_count += 1

func test_initial_setup() -> void:
	await test_component_structure()
	
	# Additional component-specific checks
	assert_not_null(_component.main_container)
	assert_false(_component.is_portrait)
	assert_eq(_component.portrait_threshold, 1.0)
	assert_eq(_component.min_width, 300.0)

func test_landscape_mode() -> void:
	_component.size = Vector2(800, 600) # Wide layout
	_component._check_orientation()
	
	assert_false(_component.is_portrait)
	assert_false(_component.is_in_portrait_mode())
	assert_eq(_orientation_changed_count, 0) # No change from default

func test_portrait_mode_by_ratio() -> void:
	_component.size = Vector2(400, 800) # Tall layout
	_component._check_orientation()
	
	assert_true(_component.is_portrait)
	assert_true(_component.is_in_portrait_mode())
	assert_eq(_orientation_changed_count, 1)
	assert_true(_last_orientation_portrait)

func test_portrait_mode_by_min_width() -> void:
	_component.size = Vector2(250, 400) # Narrow layout
	_component._check_orientation()
	
	assert_true(_component.is_portrait)
	assert_true(_component.is_in_portrait_mode())
	assert_eq(_orientation_changed_count, 1)
	assert_true(_last_orientation_portrait)

func test_orientation_change() -> void:
	# Start in landscape
	_component.size = Vector2(800, 600)
	_component._check_orientation()
	assert_false(_component.is_portrait)
	assert_eq(_orientation_changed_count, 0)
	
	# Switch to portrait
	_component.size = Vector2(400, 800)
	_component._check_orientation()
	assert_true(_component.is_portrait)
	assert_eq(_orientation_changed_count, 1)
	assert_true(_last_orientation_portrait)
	
	# Back to landscape
	_component.size = Vector2(800, 600)
	_component._check_orientation()
	assert_false(_component.is_portrait)
	assert_eq(_orientation_changed_count, 2)
	assert_false(_last_orientation_portrait)

func test_custom_threshold() -> void:
	_component.portrait_threshold = 0.75 # More lenient threshold
	
	# This size would be landscape with default threshold (1.0)
	# but is portrait with custom threshold (0.75)
	_component.size = Vector2(600, 800)
	_component._check_orientation()
	
	assert_true(_component.is_portrait)
	assert_eq(_orientation_changed_count, 1)
	assert_true(_last_orientation_portrait)

func test_custom_min_width() -> void:
	_component.min_width = 500.0 # Higher minimum width
	
	# This size would be landscape normally
	# but is portrait due to custom min_width
	_component.size = Vector2(450, 400)
	_component._check_orientation()
	
	assert_true(_component.is_portrait)
	assert_eq(_orientation_changed_count, 1)
	assert_true(_last_orientation_portrait)

# Additional tests using base class functionality
func test_component_theme() -> void:
	await super.test_component_theme()
	
	# Additional theme checks for responsive container
	assert_component_theme_color("background_color")
	assert_true(_component.has_theme_stylebox("panel"),
		"Container should have panel stylebox")

func test_component_layout() -> void:
	await super.test_component_layout()
	
	# Additional layout checks for responsive container
	assert_true(_component.size.x >= _component.min_width,
		"Container should respect minimum width")
	assert_true(_component.main_container.size.x <= _component.size.x,
		"Main container should not exceed container width")
	assert_true(_component.main_container.size.y <= _component.size.y,
		"Main container should not exceed container height")

func test_component_performance() -> void:
	start_performance_monitoring()
	
	# Perform responsive container specific operations
	var test_sizes := [
		Vector2(800, 600), # Landscape
		Vector2(400, 800), # Portrait
		Vector2(1024, 768), # Landscape
		Vector2(360, 640), # Portrait
		Vector2(1920, 1080) # Landscape
	]
	
	for size in test_sizes:
		_component.size = size
		_component._check_orientation()
		await get_tree().process_frame
	
	var metrics := stop_performance_monitoring()
	assert_performance_metrics(metrics, {
		"layout_updates": 15,
		"draw_calls": 10,
		"theme_lookups": 25
	})

func test_container_interaction() -> void:
	# Test orientation changes with different aspect ratios
	var test_ratios := [
		Vector2(16, 9), # Landscape
		Vector2(9, 16), # Portrait
		Vector2(4, 3), # Landscape
		Vector2(3, 4), # Portrait
		Vector2(21, 9) # Ultra-wide
	]
	
	for ratio in test_ratios:
		var base_size := 400.0
		var size := Vector2(base_size * ratio.x / ratio.y, base_size)
		_component.size = size
		_component._check_orientation()
		
		var expected_portrait: bool = size.x / size.y < _component.portrait_threshold or size.x < _component.min_width
		assert_eq(_component.is_portrait, expected_portrait,
			"Container should correctly detect orientation for ratio %s" % ratio)
		
		await get_tree().process_frame

func test_accessibility(control: Control = _component) -> void:
	await super.test_accessibility(control)
	
	# Additional accessibility checks for responsive container
	assert_true(_component.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"Container should ignore mouse input")
	
	# Test that container adapts to screen reader preferences
	var original_size := _component.size
	_component.size *= 1.5 # Simulate screen reader zoom
	_component._check_orientation()
	
	var zoomed_portrait: bool = _component.is_portrait
	var expected_portrait: bool = _component.size.x / _component.size.y < _component.portrait_threshold or _component.size.x < _component.min_width
	assert_eq(zoomed_portrait, expected_portrait,
		"Container should maintain correct orientation when zoomed")

# Tests for theme and UI scaling functionality
func test_theme_manager_integration() -> void:
	assert_true(_component.has_method("connect_theme_manager"), "Should have connect_theme_manager method")
	assert_not_null(_component.theme_manager, "Theme manager should be connected")

func test_ui_scale_response() -> void:
	# Test initial scale
	var initial_scale = 1.0
	assert_eq(_component.current_scale, initial_scale, "Initial scale should be 1.0")
	
	# Change UI scale and verify component responds
	var test_scale = 1.2
	_theme_manager.set_ui_scale(test_scale)
	
	# Wait for scale to propagate via signals
	await get_tree().process_frame
	await get_tree().process_frame
	
	assert_eq(_component.current_scale, test_scale, "Component scale should update with theme manager")
	assert_gt(_scale_changed_count, 0, "Scale changed signal should be emitted")

func test_breakpoint_calculation_with_scale() -> void:
	# Set a test scale
	var test_scale = 1.5
	_theme_manager.set_ui_scale(test_scale)
	
	# Wait for scale to propagate via signals
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Set specific size for testing
	_component.custom_minimum_size = Vector2(300, 200)
	
	# Force layout update and let signals propagate
	_component.update_minimum_size()
	_component.size = _component.get_minimum_size()
	_component._update_layout()
	
	await get_tree().process_frame
	
	# Verify that breakpoints are calculated with scale in mind
	var effective_width = _component.size.x / test_scale
	assert_eq(_component.is_portrait, effective_width < _component.portrait_breakpoint,
		"Orientation should be based on scaled width")

func test_adaptive_margins_with_scale() -> void:
	# Set a test scale
	var test_scale = 1.25
	_theme_manager.set_ui_scale(test_scale)
	
	# Wait for scale to propagate
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Test that margins are properly scaled
	var base_margin = 10
	_component.set_adaptive_margins(base_margin)
	
	# We expect the actual margin to be scaled
	var expected_margin = base_margin * test_scale
	
	# Check each margin
	for margin in ["margin_top", "margin_bottom", "margin_left", "margin_right"]:
		if _component.has_method("get_" + margin):
			var actual_margin = _component.call("get_" + margin)
			assert_eq(actual_margin, expected_margin, margin + " should be scaled properly")

func test_theme_property_inheritance() -> void:
	# Set a custom theme property
	var test_font_size = 24
	_theme_manager.set_theme_constant("font_size", "Label", test_font_size)
	
	# Create a test label inside responsive container
	var test_label = Label.new()
	_component.add_child(test_label)
	
	# Allow theme to propagate
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Check if the theme property was correctly inherited
	var actual_font_size = test_label.get_theme_constant("font_size", "Label")
	assert_eq(actual_font_size, test_font_size, "Theme properties should be inherited") 