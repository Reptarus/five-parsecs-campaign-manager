@tool
extends GameTest

# Type-safe script references
const ResourceItem := preload("res://src/scenes/campaign/components/ResourceItem.gd")

# Type-safe instance variables
var _resource_item: Node = null

# Test Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	
	# Initialize resource item
	_resource_item = ResourceItem.new()
	if not _resource_item:
		push_error("Failed to create resource item")
		return
	TypeSafeMixin._safe_method_call_bool(_resource_item, "initialize", [])
	add_child_autofree(_resource_item)
	track_test_node(_resource_item)
	
	await stabilize_engine()

func after_each() -> void:
	_resource_item = null
	await super.after_each()

# Item Initialization Tests
func test_item_initialization() -> void:
	assert_not_null(_resource_item, "Resource item should be initialized")
	
	var is_visible: bool = TypeSafeMixin._safe_method_call_bool(_resource_item, "is_visible", [])
	assert_true(is_visible, "Item should be visible after initialization")
	
	var resource_type: int = TypeSafeMixin._safe_method_call_int(_resource_item, "get_resource_type", [])
	assert_eq(resource_type, GameEnums.ResourceType.NONE, "Should start with NONE type")

# Resource Value Tests
func test_resource_value() -> void:
	watch_signals(_resource_item)
	
	# Test value update
	TypeSafeMixin._safe_method_call_bool(_resource_item, "set_value", [100])
	var value: int = TypeSafeMixin._safe_method_call_int(_resource_item, "get_value", [])
	assert_eq(value, 100, "Resource value should match")
	verify_signal_emitted(_resource_item, "value_changed")
	
	# Test value formatting
	var formatted_value: String = TypeSafeMixin._safe_method_call_string(_resource_item, "get_formatted_value", [])
	assert_eq(formatted_value, "100", "Formatted value should match")

# Resource Type Tests
func test_resource_type() -> void:
	watch_signals(_resource_item)
	
	# Test type update
	TypeSafeMixin._safe_method_call_bool(_resource_item, "set_resource_type", [GameEnums.ResourceType.CREDITS])
	var type: int = TypeSafeMixin._safe_method_call_int(_resource_item, "get_resource_type", [])
	assert_eq(type, GameEnums.ResourceType.CREDITS, "Resource type should match")
	verify_signal_emitted(_resource_item, "type_changed")
	
	# Test type icon
	var has_icon: bool = TypeSafeMixin._safe_method_call_bool(_resource_item, "has_type_icon", [])
	assert_true(has_icon, "Credits type should have an icon")

# Resource Label Tests
func test_resource_label() -> void:
	watch_signals(_resource_item)
	
	# Test label update
	var label := "Test Resource"
	TypeSafeMixin._safe_method_call_bool(_resource_item, "set_label", [label])
	var current_label: String = TypeSafeMixin._safe_method_call_string(_resource_item, "get_label", [])
	assert_eq(current_label, label, "Resource label should match")
	verify_signal_emitted(_resource_item, "label_changed")

# Resource State Tests
func test_resource_state() -> void:
	watch_signals(_resource_item)
	
	# Test state update
	TypeSafeMixin._safe_method_call_bool(_resource_item, "set_state", ["depleted"])
	var state: String = TypeSafeMixin._safe_method_call_string(_resource_item, "get_state", [])
	assert_eq(state, "depleted", "Resource state should match")
	verify_signal_emitted(_resource_item, "state_changed")
	
	# Test state styling
	var has_state_style: bool = TypeSafeMixin._safe_method_call_bool(_resource_item, "has_state_style", [])
	assert_true(has_state_style, "Depleted state should have styling")

# Resource Tooltip Tests
func test_resource_tooltip() -> void:
	watch_signals(_resource_item)
	
	# Test tooltip update
	var tooltip := "Test tooltip"
	TypeSafeMixin._safe_method_call_bool(_resource_item, "set_tooltip", [tooltip])
	var current_tooltip: String = TypeSafeMixin._safe_method_call_string(_resource_item, "get_tooltip", [])
	assert_eq(current_tooltip, tooltip, "Resource tooltip should match")
	verify_signal_emitted(_resource_item, "tooltip_changed")

# Resource Animation Tests
func test_resource_animation() -> void:
	watch_signals(_resource_item)
	
	# Test value change animation
	TypeSafeMixin._safe_method_call_bool(_resource_item, "animate_value_change", [50, 100])
	verify_signal_emitted(_resource_item, "animation_started")
	
	await get_tree().create_timer(0.5).timeout
	verify_signal_emitted(_resource_item, "animation_completed")
	
	var final_value: int = TypeSafeMixin._safe_method_call_int(_resource_item, "get_value", [])
	assert_eq(final_value, 100, "Value should be updated after animation")

# Resource Interaction Tests
func test_resource_interaction() -> void:
	watch_signals(_resource_item)
	
	# Test click interaction
	TypeSafeMixin._safe_method_call_bool(_resource_item, "simulate_click", [])
	verify_signal_emitted(_resource_item, "item_clicked")
	
	# Test hover interaction
	TypeSafeMixin._safe_method_call_bool(_resource_item, "simulate_hover", [true])
	verify_signal_emitted(_resource_item, "item_hovered")

# Resource Validation Tests
func test_resource_validation() -> void:
	watch_signals(_resource_item)
	
	# Test invalid value
	var success: bool = TypeSafeMixin._safe_method_call_bool(_resource_item, "set_value", [-1])
	assert_false(success, "Should not set negative value")
	verify_signal_not_emitted(_resource_item, "value_changed")
	
	# Test invalid type
	success = TypeSafeMixin._safe_method_call_bool(_resource_item, "set_resource_type", [-1])
	assert_false(success, "Should not set invalid type")
	verify_signal_not_emitted(_resource_item, "type_changed")

# UI State Tests
func test_ui_state() -> void:
	watch_signals(_resource_item)
	
	# Test UI enable/disable
	TypeSafeMixin._safe_method_call_bool(_resource_item, "set_ui_enabled", [false])
	var is_enabled: bool = TypeSafeMixin._safe_method_call_bool(_resource_item, "is_ui_enabled", [])
	assert_false(is_enabled, "UI should be disabled")
	verify_signal_emitted(_resource_item, "ui_state_changed")
	
	# Test UI visibility
	TypeSafeMixin._safe_method_call_bool(_resource_item, "set_ui_visible", [false])
	var is_visible: bool = TypeSafeMixin._safe_method_call_bool(_resource_item, "is_visible", [])
	assert_false(is_visible, "UI should be hidden")
	verify_signal_emitted(_resource_item, "visibility_changed")

# Theme Tests
func test_theme_handling() -> void:
	watch_signals(_resource_item)
	
	# Test theme change
	var success: bool = TypeSafeMixin._safe_method_call_bool(_resource_item, "set_theme", ["dark"])
	assert_true(success, "Should change theme")
	
	var current_theme: String = TypeSafeMixin._safe_method_call_string(_resource_item, "get_current_theme", [])
	assert_eq(current_theme, "dark", "Current theme should match")
	verify_signal_emitted(_resource_item, "theme_changed")