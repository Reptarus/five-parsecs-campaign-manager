@tool
extends "res://tests/fixtures/base/game_test.gd"

const ResourceDisplay = preload("res://src/ui/resource/ResourceDisplay.gd")

var display: ResourceDisplay
var resource_updated_signal_emitted := false
var last_resource_type: GameEnums.ResourceType = GameEnums.ResourceType.NONE
var last_resource_value: int = 0

# Type-safe test lifecycle
func before_each() -> void:
	await super.before_each()
	display = ResourceDisplay.new()
	add_child_autofree(display)
	track_test_node(display)
	_reset_signals()
	_connect_signals()

func after_each() -> void:
	_disconnect_signals()
	_reset_signals()
	if display:
		display.queue_free()
		display = null
	await super.after_each()

# Type-safe signal handling
func _reset_signals() -> void:
	resource_updated_signal_emitted = false
	last_resource_type = GameEnums.ResourceType.NONE
	last_resource_value = 0

func _connect_signals() -> void:
	if not display:
		return
		
	if display.has_signal("resource_updated"):
		display.connect("resource_updated", _on_resource_updated)

func _disconnect_signals() -> void:
	if not display:
		return
		
	if display.has_signal("resource_updated") and display.is_connected("resource_updated", _on_resource_updated):
		display.disconnect("resource_updated", _on_resource_updated)

func _on_resource_updated(resource_type: GameEnums.ResourceType, new_value: int) -> void:
	resource_updated_signal_emitted = true
	last_resource_type = resource_type
	last_resource_value = new_value

# Type-safe test methods
func test_initial_setup() -> void:
	assert_not_null(display, "Resource display should exist")
	
	var container: Node = _call_node_method(display, "get_node", ["resource_container"])
	assert_not_null(container, "Resource container should exist")
	
	var items: Array = _call_node_method_array(display, "get_resource_items")
	assert_true(items.is_empty(), "Should start with no resource items")

func test_resource_addition() -> void:
	var test_resources := {
		GameEnums.ResourceType.CREDITS: 1000,
		GameEnums.ResourceType.SUPPLIES: 50,
		GameEnums.ResourceType.TECH_PARTS: 25,
		GameEnums.ResourceType.REPUTATION: 10
	}
	
	for resource_type in test_resources:
		var value: int = test_resources[resource_type]
		_call_node_method(display, "add_resource", [resource_type, value])
		
		assert_true(resource_updated_signal_emitted, "Resource updated signal should be emitted")
		assert_eq(last_resource_type, resource_type, "Resource type should match")
		assert_eq(last_resource_value, value, "Resource value should match")
		
		var has_resource: bool = _call_node_method_bool(display, "has_resource", [resource_type])
		assert_true(has_resource, "Should have added resource")
		
		_reset_signals()

func test_resource_update() -> void:
	_call_node_method(display, "add_resource", [GameEnums.ResourceType.CREDITS, 100])
	_reset_signals()
	
	var new_value := 200
	_call_node_method(display, "update_resource", [GameEnums.ResourceType.CREDITS, new_value])
	
	assert_true(resource_updated_signal_emitted, "Resource updated signal should be emitted")
	assert_eq(last_resource_type, GameEnums.ResourceType.CREDITS, "Resource type should match")
	assert_eq(last_resource_value, new_value, "Resource value should match")
	
	var current_value: int = _call_node_method_int(display, "get_resource_value", [GameEnums.ResourceType.CREDITS])
	assert_eq(current_value, new_value, "Resource value should be updated")

func test_resource_removal() -> void:
	_call_node_method(display, "add_resource", [GameEnums.ResourceType.CREDITS, 100])
	
	var has_resource: bool = _call_node_method_bool(display, "has_resource", [GameEnums.ResourceType.CREDITS])
	assert_true(has_resource, "Should have added resource")
	
	_call_node_method(display, "remove_resource", [GameEnums.ResourceType.CREDITS])
	
	has_resource = _call_node_method_bool(display, "has_resource", [GameEnums.ResourceType.CREDITS])
	assert_false(has_resource, "Should have removed resource")

func test_multiple_resources() -> void:
	var test_resources := {
		GameEnums.ResourceType.CREDITS: 1000,
		GameEnums.ResourceType.SUPPLIES: 50,
		GameEnums.ResourceType.TECH_PARTS: 25
	}
	
	for resource_type in test_resources:
		var value: int = test_resources[resource_type]
		_call_node_method(display, "add_resource", [resource_type, value])
	
	var items: Array = _call_node_method_array(display, "get_resource_items")
	assert_eq(items.size(), test_resources.size(), "Should have all resources added")
	
	for resource_type in test_resources:
		var has_resource: bool = _call_node_method_bool(display, "has_resource", [resource_type])
		assert_true(has_resource, "Should have resource %s" % resource_type)
		
		var value: int = _call_node_method_int(display, "get_resource_value", [resource_type])
		assert_eq(value, test_resources[resource_type], "Resource %s should have correct value" % resource_type)

func test_resource_layout() -> void:
	_call_node_method(display, "add_resource", [GameEnums.ResourceType.CREDITS, 100])
	
	var items: Array = _call_node_method_array(display, "get_resource_items")
	assert_eq(items.size(), 1, "Should have one resource item")
	
	var item: Control = items[0] as Control
	assert_not_null(item, "Resource item should exist")
	assert_true(item.size.x > 0, "Item should have width")
	assert_true(item.size.y > 0, "Item should have height")
	assert_true(item.custom_minimum_size.x > 0, "Item should have minimum width")
	assert_true(item.custom_minimum_size.y > 0, "Item should have minimum height")

func test_invalid_resource_type() -> void:
	var invalid_type := -1
	_call_node_method(display, "add_resource", [invalid_type, 100])
	
	assert_false(resource_updated_signal_emitted, "Should not emit signal for invalid resource type")
	
	var has_resource: bool = _call_node_method_bool(display, "has_resource", [invalid_type])
	assert_false(has_resource, "Should not have invalid resource type")

func test_negative_values() -> void:
	_call_node_method(display, "add_resource", [GameEnums.ResourceType.CREDITS, -50])
	
	assert_true(resource_updated_signal_emitted, "Should emit signal for negative values")
	assert_eq(last_resource_value, -50, "Should store negative value")
	
	var value: int = _call_node_method_int(display, "get_resource_value", [GameEnums.ResourceType.CREDITS])
	assert_eq(value, -50, "Should retrieve negative value")

func test_resource_clear() -> void:
	_call_node_method(display, "add_resource", [GameEnums.ResourceType.CREDITS, 100])
	_call_node_method(display, "add_resource", [GameEnums.ResourceType.SUPPLIES, 50])
	
	_call_node_method(display, "clear_resources")
	
	var items: Array = _call_node_method_array(display, "get_resource_items")
	assert_true(items.is_empty(), "Should have no resources after clear")
	
	var has_credits: bool = _call_node_method_bool(display, "has_resource", [GameEnums.ResourceType.CREDITS])
	var has_supplies: bool = _call_node_method_bool(display, "has_resource", [GameEnums.ResourceType.SUPPLIES])
	assert_false(has_credits, "Should not have credits after clear")
	assert_false(has_supplies, "Should not have supplies after clear")