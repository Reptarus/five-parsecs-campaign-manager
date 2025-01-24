extends "res://addons/gut/test.gd"

const ResourcePanel = preload("res://src/scenes/campaign/components/ResourcePanel.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

var panel: ResourcePanel
var resource_updated_signal_emitted := false
var last_resource_type: GameEnums.ResourceType
var last_resource_value: int

func before_each() -> void:
	panel = ResourcePanel.new()
	add_child(panel)
	_reset_signals()
	_connect_signals()

func after_each() -> void:
	panel.queue_free()

func _reset_signals() -> void:
	resource_updated_signal_emitted = false
	last_resource_type = GameEnums.ResourceType.NONE
	last_resource_value = 0

func _connect_signals() -> void:
	panel.resource_updated.connect(_on_resource_updated)

func _on_resource_updated(resource_type: GameEnums.ResourceType, new_value: int) -> void:
	resource_updated_signal_emitted = true
	last_resource_type = resource_type
	last_resource_value = new_value

func test_initial_setup() -> void:
	assert_not_null(panel)
	assert_not_null(panel.credits_label)
	assert_not_null(panel.supplies_label)
	assert_not_null(panel.tech_parts_label)
	assert_not_null(panel.reputation_label)

func test_resource_update() -> void:
	var test_resources = {
		GameEnums.ResourceType.CREDITS: 1000,
		GameEnums.ResourceType.SUPPLIES: 50,
		GameEnums.ResourceType.TECH_PARTS: 25,
		GameEnums.ResourceType.REPUTATION: 10
	}
	
	for resource_type in test_resources:
		panel.update_resource(resource_type, test_resources[resource_type])
		
		var label_text = panel._get_resource_label(resource_type).text
		assert_true(str(test_resources[resource_type]) in label_text)
		assert_true(resource_updated_signal_emitted)
		assert_eq(last_resource_type, resource_type)
		assert_eq(last_resource_value, test_resources[resource_type])
		
		_reset_signals()

func test_resource_label_formatting() -> void:
	panel.update_resource(GameEnums.ResourceType.CREDITS, 1234)
	var label_text = panel.credits_label.text
	
	assert_true(label_text.begins_with("Credits"))
	assert_true(label_text.ends_with("1234"))
	assert_true(":" in label_text)

func test_negative_resource_handling() -> void:
	panel.update_resource(GameEnums.ResourceType.SUPPLIES, -50)
	var label_text = panel.supplies_label.text
	
	assert_true("-50" in label_text)
	assert_true(resource_updated_signal_emitted)
	assert_eq(last_resource_value, -50)

func test_zero_resource_handling() -> void:
	panel.update_resource(GameEnums.ResourceType.TECH_PARTS, 0)
	var label_text = panel.tech_parts_label.text
	
	assert_true("0" in label_text)
	assert_true(resource_updated_signal_emitted)
	assert_eq(last_resource_value, 0)

func test_large_number_formatting() -> void:
	panel.update_resource(GameEnums.ResourceType.CREDITS, 1000000)
	var label_text = panel.credits_label.text
	
	assert_true("1000000" in label_text)
	assert_true(resource_updated_signal_emitted)
	assert_eq(last_resource_value, 1000000)

func test_invalid_resource_type_handling() -> void:
	panel.update_resource(GameEnums.ResourceType.NONE, 100)
	
	assert_false(resource_updated_signal_emitted)
	assert_eq(last_resource_value, 0)

func test_multiple_updates() -> void:
	var updates = [
		[GameEnums.ResourceType.CREDITS, 100],
		[GameEnums.ResourceType.SUPPLIES, 50],
		[GameEnums.ResourceType.TECH_PARTS, 25],
		[GameEnums.ResourceType.REPUTATION, 10]
	]
	
	for update in updates:
		panel.update_resource(update[0], update[1])
		_reset_signals()
	
	assert_true("100" in panel.credits_label.text)
	assert_true("50" in panel.supplies_label.text)
	assert_true("25" in panel.tech_parts_label.text)
	assert_true("10" in panel.reputation_label.text)