extends "res://addons/gut/test.gd"

const CampaignResponsiveLayout = preload("res://src/ui/components/base/CampaignResponsiveLayout.gd")

var layout: CampaignResponsiveLayout
var main_container: Container
var sidebar: Control
var main_content: Control
var touch_button: Button
var touch_list: Control

func before_each() -> void:
	layout = CampaignResponsiveLayout.new()
	
	# Create required nodes
	main_container = Container.new()
	main_container.name = "MainContainer"
	
	sidebar = Control.new()
	sidebar.name = "Sidebar"
	
	main_content = Control.new()
	main_content.name = "MainContent"
	
	# Set up hierarchy
	add_child(layout)
	layout.add_child(main_container)
	main_container.add_child(sidebar)
	main_container.add_child(main_content)
	
	# Create test touch controls
	touch_button = Button.new()
	touch_button.add_to_group("touch_buttons")
	layout.add_child(touch_button)
	
	touch_list = Control.new()
	touch_list.add_to_group("touch_lists")
	touch_list.set_script(GDScript.new()) # Mock script to handle fixed_item_height
	layout.add_child(touch_list)

func after_each() -> void:
	layout.queue_free()

func test_initial_setup() -> void:
	assert_not_null(layout.sidebar)
	assert_not_null(layout.main_content)
	assert_eq(layout.PORTRAIT_SIDEBAR_HEIGHT_RATIO, 0.4)
	assert_eq(layout.LANDSCAPE_SIDEBAR_WIDTH, 300.0)
	assert_eq(layout.TOUCH_BUTTON_HEIGHT, 60.0)

func test_portrait_layout() -> void:
	layout.size = Vector2(400, 800) # Portrait size
	layout._check_orientation()
	layout._apply_portrait_layout()
	
	# Check vertical orientation
	assert_eq(main_container.get("orientation"), layout.VERTICAL)
	
	# Check sidebar sizing
	var expected_height = 800 * layout.PORTRAIT_SIDEBAR_HEIGHT_RATIO
	assert_eq(sidebar.custom_minimum_size.y, expected_height)
	assert_eq(sidebar.custom_minimum_size.x, 0)
	
	# Check touch control sizes
	assert_eq(touch_button.custom_minimum_size.y, layout.TOUCH_BUTTON_HEIGHT)

func test_landscape_layout() -> void:
	layout.size = Vector2(1024, 768) # Landscape size
	layout._check_orientation()
	layout._apply_landscape_layout()
	
	# Check horizontal orientation
	assert_eq(main_container.get("orientation"), layout.HORIZONTAL)
	
	# Check sidebar sizing
	assert_eq(sidebar.custom_minimum_size.x, layout.LANDSCAPE_SIDEBAR_WIDTH)
	assert_eq(sidebar.custom_minimum_size.y, 0)
	
	# Check touch control sizes
	assert_eq(touch_button.custom_minimum_size.y, layout.TOUCH_BUTTON_HEIGHT * 0.75)

func test_orientation_change() -> void:
	# Start in landscape
	layout.size = Vector2(1024, 768)
	layout._check_orientation()
	layout._apply_landscape_layout()
	assert_eq(main_container.get("orientation"), layout.HORIZONTAL)
	
	# Switch to portrait
	layout.size = Vector2(400, 800)
	layout._check_orientation()
	layout._apply_portrait_layout()
	assert_eq(main_container.get("orientation"), layout.VERTICAL)
	
	# Verify sidebar adjustments
	var expected_height = 800 * layout.PORTRAIT_SIDEBAR_HEIGHT_RATIO
	assert_eq(sidebar.custom_minimum_size.y, expected_height)
	assert_eq(sidebar.custom_minimum_size.x, 0)

func test_touch_controls_adjustment() -> void:
	# Test portrait mode adjustments
	layout._adjust_touch_sizes(true)
	assert_eq(touch_button.custom_minimum_size.y, layout.TOUCH_BUTTON_HEIGHT)
	
	# Test landscape mode adjustments
	layout._adjust_touch_sizes(false)
	assert_eq(touch_button.custom_minimum_size.y, layout.TOUCH_BUTTON_HEIGHT * 0.75)

func test_missing_nodes_handling() -> void:
	# Create a new layout without required nodes
	var incomplete_layout = CampaignResponsiveLayout.new()
	add_child(incomplete_layout)
	
	# Should not crash when applying layouts
	incomplete_layout._apply_portrait_layout()
	incomplete_layout._apply_landscape_layout()
	
	incomplete_layout.queue_free()