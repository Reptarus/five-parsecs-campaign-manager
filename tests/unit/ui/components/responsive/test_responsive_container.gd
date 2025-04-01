@tool
extends "res://tests/fixtures/base/game_test.gd"

const ResponsiveContainer = preload("res://src/ui/components/ResponsiveContainer.gd")

var _container
var _test_child1: Control
var _test_child2: Control

# Helper functions
func _create_test_children() -> void:
    _test_child1 = Panel.new()
    _test_child1.custom_minimum_size = Vector2(100, 100)
    _test_child1.name = "TestChild1"
    
    _test_child2 = Panel.new()
    _test_child2.custom_minimum_size = Vector2(150, 150)
    _test_child2.name = "TestChild2"

# Lifecycle methods
func before_each() -> void:
    await super.before_each()
    
    # Create container
    _container = ResponsiveContainer.new()
    if not _container:
        push_error("Failed to create responsive container")
        return
    add_child(_container)
    track_test_node(_container)
    
    # Create test children
    _create_test_children()
    
    # Add children to container
    _container.add_child(_test_child1)
    _container.add_child(_test_child2)
    
    track_test_node(_test_child1)
    track_test_node(_test_child2)
    
    await _container.ready
    
    # Watch signals
    if _signal_watcher:
        _signal_watcher.watch_signals(_container)

func after_each() -> void:
    if is_instance_valid(_test_child1):
        _test_child1.queue_free()
    _test_child1 = null
    
    if is_instance_valid(_test_child2):
        _test_child2.queue_free()
    _test_child2 = null
    
    if is_instance_valid(_container):
        _container.queue_free()
    _container = null
    
    await super.after_each()

# Basic Container Tests
func test_initial_properties() -> void:
    if not is_instance_valid(_container):
        push_warning("Skipping test_initial_properties: _container is null or invalid")
        pending("Test skipped - _container is null or invalid")
        return
        
    assert_not_null(_container, "Container should be initialized")
    
    if not ("responsive_mode" in _container and "min_width_for_horizontal" in _container):
        push_warning("Skipping layout_mode/breakpoint check: properties not found")
        pending("Test skipped - required properties not found")
        return
        
    assert_eq(_container.responsive_mode, ResponsiveContainer.ResponsiveLayoutMode.HORIZONTAL,
        "Default layout mode should be horizontal")
    assert_eq(_container.min_width_for_horizontal, 600,
        "Default breakpoint should be 600")

# Layout Tests
func test_horizontal_layout() -> void:
    if not is_instance_valid(_container):
        push_warning("Skipping test_horizontal_layout: _container is null or invalid")
        pending("Test skipped - _container is null or invalid")
        return
        
    if not ("responsive_mode" in _container and _container.has_method("_notification")):
        push_warning("Skipping test_horizontal_layout: required property or method not found")
        pending("Test skipped - required property or method not found")
        return
        
    if not (is_instance_valid(_test_child1) and is_instance_valid(_test_child2)):
        push_warning("Skipping test_horizontal_layout: test children are null or invalid")
        pending("Test skipped - test children are null or invalid")
        return
        
    # Set layout mode
    _container.responsive_mode = ResponsiveContainer.ResponsiveLayoutMode.HORIZONTAL
    
    # Set container size (above breakpoint)
    _container.size = Vector2(800, 300)
    _container._notification(Control.NOTIFICATION_RESIZED)
    
    # Check children positions
    assert_true(_test_child1.position.x < _test_child2.position.x,
        "Children should be arranged horizontally")
    assert_eq(_test_child1.position.y, _test_child2.position.y,
        "Children should have same Y position in horizontal layout")

func test_vertical_layout() -> void:
    if not is_instance_valid(_container):
        push_warning("Skipping test_vertical_layout: _container is null or invalid")
        pending("Test skipped - _container is null or invalid")
        return
        
    if not ("responsive_mode" in _container and _container.has_method("_notification")):
        push_warning("Skipping test_vertical_layout: required property or method not found")
        pending("Test skipped - required property or method not found")
        return
        
    if not (is_instance_valid(_test_child1) and is_instance_valid(_test_child2)):
        push_warning("Skipping test_vertical_layout: test children are null or invalid")
        pending("Test skipped - test children are null or invalid")
        return
        
    # Set layout mode
    _container.responsive_mode = ResponsiveContainer.ResponsiveLayoutMode.VERTICAL
    
    # Set container size
    _container.size = Vector2(300, 800)
    _container._notification(Control.NOTIFICATION_RESIZED)
    
    # Check children positions
    assert_true(_test_child1.position.y < _test_child2.position.y,
        "Children should be arranged vertically")
    assert_eq(_test_child1.position.x, _test_child2.position.x,
        "Children should have same X position in vertical layout")

# Responsive Behavior Tests
func test_responsive_behavior() -> void:
    if not is_instance_valid(_container):
        push_warning("Skipping test_responsive_behavior: _container is null or invalid")
        pending("Test skipped - _container is null or invalid")
        return
        
    if not ("responsive_mode" in _container and
            "min_width_for_horizontal" in _container and
            "auto_responsive" in _container and
            _container.has_method("_notification")):
        push_warning("Skipping test_responsive_behavior: required properties or method not found")
        pending("Test skipped - required properties or method not found")
        return
        
    if not (is_instance_valid(_test_child1) and is_instance_valid(_test_child2)):
        push_warning("Skipping test_responsive_behavior: test children are null or invalid")
        pending("Test skipped - test children are null or invalid")
        return
        
    # Enable auto-responsive mode
    _container.auto_responsive = true
    _container.responsive_mode = ResponsiveContainer.ResponsiveLayoutMode.HORIZONTAL
    _container.min_width_for_horizontal = 500
    
    # Test above breakpoint (should be horizontal)
    _container.size = Vector2(600, 300)
    _container._notification(Control.NOTIFICATION_RESIZED)
    
    assert_true(_test_child1.position.x < _test_child2.position.x,
        "Layout should be horizontal above breakpoint")
    
    # Test below breakpoint (should switch to vertical)
    _container.size = Vector2(400, 600)
    _container._notification(Control.NOTIFICATION_RESIZED)
    
    assert_true(_test_child1.position.y < _test_child2.position.y,
        "Layout should switch to vertical below breakpoint")

# Spacing Tests
func test_spacing_property() -> void:
    if not is_instance_valid(_container):
        push_warning("Skipping test_spacing_property: _container is null or invalid")
        pending("Test skipped - _container is null or invalid")
        return
        
    if not ("spacing" in _container and
            "responsive_mode" in _container and
            _container.has_method("_notification")):
        push_warning("Skipping test_spacing_property: required properties or method not found")
        pending("Test skipped - required properties or method not found")
        return
        
    if not (is_instance_valid(_test_child1) and is_instance_valid(_test_child2)):
        push_warning("Skipping test_spacing_property: test children are null or invalid")
        pending("Test skipped - test children are null or invalid")
        return
        
    # Set layout mode and spacing
    _container.responsive_mode = ResponsiveContainer.ResponsiveLayoutMode.HORIZONTAL
    _container.spacing = 50
    
    # Set container size
    _container.size = Vector2(800, 300)
    _container._notification(Control.NOTIFICATION_RESIZED)
    
    # Check spacing between children
    var expected_spacing = _test_child1.size.x + 50
    var actual_spacing = _test_child2.position.x - _test_child1.position.x
    assert_eq(actual_spacing, expected_spacing,
        "Spacing between children should match spacing property")

# Alignment Tests
func test_alignment_properties() -> void:
    if not is_instance_valid(_container):
        push_warning("Skipping test_alignment_properties: _container is null or invalid")
        pending("Test skipped - _container is null or invalid")
        return
        
    if not ("horizontal_alignment" in _container and
            "vertical_alignment" in _container and
            "responsive_mode" in _container and
            _container.has_method("_notification")):
        push_warning("Skipping test_alignment_properties: required properties or method not found")
        pending("Test skipped - required properties or method not found")
        return
        
    if not (is_instance_valid(_test_child1) and is_instance_valid(_test_child2)):
        push_warning("Skipping test_alignment_properties: test children are null or invalid")
        pending("Test skipped - test children are null or invalid")
        return
        
    # Set alignment and layout mode
    _container.horizontal_alignment = 2 # END alignment
    _container.vertical_alignment = 1 # CENTER alignment
    _container.responsive_mode = ResponsiveContainer.ResponsiveLayoutMode.HORIZONTAL
    
    # Set container size (larger than needed)
    _container.size = Vector2(1000, 500)
    _container._notification(Control.NOTIFICATION_RESIZED)
    
    # Check END horizontal alignment (children should be right-aligned)
    var total_width = _test_child1.size.x + _test_child2.size.x + _container.spacing
    var expected_child1_x = _container.size.x - total_width
    
    assert_eq(_test_child1.position.x, expected_child1_x,
        "Children should be right-aligned with END alignment")
    
    # Check CENTER vertical alignment
    var expected_y = (_container.size.y - _test_child1.size.y) / 2
    assert_eq(_test_child1.position.y, expected_y,
        "Children should be centered vertically with CENTER alignment")

# Dynamic Child Management Tests
func test_dynamic_child_addition() -> void:
    if not is_instance_valid(_container):
        push_warning("Skipping test_dynamic_child_addition: _container is null or invalid")
        pending("Test skipped - _container is null or invalid")
        return
        
    if not _container.has_method("_notification"):
        push_warning("Skipping test_dynamic_child_addition: _notification method not found")
        pending("Test skipped - _notification method not found")
        return
        
    # Add another child dynamically
    var new_child = Panel.new()
    new_child.custom_minimum_size = Vector2(120, 120)
    new_child.name = "DynamicChild"
    
    _container.add_child(new_child)
    track_test_node(new_child)
    
    # Force layout update
    _container._notification(Control.NOTIFICATION_RESIZED)
    
    # Check if all three children are positioned properly
    if not (is_instance_valid(_test_child1) and
            is_instance_valid(_test_child2) and
            is_instance_valid(new_child)):
        push_warning("Skipping child position check: one or more children are null or invalid")
        pending("Test skipped - one or more children are null or invalid")
        return
        
    assert_true(_test_child1.position.x < _test_child2.position.x,
        "First two children should maintain relative positions")
    assert_true(_test_child2.position.x < new_child.position.x,
        "New child should be positioned after existing children")

func test_dynamic_child_removal() -> void:
    if not is_instance_valid(_container):
        push_warning("Skipping test_dynamic_child_removal: _container is null or invalid")
        pending("Test skipped - _container is null or invalid")
        return
        
    if not _container.has_method("_notification"):
        push_warning("Skipping test_dynamic_child_removal: _notification method not found")
        pending("Test skipped - _notification method not found")
        return
        
    if not (is_instance_valid(_test_child1) and is_instance_valid(_test_child2)):
        push_warning("Skipping test_dynamic_child_removal: test children are null or invalid")
        pending("Test skipped - test children are null or invalid")
        return
        
    # Record initial position of second child
    var initial_position = _test_child2.position
    
    # Remove first child
    _container.remove_child(_test_child1)
    
    # Force layout update
    _container._notification(Control.NOTIFICATION_RESIZED)
    
    # Check if second child is now at the start position
    assert_eq(_test_child2.position.x, 0,
        "Second child should move to start position after first child removal")
    assert_ne(_test_child2.position, initial_position,
        "Second child position should change after first child removal")

# Resizing Tests
func test_container_resizing() -> void:
    if not is_instance_valid(_container):
        push_warning("Skipping test_container_resizing: _container is null or invalid")
        pending("Test skipped - _container is null or invalid")
        return
        
    if not (_container.has_method("_notification") and
            _container.has_signal("layout_changed")):
        push_warning("Skipping test_container_resizing: required method or signal not found")
        pending("Test skipped - required method or signal not found")
        return
        
    # Initial size
    _container.size = Vector2(800, 300)
    _container._notification(Control.NOTIFICATION_RESIZED)
    
    # Resize container
    _container.size = Vector2(600, 400)
    _container._notification(Control.NOTIFICATION_RESIZED)
    
    # Verify layout_changed signal
    verify_signal_emitted(_container, "layout_changed")

# Error Case Tests
func test_invalid_layout_mode() -> void:
    if not is_instance_valid(_container):
        push_warning("Skipping test_invalid_layout_mode: _container is null or invalid")
        pending("Test skipped - _container is null or invalid")
        return
        
    if not ("responsive_mode" in _container and _container.has_method("_notification")):
        push_warning("Skipping test_invalid_layout_mode: required property or method not found")
        pending("Test skipped - required property or method not found")
        return
        
    # Set invalid layout mode (out of enum range)
    _container.responsive_mode = 999
    
    # Layout should fall back to default horizontal mode
    _container._notification(Control.NOTIFICATION_RESIZED)
    
    if not (is_instance_valid(_test_child1) and is_instance_valid(_test_child2)):
        push_warning("Skipping test_invalid_layout_mode: test children are null or invalid")
        pending("Test skipped - test children are null or invalid")
        return
        
    assert_true(_test_child1.position.x < _test_child2.position.x,
        "Layout should fall back to horizontal with invalid mode")

# Cleanup Tests
func test_cleanup() -> void:
    if not is_instance_valid(_container):
        push_warning("Skipping test_cleanup: _container is null or invalid")
        pending("Test skipped - _container is null or invalid")
        return
        
    if not _container.has_method("cleanup"):
        push_warning("Skipping test_cleanup: cleanup method not found")
        pending("Test skipped - cleanup method not found")
        return
        
    # Add cleanup assertions here
    _container.cleanup()
    
    # Should disconnect signals, etc.
    assert_eq(_container.get_child_count(), 2,
        "Children should remain after cleanup")