extends GdUnitTestSuite

## Week 4 - Campaign Turn Loop E2E Smoke Tests
## Tests complete turn cycle execution (2 tests - well under limit)

# Test state
var campaign_phase_manager: Node

func before() -> void:
	# Get the autoloaded CampaignPhaseManager
	campaign_phase_manager = get_tree().root.get_node_or_null("CampaignPhaseManager")
	if not campaign_phase_manager:
		push_error("CampaignPhaseManager autoload not found")

func after() -> void:
	# Reset phase manager state after tests
	if campaign_phase_manager and campaign_phase_manager.has_method("force_phase_transition"):
		campaign_phase_manager.force_phase_transition(GlobalEnums.FiveParsecsCampaignPhase.NONE)

## E2E Smoke Test 1: Complete Turn Loop Execution
func test_complete_turn_loop_execution() -> void:
	"""E2E smoke test: Execute complete turn cycle Travel → World → Battle → Post-Battle → Travel"""

	# Start at clean state
	campaign_phase_manager.force_phase_transition(GlobalEnums.FiveParsecsCampaignPhase.NONE)
	var initial_turn = campaign_phase_manager.turn_number

	# PHASE 1: Start Travel Phase
	var travel_success = campaign_phase_manager.start_phase(GlobalEnums.FiveParsecsCampaignPhase.TRAVEL)
	assert_that(travel_success).is_true()
	assert_that(campaign_phase_manager.current_phase).is_equal(GlobalEnums.FiveParsecsCampaignPhase.TRAVEL)

	# Complete Travel → Should advance to World
	campaign_phase_manager.complete_current_phase()

	# PHASE 2: Verify World Phase
	assert_that(campaign_phase_manager.current_phase).is_equal(GlobalEnums.FiveParsecsCampaignPhase.UPKEEP)

	# Complete World → Should advance to Battle
	campaign_phase_manager.complete_current_phase()

	# PHASE 3: Verify Battle Phase
	assert_that(campaign_phase_manager.current_phase).is_equal(GlobalEnums.FiveParsecsCampaignPhase.MISSION)

	# Complete Battle → Should advance to Post-Battle
	campaign_phase_manager.complete_current_phase()

	# PHASE 4: Verify Post-Battle Phase
	assert_that(campaign_phase_manager.current_phase).is_equal(GlobalEnums.FiveParsecsCampaignPhase.POST_MISSION)

	# Complete Post-Battle → Should advance to Travel (new turn)
	campaign_phase_manager.complete_current_phase()

	# VERIFICATION: Back to Travel, turn number incremented
	assert_that(campaign_phase_manager.current_phase).is_equal(GlobalEnums.FiveParsecsCampaignPhase.TRAVEL)
	assert_that(campaign_phase_manager.turn_number).is_equal(initial_turn + 1)

## E2E Smoke Test 2: Phase Handlers Execute During Turn Loop
func test_phase_handlers_execute_during_turn_loop() -> void:
	"""Verify that phase handlers are actually called during phase execution"""

	campaign_phase_manager.force_phase_transition(GlobalEnums.FiveParsecsCampaignPhase.NONE)

	# Track handler execution via signal monitoring - use arrays for reference semantics in lambda
	var travel_phase_entered = [false]
	var world_phase_entered = [false]
	var battle_phase_entered = [false]
	var post_battle_phase_entered = [false]

	# Connect to phase_changed signal
	campaign_phase_manager.phase_changed.connect(func(new_phase):
		match new_phase:
			GlobalEnums.FiveParsecsCampaignPhase.TRAVEL:
				travel_phase_entered[0] = true
			GlobalEnums.FiveParsecsCampaignPhase.UPKEEP:
				world_phase_entered[0] = true
			GlobalEnums.FiveParsecsCampaignPhase.MISSION:
				battle_phase_entered[0] = true
			GlobalEnums.FiveParsecsCampaignPhase.POST_MISSION:
				post_battle_phase_entered[0] = true
	)

	# Execute half turn cycle
	campaign_phase_manager.start_phase(GlobalEnums.FiveParsecsCampaignPhase.TRAVEL)
	campaign_phase_manager.complete_current_phase()  # Travel → World
	campaign_phase_manager.complete_current_phase()  # World → Battle
	campaign_phase_manager.complete_current_phase()  # Battle → Post-Battle

	# Verify all phases were entered
	assert_that(travel_phase_entered[0]).is_true()
	assert_that(world_phase_entered[0]).is_true()
	assert_that(battle_phase_entered[0]).is_true()
	assert_that(post_battle_phase_entered[0]).is_true()
