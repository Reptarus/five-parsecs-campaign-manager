extends "res://addons/gut/test.gd"

const CampaignPhaseUI = preload("res://src/scenes/campaign/components/CampaignPhaseUI.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

var phase_ui: CampaignPhaseUI
var phase_changed_signal_emitted := false
var action_selected_signal_emitted := false
var last_phase: GameEnums.FiveParcsecsCampaignPhase
var last_action: String

func before_each() -> void:
	phase_ui = CampaignPhaseUI.new()
	add_child(phase_ui)
	_reset_signals()
	_connect_signals()

func after_each() -> void:
	phase_ui.queue_free()

func _reset_signals() -> void:
	phase_changed_signal_emitted = false
	action_selected_signal_emitted = false
	last_phase = GameEnums.FiveParcsecsCampaignPhase.SETUP
	last_action = ""

func _connect_signals() -> void:
	phase_ui.phase_changed.connect(_on_phase_changed)
	phase_ui.action_selected.connect(_on_action_selected)

func _on_phase_changed(new_phase: GameEnums.FiveParcsecsCampaignPhase) -> void:
	phase_changed_signal_emitted = true
	last_phase = new_phase

func _on_action_selected(action: String) -> void:
	action_selected_signal_emitted = true
	last_action = action

func test_initial_setup() -> void:
	assert_not_null(phase_ui)
	assert_not_null(phase_ui.phase_indicator)
	assert_not_null(phase_ui.action_panel)
	assert_eq(phase_ui.current_phase, GameEnums.FiveParcsecsCampaignPhase.SETUP)

func test_phase_change() -> void:
	var test_phase = GameEnums.FiveParcsecsCampaignPhase.UPKEEP
	phase_ui.set_phase(test_phase)
	
	assert_true(phase_changed_signal_emitted)
	assert_eq(last_phase, test_phase)
	assert_eq(phase_ui.current_phase, test_phase)

func test_action_selection() -> void:
	var test_action = "test_action"
	phase_ui._on_action_selected(test_action)
	
	assert_true(action_selected_signal_emitted)
	assert_eq(last_action, test_action)

func test_phase_specific_actions() -> void:
	# Test actions for each phase
	for phase in GameEnums.FiveParcsecsCampaignPhase.values():
		phase_ui.set_phase(phase)
		var available_actions = phase_ui.action_panel.get_available_actions()
		
		assert_true(available_actions.size() > 0)
		for action in available_actions:
			assert_true(action is String)
			assert_true(action.length() > 0)

func test_phase_transitions() -> void:
	var initial_phase = phase_ui.current_phase
	
	# Test transitioning through phases
	for i in range(GameEnums.FiveParcsecsCampaignPhase.size()):
		var next_phase = (initial_phase + i) % GameEnums.FiveParcsecsCampaignPhase.size()
		phase_ui.set_phase(next_phase)
		
		assert_true(phase_changed_signal_emitted)
		assert_eq(last_phase, next_phase)
		_reset_signals()

func test_invalid_phase_handling() -> void:
	var invalid_phase = -1
	phase_ui.set_phase(invalid_phase)
	
	assert_eq(phase_ui.current_phase, GameEnums.FiveParcsecsCampaignPhase.SETUP)

func test_ui_state_persistence() -> void:
	var test_phase = GameEnums.FiveParcsecsCampaignPhase.STORY
	phase_ui.set_phase(test_phase)
	
	# Test that UI state is maintained after phase change
	assert_eq(phase_ui.phase_indicator.current_phase, test_phase)
	assert_eq(phase_ui.action_panel.current_phase, test_phase)

func test_action_validation() -> void:
	var invalid_action = "invalid_action"
	phase_ui._on_action_selected(invalid_action)
	
	assert_true(action_selected_signal_emitted)
	assert_eq(last_action, invalid_action)
	# Add more specific validation when implemented 