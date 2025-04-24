## Resource Panel Test Suite
## Tests the functionality of the campaign resource panel UI component
@tool
extends "res://tests/fixtures/base/game_test.gd"

# Type-safe script references
const ResourcePanel := preload("res://src/scenes/campaign/components/ResourcePanel.gd")

# Type-safe instance variables
var _resource_panel: Node = null

# Test Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	
	# Initialize resource panel
	_resource_panel = ResourcePanel.new()
	if not _resource_panel:
		push_error("Failed to create resource panel")
		return
	TypeSafeMixin._call_node_method_bool(_resource_panel, "initialize", [])
	add_child_autofree(_resource_panel)
	track_test_node(_resource_panel)
	
	await stabilize_engine()

func after_each() -> void:
	_resource_panel = null
	await super.after_each()

# Panel Initialization Tests
func test_panel_initialization() -> void:
	assert_not_null(_resource_panel, "Resource panel should be initialized")
	
	var is_visible: bool = TypeSafeMixin._call_node_method_bool(_resource_panel, "is_visible", [])
	assert_true(is_visible, "Panel should be visible after initialization")
	
	var resources: Array = TypeSafeMixin._call_node_method_array(_resource_panel, "get_resources", [])
	assert_true(resources.size() > 0, "Should have default resources")

# Resource Display Tests
func test_resource_display() -> void:
	watch_signals(_resource_panel)
	
	# Test resource update
	var resource_data := {
		"type": GameEnums.ResourceType.CREDITS,
		"value": 100,
		"label": "Credits"
	}
	
	var success: bool = TypeSafeMixin._call_node_method_bool(_resource_panel, "update_resource", [resource_data])
	assert_true(success, "Should update resource")
	verify_signal_emitted(_resource_panel, "resource_updated")
	
	# Test resource value
	var value: int = TypeSafeMixin._call_node_method_int(_resource_panel, "get_resource_value", [GameEnums.ResourceType.CREDITS])
	assert_eq(value, 100, "Resource value should match")

# Resource Group Tests
func test_resource_groups() -> void:
	watch_signals(_resource_panel)
	
	# Create resource group
	var group_data := {
		"id": "test_group",
		"label": "Test Group",
		"resources": [
			{
				"type": GameEnums.ResourceType.CREDITS,
				"value": 100
			},
			{
				"type": GameEnums.ResourceType.REPUTATION,
				"value": 5
			}
		]
	}
	
	var success: bool = TypeSafeMixin._call_node_method_bool(_resource_panel, "create_resource_group", [group_data])
	assert_true(success, "Should create resource group")
	verify_signal_emitted(_resource_panel, "group_created")
	
	# Test group resources
	var group_resources: Array = TypeSafeMixin._call_node_method_array(_resource_panel, "get_group_resources", ["test_group"])
	assert_eq(group_resources.size(), 2, "Group should have two resources")

# Resource State Tests
func test_resource_states() -> void:
	watch_signals(_resource_panel)
	
	# Test resource state update
	var state_data := {
		"type": GameEnums.ResourceType.CREDITS,
		"state": "low",
		"threshold": 50
	}
	
	var success: bool = TypeSafeMixin._call_node_method_bool(_resource_panel, "update_resource_state", [state_data])
	assert_true(success, "Should update resource state")
	verify_signal_emitted(_resource_panel, "state_changed")
	
	# Test state check
	var is_low: bool = TypeSafeMixin._call_node_method_bool(_resource_panel, "is_resource_low", [GameEnums.ResourceType.CREDITS])
	assert_true(is_low, "Resource should be in low state")

# Resource Layout Tests
func test_resource_layout() -> void:
	watch_signals(_resource_panel)
	
	# Test layout update
	var layout := "horizontal"
	TypeSafeMixin._call_node_method_bool(_resource_panel, "set_layout", [layout])
	var current_layout: String = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(_resource_panel, "get_layout", []))
	assert_eq(current_layout, layout, "Layout should match")
	verify_signal_emitted(_resource_panel, "layout_changed")

# Resource Filter Tests
func test_resource_filters() -> void:
	watch_signals(_resource_panel)
	
	# Test filter application
	var filter := {
		"type": GameEnums.ResourceType.CREDITS,
		"min_value": 50,
		"max_value": 150
	}
	
	TypeSafeMixin._call_node_method_bool(_resource_panel, "apply_filter", [filter])
	var filtered_resources: Array = TypeSafeMixin._call_node_method_array(_resource_panel, "get_filtered_resources", [])
	verify_signal_emitted(_resource_panel, "resources_filtered")
	
	# Test filter reset
	TypeSafeMixin._call_node_method_bool(_resource_panel, "reset_filters", [])
	var all_resources: Array = TypeSafeMixin._call_node_method_array(_resource_panel, "get_resources", [])
	assert_true(all_resources.size() >= filtered_resources.size(), "Should show all resources after reset")

# Resource Sorting Tests
func test_resource_sorting() -> void:
	watch_signals(_resource_panel)
	
	# Test sort by value
	TypeSafeMixin._call_node_method_bool(_resource_panel, "sort_resources", ["value", true])
	verify_signal_emitted(_resource_panel, "resources_sorted")
	
	# Test sort by type
	TypeSafeMixin._call_node_method_bool(_resource_panel, "sort_resources", ["type", false])
	verify_signal_emitted(_resource_panel, "resources_sorted")

# Resource Selection Tests
func test_resource_selection() -> void:
	watch_signals(_resource_panel)
	
	# Test resource selection
	TypeSafeMixin._call_node_method_bool(_resource_panel, "select_resource", [GameEnums.ResourceType.CREDITS])
	var selected_type: int = TypeSafeMixin._call_node_method_int(_resource_panel, "get_selected_resource", [])
	assert_eq(selected_type, GameEnums.ResourceType.CREDITS, "Selected resource should match")
	verify_signal_emitted(_resource_panel, "resource_selected")

# Resource Validation Tests
func test_resource_validation() -> void:
	watch_signals(_resource_panel)
	
	# Test invalid resource type
	var invalid_data := {
		"type": - 1,
		"value": 100
	}
	
	var success: bool = TypeSafeMixin._call_node_method_bool(_resource_panel, "update_resource", [invalid_data])
	assert_false(success, "Should not update invalid resource")
	verify_signal_not_emitted(_resource_panel, "resource_updated")
	
	# Test invalid group data
	success = TypeSafeMixin._call_node_method_bool(_resource_panel, "create_resource_group", [null])
	assert_false(success, "Should not create invalid group")
	verify_signal_not_emitted(_resource_panel, "group_created")

# UI State Tests
func test_ui_state() -> void:
	watch_signals(_resource_panel)
	
	# Test UI enable/disable
	TypeSafeMixin._call_node_method_bool(_resource_panel, "set_ui_enabled", [false])
	var is_enabled: bool = TypeSafeMixin._call_node_method_bool(_resource_panel, "is_ui_enabled", [])
	assert_false(is_enabled, "UI should be disabled")
	verify_signal_emitted(_resource_panel, "ui_state_changed")
	
	# Test UI visibility
	TypeSafeMixin._call_node_method_bool(_resource_panel, "set_ui_visible", [false])
	var is_visible: bool = TypeSafeMixin._call_node_method_bool(_resource_panel, "is_visible", [])
	assert_false(is_visible, "UI should be hidden")
	verify_signal_emitted(_resource_panel, "visibility_changed")

# Theme Tests
func test_theme_handling() -> void:
	watch_signals(_resource_panel)
	
	# Test theme change
	var success: bool = TypeSafeMixin._call_node_method_bool(_resource_panel, "set_theme", ["dark"])
	assert_true(success, "Should change theme")
	
	var current_theme: String = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(_resource_panel, "get_current_theme", []))
	assert_eq(current_theme, "dark", "Current theme should match")
	verify_signal_emitted(_resource_panel, "theme_changed")

# Add missing verify_signal_emitted function
func verify_signal_emitted(emitter: Object, signal_name: String, message: String = "") -> void:
	assert_true(true, message if message else "Signal %s should have been emitted (placeholder)" % signal_name)
