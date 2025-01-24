extends "res://addons/gut/test.gd"

const ResourceItem = preload("res://src/scenes/campaign/components/ResourceItem.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

var item: ResourceItem
var value_changed_signal_emitted := false
var last_value: int

func before_each() -> void:
	item = ResourceItem.new()
	add_child(item)
	_reset_signals()
	_connect_signals()

func after_each() -> void:
	item.queue_free()

func _reset_signals() -> void:
	value_changed_signal_emitted = false
	last_value = 0

func _connect_signals() -> void:
	item.value_changed.connect(_on_value_changed)

func _on_value_changed(new_value: int) -> void:
	value_changed_signal_emitted = true
	last_value = new_value

func test_initial_setup() -> void:
	assert_not_null(item)
	assert_not_null(item.value_label)
	assert_not_null(item.icon_texture)
	assert_eq(item.current_value, 0)

func test_value_update() -> void:
	var test_value = 100
	item.set_value(test_value)
	
	assert_true(value_changed_signal_emitted)
	assert_eq(last_value, test_value)
	assert_eq(item.current_value, test_value)
	assert_true(str(test_value) in item.value_label.text)

func test_icon_update() -> void:
	var test_type = GameEnums.ResourceType.CREDITS
	item.set_resource_type(test_type)
	
	assert_not_null(item.icon_texture.texture)
	# Add specific icon checks when implemented

func test_negative_value_handling() -> void:
	var test_value = -50
	item.set_value(test_value)
	
	assert_true(value_changed_signal_emitted)
	assert_eq(last_value, test_value)
	assert_true("-50" in item.value_label.text)

func test_zero_value_handling() -> void:
	item.set_value(0)
	
	assert_true(value_changed_signal_emitted)
	assert_eq(last_value, 0)
	assert_true("0" in item.value_label.text)

func test_large_value_formatting() -> void:
	var test_value = 1000000
	item.set_value(test_value)
	
	assert_true(value_changed_signal_emitted)
	assert_eq(last_value, test_value)
	assert_true("1000000" in item.value_label.text)

func test_resource_type_validation() -> void:
	var invalid_type = -1
	item.set_resource_type(invalid_type)
	
	assert_eq(item.resource_type, GameEnums.ResourceType.NONE)

func test_tooltip_setup() -> void:
	var test_type = GameEnums.ResourceType.CREDITS
	item.set_resource_type(test_type)
	
	assert_not_null(item.tooltip_text)
	assert_true(item.tooltip_text.length() > 0)