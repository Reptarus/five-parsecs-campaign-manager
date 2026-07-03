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
	# Set deterministic seed for reproducible random numbers
	seed(12345)

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

func test_valid_transition_travel_to_pre_mission():
	"""TRAVEL → PRE_MISSION succeeds (updated 2026-07-02: the canonical
	sequence is UPKEEP→STORY→TRAVEL→PRE_MISSION; UPKEEP is only reachable
	from SETUP/RETIREMENT/NONE as the turn-entry phase)"""
	phase_manager.current_phase = GlobalEnums.FiveParsecsCampaignPhase.TRAVEL
	phase_manager.transition_in_progress = false

	var result = phase_manager.start_phase(GlobalEnums.FiveParsecsCampaignPhase.PRE_MISSION)

	assert_that(result).is_true()
	assert_that(phase_manager.current_phase).is_equal(GlobalEnums.FiveParsecsCampaignPhase.PRE_MISSION)

func test_valid_transition_world_to_battle():
	"""WORLD → BATTLE transition succeeds"""
	# Setup: Start in WORLD phase
	phase_manager.current_phase = GlobalEnums.FiveParsecsCampaignPhase.UPKEEP
	phase_manager.transition_in_progress = false

	# Execute: Transition to BATTLE
	var result = phase_manager.start_phase(GlobalEnums.FiveParsecsCampaignPhase.MISSION)

	# Verify: Transition succeeded
	assert_that(result).is_true()
	assert_that(phase_manager.current_phase).is_equal(GlobalEnums.FiveParsecsCampaignPhase.MISSION)

func test_valid_transition_battle_to_post_battle():
	"""BATTLE → POST_BATTLE transition succeeds"""
	# Setup: Start in BATTLE phase
	phase_manager.current_phase = GlobalEnums.FiveParsecsCampaignPhase.MISSION
	phase_manager.transition_in_progress = false

	# Execute: Transition to POST_BATTLE
	var result = phase_manager.start_phase(GlobalEnums.FiveParsecsCampaignPhase.POST_MISSION)

	# Verify: Transition succeeded
	assert_that(result).is_true()
	assert_that(phase_manager.current_phase).is_equal(GlobalEnums.FiveParsecsCampaignPhase.POST_MISSION)

func test_valid_transition_post_battle_to_advancement():
	"""POST_MISSION → ADVANCEMENT succeeds (updated 2026-07-02: the turn
	continues through the late phases; TRAVEL only follows STORY and new
	turns start at UPKEEP via start_new_turn)"""
	phase_manager.current_phase = GlobalEnums.FiveParsecsCampaignPhase.POST_MISSION
	phase_manager.transition_in_progress = false

	var result = phase_manager.start_phase(GlobalEnums.FiveParsecsCampaignPhase.ADVANCEMENT)

	assert_that(result).is_true()
	assert_that(phase_manager.current_phase).is_equal(GlobalEnums.FiveParsecsCampaignPhase.ADVANCEMENT)

# ============================================================================
# Invalid Phase Transitions (3 tests)
# ============================================================================

func test_invalid_transition_travel_to_battle_resolution():
	"""TRAVEL → BATTLE_RESOLUTION fails (updated 2026-07-02: TRAVEL →
	MISSION is now ALLOWED by design since the world-phase UI covers all
	world-phase states; battle RESOLUTION still requires BATTLE_SETUP)"""
	phase_manager.current_phase = GlobalEnums.FiveParsecsCampaignPhase.TRAVEL
	phase_manager.transition_in_progress = false

	var result = phase_manager.start_phase(GlobalEnums.FiveParsecsCampaignPhase.BATTLE_RESOLUTION)

	assert_that(result).is_false()
	assert_that(phase_manager.current_phase).is_equal(GlobalEnums.FiveParsecsCampaignPhase.TRAVEL)

func test_invalid_transition_world_to_post_battle():
	"""WORLD → POST_BATTLE transition fails (must go through BATTLE)"""
	# Setup: Start in WORLD phase
	phase_manager.current_phase = GlobalEnums.FiveParsecsCampaignPhase.UPKEEP
	phase_manager.transition_in_progress = false

	# Execute: Attempt invalid transition to POST_BATTLE
	var result = phase_manager.start_phase(GlobalEnums.FiveParsecsCampaignPhase.POST_MISSION)

	# Verify: Transition blocked, still in WORLD
	assert_that(result).is_false()
	assert_that(phase_manager.current_phase).is_equal(GlobalEnums.FiveParsecsCampaignPhase.UPKEEP)

func test_invalid_transition_battle_to_travel():
	"""BATTLE → TRAVEL transition fails (must go through POST_BATTLE)"""
	# Setup: Start in BATTLE phase
	phase_manager.current_phase = GlobalEnums.FiveParsecsCampaignPhase.MISSION
	phase_manager.transition_in_progress = false

	# Execute: Attempt invalid transition to TRAVEL
	var result = phase_manager.start_phase(GlobalEnums.FiveParsecsCampaignPhase.TRAVEL)

	# Verify: Transition blocked, still in BATTLE
	assert_that(result).is_false()
	assert_that(phase_manager.current_phase).is_equal(GlobalEnums.FiveParsecsCampaignPhase.MISSION)

# ============================================================================
# Race Condition Prevention (1 test)
# ============================================================================

func test_transition_blocked_when_in_progress():
	"""Transition blocked when transition_in_progress flag is set"""
	# Setup: Start in TRAVEL phase with transition in progress
	phase_manager.current_phase = GlobalEnums.FiveParsecsCampaignPhase.TRAVEL
	phase_manager.transition_in_progress = true

	# Execute: Attempt transition while flag is set
	var result = phase_manager.start_phase(GlobalEnums.FiveParsecsCampaignPhase.UPKEEP)

	# Verify: Transition blocked by flag
	assert_that(result).is_false()
	assert_that(phase_manager.current_phase).is_equal(GlobalEnums.FiveParsecsCampaignPhase.TRAVEL)
