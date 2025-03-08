@tool
extends "res://tests/unit/ui/base/component_test_base.gd"

## Test Suite for BaseContainer
##
## Tests the functionality of the base container component

# Script dependencies
const BaseContainer = preload("res://src/ui/components/base/BaseContainer.gd")

# Test constants
const TEST_MINIMUM_SIZE := Vector2(100, 100)
const TEST_SIZE_FLAGS := Control.SIZE_EXPAND_FILL

func _create_component_instance() -> Control:
    var container := BaseContainer.new()
    container.name = "TestBaseContainer"
    container.custom_minimum_size = TEST_MINIMUM_SIZE
    container.size_flags_horizontal = TEST_SIZE_FLAGS
    container.size_flags_vertical = TEST_SIZE_FLAGS
    
    # Add some child nodes for testing
    var child1 := Label.new()
    child1.name = "Child1"
    child1.text = "Test Child 1"
    container.add_child(child1)
    
    var child2 := Button.new()
    child2.name = "Child2"
    child2.text = "Test Button"
    container.add_child(child2)
    
    return container

# Basic functionality tests
func test_basic_container_functionality() -> void:
    assert_not_null(_component, "BaseContainer should be created successfully")
    assert_eq(_component.get_class(), "BaseContainer", "Component should be a BaseContainer")
    assert_eq(_component.custom_minimum_size, TEST_MINIMUM_SIZE, "Minimum size should be set correctly")
    assert_eq(_component.size_flags_horizontal, TEST_SIZE_FLAGS, "Horizontal size flags should be set correctly")
    assert_eq(_component.size_flags_vertical, TEST_SIZE_FLAGS, "Vertical size flags should be set correctly")

func test_container_child_management() -> void:
    # Test children were added correctly
    assert_eq(_component.get_child_count(), 2, "Container should have 2 children")
    
    var child1 := _component.get_node("Child1")
    var child2 := _component.get_node("Child2")
    
    assert_not_null(child1, "Child1 should exist")
    assert_not_null(child2, "Child2 should exist")
    
    # Test child removal
    _component.remove_child(child1)
    assert_eq(_component.get_child_count(), 1, "Container should have 1 child after removal")
    
    # Test child addition
    var child3 := Panel.new()
    child3.name = "Child3"
    _component.add_child(child3)
    assert_eq(_component.get_child_count(), 2, "Container should have 2 children after addition")
    
    # Check if child is in the tree
    assert_true(child3.is_inside_tree(), "New child should be in the scene tree")

func test_theme_inheritance() -> void:
    # Test theme inheritance works
    var theme := Theme.new()
    _component.theme = theme
    
    for child in _component.get_children():
        assert_eq(child.theme, theme, "Child should inherit theme from parent container")

func test_container_lifecycle() -> void:
    # Test entering tree
    var root := get_tree().get_root()
    var temp_component := BaseContainer.new()
    
    assert_false(temp_component.is_inside_tree(), "New container should not be in tree yet")
    
    root.add_child(temp_component)
    await get_tree().process_frame
    
    assert_true(temp_component.is_inside_tree(), "Added container should be in tree")
    
    # Test exiting tree
    root.remove_child(temp_component)
    await get_tree().process_frame
    
    assert_false(temp_component.is_inside_tree(), "Removed container should not be in tree")
    
    # Cleanup
    temp_component.queue_free()

func test_container_signals() -> void:
    # Test resizing signals
    watch_signals(_component)
    
    _component.size = Vector2(200, 200)
    await get_tree().process_frame
    
    _component.size = Vector2(300, 300)
    await get_tree().process_frame
    
    # BaseContainer may not have custom signals, but we should test any that exist
    
# Theme awareness tests
func test_container_theme_awareness() -> void:
    # This test verifies that the container properly responds to theme changes
    # Apply a test theme
    var test_theme := Theme.new()
    test_theme.set_color("font_color", "Label", Color(1, 0, 0))
    _component.theme = test_theme
    
    # Verify theme is applied
    for child in _component.get_children():
        if child is Label:
            var color: Color = child.get_theme_color("font_color", "Label")
            assert_eq(color, Color(1, 0, 0), "Label should inherit font color from container theme")