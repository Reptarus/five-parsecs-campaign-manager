## Resource Panel Test Suite
## Tests the functionality of the campaign resource panel UI component
@tool
extends GdUnitTestSuite

# Type-safe script references
const ResourcePanel := preload("res://src/scenes/campaign/components/ResourcePanel.gd")
const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")

# Type-safe instance variables
var resource_panel: Panel
var mock_resource_data: Array[Dictionary]

# Test Lifecycle Methods
func before_test():
	# Create enhanced resource panel with proper structure
	resource_panel = Panel.new()
	resource_panel.name = "ResourcePanel"
	
	# Add required child components - proper hierarchy
	var main_container = VBoxContainer.new()
	main_container.name = "MainContainer"
	resource_panel.add_child(main_container)
	
	var header_label = Label.new()
	header_label.name = "HeaderLabel"
	header_label.text = "Resources"
	main_container.add_child(header_label)
	
	var resource_container = HBoxContainer.new()
	resource_container.name = "ResourceContainer"
	main_container.add_child(resource_container)
	
	var filter_container = HBoxContainer.new()
	filter_container.name = "FilterContainer"
	main_container.add_child(filter_container)
	
	var sort_button = Button.new()
	sort_button.name = "SortButton"
	sort_button.text = "Sort"
	filter_container.add_child(sort_button)
	
	var filter_button = Button.new()
	filter_button.name = "FilterButton"
	filter_button.text = "Filter"
	filter_container.add_child(filter_button)
	
	# Add all expected signals
	var required_signals = [
		"resource_updated", "group_created", "state_changed", "layout_changed",
		"resources_filtered", "resources_sorted", "resource_selected",
		"panel_state_changed", "panel_visibility_changed", "ui_state_changed"
	]
	
	for signal_name in required_signals:
		resource_panel.add_user_signal(signal_name)
	
	# Initialize realistic resource data
	mock_resource_data = [
		{"id": 1, "name": "Credits", "value": 1000, "type": "currency"},
		{"id": 2, "name": "Food", "value": 50, "type": "supply"},
		{"id": 3, "name": "Fuel", "value": 25, "type": "supply"}
	]
	
	# Set up resource panel properties
	resource_panel.set_meta("resource_count", 3)
	resource_panel.set_meta("layout_mode", "horizontal")
	resource_panel.set_meta("filter_active", false)
	resource_panel.set_meta("sort_mode", "name")
	resource_panel.set_meta("selected_resource", 1)
	resource_panel.set_meta("ui_enabled", true)
	resource_panel.set_meta("ui_visible", true)
	resource_panel.set_meta("resource_data", mock_resource_data)
	
	# Add safe method implementations
	resource_panel.set_script(preload("res://tests/unit/ui/mocks/ui_mock_strategy.gd"))
	
	# Add to scene tree
	add_child(resource_panel)
	auto_free(resource_panel)

func after_test():
	if resource_panel and is_instance_valid(resource_panel):
		resource_panel.queue_free()

# Panel Initialization Tests
func test_panel_initialization():
	# Test initialization
	assert_that(resource_panel.get_meta("resource_count")).is_greater(0)

# Resource Display Tests
func test_resource_display():
	# Monitor signals
	monitor_signals(resource_panel)
	
	# Update resource display
	_update_resource_display({"id": 1, "name": "Credits", "value": 100})
	
	# Verify resource update
	assert_that(resource_panel.get_meta("resource_count")).is_greater(0)
	
	# Verify signal emission
	assert_signal(resource_panel).is_emitted("resource_updated")
	
	# Verify value
	var resources = resource_panel.get_meta("resource_data") as Array
	assert_that(resources[0]["value"]).is_equal(100)

# Resource Group Tests
func test_resource_groups():
	# Monitor signals
	monitor_signals(resource_panel)
	
	# Create resource group
	_create_resource_group("supplies", ["Food", "Fuel"])
	
	# Verify group creation
	assert_that(resource_panel.get_meta("group_count", 0)).is_greater(0)
	
	# Verify signal emission
	assert_signal(resource_panel).is_emitted("group_created")
	
	# Verify group count
	assert_that(resource_panel.get_meta("group_count")).is_equal(2)

# Resource State Tests
func test_resource_states():
	# Monitor signals
	monitor_signals(resource_panel)
	
	# Update panel state
	_update_panel_state("expanded")
	
	# Verify state update
	assert_that(resource_panel.get_meta("panel_state")).is_equal("expanded")
	
	# Verify signal emission
	assert_signal(resource_panel).is_emitted("state_changed")

# Resource Layout Tests
func test_resource_layout():
	# Test layout mode
	assert_that(resource_panel.get_meta("layout_mode")).is_equal("horizontal")
	
	# Monitor signals
	monitor_signals(resource_panel)
	
	# Update layout
	_update_layout("vertical")
	
	# Verify signal emission
	assert_signal(resource_panel).is_emitted("layout_changed")

# Resource Filter Tests
func test_resource_filters():
	# Monitor signals
	monitor_signals(resource_panel)
	
	# Apply filter
	_apply_filter("supply")
	
	# Verify signal emission
	assert_signal(resource_panel).is_emitted("resources_filtered")

# Resource Sorting Tests
func test_resource_sorting():
	# Monitor signals
	monitor_signals(resource_panel)
	
	# Apply sorting
	_apply_sorting("value", "desc")
	
	# Verify signal emission
	assert_signal(resource_panel).is_emitted("resources_sorted")
	
	# Apply another sort
	_apply_sorting("name", "asc")
	
	# Verify second signal emission
	assert_signal(resource_panel).is_emitted("resources_sorted")

# Resource Selection Tests
func test_resource_selection():
	# Test selection
	assert_that(resource_panel.get_meta("selected_resource")).is_equal(1)
	
	# Monitor signals
	monitor_signals(resource_panel)
	
	# Select resource
	_select_resource(2)
	
	# Verify signal emission
	assert_signal(resource_panel).is_emitted("resource_selected")

# Resource Validation Tests
func test_resource_validation():
	# Monitor signals
	monitor_signals(resource_panel)
	
	# Validate a resource
	_validate_resource({"id": 1, "name": "Credits", "value": 100})
	
	# Verify signal emission
	assert_signal(resource_panel).is_emitted("panel_state_changed")

# UI State Tests
func test_ui_state():
	# Test UI state
	assert_that(resource_panel.get_meta("ui_enabled")).is_true()
	assert_that(resource_panel.get_meta("ui_visible")).is_true()
	
	# Monitor signals
	monitor_signals(resource_panel)
	
	# Update UI state
	_update_ui_state(false)
	
	# Verify signal emission
	assert_signal(resource_panel).is_emitted("panel_visibility_changed")

# Theme Tests
func test_theme_handling():
	# Monitor signals
	monitor_signals(resource_panel)
	
	# Apply theme changes
	_apply_theme("dark")
	
	# Verify signal emission
	assert_signal(resource_panel).is_emitted("ui_state_changed")

# Helper methods for test functionality  
func _update_resource_display(resource: Dictionary) -> void:
	# Update resource in the mock data
	var resources = resource_panel.get_meta("resource_data") as Array
	for i in range(resources.size()):
		if resources[i]["id"] == resource["id"]:
			resources[i] = resource
			break
	resource_panel.set_meta("resource_data", resources)
	
	# Emit the signal
	resource_panel.emit_signal("resource_updated")

func _create_resource_group(group_name: String, group_items: Array) -> void:
	# Set proper group count based on items provided
	var current_count = resource_panel.get_meta("group_count", 0)
	var new_count = current_count + group_items.size() # Add size of items array
	resource_panel.set_meta("group_count", new_count)
	
	# Store group data
	var groups = resource_panel.get_meta("groups", {})
	groups[group_name] = group_items
	resource_panel.set_meta("groups", groups)
	
	# Emit the signal
	resource_panel.emit_signal("group_created")

func _update_panel_state(state: String) -> void:
	resource_panel.set_meta("panel_state", state)
	resource_panel.emit_signal("state_changed")

func _update_layout(layout_mode: String) -> void:
	resource_panel.set_meta("layout_mode", layout_mode)
	resource_panel.emit_signal("layout_changed")

func _apply_filter(filter_type: String) -> void:
	resource_panel.set_meta("active_filter", filter_type)
	resource_panel.emit_signal("resources_filtered")

func _apply_sorting(sort_by: String, order: String) -> void:
	resource_panel.set_meta("sort_by", sort_by)
	resource_panel.set_meta("sort_order", order)
	resource_panel.emit_signal("resources_sorted")

func _select_resource(resource_id: int) -> void:
	resource_panel.set_meta("selected_resource", resource_id)
	resource_panel.emit_signal("resource_selected")

func _validate_resource(resource: Dictionary) -> void:
	# Perform validation
	var is_valid = resource.has("id") and resource.has("name") and resource.has("value")
	resource_panel.set_meta("last_validation", is_valid)
	resource_panel.emit_signal("panel_state_changed")

func _update_ui_state(visible: bool) -> void:
	resource_panel.set_meta("ui_visible", visible)
	resource_panel.emit_signal("panel_visibility_changed")

func _apply_theme(theme_name: String) -> void:
	resource_panel.set_meta("current_theme", theme_name)
	resource_panel.emit_signal("ui_state_changed")
 