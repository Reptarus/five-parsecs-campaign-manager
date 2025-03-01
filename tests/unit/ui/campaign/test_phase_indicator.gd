## Phase Indicator Test Suite
## Tests the functionality of the campaign phase indicator UI component
@tool
extends GameTest

# Type-safe script references
const PhaseIndicator := preload("res://src/scenes/campaign/components/PhaseIndicator.gd")

# Type-safe instance variables
var _phase_indicator: Node = null

# Test Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	
	# Initialize game state
	if not _game_state:
		push_error("Failed to create game state")
		return
	add_child_autofree(_game_state)
	track_test_node(_game_state)
	
	# Initialize phase indicator
	_phase_indicator = PhaseIndicator.new()
	if not _phase_indicator:
		push_error("Failed to create phase indicator")
		return
	TypeSafeMixin._call_node_method_bool(_phase_indicator, "initialize", [_game_state])
	add_child_autofree(_phase_indicator)
	track_test_node(_phase_indicator)
	
	await stabilize_engine()

func after_each() -> void:
	_phase_indicator = null
	await super.after_each()

# Initialization Tests
func test_initialization() -> void:
	assert_not_null(_phase_indicator, "Phase indicator should be initialized")
	
	var is_visible: bool = TypeSafeMixin._call_node_method_bool(_phase_indicator, "is_visible", [])
	assert_true(is_visible, "Indicator should be visible after initialization")
	
	var current_phase: int = TypeSafeMixin._call_node_method_int(_phase_indicator, "get_current_phase", [])
	assert_eq(current_phase, GameEnums.FiveParcsecsCampaignPhase.NONE, "Should start in NONE phase")

# Phase Display Tests
func test_phase_display() -> void:
	watch_signals(_phase_indicator)
	
	# Test phase text
	TypeSafeMixin._call_node_method_bool(_phase_indicator, "set_phase", [GameEnums.FiveParcsecsCampaignPhase.UPKEEP])
	var phase_text: String = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(_phase_indicator, "get_phase_text", []))
	assert_eq(phase_text, "Upkeep", "Phase text should match current phase")
	verify_signal_emitted(_phase_indicator, "phase_display_updated")

# Phase Icon Tests
func test_phase_icon() -> void:
	watch_signals(_phase_indicator)
	
	# Test phase icon update
	TypeSafeMixin._call_node_method_bool(_phase_indicator, "set_phase", [GameEnums.FiveParcsecsCampaignPhase.BATTLE_SETUP])
	var has_icon: bool = TypeSafeMixin._call_node_method_bool(_phase_indicator, "has_phase_icon", [])
	assert_true(has_icon, "Battle setup phase should have an icon")
	verify_signal_emitted(_phase_indicator, "icon_updated")

# Phase Progress Tests
func test_phase_progress() -> void:
	watch_signals(_phase_indicator)
	
	# Test progress update
	TypeSafeMixin._call_node_method_bool(_phase_indicator, "set_progress", [0.5])
	var progress: float = TypeSafeMixin._safe_cast_float(TypeSafeMixin._call_node_method(_phase_indicator, "get_progress", []))
	assert_eq(progress, 0.5, "Progress should match set value")
	verify_signal_emitted(_phase_indicator, "progress_updated")

# Phase State Tests
func test_phase_state() -> void:
	watch_signals(_phase_indicator)
	
	# Test active state
	TypeSafeMixin._call_node_method_bool(_phase_indicator, "set_active", [true])
	var is_active: bool = TypeSafeMixin._call_node_method_bool(_phase_indicator, "is_active", [])
	assert_true(is_active, "Indicator should be active")
	verify_signal_emitted(_phase_indicator, "state_changed")
	
	# Test inactive state
	TypeSafeMixin._call_node_method_bool(_phase_indicator, "set_active", [false])
	is_active = TypeSafeMixin._call_node_method_bool(_phase_indicator, "is_active", [])
	assert_false(is_active, "Indicator should be inactive")
	verify_signal_emitted(_phase_indicator, "state_changed")

# Phase Description Tests
func test_phase_description() -> void:
	watch_signals(_phase_indicator)
	
	# Test description update
	var description := "Test phase description"
	TypeSafeMixin._call_node_method_bool(_phase_indicator, "set_description", [description])
	var current_description: String = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(_phase_indicator, "get_description", []))
	assert_eq(current_description, description, "Description should match")
	verify_signal_emitted(_phase_indicator, "description_updated")

# Phase Transition Tests
func test_phase_transition() -> void:
	watch_signals(_phase_indicator)
	
	# Test transition animation
	TypeSafeMixin._call_node_method_bool(_phase_indicator, "start_transition", [GameEnums.FiveParcsecsCampaignPhase.STORY])
	verify_signal_emitted(_phase_indicator, "transition_started")
	
	await get_tree().create_timer(0.5).timeout
	
	var current_phase: int = TypeSafeMixin._call_node_method_int(_phase_indicator, "get_current_phase", [])
	assert_eq(current_phase, GameEnums.FiveParcsecsCampaignPhase.STORY, "Phase should be updated after transition")
	verify_signal_emitted(_phase_indicator, "transition_completed")

# Phase Validation Tests
func test_phase_validation() -> void:
	watch_signals(_phase_indicator)
	
	# Test invalid phase
	var success: bool = TypeSafeMixin._call_node_method_bool(_phase_indicator, "set_phase", [-1])
	assert_false(success, "Should not set invalid phase")
	verify_signal_not_emitted(_phase_indicator, "phase_display_updated")
	
	# Test invalid progress
	success = TypeSafeMixin._call_node_method_bool(_phase_indicator, "set_progress", [-0.5])
	assert_false(success, "Should not set invalid progress")
	verify_signal_not_emitted(_phase_indicator, "progress_updated")

# UI State Tests
func test_ui_state() -> void:
	watch_signals(_phase_indicator)
	
	# Test UI enable/disable
	TypeSafeMixin._call_node_method_bool(_phase_indicator, "set_ui_enabled", [false])
	var is_enabled: bool = TypeSafeMixin._call_node_method_bool(_phase_indicator, "is_ui_enabled", [])
	assert_false(is_enabled, "UI should be disabled")
	verify_signal_emitted(_phase_indicator, "ui_state_changed")
	
	# Test UI visibility
	TypeSafeMixin._call_node_method_bool(_phase_indicator, "set_ui_visible", [false])
	var is_visible: bool = TypeSafeMixin._call_node_method_bool(_phase_indicator, "is_visible", [])
	assert_false(is_visible, "UI should be hidden")
	verify_signal_emitted(_phase_indicator, "visibility_changed")

# Theme Tests
func test_theme_handling() -> void:
	watch_signals(_phase_indicator)
	
	# Test theme change
	var success: bool = TypeSafeMixin._call_node_method_bool(_phase_indicator, "set_theme", ["dark"])
	assert_true(success, "Should change theme")
	
	var current_theme: String = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(_phase_indicator, "get_current_theme", []))
	assert_eq(current_theme, "dark", "Current theme should match")
	verify_signal_emitted(_phase_indicator, "theme_changed")