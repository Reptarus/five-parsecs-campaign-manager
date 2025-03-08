@tool
extends "res://tests/unit/ui/base/component_test_base.gd"

## Test Suite for Campaign UI Components
##
## Tests the functionality of the campaign interface components

# Script dependencies
const CampaignResponsiveLayout = preload("res://src/ui/components/base/CampaignResponsiveLayout.gd")

# Test constants
const TEST_SIZE := Vector2(800, 600)

func _create_component_instance() -> Control:
    var container := CampaignResponsiveLayout.new()
    container.name = "TestCampaignLayout"
    container.size = TEST_SIZE
    
    # Add some standard campaign layout components
    var header := Label.new()
    header.name = "CampaignHeader"
    header.text = "Campaign Header"
    container.add_child(header)
    
    var content := Panel.new()
    content.name = "CampaignContent"
    container.add_child(content)
    
    var footer := Label.new()
    footer.name = "CampaignFooter"
    footer.text = "Campaign Footer"
    container.add_child(footer)
    
    return container

# Basic functionality tests
func test_campaign_layout_initialization() -> void:
    assert_not_null(_component, "Campaign layout should be created successfully")
    assert_eq(_component.get_class(), "CampaignResponsiveLayout", "Component should be a CampaignResponsiveLayout")
    assert_eq(_component.size, TEST_SIZE, "Container size should be set correctly")
    
    # Check essential components
    assert_not_null(_component.get_node("CampaignHeader"), "Campaign header should exist")
    assert_not_null(_component.get_node("CampaignContent"), "Campaign content area should exist")
    assert_not_null(_component.get_node("CampaignFooter"), "Campaign footer should exist")

func test_campaign_layout_responsiveness() -> void:
    var container := _component as CampaignResponsiveLayout
    
    # Test different responsive screen sizes
    var test_sizes := [
        Vector2(1920, 1080), # Desktop
        Vector2(1024, 768), # Tablet landscape
        Vector2(768, 1024), # Tablet portrait
        Vector2(480, 854) # Phone
    ]
    
    for size in test_sizes:
        get_viewport().size = size
        await get_tree().process_frame
        
        # Update layout manually
        container.update_layout()
        await get_tree().process_frame
        
        # Verify layout adjusts to screen size
        assert_true(container.size.x <= size.x,
            "Container width should fit screen for size %s" % size)
        assert_true(container.size.y <= size.y,
            "Container height should fit screen for size %s" % size)
        
        # Check that all children are still visible and arranged properly
        var header := container.get_node("CampaignHeader") as Control
        var content := container.get_node("CampaignContent") as Control
        var footer := container.get_node("CampaignFooter") as Control
        
        assert_true(header.visible, "Header should remain visible at size %s" % size)
        assert_true(content.visible, "Content should remain visible at size %s" % size)
        assert_true(footer.visible, "Footer should remain visible at size %s" % size)

func test_campaign_layout_margins() -> void:
    var container := _component as CampaignResponsiveLayout
    
    # Test with different margins
    var test_margins := [
        0, # No margin
        10, # Small margin
        50 # Large margin
    ]
    
    for margin in test_margins:
        # Set margins
        container.set("margin", margin)
        await get_tree().process_frame
        
        # Verify margins are applied
        var content := container.get_node("CampaignContent") as Control
        assert_true(content.position.x >= margin,
            "Content should respect horizontal margin of %s" % margin)
        assert_true(content.position.y >= margin,
            "Content should respect vertical margin of %s" % margin)

# Theme awareness tests
func test_campaign_layout_theme_awareness() -> void:
    # Setup theme manager if available
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

func test_campaign_layout_accessibility() -> void:
    var container := _component as CampaignResponsiveLayout
    
    # Test text scaling
    if _theme_manager:
        var original_font_size := 0
        var header := container.get_node("CampaignHeader") as Label
        
        if header:
            original_font_size = header.get_theme_font_size("font_size")
            
            # Test with increased text scale
            _theme_manager.set_text_scale(1.5)
            await get_tree().process_frame
            
            var scaled_font_size = header.get_theme_font_size("font_size")
            assert_gt(scaled_font_size, original_font_size,
                "Font size should increase with larger text scale")
            
            # Reset text scale
            _theme_manager.set_text_scale(1.0)
            await get_tree().process_frame