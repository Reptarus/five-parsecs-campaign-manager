@tool
extends "res://tests/unit/ui/base/component_test_base.gd"

const EventItem: GDScript = preload("res://src/scenes/campaign/components/EventItem.gd")

# Test variables with explicit types
var value_changed_signal_emitted: bool = false
var last_value: String = ""

# Override _create_component_instance to provide the specific component
func _create_component_instance() -> Control:
	return EventItem.new()

func before_each() -> void:
	await super.before_each()
	_reset_signals()
	_connect_signals()

func after_each() -> void:
	await super.after_each()
	value_changed_signal_emitted = false
	last_value = ""

func _reset_signals() -> void:
	value_changed_signal_emitted = false
	last_value = ""

func _connect_signals() -> void:
	if not _component:
		push_error("Cannot connect signals: component is null")
		return
		
	if _component.has_signal("value_changed"):
		_component.value_changed.connect(_on_value_changed)

func _on_value_changed(new_value: String) -> void:
	value_changed_signal_emitted = true
	last_value = new_value

func test_initial_setup() -> void:
	assert_not_null(_component, "Event item should be initialized")
	
	var value_label: Label = _component.value_label
	var timestamp_label: Label = _component.timestamp_label
	
	assert_not_null(value_label, "Value label should exist")
	assert_not_null(timestamp_label, "Timestamp label should exist")
	
	var current_value: String = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(_component, "get_current_value", []))
	assert_eq(current_value, "", "Initial value should be empty")

func test_value_update() -> void:
	var test_value: String = "Test Event"
	TypeSafeMixin._call_node_method_bool(_component, "set_value", [test_value])
	
	assert_true(value_changed_signal_emitted, "Value changed signal should be emitted")
	assert_eq(last_value, test_value, "Last value should match test value")
	
	var current_value: String = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(_component, "get_current_value", []))
	var label_text: String = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(_component.value_label, "get_text", []))
	
	assert_eq(current_value, test_value, "Current value should be updated")
	assert_eq(label_text, test_value, "Label should display the new value")

func test_empty_value_handling() -> void:
	TypeSafeMixin._call_node_method_bool(_component, "set_value", [""])
	
	assert_true(value_changed_signal_emitted, "Value changed signal should be emitted")
	assert_eq(last_value, "", "Last value should be empty")
	
	var label_text: String = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(_component.value_label, "get_text", []))
	assert_eq(label_text, "", "Label should be empty")

func test_timestamp_formatting() -> void:
	var test_timestamp: String = "2024-03-20 15:30:00"
	TypeSafeMixin._call_node_method_bool(_component, "set_timestamp", [test_timestamp])
	
	var timestamp_text: String = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(_component.timestamp_label, "get_text", []))
	assert_true(timestamp_text.length() > 0, "Timestamp should be formatted")
	assert_true("2024" in timestamp_text, "Timestamp should contain year")

func test_color_handling() -> void:
	var test_color := Color(1, 0, 0, 1) # Red color
	TypeSafeMixin._call_node_method_bool(_component, "set_text_color", [test_color])
	
	var value_label: Label = _component.value_label
	var timestamp_label: Label = _component.timestamp_label
	
	assert_not_null(value_label, "Value label should exist")
	assert_not_null(timestamp_label, "Timestamp label should exist")
	
	# Check if the color was applied to both labels
	var value_label_color: Color = value_label.get_theme_color("font_color")
	var timestamp_label_color: Color = timestamp_label.get_theme_color("font_color")
	
	assert_eq(value_label_color, test_color, "Value label color should match test color")
	assert_eq(timestamp_label_color, test_color, "Timestamp label color should match test color")

func test_animation_handling() -> void:
	TypeSafeMixin._call_node_method_bool(_component, "play_highlight_animation", [])
	
	# Wait for animation to start
	await get_tree().process_frame
	
	var animation_player: AnimationPlayer = _component.animation_player
	assert_not_null(animation_player, "Animation player should exist")
	assert_true(animation_player.is_playing(), "Animation should be playing")

# Add inherited component tests
func test_component_structure() -> void:
	await super.test_component_structure()
	
	# Additional EventItem-specific structure tests
	assert_not_null(_component.value_label, "Value label should exist")
	assert_not_null(_component.timestamp_label, "Timestamp label should exist")
	assert_not_null(_component.animation_player, "Animation player should exist")

func test_component_theme() -> void:
	await super.test_component_theme()
	
	# Additional EventItem-specific theme tests
	assert_true(_component.has_theme_color("font_color"), "Should have font color theme property")
	assert_true(_component.has_theme_stylebox("normal"), "Should have normal stylebox")

func test_component_accessibility() -> void:
	await super.test_component_accessibility()
	
	# Additional EventItem-specific accessibility tests
	assert_true(_component.value_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT,
		"Value label should be left-aligned for readability")
	assert_true(_component.timestamp_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT,
		"Timestamp label should be right-aligned for consistency")