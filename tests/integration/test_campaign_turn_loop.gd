extends GdUnitTestSuite

## Week 4 - Campaign Turn Loop Integration Test
## Tests complete turn cycle: Travel → World → Battle → Post-Battle

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

## Test 1: Phase Manager Initialization
func test_manager_initializes_with_correct_phase() -> void:
	assert_that(campaign_phase_manager).is_not_null()
	# After initialization, phase should be NONE (0) or a valid starting phase
	assert_that(campaign_phase_manager.current_phase).is_equal(GlobalEnums.FiveParsecsCampaignPhase.NONE)

func test_turn_number_starts_at_one() -> void:
	assert_that(campaign_phase_manager.turn_number).is_equal(1)

func test_no_transition_in_progress_initially() -> void:
	assert_that(campaign_phase_manager.is_transition_in_progress()).is_false()

## Test 2: Phase Handlers Exist
func test_travel_phase_handler_exists() -> void:
	assert_that(campaign_phase_manager.travel_phase_handler).is_not_null()

func test_world_phase_handler_exists() -> void:
	assert_that(campaign_phase_manager.world_phase_handler).is_not_null()

func test_post_battle_phase_handler_exists() -> void:
	assert_that(campaign_phase_manager.post_battle_phase_handler).is_not_null()

## Test 3: Phase Transitions
func test_can_transition_from_none_to_travel() -> void:
	campaign_phase_manager.force_phase_transition(GlobalEnums.FiveParsecsCampaignPhase.NONE)
	var can_transition = campaign_phase_manager._can_transition_to_phase(GlobalEnums.FiveParsecsCampaignPhase.TRAVEL)
	assert_that(can_transition).is_true()

func test_can_transition_from_travel_to_world() -> void:
	campaign_phase_manager.force_phase_transition(GlobalEnums.FiveParsecsCampaignPhase.TRAVEL)
	var can_transition = campaign_phase_manager._can_transition_to_phase(GlobalEnums.FiveParsecsCampaignPhase.WORLD)
	assert_that(can_transition).is_true()

func test_can_transition_from_world_to_battle() -> void:
	campaign_phase_manager.force_phase_transition(GlobalEnums.FiveParsecsCampaignPhase.WORLD)
	var can_transition = campaign_phase_manager._can_transition_to_phase(GlobalEnums.FiveParsecsCampaignPhase.BATTLE)
	assert_that(can_transition).is_true()

func test_can_transition_from_battle_to_post_battle() -> void:
	campaign_phase_manager.force_phase_transition(GlobalEnums.FiveParsecsCampaignPhase.BATTLE)
	var can_transition = campaign_phase_manager._can_transition_to_phase(GlobalEnums.FiveParsecsCampaignPhase.POST_BATTLE)
	assert_that(can_transition).is_true()

func test_can_transition_from_post_battle_to_travel() -> void:
	campaign_phase_manager.force_phase_transition(GlobalEnums.FiveParsecsCampaignPhase.POST_BATTLE)
	var can_transition = campaign_phase_manager._can_transition_to_phase(GlobalEnums.FiveParsecsCampaignPhase.TRAVEL)
	assert_that(can_transition).is_true()

func test_cannot_skip_from_travel_to_battle() -> void:
	campaign_phase_manager.force_phase_transition(GlobalEnums.FiveParsecsCampaignPhase.TRAVEL)
	var can_transition = campaign_phase_manager._can_transition_to_phase(GlobalEnums.FiveParsecsCampaignPhase.BATTLE)
	assert_that(can_transition).is_false()

func test_cannot_go_backwards_from_travel_to_post_battle() -> void:
	campaign_phase_manager.force_phase_transition(GlobalEnums.FiveParsecsCampaignPhase.TRAVEL)
	var can_transition = campaign_phase_manager._can_transition_to_phase(GlobalEnums.FiveParsecsCampaignPhase.POST_BATTLE)
	assert_that(can_transition).is_false()

## Test 4: Turn Cycle Signals
func test_start_phase_returns_true() -> void:
	campaign_phase_manager.force_phase_transition(GlobalEnums.FiveParsecsCampaignPhase.NONE)
	var success = campaign_phase_manager.start_phase(GlobalEnums.FiveParsecsCampaignPhase.TRAVEL)
	assert_that(success).is_true()

func test_phase_changes_to_travel_after_start() -> void:
	campaign_phase_manager.force_phase_transition(GlobalEnums.FiveParsecsCampaignPhase.NONE)
	campaign_phase_manager.start_phase(GlobalEnums.FiveParsecsCampaignPhase.TRAVEL)
	assert_that(campaign_phase_manager.current_phase).is_equal(GlobalEnums.FiveParsecsCampaignPhase.TRAVEL)

func test_phase_advances_to_world_after_complete() -> void:
	campaign_phase_manager.force_phase_transition(GlobalEnums.FiveParsecsCampaignPhase.TRAVEL)
	campaign_phase_manager.complete_current_phase()
	assert_that(campaign_phase_manager.current_phase).is_equal(GlobalEnums.FiveParsecsCampaignPhase.WORLD)
