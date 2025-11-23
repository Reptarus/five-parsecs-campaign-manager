extends GdUnitTestSuite
## Phase 2A: Backend Integration Tests - Part 1: Phase Transitions
## Tests CampaignPhaseManager phase state machine and transition logic
## gdUnit4 v6.0.1 compatible

# System under test - CampaignPhaseManager requires scene tree context
var PhaseManagerClass
var phase_manager: Node = null

# Helper for test data
var HelperClass
var helper

# Mock dependencies
var mock_game_state_manager: Node = null

func before():
	"""Suite-level setup - runs once before all tests"""
	PhaseManagerClass = load("res://src/core/campaign/CampaignPhaseManager.gd")
	HelperClass = load("res://tests/helpers/CampaignTurnTestHelper.gd")
	helper = HelperClass.new()

func before_test():
	"""Test-level setup - create fresh manager instance for each test"""
	# Create manager instance
	phase_manager = auto_free(PhaseManagerClass.new())

	# Add to scene tree for proper initialization
	add_child(phase_manager)

	# Wait for _ready() to complete
	await get_tree().process_frame

func after_test():
	"""Test-level cleanup - remove manager from scene tree"""
	if phase_manager and phase_manager.get_parent():
		remove_child(phase_manager)
	phase_manager = null

func after():
	"""Suite-level cleanup - runs once after all tests"""
	helper = null
	HelperClass = null
	PhaseManagerClass = null

# ============================================================================
# Valid Phase Transitions (4 tests)
# ============================================================================

func test_valid_transition_travel_to_world():
	"""TRAVEL → WORLD transition succeeds"""
	# Setup: Start in TRAVEL phase
	phase_manager.current_phase = GlobalEnums.FiveParsecsCampaignPhase.TRAVEL
	phase_manager.transition_in_progress = false

	# Execute: Transition to WORLD
	var result = phase_manager.start_phase(GlobalEnums.FiveParsecsCampaignPhase.WORLD)

	# Verify: Transition succeeded
	assert_that(result).is_true()
	assert_that(phase_manager.current_phase).is_equal(GlobalEnums.FiveParsecsCampaignPhase.WORLD)

func test_valid_transition_world_to_battle():
	"""WORLD → BATTLE transition succeeds"""
	# Setup: Start in WORLD phase
	phase_manager.current_phase = GlobalEnums.FiveParsecsCampaignPhase.WORLD
	phase_manager.transition_in_progress = false

	# Execute: Transition to BATTLE
	var result = phase_manager.start_phase(GlobalEnums.FiveParsecsCampaignPhase.BATTLE)

	# Verify: Transition succeeded
	assert_that(result).is_true()
	assert_that(phase_manager.current_phase).is_equal(GlobalEnums.FiveParsecsCampaignPhase.BATTLE)

func test_valid_transition_battle_to_post_battle():
	"""BATTLE → POST_BATTLE transition succeeds"""
	# Setup: Start in BATTLE phase
	phase_manager.current_phase = GlobalEnums.FiveParsecsCampaignPhase.BATTLE
	phase_manager.transition_in_progress = false

	# Execute: Transition to POST_BATTLE
	var result = phase_manager.start_phase(GlobalEnums.FiveParsecsCampaignPhase.POST_BATTLE)

	# Verify: Transition succeeded
	assert_that(result).is_true()
	assert_that(phase_manager.current_phase).is_equal(GlobalEnums.FiveParsecsCampaignPhase.POST_BATTLE)

func test_valid_transition_post_battle_to_travel():
	"""POST_BATTLE → TRAVEL transition succeeds (new turn)"""
	# Setup: Start in POST_BATTLE phase
	phase_manager.current_phase = GlobalEnums.FiveParsecsCampaignPhase.POST_BATTLE
	phase_manager.transition_in_progress = false
	var initial_turn = phase_manager.turn_number

	# Execute: Transition to TRAVEL (starts new turn)
	var result = phase_manager.start_phase(GlobalEnums.FiveParsecsCampaignPhase.TRAVEL)

	# Verify: Transition succeeded
	assert_that(result).is_true()
	assert_that(phase_manager.current_phase).is_equal(GlobalEnums.FiveParsecsCampaignPhase.TRAVEL)

# ============================================================================
# Invalid Phase Transitions (3 tests)
# ============================================================================

func test_invalid_transition_travel_to_battle():
	"""TRAVEL → BATTLE transition fails (must go through WORLD)"""
	# Setup: Start in TRAVEL phase
	phase_manager.current_phase = GlobalEnums.FiveParsecsCampaignPhase.TRAVEL
	phase_manager.transition_in_progress = false

	# Execute: Attempt invalid transition to BATTLE
	var result = phase_manager.start_phase(GlobalEnums.FiveParsecsCampaignPhase.BATTLE)

	# Verify: Transition blocked, still in TRAVEL
	assert_that(result).is_false()
	assert_that(phase_manager.current_phase).is_equal(GlobalEnums.FiveParsecsCampaignPhase.TRAVEL)

func test_invalid_transition_world_to_post_battle():
	"""WORLD → POST_BATTLE transition fails (must go through BATTLE)"""
	# Setup: Start in WORLD phase
	phase_manager.current_phase = GlobalEnums.FiveParsecsCampaignPhase.WORLD
	phase_manager.transition_in_progress = false

	# Execute: Attempt invalid transition to POST_BATTLE
	var result = phase_manager.start_phase(GlobalEnums.FiveParsecsCampaignPhase.POST_BATTLE)

	# Verify: Transition blocked, still in WORLD
	assert_that(result).is_false()
	assert_that(phase_manager.current_phase).is_equal(GlobalEnums.FiveParsecsCampaignPhase.WORLD)

func test_invalid_transition_battle_to_travel():
	"""BATTLE → TRAVEL transition fails (must go through POST_BATTLE)"""
	# Setup: Start in BATTLE phase
	phase_manager.current_phase = GlobalEnums.FiveParsecsCampaignPhase.BATTLE
	phase_manager.transition_in_progress = false

	# Execute: Attempt invalid transition to TRAVEL
	var result = phase_manager.start_phase(GlobalEnums.FiveParsecsCampaignPhase.TRAVEL)

	# Verify: Transition blocked, still in BATTLE
	assert_that(result).is_false()
	assert_that(phase_manager.current_phase).is_equal(GlobalEnums.FiveParsecsCampaignPhase.BATTLE)

# ============================================================================
# Race Condition Prevention (1 test)
# ============================================================================

func test_transition_blocked_when_in_progress():
	"""Transition blocked when transition_in_progress flag is set"""
	# Setup: Start in TRAVEL phase with transition in progress
	phase_manager.current_phase = GlobalEnums.FiveParsecsCampaignPhase.TRAVEL
	phase_manager.transition_in_progress = true

	# Execute: Attempt transition while flag is set
	var result = phase_manager.start_phase(GlobalEnums.FiveParsecsCampaignPhase.WORLD)

	# Verify: Transition blocked by flag
	assert_that(result).is_false()
	assert_that(phase_manager.current_phase).is_equal(GlobalEnums.FiveParsecsCampaignPhase.TRAVEL)
