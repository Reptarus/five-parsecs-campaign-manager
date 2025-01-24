extends "res://addons/gut/test.gd"

const ResourceDisplay = preload("res://src/ui/resource/ResourceDisplay.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

var display: ResourceDisplay
var resource_updated_signal_emitted := false
var last_resource_type: GameEnums.ResourceType
var last_resource_value: int

func before_each() -> void:
	display = ResourceDisplay.new()
	add_child(display)
	_reset_signals()
	_connect_signals()

func after_each() -> void:
	display.queue_free()

func _reset_signals() -> void:
	resource_updated_signal_emitted = false
	last_resource_type = GameEnums.ResourceType.NONE
	last_resource_value = 0

func _connect_signals() -> void:
	display.resource_updated.connect(_on_resource_updated)

func _on_resource_updated(resource_type: GameEnums.ResourceType, new_value: int) -> void:
	resource_updated_signal_emitted = true
	last_resource_type = resource_type
	last_resource_value = new_value

func test_initial_setup() -> void:
	assert_not_null(display)
	assert_not_null(display.resource_container)
	assert_true(display.get_resource_items().is_empty())

func test_resource_addition() -> void:
	var test_resources = {
		GameEnums.ResourceType.CREDITS: 1000,
		GameEnums.ResourceType.SUPPLIES: 50,
		GameEnums.ResourceType.TECH_PARTS: 25,
		GameEnums.ResourceType.REPUTATION: 10
	}
	
	for resource_type in test_resources:
		display.add_resource(resource_type, test_resources[resource_type])
		
		assert_true(resource_updated_signal_emitted)
		assert_eq(last_resource_type, resource_type)
		assert_eq(last_resource_value, test_resources[resource_type])
		assert_true(display.has_resource(resource_type))
		
		_reset_signals()

func test_resource_update() -> void:
	display.add_resource(GameEnums.ResourceType.CREDITS, 100)
	_reset_signals()
	
	var new_value = 200
	display.update_resource(GameEnums.ResourceType.CREDITS, new_value)
	
	assert_true(resource_updated_signal_emitted)
	assert_eq(last_resource_type, GameEnums.ResourceType.CREDITS)
	assert_eq(last_resource_value, new_value)
	assert_eq(display.get_resource_value(GameEnums.ResourceType.CREDITS), new_value)

func test_resource_removal() -> void:
	display.add_resource(GameEnums.ResourceType.CREDITS, 100)
	assert_true(display.has_resource(GameEnums.ResourceType.CREDITS))
	
	display.remove_resource(GameEnums.ResourceType.CREDITS)
	assert_false(display.has_resource(GameEnums.ResourceType.CREDITS))

func test_multiple_resources() -> void:
	var test_resources = {
		GameEnums.ResourceType.CREDITS: 1000,
		GameEnums.ResourceType.SUPPLIES: 50,
		GameEnums.ResourceType.TECH_PARTS: 25
	}
	
	for resource_type in test_resources:
		display.add_resource(resource_type, test_resources[resource_type])
	
	assert_eq(display.get_resource_items().size(), test_resources.size())
	
	for resource_type in test_resources:
		assert_true(display.has_resource(resource_type))
		assert_eq(display.get_resource_value(resource_type), test_resources[resource_type])

func test_resource_layout() -> void:
	display.add_resource(GameEnums.ResourceType.CREDITS, 100)
	var items = display.get_resource_items()
	
	assert_eq(items.size(), 1)
	var item = items[0]
	assert_true(item.size.x > 0)
	assert_true(item.size.y > 0)
	assert_true(item.custom_minimum_size.x > 0)
	assert_true(item.custom_minimum_size.y > 0)

func test_invalid_resource_type() -> void:
	var invalid_type = -1
	display.add_resource(invalid_type, 100)
	
	assert_false(resource_updated_signal_emitted)
	assert_false(display.has_resource(invalid_type))

func test_negative_values() -> void:
	display.add_resource(GameEnums.ResourceType.CREDITS, -50)
	
	assert_true(resource_updated_signal_emitted)
	assert_eq(last_resource_value, -50)
	assert_eq(display.get_resource_value(GameEnums.ResourceType.CREDITS), -50)

func test_resource_clear() -> void:
	display.add_resource(GameEnums.ResourceType.CREDITS, 100)
	display.add_resource(GameEnums.ResourceType.SUPPLIES, 50)
	
	display.clear_resources()
	
	assert_true(display.get_resource_items().is_empty())
	assert_false(display.has_resource(GameEnums.ResourceType.CREDITS))
	assert_false(display.has_resource(GameEnums.ResourceType.SUPPLIES))