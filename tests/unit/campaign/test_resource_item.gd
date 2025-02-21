@tool
extends "res://addons/gut/test.gd"

const TypeSafeMixin = preload("res://tests/fixtures/type_safe_test_mixin.gd")
const ResourceItem: GDScript = preload("res://src/scenes/campaign/components/ResourceItem.gd")
const GameEnums: GDScript = preload("res://src/core/systems/GlobalEnums.gd")

# Test variables with explicit types
var item: ResourceItem = null
var value_changed_signal_emitted: bool = false
var last_value: int = 0

func before_each() -> void:
	await super.before_each()
	
	item = ResourceItem.new()
	if not item:
		push_error("Failed to create resource item instance")
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
	last_value = 0

func _connect_signals() -> void:
	if not item:
		push_error("Cannot connect signals: item is null")
		return
		
	if item.has_signal("value_changed"):
		var err := item.connect("value_changed", _on_value_changed)
		if err != OK:
			push_error("Failed to connect value_changed signal")

func _on_value_changed(new_value: int) -> void:
	value_changed_signal_emitted = true
	last_value = new_value

func test_initial_setup() -> void:
	assert_not_null(item, "Resource item should be initialized")
	
	var value_label: Label = item.value_label
	var icon_texture: TextureRect = item.icon_texture
	
	assert_not_null(value_label, "Value label should exist")
	assert_not_null(icon_texture, "Icon texture should exist")
	
	var current_value: int = TypeSafeMixin._safe_method_call_int(item, "get_current_value", [], -1)
	assert_eq(current_value, 0, "Initial value should be 0")

func test_value_update() -> void:
	var test_value: int = 100
	TypeSafeMixin._safe_method_call_bool(item, "set_value", [test_value])
	
	assert_true(value_changed_signal_emitted, "Value changed signal should be emitted")
	assert_eq(last_value, test_value, "Last value should match test value")
	
	var current_value: int = TypeSafeMixin._safe_method_call_int(item, "get_current_value", [], -1)
	var label_text: String = TypeSafeMixin._safe_method_call_string(item.value_label, "get_text", [], "")
	
	assert_eq(current_value, test_value, "Current value should be updated")
	assert_true(str(test_value) in label_text, "Label should display the new value")

func test_icon_update() -> void:
	var test_type: int = GameEnums.ResourceType.CREDITS
	TypeSafeMixin._safe_method_call_bool(item, "set_resource_type", [test_type])
	
	var icon_texture: TextureRect = item.icon_texture
	assert_not_null(icon_texture, "Icon texture should exist")
	assert_not_null(icon_texture.texture, "Icon texture should be set")

func test_negative_value_handling() -> void:
	var test_value: int = -50
	TypeSafeMixin._safe_method_call_bool(item, "set_value", [test_value])
	
	assert_true(value_changed_signal_emitted, "Value changed signal should be emitted")
	assert_eq(last_value, test_value, "Last value should match test value")
	
	var label_text: String = TypeSafeMixin._safe_method_call_string(item.value_label, "get_text", [], "")
	assert_true("-50" in label_text, "Label should display negative value")

func test_zero_value_handling() -> void:
	TypeSafeMixin._safe_method_call_bool(item, "set_value", [0])
	
	assert_true(value_changed_signal_emitted, "Value changed signal should be emitted")
	assert_eq(last_value, 0, "Last value should be 0")
	
	var label_text: String = TypeSafeMixin._safe_method_call_string(item.value_label, "get_text", [], "")
	assert_true("0" in label_text, "Label should display zero")

func test_large_value_formatting() -> void:
	var test_value: int = 1000000
	TypeSafeMixin._safe_method_call_bool(item, "set_value", [test_value])
	
	assert_true(value_changed_signal_emitted, "Value changed signal should be emitted")
	assert_eq(last_value, test_value, "Last value should match test value")
	
	var label_text: String = TypeSafeMixin._safe_method_call_string(item.value_label, "get_text", [], "")
	assert_true("1000000" in label_text, "Label should display large value")

func test_resource_type_validation() -> void:
	var invalid_type: int = -1
	TypeSafeMixin._safe_method_call_bool(item, "set_resource_type", [invalid_type])
	
	var resource_type: int = TypeSafeMixin._safe_method_call_int(item, "get_resource_type", [], -999)
	assert_eq(resource_type, GameEnums.ResourceType.NONE, "Invalid type should default to NONE")

func test_tooltip_setup() -> void:
	var test_type: int = GameEnums.ResourceType.CREDITS
	TypeSafeMixin._safe_method_call_bool(item, "set_resource_type", [test_type])
	
	var tooltip_text: String = TypeSafeMixin._safe_method_call_string(item, "get_tooltip_text", [], "")
	assert_not_null(tooltip_text, "Tooltip text should exist")
	assert_true(tooltip_text.length() > 0, "Tooltip should not be empty")