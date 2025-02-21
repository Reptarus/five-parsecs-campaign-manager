@tool
extends GameTest

const ResourcePanel = preload("res://src/scenes/campaign/components/ResourcePanel.gd")

var panel: Node = null
var resource_updated_signal_emitted: bool = false
var last_resource_type: GameEnums.ResourceType
var last_resource_value: int

func before_each() -> void:
	panel = ResourcePanel.new()
	if not panel:
		push_error("Failed to create resource panel")
		return
		
	add_child(panel)
	watch_signals(panel)
	
	_reset_signals()
	_connect_signals()
	
	await get_tree().process_frame

func after_each() -> void:
	if is_instance_valid(panel):
		panel.queue_free()
	panel = null

func _reset_signals() -> void:
	resource_updated_signal_emitted = false
	last_resource_type = GameEnums.ResourceType.NONE
	last_resource_value = 0

func _connect_signals() -> void:
	if not panel:
		push_error("Cannot connect signals: panel is null")
		return
		
	if panel.has_signal("resource_updated"):
		var err := panel.connect("resource_updated", _on_resource_updated)
		if err != OK:
			push_error("Failed to connect resource_updated signal")

func _on_resource_updated(resource_type: GameEnums.ResourceType, new_value: int) -> void:
	resource_updated_signal_emitted = true
	last_resource_type = resource_type
	last_resource_value = new_value

func test_initial_setup() -> void:
	assert_not_null(panel, "Resource panel should be initialized")
	assert_not_null(TypeSafeMixin._safe_cast_to_node(panel.credits_label, "Label"), "Credits label should exist")
	assert_not_null(TypeSafeMixin._safe_cast_to_node(panel.supplies_label, "Label"), "Supplies label should exist")
	assert_not_null(TypeSafeMixin._safe_cast_to_node(panel.tech_parts_label, "Label"), "Tech parts label should exist")
	assert_not_null(TypeSafeMixin._safe_cast_to_node(panel.reputation_label, "Label"), "Reputation label should exist")

func test_resource_update() -> void:
	var test_resources: Dictionary = {
		GameEnums.ResourceType.CREDITS: 1000,
		GameEnums.ResourceType.SUPPLIES: 50,
		GameEnums.ResourceType.TECH_PARTS: 25,
		GameEnums.ResourceType.REPUTATION: 10
	}
	
	for resource_type in test_resources:
		TypeSafeMixin._safe_method_call_bool(panel, "update_resource", [resource_type, test_resources[resource_type]])
		
		var label: Label = TypeSafeMixin._safe_cast_to_node(panel._get_resource_label(resource_type), "Label")
		var label_text: String = TypeSafeMixin._safe_method_call_string(label, "get_text", [], "")
		assert_true(str(test_resources[resource_type]) in label_text)
		assert_true(resource_updated_signal_emitted)
		assert_eq(last_resource_type, resource_type)
		assert_eq(last_resource_value, test_resources[resource_type])
		
		_reset_signals()

func test_resource_label_formatting() -> void:
	TypeSafeMixin._safe_method_call_bool(panel, "update_resource", [GameEnums.ResourceType.CREDITS, 1234])
	var label_text: String = TypeSafeMixin._safe_method_call_string(panel.credits_label, "get_text", [], "")
	
	assert_true(label_text.begins_with("Credits"))
	assert_true(label_text.ends_with("1234"))
	assert_true(":" in label_text)

func test_negative_resource_handling() -> void:
	TypeSafeMixin._safe_method_call_bool(panel, "update_resource", [GameEnums.ResourceType.SUPPLIES, -50])
	var label_text: String = TypeSafeMixin._safe_method_call_string(panel.supplies_label, "get_text", [], "")
	
	assert_true("-50" in label_text)
	assert_true(resource_updated_signal_emitted)
	assert_eq(last_resource_value, -50)

func test_zero_resource_handling() -> void:
	TypeSafeMixin._safe_method_call_bool(panel, "update_resource", [GameEnums.ResourceType.TECH_PARTS, 0])
	var label_text: String = TypeSafeMixin._safe_method_call_string(panel.tech_parts_label, "get_text", [], "")
	
	assert_true("0" in label_text)
	assert_true(resource_updated_signal_emitted)
	assert_eq(last_resource_value, 0)

func test_large_number_formatting() -> void:
	TypeSafeMixin._safe_method_call_bool(panel, "update_resource", [GameEnums.ResourceType.CREDITS, 1000000])
	var label_text: String = TypeSafeMixin._safe_method_call_string(panel.credits_label, "get_text", [], "")
	
	assert_true("1000000" in label_text)
	assert_true(resource_updated_signal_emitted)
	assert_eq(last_resource_value, 1000000)

func test_invalid_resource_type_handling() -> void:
	TypeSafeMixin._safe_method_call_bool(panel, "update_resource", [GameEnums.ResourceType.NONE, 100])
	
	assert_false(resource_updated_signal_emitted)
	assert_eq(last_resource_value, 0)

func test_multiple_updates() -> void:
	var updates: Array = [
		[GameEnums.ResourceType.CREDITS, 100],
		[GameEnums.ResourceType.SUPPLIES, 50],
		[GameEnums.ResourceType.TECH_PARTS, 25],
		[GameEnums.ResourceType.REPUTATION, 10]
	]
	
	for update in updates:
		TypeSafeMixin._safe_method_call_bool(panel, "update_resource", [update[0], update[1]])
		_reset_signals()
	
	assert_true("100" in TypeSafeMixin._safe_method_call_string(panel.credits_label, "get_text", [], ""))
	assert_true("50" in TypeSafeMixin._safe_method_call_string(panel.supplies_label, "get_text", [], ""))
	assert_true("25" in TypeSafeMixin._safe_method_call_string(panel.tech_parts_label, "get_text", [], ""))
	assert_true("10" in TypeSafeMixin._safe_method_call_string(panel.reputation_label, "get_text", [], ""))
