## Campaign Phase UI Test Suite
## Tests the functionality of the campaign phase UI component
@tool
extends GameTest

# Type-safe script references
const CampaignPhaseUI := preload("res://src/scenes/campaign/components/CampaignPhaseUI.gd")

# Type-safe instance variables
var _phase_ui: Node = null

# Test Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	
	# Initialize game state
	_game_state = create_test_game_state()
	if not _game_state:
		push_error("Failed to create game state")
		return
	add_child_autofree(_game_state)
	track_test_node(_game_state)
	
	# Initialize phase UI
	_phase_ui = CampaignPhaseUI.new()
	if not _phase_ui:
		push_error("Failed to create phase UI")
		return
	TypeSafeMixin._safe_method_call_bool(_phase_ui, "initialize", [_game_state])
	add_child_autofree(_phase_ui)
	track_test_node(_phase_ui)
	
	await stabilize_engine()

func after_each() -> void:
	_phase_ui = null
	_game_state = null
	await super.after_each()

# UI Initialization Tests
func test_ui_initialization() -> void:
	assert_not_null(_phase_ui, "Phase UI should be initialized")
	
	var is_visible: bool = TypeSafeMixin._safe_method_call_bool(_phase_ui, "is_visible", [])
	assert_true(is_visible, "UI should be visible after initialization")
	
	var current_phase: int = TypeSafeMixin._safe_method_call_int(_phase_ui, "get_current_phase", [])
	assert_eq(current_phase, GameEnums.FiveParcsecsCampaignPhase.NONE, "Should start in NONE phase")

# Phase Display Tests
func test_phase_display() -> void:
	watch_signals(_phase_ui)
	
	# Test phase label update
	TypeSafeMixin._safe_method_call_bool(_phase_ui, "set_phase", [GameEnums.FiveParcsecsCampaignPhase.UPKEEP])
	var phase_text: String = TypeSafeMixin._safe_method_call_string(_phase_ui, "get_phase_text", [])
	assert_eq(phase_text, "Upkeep", "Phase text should match current phase")
	verify_signal_emitted(_phase_ui, "phase_display_updated")
	
	# Test phase description update
	var description: String = TypeSafeMixin._safe_method_call_string(_phase_ui, "get_phase_description", [])
	assert_true(description.length() > 0, "Phase description should not be empty")
	verify_signal_emitted(_phase_ui, "description_updated")

# Phase Button Tests
func test_phase_buttons() -> void:
	watch_signals(_phase_ui)
	
	# Test next phase button
	var next_enabled: bool = TypeSafeMixin._safe_method_call_bool(_phase_ui, "is_next_phase_enabled", [])
	assert_true(next_enabled, "Next phase button should be enabled")
	
	# Test previous phase button
	var prev_enabled: bool = TypeSafeMixin._safe_method_call_bool(_phase_ui, "is_prev_phase_enabled", [])
	assert_false(prev_enabled, "Previous phase button should be disabled in NONE phase")

# Phase Transition Tests
func test_phase_transitions() -> void:
	watch_signals(_phase_ui)
	
	# Test transition to UPKEEP
	TypeSafeMixin._safe_method_call_bool(_phase_ui, "transition_to", [GameEnums.FiveParcsecsCampaignPhase.UPKEEP])
	var current_phase: int = TypeSafeMixin._safe_method_call_int(_phase_ui, "get_current_phase", [])
	assert_eq(current_phase, GameEnums.FiveParcsecsCampaignPhase.UPKEEP, "Should transition to UPKEEP phase")
	verify_signal_emitted(_phase_ui, "phase_changed")
	
	# Test transition to STORY
	TypeSafeMixin._safe_method_call_bool(_phase_ui, "transition_to", [GameEnums.FiveParcsecsCampaignPhase.STORY])
	current_phase = TypeSafeMixin._safe_method_call_int(_phase_ui, "get_current_phase", [])
	assert_eq(current_phase, GameEnums.FiveParcsecsCampaignPhase.STORY, "Should transition to STORY phase")
	verify_signal_emitted(_phase_ui, "phase_changed")

# Phase Action Tests
func test_phase_actions() -> void:
	watch_signals(_phase_ui)
	
	# Test upkeep actions
	TypeSafeMixin._safe_method_call_bool(_phase_ui, "set_phase", [GameEnums.FiveParcsecsCampaignPhase.UPKEEP])
	var actions: Array = TypeSafeMixin._safe_method_call_array(_phase_ui, "get_available_actions", [])
	assert_true(actions.size() > 0, "Should have available actions in UPKEEP phase")
	
	# Test action execution
	var action_result: bool = TypeSafeMixin._safe_method_call_bool(_phase_ui, "execute_action", ["maintain_crew"])
	assert_true(action_result, "Should execute upkeep action successfully")
	verify_signal_emitted(_phase_ui, "action_completed")

# Phase Information Tests
func test_phase_information() -> void:
	watch_signals(_phase_ui)
	
	# Test phase info panel
	TypeSafeMixin._safe_method_call_bool(_phase_ui, "set_phase", [GameEnums.FiveParcsecsCampaignPhase.STORY])
	var info_visible: bool = TypeSafeMixin._safe_method_call_bool(_phase_ui, "is_info_panel_visible", [])
	assert_true(info_visible, "Info panel should be visible")
	
	# Test info content
	var info_text: String = TypeSafeMixin._safe_method_call_string(_phase_ui, "get_info_text", [])
	assert_true(info_text.length() > 0, "Info text should not be empty")
	verify_signal_emitted(_phase_ui, "info_updated")

# Phase Validation Tests
func test_phase_validation() -> void:
	watch_signals(_phase_ui)
	
	# Test invalid phase transition
	var success: bool = TypeSafeMixin._safe_method_call_bool(_phase_ui, "transition_to", [-1])
	assert_false(success, "Should not transition to invalid phase")
	verify_signal_not_emitted(_phase_ui, "phase_changed")
	
	# Test invalid action
	success = TypeSafeMixin._safe_method_call_bool(_phase_ui, "execute_action", ["invalid_action"])
	assert_false(success, "Should not execute invalid action")
	verify_signal_not_emitted(_phase_ui, "action_completed")

# UI State Tests
func test_ui_state() -> void:
	watch_signals(_phase_ui)
	
	# Test UI enable/disable
	TypeSafeMixin._safe_method_call_bool(_phase_ui, "set_ui_enabled", [false])
	var is_enabled: bool = TypeSafeMixin._safe_method_call_bool(_phase_ui, "is_ui_enabled", [])
	assert_false(is_enabled, "UI should be disabled")
	verify_signal_emitted(_phase_ui, "ui_state_changed")
	
	# Test UI visibility
	TypeSafeMixin._safe_method_call_bool(_phase_ui, "set_ui_visible", [false])
	var is_visible: bool = TypeSafeMixin._safe_method_call_bool(_phase_ui, "is_visible", [])
	assert_false(is_visible, "UI should be hidden")
	verify_signal_emitted(_phase_ui, "visibility_changed")

# Error Handling Tests
func test_error_handling() -> void:
	watch_signals(_phase_ui)
	
	# Test null phase data
	var success: bool = TypeSafeMixin._safe_method_call_bool(_phase_ui, "update_phase_data", [null])
	assert_false(success, "Should handle null phase data gracefully")
	verify_signal_not_emitted(_phase_ui, "phase_data_updated")
	
	# Test invalid action data
	success = TypeSafeMixin._safe_method_call_bool(_phase_ui, "execute_action", [null])
	assert_false(success, "Should handle invalid action data gracefully")
	verify_signal_not_emitted(_phase_ui, "action_completed")