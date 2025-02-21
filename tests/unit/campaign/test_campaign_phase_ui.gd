@tool
extends GameTest

const CampaignPhaseUI = preload("res://src/scenes/campaign/components/CampaignPhaseUI.gd")

var phase_ui: CampaignPhaseUI
var phase_changed_signal_emitted := false
var action_selected_signal_emitted := false
var last_phase: GameEnums.FiveParcsecsCampaignPhase
var last_action: String

## Safe Property Access Methods
func _get_ui_property(property: String, default_value = null) -> Variant:
	if not phase_ui:
		push_error("Trying to access property '%s' on null UI" % property)
		return default_value
	if not property in phase_ui:
		push_error("UI missing required property: %s" % property)
		return default_value
	return phase_ui.get(property)

func _set_ui_property(property: String, value: Variant) -> void:
	if not phase_ui:
		push_error("Trying to set property '%s' on null UI" % property)
		return
	if not property in phase_ui:
		push_error("UI missing required property: %s" % property)
		return
	phase_ui.set(property, value)

func before_each() -> void:
	await super.before_each()
	phase_ui = CampaignPhaseUI.new()
	add_child_autofree(phase_ui)
	track_test_node(phase_ui)
	_reset_signals()
	_connect_signals()

func after_each() -> void:
	phase_ui = null
	await super.after_each()

func _reset_signals() -> void:
	phase_changed_signal_emitted = false
	action_selected_signal_emitted = false
	last_phase = GameEnums.FiveParcsecsCampaignPhase.SETUP
	last_action = ""

func _connect_signals() -> void:
	if not phase_ui:
		return
		
	if phase_ui.has_signal("phase_changed"):
		phase_ui.connect("phase_changed", _on_phase_changed)
	if phase_ui.has_signal("action_selected"):
		phase_ui.connect("action_selected", _on_action_selected)

func _on_phase_changed(new_phase: GameEnums.FiveParcsecsCampaignPhase) -> void:
	phase_changed_signal_emitted = true
	last_phase = new_phase

func _on_action_selected(action: String) -> void:
	action_selected_signal_emitted = true
	last_action = action

func test_initial_setup() -> void:
	assert_not_null(phase_ui)
	assert_not_null(_get_ui_property("phase_indicator"), "Phase indicator should exist")
	assert_not_null(_get_ui_property("action_panel"), "Action panel should exist")
	assert_eq(_get_ui_property("current_phase", GameEnums.FiveParcsecsCampaignPhase.SETUP), GameEnums.FiveParcsecsCampaignPhase.SETUP, "Initial phase should be SETUP")

func test_phase_change() -> void:
	var test_phase = GameEnums.FiveParcsecsCampaignPhase.UPKEEP
	if "set_phase" in phase_ui:
		phase_ui.set_phase(test_phase)
	
	assert_true(phase_changed_signal_emitted)
	assert_eq(last_phase, test_phase)
	assert_eq(_get_ui_property("current_phase", GameEnums.FiveParcsecsCampaignPhase.SETUP), test_phase)

func test_action_selection() -> void:
	var test_action = "test_action"
	if "_on_action_selected" in phase_ui:
		phase_ui._on_action_selected(test_action)
	
	assert_true(action_selected_signal_emitted)
	assert_eq(last_action, test_action)

func test_phase_specific_actions() -> void:
	# Test actions for each phase
	for phase in GameEnums.FiveParcsecsCampaignPhase.values():
		if "set_phase" in phase_ui:
			phase_ui.set_phase(phase)
		var action_panel = _get_ui_property("action_panel")
		assert_not_null(action_panel, "Action panel should exist")
		
		if action_panel and "get_available_actions" in action_panel:
			var available_actions = action_panel.get_available_actions()
			assert_true(available_actions.size() > 0)
			for action in available_actions:
				assert_true(action is String)
				assert_true(action.length() > 0)

func test_phase_transitions() -> void:
	var initial_phase = _get_ui_property("current_phase", GameEnums.FiveParcsecsCampaignPhase.SETUP)
	
	# Test transitioning through phases
	for i in range(GameEnums.FiveParcsecsCampaignPhase.size()):
		var next_phase = (initial_phase + i) % GameEnums.FiveParcsecsCampaignPhase.size()
		if "set_phase" in phase_ui:
			phase_ui.set_phase(next_phase)
		
		assert_true(phase_changed_signal_emitted)
		assert_eq(last_phase, next_phase)
		_reset_signals()

func test_invalid_phase_handling() -> void:
	var invalid_phase = -1
	if "set_phase" in phase_ui:
		phase_ui.set_phase(invalid_phase)
	
	# Should default to SETUP phase
	assert_eq(_get_ui_property("current_phase", GameEnums.FiveParcsecsCampaignPhase.SETUP), GameEnums.FiveParcsecsCampaignPhase.SETUP)

func test_ui_state_persistence() -> void:
	var test_phase = GameEnums.FiveParcsecsCampaignPhase.STORY
	phase_ui.set_phase(test_phase)
	
	# Test that UI state is maintained after phase change
	var phase_indicator = _get_ui_property("phase_indicator")
	var action_panel = _get_ui_property("action_panel")
	
	assert_not_null(phase_indicator, "Phase indicator should exist")
	assert_not_null(action_panel, "Action panel should exist")
	assert_eq(_get_ui_property("current_phase", GameEnums.FiveParcsecsCampaignPhase.SETUP), test_phase)
	assert_eq(_get_ui_property("current_phase", GameEnums.FiveParcsecsCampaignPhase.SETUP), test_phase)

func test_action_validation() -> void:
	var invalid_action = "invalid_action"
	if "_on_action_selected" in phase_ui:
		phase_ui._on_action_selected(invalid_action)
	
	assert_true(action_selected_signal_emitted)
	assert_eq(last_action, invalid_action)