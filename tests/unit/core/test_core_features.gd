## Test class for core feature management functionality
##
## Tests the enabling, disabling, and toggling of core game features
## through metadata management and game-specific feature flags.
## Includes performance testing and error boundary verification.
@tool
extends "res://tests/fixtures/base_test.gd"

const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")

# Type definitions
var core_features: Node
var _test_features: Dictionary = {}

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
		core_features.set_meta(feature_name, _test_features[feature_name])

# Setup and Teardown
func before_each() -> void:
	await super.before_each()
	core_features = Node.new()
	add_child(core_features)
	track_test_node(core_features)
	await get_tree().process_frame

func after_each() -> void:
	await super.after_each()
	core_features = null
	_test_features.clear()

# Basic Feature Management Tests
func test_initial_state() -> void:
	assert_not_null(core_features, "Core features should be initialized")
	assert_false(core_features.has_meta("test_feature"), "Should not have any features by default")

func test_enable_feature() -> void:
	watch_signals(core_features)
	
	core_features.set_meta("test_feature", true)
	assert_true(core_features.get_meta("test_feature"), "Feature should be enabled")

func test_disable_feature() -> void:
	watch_signals(core_features)
	
	core_features.set_meta("test_feature", true)
	core_features.set_meta("test_feature", false)
	assert_false(core_features.get_meta("test_feature"), "Feature should be disabled")

# Game State Management Tests
func test_game_state_features() -> void:
	watch_signals(core_features)
	
	# Test game state transitions
	var states = [
		GameEnums.GameState.SETUP,
		GameEnums.GameState.CAMPAIGN,
		GameEnums.GameState.BATTLE,
		GameEnums.GameState.GAME_OVER
	]
	
	for state in states:
		core_features.set_meta("game_state", state)
		assert_eq(core_features.get_meta("game_state"), state, "Should track game state correctly")

func test_campaign_phase_features() -> void:
	watch_signals(core_features)
	
	# Test campaign phase tracking
	var phases = [
		GameEnums.CampaignPhase.SETUP,
		GameEnums.CampaignPhase.UPKEEP,
		GameEnums.CampaignPhase.STORY,
		GameEnums.CampaignPhase.CAMPAIGN
	]
	
	for phase in phases:
		core_features.set_meta("campaign_phase", phase)
		assert_eq(core_features.get_meta("campaign_phase"), phase, "Should track campaign phase correctly")

# Combat System Tests
func test_combat_features() -> void:
	watch_signals(core_features)
	
	# Test combat phase tracking
	var combat_phases = [
		GameEnums.CombatPhase.SETUP,
		GameEnums.CombatPhase.DEPLOYMENT,
		GameEnums.CombatPhase.INITIATIVE,
		GameEnums.CombatPhase.ACTION
	]
	
	for phase in combat_phases:
		core_features.set_meta("combat_phase", phase)
		assert_eq(core_features.get_meta("combat_phase"), phase, "Should track combat phase correctly")

# Verification System Tests
func test_verification_features() -> void:
	watch_signals(core_features)
	
	# Test verification status tracking
	var statuses = [
		GameEnums.VerificationStatus.PENDING,
		GameEnums.VerificationStatus.VERIFIED,
		GameEnums.VerificationStatus.REJECTED
	]
	
	for status in statuses:
		core_features.set_meta("verification_status", status)
		assert_eq(core_features.get_meta("verification_status"), status, "Should track verification status correctly")

# Error Handling and Boundary Tests
func test_remove_nonexistent_feature() -> void:
	watch_signals(core_features)
	
	core_features.remove_meta("nonexistent_feature")
	assert_false(core_features.has_meta("nonexistent_feature"), "Should handle removing nonexistent features gracefully")

func test_invalid_feature_value() -> void:
	watch_signals(core_features)
	
	core_features.set_meta("test_feature", null)
	assert_false(core_features.get_meta("test_feature", false), "Should handle invalid feature values gracefully")

# Performance Tests
func test_performance_bulk_operations() -> void:
	watch_signals(core_features)
	
	var start_time: float = Time.get_ticks_msec()
	for i in range(1000):
		_setup_test_features()
		_apply_test_features()
	var end_time: float = Time.get_ticks_msec()
	
	assert_true(end_time - start_time < 1000.0, "Bulk operations should complete within reasonable time")

# Signal Verification Tests
func test_feature_change_signals() -> void:
	watch_signals(core_features)
	var signal_count: int = 0
	
	core_features.connect("meta_changed", func(_meta: String): signal_count += 1)
	
	_setup_test_features()
	_apply_test_features()
	
	assert_eq(signal_count, _test_features.size(), "Should emit correct number of signals")

# Error Boundary Tests
func test_error_boundaries() -> void:
	watch_signals(core_features)
	
	# Test invalid enum values
	var invalid_state: int = 9999
	core_features.set_meta("game_state", invalid_state)
	assert_ne(core_features.get_meta("game_state", GameEnums.GameState.SETUP),
			 invalid_state,
			 "Should handle invalid enum values gracefully")

# Boundary Tests
func test_multiple_features() -> void:
	watch_signals(core_features)
	
	# Test managing multiple game-specific features
	var features = {
		"game_state": GameEnums.GameState.CAMPAIGN,
		"campaign_phase": GameEnums.CampaignPhase.STORY,
		"combat_phase": GameEnums.CombatPhase.INITIATIVE,
		"verification_status": GameEnums.VerificationStatus.PENDING
	}
	
	for feature_name in features:
		core_features.set_meta(feature_name, features[feature_name])
	
	for feature_name in features:
		assert_eq(core_features.get_meta(feature_name), features[feature_name], "Should handle multiple game features correctly")

func test_feature_transitions() -> void:
	watch_signals(core_features)
	
	# Test game state transitions with validation
	core_features.set_meta("game_state", GameEnums.GameState.SETUP)
	assert_eq(core_features.get_meta("game_state"), GameEnums.GameState.SETUP, "Should start in SETUP state")
	
	core_features.set_meta("game_state", GameEnums.GameState.CAMPAIGN)
	assert_eq(core_features.get_meta("game_state"), GameEnums.GameState.CAMPAIGN, "Should transition to CAMPAIGN state")
	
	core_features.set_meta("campaign_phase", GameEnums.CampaignPhase.SETUP)
	assert_eq(core_features.get_meta("campaign_phase"), GameEnums.CampaignPhase.SETUP, "Should track campaign phase in campaign state")

func test_rapid_state_changes() -> void:
	watch_signals(core_features)
	
	# Test rapid state transitions
	var states = [
		GameEnums.GameState.SETUP,
		GameEnums.GameState.CAMPAIGN,
		GameEnums.GameState.BATTLE,
		GameEnums.GameState.GAME_OVER
	]
	
	for i in range(100):
		var state = states[i % states.size()]
		core_features.set_meta("game_state", state)
		assert_eq(core_features.get_meta("game_state"), state, "Should handle rapid state changes correctly")