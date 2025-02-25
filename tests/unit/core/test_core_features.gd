## Core Features Test Suite
## Tests the functionality of the core game state features including:
## - Game state transitions
## - Campaign phase management
## - Combat phase tracking
## - Verification status handling
@tool
extends "res://tests/fixtures/base/game_test.gd"

# Type-safe script references
const GameStateManager: GDScript = preload("res://src/core/managers/GameStateManager.gd")

# Type-safe constants
const TEST_TIMEOUT := 2.0

# Type-safe instance variables
var _test_features: Dictionary = {}
var _test_game_state: Node = null
var game_state_manager: Node = null

# Helper Methods
func _setup_test_features() -> void:
	_test_features = {
		"game_state": GameEnums.GameState.CAMPAIGN,
		"campaign_phase": GameEnums.CampaignPhase.STORY,
		"combat_phase": GameEnums.CombatPhase.INITIATIVE,
		"verification_status": GameEnums.VerificationStatus.PENDING
	}

func _apply_test_features() -> void:
	for feature_name: String in _test_features:
		TypeSafeMixin._safe_method_call_bool(game_state_manager, "set_state", [feature_name, _test_features[feature_name]])

# Test Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	
	# Initialize game state first
	_test_game_state = create_test_game_state()
	assert_valid_game_state(_test_game_state)
	
	# Initialize game state manager
	game_state_manager = GameStateManager.new()
	add_child_autofree(game_state_manager)
	track_test_node(game_state_manager)
	
	# Set up initial state
	game_state_manager.set_game_state(_test_game_state)
	game_state_manager.set_campaign_phase(GameEnums.FiveParcsecsCampaignPhase.NONE)
	
	await stabilize_engine()

func after_each() -> void:
	if is_instance_valid(_test_game_state):
		_test_game_state.queue_free()
	if is_instance_valid(game_state_manager):
		game_state_manager.queue_free()
	
	_test_game_state = null
	game_state_manager = null
	_test_features.clear()
	await super.after_each()

# Basic State Management Tests
func test_initial_state() -> void:
	assert_not_null(_game_state, "Game state should be initialized")
	var current_state: int = TypeSafeMixin._safe_method_call_int(_game_state, "get_state", [])
	assert_eq(current_state, GameEnums.GameState.SETUP, "Should start in SETUP state")

# Game State Tests
func test_game_state_transitions() -> void:
	watch_signals(_game_state)
	
	# Test game state transitions
	var states := [
		GameEnums.GameState.SETUP,
		GameEnums.GameState.CAMPAIGN,
		GameEnums.GameState.BATTLE,
		GameEnums.GameState.GAME_OVER
	]
	
	for state: int in states:
		TypeSafeMixin._safe_method_call_bool(_game_state, "set_state", [state])
		var current_state: int = TypeSafeMixin._safe_method_call_int(_game_state, "get_state", [])
		assert_eq(current_state, state, "Should transition to correct state")
		verify_signal_emitted(_game_state, "state_changed")

# Campaign Phase Tests
func test_campaign_phase_transitions() -> void:
	watch_signals(_game_state)
	
	# Set game state to campaign
	TypeSafeMixin._safe_method_call_bool(_game_state, "set_state", [GameEnums.GameState.CAMPAIGN])
	
	# Test campaign phase transitions
	var phases := [
		GameEnums.CampaignPhase.SETUP,
		GameEnums.CampaignPhase.UPKEEP,
		GameEnums.CampaignPhase.STORY,
		GameEnums.CampaignPhase.CAMPAIGN
	]
	
	for phase: int in phases:
		TypeSafeMixin._safe_method_call_bool(_game_state, "set_campaign_phase", [phase])
		var current_phase: int = TypeSafeMixin._safe_method_call_int(_game_state, "get_campaign_phase", [])
		assert_eq(current_phase, phase, "Should transition to correct campaign phase")
		verify_signal_emitted(_game_state, "campaign_phase_changed")

# Combat Phase Tests
func test_combat_phase_transitions() -> void:
	watch_signals(_game_state)
	
	# Set game state to battle
	TypeSafeMixin._safe_method_call_bool(_game_state, "set_state", [GameEnums.GameState.BATTLE])
	
	# Test combat phase transitions
	var phases := [
		GameEnums.CombatPhase.SETUP,
		GameEnums.CombatPhase.DEPLOYMENT,
		GameEnums.CombatPhase.INITIATIVE,
		GameEnums.CombatPhase.ACTION
	]
	
	for phase: int in phases:
		TypeSafeMixin._safe_method_call_bool(_game_state, "set_combat_phase", [phase])
		var current_phase: int = TypeSafeMixin._safe_method_call_int(_game_state, "get_combat_phase", [])
		assert_eq(current_phase, phase, "Should transition to correct combat phase")
		verify_signal_emitted(_game_state, "combat_phase_changed")

# State Validation Tests
func test_invalid_state_transitions() -> void:
	watch_signals(_game_state)
	
	# Test invalid game state
	var invalid_state := 9999
	TypeSafeMixin._safe_method_call_bool(_game_state, "set_state", [invalid_state])
	var current_state: int = TypeSafeMixin._safe_method_call_int(_game_state, "get_state", [])
	assert_ne(current_state, invalid_state, "Should not transition to invalid state")
	verify_signal_not_emitted(_game_state, "state_changed")
	
	# Test invalid campaign phase
	TypeSafeMixin._safe_method_call_bool(_game_state, "set_campaign_phase", [invalid_state])
	var current_phase: int = TypeSafeMixin._safe_method_call_int(_game_state, "get_campaign_phase", [])
	assert_ne(current_phase, invalid_state, "Should not transition to invalid campaign phase")
	verify_signal_not_emitted(_game_state, "campaign_phase_changed")
	
	# Test invalid combat phase
	TypeSafeMixin._safe_method_call_bool(_game_state, "set_combat_phase", [invalid_state])
	var current_combat_phase: int = TypeSafeMixin._safe_method_call_int(_game_state, "get_combat_phase", [])
	assert_ne(current_combat_phase, invalid_state, "Should not transition to invalid combat phase")
	verify_signal_not_emitted(_game_state, "combat_phase_changed")

# Performance Tests
func test_rapid_state_transitions() -> void:
	watch_signals(_game_state)
	var start_time := Time.get_ticks_msec()
	
	var states := [
		GameEnums.GameState.SETUP,
		GameEnums.GameState.CAMPAIGN,
		GameEnums.GameState.BATTLE,
		GameEnums.GameState.GAME_OVER
	]
	
	for i in range(100):
		var state: int = states[i % states.size()]
		TypeSafeMixin._safe_method_call_bool(_game_state, "set_state", [state])
		var current_state: int = TypeSafeMixin._safe_method_call_int(_game_state, "get_state", [])
		assert_eq(current_state, state, "Should handle rapid state changes correctly")
	
	var duration := Time.get_ticks_msec() - start_time
	assert_true(duration < 1000, "Should handle rapid state transitions efficiently")
	verify_signal_emit_count(_game_state, "state_changed", 100)

# State Dependency Tests
func test_state_dependencies() -> void:
	watch_signals(_game_state)
	
	# Test campaign phase only valid in campaign state
	TypeSafeMixin._safe_method_call_bool(_game_state, "set_state", [GameEnums.GameState.SETUP])
	TypeSafeMixin._safe_method_call_bool(_game_state, "set_campaign_phase", [GameEnums.CampaignPhase.STORY])
	var campaign_phase: int = TypeSafeMixin._safe_method_call_int(_game_state, "get_campaign_phase", [])
	assert_eq(campaign_phase, GameEnums.CampaignPhase.NONE, "Should not set campaign phase outside campaign state")
	
	# Test combat phase only valid in battle state
	TypeSafeMixin._safe_method_call_bool(_game_state, "set_state", [GameEnums.GameState.CAMPAIGN])
	TypeSafeMixin._safe_method_call_bool(_game_state, "set_combat_phase", [GameEnums.CombatPhase.ACTION])
	var combat_phase: int = TypeSafeMixin._safe_method_call_int(_game_state, "get_combat_phase", [])
	assert_eq(combat_phase, GameEnums.CombatPhase.NONE, "Should not set combat phase outside battle state")