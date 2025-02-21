@tool
extends "res://addons/gut/test.gd"

const TypeSafeMixin = preload("res://tests/fixtures/type_safe_test_mixin.gd")
const EventItem: GDScript = preload("res://src/scenes/campaign/components/EventItem.gd")

# Test variables with explicit types
var item: EventItem = null
var value_changed_signal_emitted: bool = false
var last_value: String = ""

func before_each() -> void:
	await super.before_each()
	
	item = EventItem.new()
	if not item:
		push_error("Failed to create event item instance")
		return
	add_child(item)
	
	_reset_signals()
	_connect_signals()
	
	await get_tree().process_frame

func after_each() -> void:
	if is_instance_valid(item):
		remove_child(item)
		item.queue_free()
	item = null
	await super.after_each()

func _reset_signals() -> void:
	value_changed_signal_emitted = false
	last_value = ""

func _connect_signals() -> void:
	if not item:
		push_error("Cannot connect signals: item is null")
		return
		
	if item.has_signal("value_changed"):
		var err := item.connect("value_changed", _on_value_changed)
		if err != OK:
			push_error("Failed to connect value_changed signal")

func _on_value_changed(new_value: String) -> void:
	value_changed_signal_emitted = true
	last_value = new_value

func test_initial_setup() -> void:
	assert_not_null(item, "Event item should be initialized")
	
	var value_label: Label = item.value_label
	var timestamp_label: Label = item.timestamp_label
	
	assert_not_null(value_label, "Value label should exist")
	assert_not_null(timestamp_label, "Timestamp label should exist")
	
	var current_value: String = TypeSafeMixin._safe_method_call_string(item, "get_current_value", [], "")
	assert_eq(current_value, "", "Initial value should be empty")

func test_value_update() -> void:
	var test_value: String = "Test Event"
	TypeSafeMixin._safe_method_call_bool(item, "set_value", [test_value])
	
	assert_true(value_changed_signal_emitted, "Value changed signal should be emitted")
	assert_eq(last_value, test_value, "Last value should match test value")
	
	var current_value: String = TypeSafeMixin._safe_method_call_string(item, "get_current_value", [], "")
	var label_text: String = TypeSafeMixin._safe_method_call_string(item.value_label, "get_text", [], "")
	
	assert_eq(current_value, test_value, "Current value should be updated")
	assert_eq(label_text, test_value, "Label should display the new value")

func test_empty_value_handling() -> void:
	TypeSafeMixin._safe_method_call_bool(item, "set_value", [""])
	
	assert_true(value_changed_signal_emitted, "Value changed signal should be emitted")
	assert_eq(last_value, "", "Last value should be empty")
	
	var label_text: String = TypeSafeMixin._safe_method_call_string(item.value_label, "get_text", [], "")
	assert_eq(label_text, "", "Label should be empty")

func test_timestamp_formatting() -> void:
	var test_timestamp: String = "2024-03-20 15:30:00"
	TypeSafeMixin._safe_method_call_bool(item, "set_timestamp", [test_timestamp])
	
	var timestamp_text: String = TypeSafeMixin._safe_method_call_string(item.timestamp_label, "get_text", [], "")
	assert_true(timestamp_text.length() > 0, "Timestamp should be formatted")
	assert_true("2024" in timestamp_text, "Timestamp should contain year")

func test_color_handling() -> void:
	var test_color := Color(1, 0, 0, 1) # Red color
	TypeSafeMixin._safe_method_call_bool(item, "set_text_color", [test_color])
	
	var value_label: Label = item.value_label
	var timestamp_label: Label = item.timestamp_label
	
	assert_not_null(value_label, "Value label should exist")
	assert_not_null(timestamp_label, "Timestamp label should exist")
	
	# Check if the color was applied to both labels
	var value_label_color: Color = value_label.get_theme_color("font_color")
	var timestamp_label_color: Color = timestamp_label.get_theme_color("font_color")
	
	assert_eq(value_label_color, test_color, "Value label color should match test color")
	assert_eq(timestamp_label_color, test_color, "Timestamp label color should match test color")

func test_animation_handling() -> void:
	TypeSafeMixin._safe_method_call_bool(item, "play_highlight_animation", [])
	
	# Wait for animation to start
	await get_tree().process_frame
	
	var animation_player: AnimationPlayer = item.animation_player
	assert_not_null(animation_player, "Animation player should exist")
	assert_true(animation_player.is_playing(), "Animation should be playing")