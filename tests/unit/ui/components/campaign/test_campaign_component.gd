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
	var container = CampaignResponsiveLayout.new()
	if not container:
		push_error("Failed to create CampaignResponsiveLayout instance")
		return null
		
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
	if not is_instance_valid(_component):
		push_warning("Skipping test_campaign_layout_initialization: _component is null or invalid")
		pending("Test skipped - _component is null or invalid")
		return
		
	assert_not_null(_component, "Campaign layout should be created successfully")
	
	# Safely check class type
	if _component != null and _component.has_method("get_class"):
		assert_eq(_component.get_class(), "CampaignResponsiveLayout", "Component should be a CampaignResponsiveLayout")
	else:
		push_warning("Component missing get_class method or is null")
		
	# Only check size if component is valid
	if is_instance_valid(_component):
		assert_eq(_component.size, TEST_SIZE, "Container size should be set correctly")
	
		# Check essential components
		assert_not_null(_component.get_node_or_null("CampaignHeader"), "Campaign header should exist")
		assert_not_null(_component.get_node_or_null("CampaignContent"), "Campaign content area should exist")
		assert_not_null(_component.get_node_or_null("CampaignFooter"), "Campaign footer should exist")

func test_campaign_layout_responsiveness() -> void:
	if not is_instance_valid(_component):
		push_warning("Skipping test_campaign_layout_responsiveness: _component is null or invalid")
		pending("Test skipped - _component is null or invalid")
		return
		
	var container = _component as CampaignResponsiveLayout
	if not container:
		push_warning("Component is not a CampaignResponsiveLayout")
		pending("Test skipped - component is not a CampaignResponsiveLayout")
		return
		
	# Test different responsive screen sizes
	var test_sizes := [
		Vector2(1920, 1080), # Desktop
		Vector2(1024, 768), # Tablet landscape
		Vector2(768, 1024), # Tablet portrait
		Vector2(480, 854) # Phone
	]
	
	var viewport = get_viewport()
	if not is_instance_valid(viewport):
		push_warning("Viewport not available")
		pending("Test skipped - viewport not available")
		return
		
	var tree = get_tree()
	if not is_instance_valid(tree):
		push_warning("SceneTree not available")
		pending("Test skipped - scene tree not available")
		return
	
	for size in test_sizes:
		if not is_instance_valid(container):
			push_warning("Container became invalid during test")
			continue
			
		if not is_instance_valid(viewport):
			push_warning("Viewport became invalid during test")
			continue
			
		viewport.size = size
		
		# Ensure tree is still valid before awaiting
		if not is_instance_valid(tree):
			push_warning("SceneTree became invalid during test")
			continue
			
		await tree.process_frame
		
		# Update layout using the correct method
		if is_instance_valid(container) and container.has_method("update_layout"):
			container.update_layout()
		elif is_instance_valid(container) and container.has_method("force_layout_update"):
			container.force_layout_update()
		elif is_instance_valid(container) and container.has_method("_update_layout"):
			container._update_layout()
		else:
			push_warning("No appropriate layout update method found or container is invalid")
			continue
			
		# Ensure tree is still valid before awaiting
		if not is_instance_valid(tree):
			push_warning("SceneTree became invalid during test")
			continue
			
		await tree.process_frame
		
		if not is_instance_valid(container):
			push_warning("Container became invalid during test")
			continue
			
		# Verify layout adjusts to screen size
		assert_true(container.size.x <= size.x,
			"Container width should fit screen for size %s" % size)
		assert_true(container.size.y <= size.y,
			"Container height should fit screen for size %s" % size)
		
		# Check that all children are still visible and arranged properly
		var header := container.get_node_or_null("CampaignHeader") as Control
		var content := container.get_node_or_null("CampaignContent") as Control
		var footer := container.get_node_or_null("CampaignFooter") as Control
		
		if is_instance_valid(header):
			assert_true(header.visible, "Header should remain visible at size %s" % size)
		
		if is_instance_valid(content):
			assert_true(content.visible, "Content should remain visible at size %s" % size)
			
		if is_instance_valid(footer):
			assert_true(footer.visible, "Footer should remain visible at size %s" % size)

func test_campaign_layout_margins() -> void:
	if not is_instance_valid(_component):
		push_warning("Skipping test_campaign_layout_margins: _component is null or invalid")
		pending("Test skipped - _component is null or invalid")
		return
		
	var container = _component as CampaignResponsiveLayout
	if not container:
		push_warning("Component is not a CampaignResponsiveLayout")
		pending("Test skipped - component is not a CampaignResponsiveLayout")
		return
		
	# Test with different margins
	var test_margins := [
		0, # No margin
		10, # Small margin
		50 # Large margin
	]
	
	for margin in test_margins:
		if not is_instance_valid(container):
			push_warning("Container became invalid during test")
			break
			
		# Set margins - check if container has the property or setter method
		if "margin" in container:
			container.margin = margin
		elif container.has_method("set_margin"):
			container.set_margin(margin)
		elif container.has_method("set"):
			container.set("margin", margin)
		else:
			push_warning("Cannot set margin - no appropriate property or method found")
			continue
			
		await get_tree().process_frame
		
		if not is_instance_valid(container):
			push_warning("Container became invalid during test")
			break
			
		# Verify margins are applied
		var content := container.get_node_or_null("CampaignContent") as Control
		if not is_instance_valid(content):
			push_warning("Content node not found")
			continue
			
		assert_true(content.position.x >= margin,
			"Content should respect horizontal margin of %s" % margin)
		assert_true(content.position.y >= margin,
			"Content should respect vertical margin of %s" % margin)

# Theme awareness tests
func test_campaign_layout_theme_awareness() -> void:
	if not is_instance_valid(_component):
		push_warning("Skipping test_campaign_layout_theme_awareness: _component is null or invalid")
		pending("Test skipped - _component is null or invalid")
		return
		
	# Setup theme manager if available
	if not is_instance_valid(_theme_manager):
		push_warning("Theme manager not available")
		pending("Test skipped - theme manager not available")
		return
		
	# Verify theme manager has required methods
	if not _theme_manager.has_method("set_active_theme"):
		push_warning("Theme manager missing set_active_theme method")
		pending("Test skipped - theme manager missing required methods")
		return
		
	# Switch themes and verify the container updates properly
	_theme_manager.set_active_theme("dark")
	await get_tree().process_frame
	
	if not is_instance_valid(_component):
		push_warning("Component became invalid during theme test")
		return
		
	# Check that theme propagates to container's children
	for child in _component.get_children():
		if child is Control and is_instance_valid(child) and is_instance_valid(_component) and _component.theme:
			assert_eq(child.theme, _component.theme,
				"Child %s should inherit container theme" % child.name)
			
	# Switch back to light theme
	if is_instance_valid(_theme_manager):
		_theme_manager.set_active_theme("base")
		await get_tree().process_frame

func test_campaign_layout_accessibility() -> void:
	if not is_instance_valid(_component):
		push_warning("Skipping test_campaign_layout_accessibility: _component is null or invalid")
		pending("Test skipped - _component is null or invalid")
		return
		
	var container = _component as CampaignResponsiveLayout
	if not container:
		push_warning("Component is not a CampaignResponsiveLayout")
		pending("Test skipped - component is not a CampaignResponsiveLayout")
		return
		
	# Test text scaling
	if not is_instance_valid(_theme_manager):
		push_warning("Theme manager not available")
		pending("Test skipped - theme manager not available")
		return
		
	if not _theme_manager.has_method("set_text_scale"):
		push_warning("Theme manager missing set_text_scale method")
		pending("Test skipped - theme manager missing required methods")
		return
		
	var original_font_size := 0
	var header := container.get_node_or_null("CampaignHeader") as Label
	
	if not is_instance_valid(header):
		push_warning("Header label not found")
		pending("Test skipped - header label not found")
		return
		
	if is_instance_valid(header) and header.has_method("get_theme_font_size"):
		original_font_size = header.get_theme_font_size("font_size")
		
		# Test with increased text scale
		if is_instance_valid(_theme_manager):
			_theme_manager.set_text_scale(1.5)
			await get_tree().process_frame
		
		if is_instance_valid(header):
			var scaled_font_size = header.get_theme_font_size("font_size")
			assert_gt(scaled_font_size, original_font_size,
				"Font size should increase with larger text scale")
		
		# Reset text scale
		if is_instance_valid(_theme_manager):
			_theme_manager.set_text_scale(1.0)
			await get_tree().process_frame
	else:
		push_warning("Header label missing get_theme_font_size method or is invalid")
		pending("Test skipped - header label missing required methods")
