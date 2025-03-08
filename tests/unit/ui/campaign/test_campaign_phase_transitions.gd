## Campaign Phase Transitions Test Suite
## Tests the transitions between different campaign phases and their effects
@tool
extends "res://tests/fixtures/base/game_test.gd"
# Use explicit preloads instead of global class names

# Type-safe script references
const CampaignPhaseManager := preload("res://src/core/campaign/CampaignPhaseManager.gd")
const GameStateManager := preload("res://src/core/managers/GameStateManager.gd")

# Type-safe instance variables
var _phase_manager: Node = null
var _current_phase: int = GameEnums.FiveParcsecsCampaignPhase.NONE

# Test Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	
	# Initialize game state
	_game_state = GameStateManager.new()
	if not _game_state:
		push_error("Failed to create game state")
		return
	add_child_autofree(_game_state)
	track_test_node(_game_state)
	
	# Initialize phase manager
	_phase_manager = CampaignPhaseManager.new()
	if not _phase_manager:
		push_error("Failed to create phase manager")
		return
	TypeSafeMixin._call_node_method_bool(_phase_manager, "initialize", [_game_state])
	add_child_autofree(_phase_manager)
	track_test_node(_phase_manager)
	
	await stabilize_engine()

func after_each() -> void:
	_phase_manager = null
	_game_state = null
	_current_phase = GameEnums.FiveParcsecsCampaignPhase.NONE
	await super.after_each()

# Initial State Tests
func test_initial_phase() -> void:
	var phase: int = TypeSafeMixin._call_node_method_int(_phase_manager, "get_current_phase", [])
	assert_eq(phase, GameEnums.FiveParcsecsCampaignPhase.NONE, "Should start in NONE phase")

# Phase Transition Tests
func test_basic_phase_transition() -> void:
	watch_signals(_phase_manager)
	
	var success: bool = TypeSafeMixin._call_node_method_bool(_phase_manager, "transition_to", [GameEnums.FiveParcsecsCampaignPhase.UPKEEP])
	assert_true(success, "Should transition to UPKEEP phase")
	
	var current_phase: int = TypeSafeMixin._call_node_method_int(_phase_manager, "get_current_phase", [])
	assert_eq(current_phase, GameEnums.FiveParcsecsCampaignPhase.UPKEEP, "Current phase should be UPKEEP")
	verify_signal_emitted(_phase_manager, "phase_changed")

func test_invalid_phase_transition() -> void:
	watch_signals(_phase_manager)
	
	# Try to transition to an invalid phase
	var success: bool = TypeSafeMixin._call_node_method_bool(_phase_manager, "transition_to", [-1])
	assert_false(success, "Should not transition to invalid phase")
	
	var current_phase: int = TypeSafeMixin._call_node_method_int(_phase_manager, "get_current_phase", [])
	assert_eq(current_phase, GameEnums.FiveParcsecsCampaignPhase.NONE, "Phase should remain unchanged")
	verify_signal_not_emitted(_phase_manager, "phase_changed")

# Phase-Specific Tests
func test_upkeep_phase() -> void:
	watch_signals(_phase_manager)
	
	# Transition to UPKEEP phase
	TypeSafeMixin._call_node_method_bool(_phase_manager, "transition_to", [GameEnums.FiveParcsecsCampaignPhase.UPKEEP])
	
	# Test upkeep actions
	var upkeep_result: Dictionary = TypeSafeMixin._call_node_method_dict(_phase_manager, "process_upkeep", [])
	assert_true(upkeep_result.has("resources_updated"), "Should process resource updates")
	assert_true(upkeep_result.has("maintenance_costs"), "Should calculate maintenance costs")
	verify_signal_emitted(_phase_manager, "upkeep_completed")

func test_story_phase() -> void:
	watch_signals(_phase_manager)
	
	# Transition to STORY phase
	TypeSafeMixin._call_node_method_bool(_phase_manager, "transition_to", [GameEnums.FiveParcsecsCampaignPhase.STORY])
	
	# Test story event generation
	var story_event: Dictionary = TypeSafeMixin._call_node_method_dict(_phase_manager, "generate_story_event", [])
	assert_not_null(story_event, "Should generate story event")
	assert_true(story_event.has("type"), "Story event should have type")
	assert_true(story_event.has("description"), "Story event should have description")
	verify_signal_emitted(_phase_manager, "story_event_generated")

func test_battle_setup_phase() -> void:
	watch_signals(_phase_manager)
	
	# Transition to BATTLE_SETUP phase
	TypeSafeMixin._call_node_method_bool(_phase_manager, "transition_to", [GameEnums.FiveParcsecsCampaignPhase.BATTLE_SETUP])
	
	# Test battle initialization
	var battle_state: Dictionary = TypeSafeMixin._call_node_method_dict(_phase_manager, "initialize_battle", [])
	assert_not_null(battle_state, "Should initialize battle state")
	assert_true(battle_state.has("units"), "Battle should have units")
	assert_true(battle_state.has("terrain"), "Battle should have terrain")
	verify_signal_emitted(_phase_manager, "battle_initialized")

func test_battle_resolution_phase() -> void:
	watch_signals(_phase_manager)
	
	# Transition to BATTLE_RESOLUTION phase
	TypeSafeMixin._call_node_method_bool(_phase_manager, "transition_to", [GameEnums.FiveParcsecsCampaignPhase.BATTLE_RESOLUTION])
	
	# Test battle resolution
	var resolution: Dictionary = TypeSafeMixin._call_node_method_dict(_phase_manager, "resolve_battle", [])
	assert_not_null(resolution, "Should resolve battle")
	assert_true(resolution.has("outcome"), "Resolution should have outcome")
	assert_true(resolution.has("rewards"), "Resolution should have rewards")
	verify_signal_emitted(_phase_manager, "battle_resolved")

# Phase Sequence Tests
func test_full_phase_sequence() -> void:
	watch_signals(_phase_manager)
	
	var phases := [
		GameEnums.FiveParcsecsCampaignPhase.UPKEEP,
		GameEnums.FiveParcsecsCampaignPhase.STORY,
		GameEnums.FiveParcsecsCampaignPhase.BATTLE_SETUP,
		GameEnums.FiveParcsecsCampaignPhase.BATTLE_RESOLUTION
	]
	
	for phase in phases:
		var success: bool = TypeSafeMixin._call_node_method_bool(_phase_manager, "transition_to", [phase])
		assert_true(success, "Should transition to phase %d" % phase)
		
		var current_phase: int = TypeSafeMixin._call_node_method_int(_phase_manager, "get_current_phase", [])
		assert_eq(current_phase, phase, "Current phase should match target phase")
		verify_signal_emitted(_phase_manager, "phase_changed")

# Phase Validation Tests
func test_phase_prerequisites() -> void:
	watch_signals(_phase_manager)
	
	# Try to enter BATTLE_SETUP phase without going through STORY phase
	var success: bool = TypeSafeMixin._call_node_method_bool(_phase_manager, "transition_to", [GameEnums.FiveParcsecsCampaignPhase.BATTLE_SETUP])
	assert_false(success, "Should not enter BATTLE_SETUP without STORY phase")
	
	# Try to enter BATTLE_RESOLUTION phase without going through BATTLE_SETUP phase
	success = TypeSafeMixin._call_node_method_bool(_phase_manager, "transition_to", [GameEnums.FiveParcsecsCampaignPhase.BATTLE_RESOLUTION])
	assert_false(success, "Should not enter BATTLE_RESOLUTION without BATTLE_SETUP phase")

# Phase State Tests
func test_phase_state_persistence() -> void:
	watch_signals(_phase_manager)
	
	# Set up initial phase state
	TypeSafeMixin._call_node_method_bool(_phase_manager, "transition_to", [GameEnums.FiveParcsecsCampaignPhase.UPKEEP])
	TypeSafeMixin._call_node_method_bool(_phase_manager, "set_phase_data", [ {"resources": 100}])
	
	# Transition through phases
	TypeSafeMixin._call_node_method_bool(_phase_manager, "transition_to", [GameEnums.FiveParcsecsCampaignPhase.STORY])
	TypeSafeMixin._call_node_method_bool(_phase_manager, "transition_to", [GameEnums.FiveParcsecsCampaignPhase.UPKEEP])
	
	# Verify state persistence
	var phase_data: Dictionary = TypeSafeMixin._call_node_method_dict(_phase_manager, "get_phase_data", [])
	assert_eq(phase_data.get("resources"), 100, "Phase data should persist through transitions")

# Error Handling Tests
func test_error_handling() -> void:
	watch_signals(_phase_manager)
	
	# Test null phase data
	var success: bool = TypeSafeMixin._call_node_method_bool(_phase_manager, "set_phase_data", [null])
	assert_false(success, "Should handle null phase data gracefully")
	
	# Test invalid phase transition
	success = TypeSafeMixin._call_node_method_bool(_phase_manager, "transition_to", [999])
	assert_false(success, "Should handle invalid phase transition gracefully")
	
	# Test missing prerequisites
	success = TypeSafeMixin._call_node_method_bool(_phase_manager, "process_battle", [])
	assert_false(success, "Should handle missing battle prerequisites gracefully")