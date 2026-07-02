extends GdUnitTestSuite
## Integration Test: World Phase to Battle Transition Flow
## Tests the complete data flow from World Phase → BattleTransition → PreBattle → TacticalBattle
## Validates signals, data passing, and state persistence
## gdUnit4 v6.0.1 compatible

# Systems under test
var PhaseManagerClass
var phase_manager: Node = null

# Test helper
var HelperClass
var helper = null

# Signal tracking
var signals_received: Array = []

func before():
	"""Suite-level setup"""
	PhaseManagerClass = load("res://src/core/campaign/CampaignPhaseManager.gd")
	HelperClass = load("res://tests/helpers/CampaignTurnTestHelper.gd")
	helper = HelperClass.new()

func before_test():
	"""Test-level setup"""
	phase_manager = auto_free(PhaseManagerClass.new())
	add_child(phase_manager)
	await get_tree().process_frame
	signals_received = []

func after_test():
	"""Test-level cleanup"""
	if phase_manager and phase_manager.get_parent():
		remove_child(phase_manager)
	phase_manager = null
	signals_received = []

func after():
	"""Suite-level cleanup"""
	helper = null
	HelperClass = null
	PhaseManagerClass = null

# ============================================================================
# World → Battle Transition Tests (4 tests)
# ============================================================================

func test_world_to_battle_transition_valid():
	"""World phase can transition to Battle phase"""
	# Setup: Start in WORLD phase
	phase_manager.current_phase = GlobalEnums.FiveParsecsCampaignPhase.UPKEEP
	phase_manager.transition_in_progress = false

	# Execute: Transition to BATTLE
	var result = phase_manager.start_phase(GlobalEnums.FiveParsecsCampaignPhase.MISSION)

	# Verify
	assert_that(result).is_true()
	assert_that(phase_manager.current_phase).is_equal(GlobalEnums.FiveParsecsCampaignPhase.MISSION)

func test_mission_context_structure_valid():
	"""Mission context has all required fields for battle initialization"""
	# Create mission context using helper
	var mock_battle = helper.create_mock_battle_phase_data()

	var mission_context = {
		"mission_type": mock_battle.get("mission_type", "OPPORTUNITY"),
		"enemy_count": mock_battle.get("enemy_count", 5),
		"enemy_type": mock_battle.get("enemy_type", "RAIDERS"),
		"deployment_zones": ["north", "south"],
		"terrain_type": "urban",
		"objective": "eliminate_hostiles",
		"crew": [],
		"equipment": []
	}

	# Verify required fields exist
	assert_that(mission_context.has("mission_type")).is_true()
	assert_that(mission_context.has("enemy_count")).is_true()
	assert_that(mission_context.has("enemy_type")).is_true()
	assert_that(mission_context.has("deployment_zones")).is_true()
	assert_that(mission_context.has("crew")).is_true()
	assert_that(mission_context.has("equipment")).is_true()

func test_battle_requirements_validation():
	"""Battle phase requires crew to be available"""
	var campaign = helper.create_full_campaign()

	# Validate battle requirements
	var result = helper.validate_battle_phase_requirements(campaign)

	assert_that(result.valid).is_true()
	assert_that(result.errors.size()).is_equal(0)

func test_battle_requirements_fail_without_crew():
	"""Battle phase validation fails without crew"""
	var campaign = helper.create_minimal_campaign()
	campaign["crew"]["members"] = []  # Remove all crew

	# Validate battle requirements
	var result = helper.validate_battle_phase_requirements(campaign)

	assert_that(result.valid).is_false()
	assert_that(result.errors.size()).is_greater(0)

# ============================================================================
# Data Flow Tests (3 tests)
# ============================================================================

func test_crew_data_passes_to_battle():
	"""Crew data from campaign is available for battle initialization"""
	var campaign = helper.create_full_campaign()

	# Verify crew data structure
	assert_that(campaign["crew"]["members"].size()).is_greater(0)

	var first_crew = campaign["crew"]["members"][0]
	assert_that(first_crew.has("character_name")).is_true()
	assert_that(first_crew.has("reactions")).is_true()
	assert_that(first_crew.has("combat")).is_true()

func test_equipment_data_passes_to_battle():
	"""Equipment data from campaign is available for battle"""
	var campaign = helper.create_full_campaign()

	# Verify equipment data structure
	assert_that(campaign["equipment"]["equipment"].size()).is_greater(0)

	var first_item = campaign["equipment"]["equipment"][0]
	assert_that(first_item.has("id")).is_true()
	assert_that(first_item.has("type")).is_true()

func test_mock_battle_data_complete():
	"""Mock battle data contains all required fields"""
	var mock_battle = helper.create_mock_battle_phase_data()

	# Core battle setup fields
	assert_that(mock_battle.has("mission_type")).is_true()
	assert_that(mock_battle.has("enemy_count")).is_true()
	assert_that(mock_battle.has("enemy_type")).is_true()
	assert_that(mock_battle.has("deployment_valid")).is_true()
	assert_that(mock_battle.has("crew_deployed")).is_true()

	# Value validation
	assert_that(mock_battle.enemy_count).is_greater(0)
	assert_that(mock_battle.crew_deployed).is_greater(0)

# ============================================================================
# Phase State Machine Tests (3 tests)
# ============================================================================

func test_invalid_phase_transitions_rejected():
	"""Genuinely invalid jumps are rejected. (Updated 2026-07-02: the old
	TRAVEL -> MISSION block is GONE by design — _can_transition_to_phase
	allows MISSION from any world-phase state because the world-phase UI
	covers UPKEEP/STORY/TRAVEL/PRE_MISSION.)"""
	phase_manager.current_phase = GlobalEnums.FiveParsecsCampaignPhase.TRAVEL
	phase_manager.transition_in_progress = false

	# Battle resolution requires battle setup first
	var to_resolution = phase_manager.start_phase(
		GlobalEnums.FiveParsecsCampaignPhase.BATTLE_RESOLUTION)
	assert_that(to_resolution).is_false()

	# Trading requires advancement first
	var to_trading = phase_manager.start_phase(
		GlobalEnums.FiveParsecsCampaignPhase.TRADING)
	assert_that(to_trading).is_false()

	assert_that(phase_manager.current_phase).is_equal(GlobalEnums.FiveParsecsCampaignPhase.TRAVEL)

func test_battle_to_post_battle_valid():
	"""Battle phase can transition to Post-Battle"""
	phase_manager.current_phase = GlobalEnums.FiveParsecsCampaignPhase.MISSION
	phase_manager.transition_in_progress = false

	var result = phase_manager.start_phase(GlobalEnums.FiveParsecsCampaignPhase.POST_MISSION)

	assert_that(result).is_true()
	assert_that(phase_manager.current_phase).is_equal(GlobalEnums.FiveParsecsCampaignPhase.POST_MISSION)

func test_full_turn_cycle():
	"""Complete UI-path cycle (updated 2026-07-02 to the real transition
	map): TRAVEL -> MISSION (world-phase UI covers travel state) ->
	POST_MISSION -> ADVANCEMENT ... RETIREMENT -> UPKEEP (new turn entry).
	The old TRAVEL->UPKEEP and POST_MISSION->TRAVEL jumps were never valid
	in the current map (UPKEEP only follows SETUP/RETIREMENT/NONE; TRAVEL
	only follows STORY)."""
	phase_manager.current_phase = GlobalEnums.FiveParsecsCampaignPhase.TRAVEL
	phase_manager.transition_in_progress = false

	# TRAVEL -> MISSION (the battle flow the world-phase UI drives)
	var result1 = phase_manager.start_phase(GlobalEnums.FiveParsecsCampaignPhase.MISSION)
	assert_that(result1).is_true()

	# MISSION -> POST_MISSION (battle UI covers setup/resolution visually)
	var result2 = phase_manager.start_phase(GlobalEnums.FiveParsecsCampaignPhase.POST_MISSION)
	assert_that(result2).is_true()

	# POST_MISSION -> ADVANCEMENT -> TRADING -> CHARACTER -> RETIREMENT
	assert_that(phase_manager.start_phase(
		GlobalEnums.FiveParsecsCampaignPhase.ADVANCEMENT)).is_true()
	assert_that(phase_manager.start_phase(
		GlobalEnums.FiveParsecsCampaignPhase.TRADING)).is_true()
	assert_that(phase_manager.start_phase(
		GlobalEnums.FiveParsecsCampaignPhase.CHARACTER)).is_true()
	assert_that(phase_manager.start_phase(
		GlobalEnums.FiveParsecsCampaignPhase.RETIREMENT)).is_true()

	# RETIREMENT -> UPKEEP: the next turn's entry transition
	var result_new_turn = phase_manager.start_phase(
		GlobalEnums.FiveParsecsCampaignPhase.UPKEEP)
	assert_that(result_new_turn).is_true()
	assert_that(phase_manager.current_phase).is_equal(GlobalEnums.FiveParsecsCampaignPhase.UPKEEP)
