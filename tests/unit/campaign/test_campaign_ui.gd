@tool
extends "res://tests/fixtures/game_test.gd"

const CampaignUIScript: GDScript = preload("res://src/scenes/campaign/CampaignUI.gd")

var ui: Node = null

func before_each() -> void:
	await super.before_each()
	ui = CampaignUIScript.new()
	if not ui:
		push_error("Failed to create UI instance")
		return
	add_child_autofree(ui)
	watch_signals(ui)
	await stabilize_engine()

func after_each() -> void:
	await super.after_each()
	ui = null

func test_initial_setup() -> void:
	assert_not_null(ui, "UI should be initialized")
	assert_eq(_get_property_safe(ui, "_current_phase", -1), GameEnums.CampaignPhase.SETUP, "Initial phase should be SETUP")
	assert_not_null(_get_property_safe(ui, "_layout"), "Layout should be initialized")

func test_phase_change() -> void:
	var new_phase: int = GameEnums.CampaignPhase.UPKEEP
	_call_node_method(ui, "_on_phase_changed", [new_phase])
	
	var phase_changed: bool = await assert_async_signal(ui, "phase_changed")
	assert_true(phase_changed, "Phase changed signal should be emitted")
	
	# Get signal data
	var signal_data: Array = await wait_for_signal(ui, "phase_changed")
	assert_eq(signal_data[0], new_phase, "Signal should contain new phase")
	assert_eq(_get_property_safe(ui, "_current_phase", -1), new_phase, "Current phase should be updated")

func test_resource_update() -> void:
	var resource_type: int = GameEnums.ResourceType.CREDITS
	var new_value: int = 100
	_call_node_method(ui, "_on_resource_updated", [resource_type, new_value])
	
	var resource_updated: bool = await assert_async_signal(ui, "resource_updated")
	assert_true(resource_updated, "Resource updated signal should be emitted")
	
	# Get signal data
	var signal_data: Array = await wait_for_signal(ui, "resource_updated")
	assert_eq(signal_data[0], resource_type, "Signal should contain resource type")
	assert_eq(signal_data[1], new_value, "Signal should contain new value")

func test_event_logging() -> void:
	var test_event: Dictionary = {
		"id": "test_event",
		"title": "Test Event",
		"description": "Test event description",
		"category": "test"
	}
	
	_call_node_method(ui, "_on_event_occurred", [test_event])
	
	var event_occurred: bool = await assert_async_signal(ui, "event_occurred")
	assert_true(event_occurred, "Event occurred signal should be emitted")
	
	# Get signal data
	var signal_data: Array = await wait_for_signal(ui, "event_occurred")
	var event_data: Dictionary = signal_data[0] as Dictionary
	assert_eq(event_data.get("id", ""), test_event.id, "Event ID should match")
	assert_eq(event_data.get("title", ""), test_event.title, "Event title should match")
	assert_eq(event_data.get("description", ""), test_event.description, "Event description should match")
	assert_eq(event_data.get("category", ""), test_event.category, "Event category should match")

func test_phase_action_handling() -> void:
	# Test crew creation action
	_call_node_method(ui, "_handle_crew_creation")
	await stabilize_engine()
	assert_eq(get_tree().current_scene.scene_file_path, "res://src/scenes/character/CrewCreation.tscn", "Should navigate to crew creation")
	
	# Test campaign selection action
	_call_node_method(ui, "_handle_campaign_selection")
	await stabilize_engine()
	assert_eq(get_tree().current_scene.scene_file_path, "res://src/scenes/campaign/CampaignSelection.tscn", "Should navigate to campaign selection")
	
	# Test resource management action
	_call_node_method(ui, "_handle_resource_management")
	await stabilize_engine()
	assert_eq(get_tree().current_scene.scene_file_path, "res://src/scenes/resource/ResourceManagement.tscn", "Should navigate to resource management")

func test_ui_components_setup() -> void:
	_call_node_method(ui, "_setup_ui_components")
	await stabilize_engine()
	
	# Test resource panel setup
	var resource_labels: Dictionary = {
		"credits": "Credits: 0",
		"supplies": "Supplies: 0",
		"reputation": "Reputation: 0",
		"tech_parts": "Tech Parts: 0"
	}
	
	for label_name in resource_labels:
		var label: Node = _get_node_safe(ui.resource_panel, "%s_label" % label_name)
		assert_not_null(label, "%s label should exist" % label_name.capitalize())
		assert_eq(_get_property_safe(label, "text", ""), resource_labels[label_name], "%s should start at 0" % label_name.capitalize())
