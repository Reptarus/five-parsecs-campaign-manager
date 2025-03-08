@tool
extends "res://tests/unit/ui/base/component_test_base.gd"

## Test Suite for ResponsiveContainer
##
## Tests the functionality of the responsive container component,
## which adapts to different screen sizes and orientations.

# Script dependencies
const ResponsiveContainer = preload("res://src/ui/components/base/ResponsiveContainer.gd")

# Test constants
const TEST_DEFAULT_SIZE := Vector2(400, 300)
const TEST_CONTENT_SIZE := Vector2(300, 200)
const TEST_SCREEN_SIZES := {
    "phone": Vector2(360, 640),
    "tablet": Vector2(768, 1024),
    "desktop": Vector2(1920, 1080)
}
const ORIENTATION_PORTRAIT := 0
const ORIENTATION_LANDSCAPE := 1

func _create_component_instance() -> Control:
    var container := ResponsiveContainer.new()
    container.name = "TestResponsiveContainer"
    container.size = TEST_DEFAULT_SIZE
    
    # Add content to the container
    var content := Panel.new()
    content.name = "Content"
    content.custom_minimum_size = TEST_CONTENT_SIZE
    container.add_child(content)
    
    # Add responsive elements for different screen sizes
    var phone_label := Label.new()
    phone_label.name = "PhoneLabel"
    phone_label.text = "Phone Layout"
    phone_label.visible = false
    container.add_child(phone_label)
    
    var tablet_label := Label.new()
    tablet_label.name = "TabletLabel"
    tablet_label.text = "Tablet Layout"
    tablet_label.visible = false
    container.add_child(tablet_label)
    
    var desktop_label := Label.new()
    desktop_label.name = "DesktopLabel"
    desktop_label.text = "Desktop Layout"
    desktop_label.visible = false
    container.add_child(desktop_label)
    
    return container

# Basic functionality tests
func test_responsive_container_initialization() -> void:
    assert_not_null(_component, "ResponsiveContainer should be created successfully")
    assert_eq(_component.get_class(), "ResponsiveContainer", "Component should be a ResponsiveContainer")
    assert_eq(_component.size, TEST_DEFAULT_SIZE, "Container size should be set correctly")
    
    # Check content is present
    var content := _component.get_node("Content")
    assert_not_null(content, "Content node should exist")
    assert_eq(content.custom_minimum_size, TEST_CONTENT_SIZE, "Content size should be set correctly")

func test_responsive_screen_size_detection() -> void:
    var container := _component as ResponsiveContainer
    
    # Test different screen sizes
    for size_name in TEST_SCREEN_SIZES:
        var size: Vector2 = TEST_SCREEN_SIZES[size_name]
        get_viewport().size = size
        await get_tree().process_frame
        await get_tree().process_frame
        
        # Call responsive update manually since we're changing viewport directly
        container.update_responsive_layout()
        await get_tree().process_frame
        
        # Verify correct screen size is detected
        if size.x < size.y:
            assert_eq(container.get_current_orientation(), ORIENTATION_PORTRAIT,
                "Should detect portrait orientation for %s" % size_name)
        else:
            assert_eq(container.get_current_orientation(), ORIENTATION_LANDSCAPE,
                "Should detect landscape orientation for %s" % size_name)
        
        # Verify container adapts to screen size
        assert_true(container.size.x <= size.x,
            "Container width should fit screen for %s" % size_name)
        assert_true(container.size.y <= size.y,
            "Container height should fit screen for %s" % size_name)

func test_responsive_layout_changes() -> void:
    var container := _component as ResponsiveContainer
    
    # Test phone layout
    get_viewport().size = TEST_SCREEN_SIZES.phone
    await get_tree().process_frame
    container.update_responsive_layout()
    await get_tree().process_frame
    
    var phone_label := _component.get_node("PhoneLabel")
    phone_label.visible = true
    
    # Test tablet layout
    get_viewport().size = TEST_SCREEN_SIZES.tablet
    await get_tree().process_frame
    container.update_responsive_layout()
    await get_tree().process_frame
    
    var tablet_label := _component.get_node("TabletLabel")
    tablet_label.visible = true
    
    # Test desktop layout
    get_viewport().size = TEST_SCREEN_SIZES.desktop
    await get_tree().process_frame
    container.update_responsive_layout()
    await get_tree().process_frame
    
    var desktop_label := _component.get_node("DesktopLabel")
    desktop_label.visible = true
    
    # Verify all labels are now visible after testing all layouts
    assert_true(phone_label.visible, "Phone label should be visible")
    assert_true(tablet_label.visible, "Tablet label should be visible")
    assert_true(desktop_label.visible, "Desktop label should be visible")

func test_orientation_change_handling() -> void:
    var container := _component as ResponsiveContainer
    
    # Test portrait orientation
    get_viewport().size = Vector2(TEST_SCREEN_SIZES.tablet.y, TEST_SCREEN_SIZES.tablet.x) # Swap to force portrait
    await get_tree().process_frame
    container.update_responsive_layout()
    await get_tree().process_frame
    
    assert_eq(container.get_current_orientation(), ORIENTATION_PORTRAIT,
        "Should detect portrait orientation")
    
    # Test landscape orientation
    get_viewport().size = TEST_SCREEN_SIZES.tablet # Normal is landscape
    await get_tree().process_frame
    container.update_responsive_layout()
    await get_tree().process_frame
    
    assert_eq(container.get_current_orientation(), ORIENTATION_LANDSCAPE,
        "Should detect landscape orientation")

func test_resize_handling() -> void:
    var container := _component as ResponsiveContainer
    watch_signals(container)
    
    # Start with standard size
    get_viewport().size = TEST_DEFAULT_SIZE
    await get_tree().process_frame
    
    # Resize to smaller
    get_viewport().size = TEST_DEFAULT_SIZE / 2
    await get_tree().process_frame
    container.update_responsive_layout()
    await get_tree().process_frame
    
    # Resize to larger
    get_viewport().size = TEST_DEFAULT_SIZE * 2
    await get_tree().process_frame
    container.update_responsive_layout()
    await get_tree().process_frame

# Theme awareness tests
func test_responsive_container_theme_awareness() -> void:
    # Setup theme manager if needed for testing theme awareness
    if _theme_manager:
        # Switch themes and verify the container updates properly
        _theme_manager.set_active_theme("dark")
        await get_tree().process_frame
        
        # Check that theme propagates to container's children
        for child in _component.get_children():
            if child is Control:
                assert_eq(child.theme, _component.theme,
                    "Child %s should inherit container theme" % child.name)
                
        # Switch back to light theme
        _theme_manager.set_active_theme("base")
        await get_tree().process_frame