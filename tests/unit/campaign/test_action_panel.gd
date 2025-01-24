extends "res://addons/gut/test.gd"

const ActionPanel = preload("res://src/scenes/campaign/components/ActionPanel.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

var panel: ActionPanel
var action_selected_signal_emitted := false
var last_action: String

func before_each() -> void:
	panel = ActionPanel.new()
	add_child(panel)
	_reset_signals()
	_connect_signals()

func after_each() -> void:
	panel.queue_free()

func _reset_signals() -> void:
	action_selected_signal_emitted = false
	last_action = ""

func _connect_signals() -> void:
	panel.action_selected.connect(_on_action_selected)

func _on_action_selected(action: String) -> void:
	action_selected_signal_emitted = true
	last_action = action

func test_initial_setup() -> void:
	assert_not_null(panel)
	assert_not_null(panel.action_container)
	assert_eq(panel.current_phase, "")
	assert_true(panel.available_actions.is_empty())

func test_phase_specific_actions() -> void:
	# Test actions for each phase
	var phases = ["upkeep", "world_step", "travel", "patrons", "battle", "post_battle", "management"]
	for phase in phases:
		panel.set_phase(phase)
		var actions = panel._get_phase_actions(phase)
		
		assert_true(actions.size() > 0)
		for action in actions:
			assert_true(action.name is String)
			assert_true(action.name.length() > 0)

func test_action_button_creation() -> void:
	panel.set_phase("upkeep")
	var actions = panel._get_phase_actions("upkeep")
	
	for action in actions:
		panel._add_action_button(action)
		# Verify button was added to container
		var buttons = panel.action_container.get_children()
		assert_true(buttons.size() > 0)
		var last_button = buttons[-1]
		assert_true(last_button.text.length() > 0)

func test_action_selection() -> void:
	var test_action = "test_action"
	panel.action_selected.emit(test_action)
	
	assert_true(action_selected_signal_emitted)
	assert_eq(last_action, test_action)

func test_action_button_state() -> void:
	panel.set_phase("upkeep")
	var actions = panel._get_phase_actions("upkeep")
	
	for action in actions:
		panel._add_action_button(action)
		var buttons = panel.action_container.get_children()
		var last_button = buttons[-1]
		assert_true(last_button.visible)
		assert_true(last_button.disabled == false)

func test_action_button_visibility() -> void:
	panel.set_phase("upkeep")
	var initial_actions = panel._get_phase_actions("upkeep")
	var initial_count = initial_actions.size()
	
	panel.set_phase("battle")
	var new_actions = panel._get_phase_actions("battle")
	
	assert_ne(initial_count, new_actions.size())

func test_action_validation() -> void:
	var invalid_action = "invalid_action"
	panel.action_selected.emit(invalid_action)
	
	assert_true(action_selected_signal_emitted)
	assert_eq(last_action, invalid_action)

func test_phase_transition() -> void:
	var initial_phase = panel.current_phase
	var initial_actions = panel._get_phase_actions(initial_phase) if initial_phase else []
	
	panel.set_phase("battle")
	
	assert_ne(panel.current_phase, initial_phase)
	assert_ne(panel._get_phase_actions("battle"), initial_actions)

func test_action_button_layout() -> void:
	panel.set_phase("management")
	var actions = panel._get_phase_actions("management")
	
	for action in actions:
		panel._add_action_button(action)
		var buttons = panel.action_container.get_children()
		var last_button = buttons[-1]
		assert_true(last_button.size.x > 0)
		assert_true(last_button.size.y > 0)
		assert_true(last_button.custom_minimum_size.x > 0)
		assert_true(last_button.custom_minimum_size.y > 0)