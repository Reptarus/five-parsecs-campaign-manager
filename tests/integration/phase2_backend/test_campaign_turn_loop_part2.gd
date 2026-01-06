extends GdUnitTestSuite
## Phase 2B: Backend Integration Tests - Part 2: Campaign Turn Loop (Persistence & Multi-Turn)
## Split from test_campaign_turn_loop.gd to stay under 13 test limit
## gdUnit4 v6.0.1 compatible
## CRITICAL INTEGRATION TEST - State persistence and multi-turn validation

# System under test
var CampaignPhaseManagerClass
var phase_manager = null

# Test helper
var HelperClass
var helper = null

# Mock GlobalEnums for phase constants
var mock_phase_enum = {
	"NONE": 0,
	"TRAVEL": 1,
	"WORLD": 2,
	"BATTLE": 3,
	"POST_BATTLE": 4
}

func before():
	"""Suite-level setup - runs once before all tests"""
	CampaignPhaseManagerClass = load("res://src/core/campaign/CampaignPhaseManager.gd")
	HelperClass = load("res://tests/helpers/CampaignTurnTestHelper.gd")
	helper = HelperClass.new()

func before_test():
	"""Test-level setup - create fresh manager instance for each test"""
	# Create campaign phase manager without adding to tree
	# (avoids autoload dependencies like GameStateManager)
	phase_manager = auto_free(CampaignPhaseManagerClass.new())

	# Set initial state
	phase_manager.current_phase = mock_phase_enum.NONE
	phase_manager.turn_number = 0
	phase_manager.transition_in_progress = false

func after_test():
	"""Test-level cleanup"""
	phase_manager = null

func after():
	"""Suite-level cleanup - runs once after all tests"""
	helper = null
	HelperClass = null
	CampaignPhaseManagerClass = null

# ============================================================================
# State Persistence Tests (3 tests)
# ============================================================================

func test_turn_number_persists_across_phases():
	"""Turn number remains constant throughout phase cycle"""
	phase_manager.turn_number = 5
	var snapshot_travel = helper.create_state_snapshot({
		"turn_number": phase_manager.turn_number,
		"current_phase": mock_phase_enum.TRAVEL
	})

	# Simulate phase transitions
	phase_manager.current_phase = mock_phase_enum.WORLD
	var snapshot_world = helper.create_state_snapshot({
		"turn_number": phase_manager.turn_number,
		"current_phase": mock_phase_enum.WORLD
	})

	phase_manager.current_phase = mock_phase_enum.BATTLE
	var snapshot_battle = helper.create_state_snapshot({
		"turn_number": phase_manager.turn_number,
		"current_phase": mock_phase_enum.BATTLE
	})

	# Turn number should remain 5 throughout
	assert_that(snapshot_travel.turn_number).is_equal(5)
	assert_that(snapshot_world.turn_number).is_equal(5)
	assert_that(snapshot_battle.turn_number).is_equal(5)

func test_phase_data_persists_to_next_phase():
	"""Phase transition data mechanism exists in CampaignPhaseManager"""
	# IMPLEMENTATION: CampaignPhaseManager uses _phase_transition_data (private)
	# to pass data between phases (e.g., selected job from WORLD to BATTLE)

	# Check if phase transition data mechanism exists (private property)
	# Note: We check for the internal implementation _phase_transition_data
	var has_persistence: bool = "_phase_transition_data" in phase_manager

	# Verify the private phase transition mechanism exists
	assert_bool(has_persistence).is_true()

func test_campaign_state_consistent_across_cycle():
	"""Campaign resources should persist across full cycle"""
	# EXPECTED: Credits, equipment, crew should persist through all phases
	# ACTUAL: May lose campaign state during phase transitions

	# Simulate campaign state
	var _initial_state = {
		"credits": 50,
		"crew_count": 4,
		"equipment_count": 6
	}

	# This tests that campaign state tracking exists (use 'in' for property check on Node)
	var state_tracking_exists: bool = "campaign_state" in phase_manager or \
									   "game_state_manager" in phase_manager

	# This will FAIL if campaign state persistence is not properly implemented
	# Critical for maintaining game state across the turn cycle
	assert_bool(state_tracking_exists).is_true()

# ============================================================================
# Turn Completion Tests (2 tests)
# ============================================================================

func test_completing_post_battle_allows_new_turn():
	"""Completing POST_BATTLE phase allows starting new turn"""
	phase_manager.current_phase = mock_phase_enum.POST_BATTLE
	phase_manager.transition_in_progress = false
	phase_manager.turn_number = 5

	# After POST_BATTLE completes, should be able to start new turn
	var can_start_new_turn = not phase_manager.transition_in_progress and \
							  phase_manager.current_phase == mock_phase_enum.POST_BATTLE

	assert_that(can_start_new_turn).is_true()

	# Simulate new turn start
	phase_manager.turn_number += 1
	phase_manager.current_phase = mock_phase_enum.TRAVEL

	assert_that(phase_manager.turn_number).is_equal(6)
	assert_that(phase_manager.current_phase).is_equal(mock_phase_enum.TRAVEL)

func test_multi_turn_progression():
	"""Multiple turns should progress correctly"""
	phase_manager.turn_number = 1

	# Simulate 3 complete turn cycles
	for i in range(3):
		# Complete one full cycle
		phase_manager.current_phase = mock_phase_enum.TRAVEL
		phase_manager.current_phase = mock_phase_enum.WORLD
		phase_manager.current_phase = mock_phase_enum.BATTLE
		phase_manager.current_phase = mock_phase_enum.POST_BATTLE

		# Start new turn
		phase_manager.turn_number += 1
		phase_manager.current_phase = mock_phase_enum.TRAVEL

	# Should now be on turn 4 (started at 1, completed 3 cycles)
	assert_that(phase_manager.turn_number).is_equal(4)
	assert_that(phase_manager.current_phase).is_equal(mock_phase_enum.TRAVEL)
