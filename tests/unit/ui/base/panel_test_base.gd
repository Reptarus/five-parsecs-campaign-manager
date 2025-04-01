@tool
extends "res://tests/unit/ui/base/ui_test_base.gd"

# Base class for panel testing
# Do not use class_name to avoid conflicts

# Type-safe instance variables
var _panel: Control
var _content_container: Control
var _header: Control
var _footer: Control

func before_each() -> void:
	await super.before_each()
	_setup_panel()

func after_each() -> void:
	_cleanup_panel()
	await super.after_each()

func _setup_panel() -> void:
	_panel = _create_panel_instance()
	if not _panel:
		return
		
	add_child_autofree(_panel)
	track_test_node(_panel)
	
	# Find common panel elements
	_content_container = _panel.get_node_or_null("Content")
	_header = _panel.get_node_or_null("Header")
	_footer = _panel.get_node_or_null("Footer")
	
	await stabilize_engine()

func _cleanup_panel() -> void:
	_panel = null
	_content_container = null
	_header = null
	_footer = null

# Virtual method to be overridden by specific panel tests
func _create_panel_instance() -> Control:
	push_error("_create_panel_instance() must be implemented by derived class")
	return null

# Common Panel Tests
func test_panel_structure() -> void:
	assert_not_null(_panel, "Panel instance should be created")
	
	if _content_container:
		assert_control_visible(_content_container, "Content container should be visible")
	
	if _header:
		assert_control_visible(_header, "Header should be visible")
	
	if _footer:
		assert_control_visible(_footer, "Footer should be visible")

func test_panel_theme() -> void:
	# Check if panel is valid
	if not _panel:
		push_warning("Skipping test_panel_theme: panel is null")
		pending("Test skipped - panel is null")
		return

	# Test panel background
	assert_true(_panel.has_theme_stylebox("panel"),
		"Panel should have panel stylebox")
	
	# Test content margins
	if _content_container:
		if not _content_container.has_method("get_theme_constant"):
			push_warning("Skipping margin test: content container does not have get_theme_constant method")
			return
			
		var margin := _content_container.get_theme_constant("margin", "MarginContainer")
		assert_gt(margin, 0, "Content container should have margin")

func test_panel_focus() -> void:
	# Check if panel is valid
	if not _panel:
		push_warning("Skipping test_panel_focus: panel is null")
		pending("Test skipped - panel is null")
		return
		
	if not _panel.has_method("grab_focus") or not _panel.has_method("has_focus"):
		push_warning("Skipping test_panel_focus: required methods missing")
		pending("Test skipped - required methods missing")
		return

	# Test that panel can receive focus
	_panel.grab_focus()
	assert_true(_panel.has_focus(), "Panel should be able to receive focus")
	
	# Test focus navigation within panel
	var focusable := _panel.find_children("*", "Control", true, false)
	focusable = focusable.filter(func(c): return c.focus_mode != Control.FOCUS_NONE)
	
	for i in range(focusable.size()):
		var current := focusable[i] as Control
		if current.has_method("grab_focus") and current.has_method("has_focus"):
			current.grab_focus()
			assert_true(current.has_focus(),
				"Control %s should be able to receive focus" % current.name)

func test_panel_visibility() -> void:
	# Check if panel is valid
	if not _panel:
		push_warning("Skipping test_panel_visibility: panel is null")
		pending("Test skipped - panel is null")
		return

	# Test show/hide
	_panel.hide()
	assert_control_hidden(_panel)
	
	_panel.show()
	assert_control_visible(_panel)
	
	# Test modulation
	_panel.modulate.a = 0.0
	assert_control_hidden(_panel)
	
	_panel.modulate.a = 1.0
	assert_control_visible(_panel)

func test_panel_size() -> void:
	# Check if panel is valid
	if not _panel:
		push_warning("Skipping test_panel_size: panel is null")
		pending("Test skipped - panel is null")
		return
		
	if not _panel.has_method("get_combined_minimum_size"):
		push_warning("Skipping test_panel_size: required methods missing")
		pending("Test skipped - required methods missing")
		return

	# Test minimum size
	var min_size := _panel.get_combined_minimum_size()
	assert_gt(min_size.x, 0, "Panel should have minimum width")
	assert_gt(min_size.y, 0, "Panel should have minimum height")
	
	# Test size constraints
	assert_true(_panel.size.x >= min_size.x,
		"Panel width should be at least minimum width")
	assert_true(_panel.size.y >= min_size.y,
		"Panel height should be at least minimum height")

func test_panel_layout() -> void:
	# Check if panel is valid
	if not _panel:
		push_warning("Skipping test_panel_layout: panel is null")
		pending("Test skipped - panel is null")
		return

	# Test responsive layout
	await test_responsive_layout(_panel)
	
	# Test content container layout
	if _content_container:
		assert_true(_content_container.size.x <= _panel.size.x,
			"Content width should not exceed panel width")
		assert_true(_content_container.size.y <= _panel.size.y,
			"Content height should not exceed panel height")

func test_panel_animations() -> void:
	# Check if panel is valid
	if not _panel:
		push_warning("Skipping test_panel_animations: panel is null")
		pending("Test skipped - panel is null")
		return
		
	await test_animations(_panel)

func test_panel_accessibility() -> void:
	# Check if panel is valid
	if not _panel:
		push_warning("Skipping test_panel_accessibility: panel is null")
		pending("Test skipped - panel is null")
		return
		
	await test_accessibility(_panel)

# Performance Testing
func test_panel_performance() -> void:
	# Check if panel is valid
	if not _panel:
		push_warning("Skipping test_panel_performance: panel is null")
		pending("Test skipped - panel is null")
		return

	start_performance_monitoring()
	
	# Perform standard panel operations
	_panel.hide()
	_panel.show()
	_panel.size *= 1.5
	_panel.size /= 1.5
	
	var metrics := stop_performance_monitoring()
	assert_performance_metrics(metrics, {
		"layout_updates": 10,
		"draw_calls": 5,
		"theme_lookups": 20
	})

# Helper Methods
func assert_panel_state(expected_state: Dictionary) -> void:
	# Check if panel is valid
	if not _panel:
		push_warning("Skipping assert_panel_state: panel is null")
		return

	for property in expected_state:
		var actual_value = _panel.get(property)
		var expected_value = expected_state[property]
		assert_eq(actual_value, expected_value,
			"Panel property %s should be %s but was %s" % [property, expected_value, actual_value])

func simulate_panel_input(event: InputEvent) -> void:
	# Check if panel is valid
	if not _panel:
		push_warning("Skipping simulate_panel_input: panel is null")
		return
		
	await simulate_ui_input(_panel, event)

func simulate_panel_click(position: Vector2 = Vector2.ZERO) -> void:
	# Check if panel is valid
	if not _panel:
		push_warning("Skipping simulate_panel_click: panel is null")
		return
		
	await simulate_click(_panel, position)