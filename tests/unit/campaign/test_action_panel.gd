@tool
extends "res://tests/fixtures/game_test.gd"

const ActionPanel = preload("res://src/scenes/campaign/components/ActionPanel.gd")

var panel: ActionPanel
var action_selected_signal_emitted := false
var last_action: String

func before_each() -> void:
	await super.before_each()
	panel = ActionPanel.new()
	add_child_autofree(panel)
	watch_signals(panel)
	await stabilize_engine()
	_reset_signals()
	_connect_signals()

func after_each() -> void:
	await super.after_each()
	panel = null

func _reset_signals() -> void:
	action_selected_signal_emitted = false
	last_action = ""

func _connect_signals() -> void:
	panel.action_selected.connect(_on_action_selected)

func _on_action_selected(action: String) -> void:
	action_selected_signal_emitted = true
	last_action = action

func test_initial_setup() -> void:
	assert_not_null(panel, "Action panel should be initialized")
	assert_not_null(panel.action_container, "Action container should be initialized")
	assert_eq(panel.current_phase, "", "Initial phase should be empty")
	assert_true(panel.available_actions.is_empty(), "Available actions should be empty")

func test_phase_specific_actions() -> void:
	# Test actions for each phase
	var phases = ["upkeep", "world_step", "travel", "patrons", "battle", "post_battle", "management"]
	for phase in phases:
		panel.set_phase(phase)
		await stabilize_engine()
		
		var actions = panel._get_phase_actions(phase)
		assert_true(actions.size() > 0, "Phase %s should have actions" % phase)
		
		for action in actions:
			assert_true(action.name is String, "Action name should be a string")
			assert_true(action.name.length() > 0, "Action name should not be empty")

func test_action_button_creation() -> void:
	panel.set_phase("upkeep")
	await stabilize_engine()
	
	var actions = panel._get_phase_actions("upkeep")
	for action in actions:
		panel._add_action_button(action)
		await stabilize_engine()
		
		# Verify button was added to container
		var buttons = panel.action_container.get_children()
		assert_true(buttons.size() > 0, "Button should be added to container")
		var last_button = buttons[-1]
		assert_true(last_button.text.length() > 0, "Button should have text")

func test_action_selection() -> void:
	var test_action = "test_action"
	panel.action_selected.emit(test_action)
	
	var action_selected = await assert_async_signal(panel, "action_selected")
	assert_true(action_selected, "Action selected signal should be emitted")
	
	# Get signal data
	var signal_data = await wait_for_signal(panel, "action_selected")
	assert_eq(signal_data[0], test_action, "Selected action should match test action")

func test_action_button_state() -> void:
	panel.set_phase("upkeep")
	await stabilize_engine()
	
	var actions = panel._get_phase_actions("upkeep")
	for action in actions:
		panel._add_action_button(action)
		await stabilize_engine()
		
		var buttons = panel.action_container.get_children()
		var last_button = buttons[-1]
		assert_true(last_button.visible, "Button should be visible")
		assert_false(last_button.disabled, "Button should be enabled")

func test_action_button_visibility() -> void:
	panel.set_phase("upkeep")
	await stabilize_engine()
	
	var initial_actions = panel._get_phase_actions("upkeep")
	var initial_count = initial_actions.size()
	
	panel.set_phase("battle")
	await stabilize_engine()
	
	var new_actions = panel._get_phase_actions("battle")
	assert_ne(initial_count, new_actions.size(), "Different phases should have different action counts")

func test_action_validation() -> void:
	var invalid_action = "invalid_action"
	panel.action_selected.emit(invalid_action)
	
	var action_selected = await assert_async_signal(panel, "action_selected")
	assert_true(action_selected, "Action selected signal should be emitted")
	
	# Get signal data
	var signal_data = await wait_for_signal(panel, "action_selected")
	assert_eq(signal_data[0], invalid_action, "Invalid action should still emit signal")

func test_phase_transition(resource: Resource = null, args: Array = []) -> void:
	var initial_phase = panel.current_phase
	var initial_actions = panel._get_phase_actions(initial_phase) if initial_phase else []
	
	panel.set_phase("battle")
	await stabilize_engine()
	
	assert_ne(panel.current_phase, initial_phase, "Phase should change")
	assert_ne(panel._get_phase_actions("battle"), initial_actions, "Actions should change with phase")

func test_action_button_layout() -> void:
	panel.set_phase("management")
	await stabilize_engine()
	
	var actions = panel._get_phase_actions("management")
	for action in actions:
		panel._add_action_button(action)
		await stabilize_engine()
		
		var buttons = panel.action_container.get_children()
		var last_button = buttons[-1]
		assert_true(last_button.size.x > 0, "Button should have width")
		assert_true(last_button.size.y > 0, "Button should have height")
		assert_true(last_button.custom_minimum_size.x > 0, "Button should have minimum width")
		assert_true(last_button.custom_minimum_size.y > 0, "Button should have minimum height")