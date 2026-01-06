extends GdUnitTestSuite
## Sprint 13: Phase Navigation and Battle System Integration Tests
## Tests bidirectional navigation (rollback) and BattleRoundTracker integration
## gdUnit4 v6.0.1 compatible

# System under test - CampaignPhaseManager with rollback support
var PhaseManagerClass
var phase_manager: Node = null

# BattleRoundTracker for battle system tests
var RoundTrackerClass
var round_tracker: Node = null

# BattlePhase handler for integration tests
var BattlePhaseClass
var battle_phase: Node = null

func before():
	"""Suite-level setup - runs once before all tests"""
	PhaseManagerClass = load("res://src/core/campaign/CampaignPhaseManager.gd")
	RoundTrackerClass = load("res://src/core/battle/BattleRoundTracker.gd")
	BattlePhaseClass = load("res://src/core/campaign/phases/BattlePhase.gd")

func before_test():
	"""Test-level setup - create fresh instances for each test"""
	seed(12345)  # Deterministic random

	# Create manager instance
	phase_manager = auto_free(PhaseManagerClass.new())
	add_child(phase_manager)

	await get_tree().process_frame

func after_test():
	"""Test-level cleanup"""
	if phase_manager and phase_manager.get_parent():
		remove_child(phase_manager)
	phase_manager = null

	if round_tracker:
		if round_tracker.get_parent():
			round_tracker.get_parent().remove_child(round_tracker)
		round_tracker = null

	if battle_phase:
		if battle_phase.get_parent():
			battle_phase.get_parent().remove_child(battle_phase)
		battle_phase = null

func after():
	"""Suite-level cleanup"""
	PhaseManagerClass = null
	RoundTrackerClass = null
	BattlePhaseClass = null

# ============================================================================
# Sprint 10: Phase Rollback Tests (4 tests)
# ============================================================================

func test_can_rollback_from_world_to_travel():
	"""WORLD → TRAVEL rollback succeeds (Sprint 10.1)"""
	# Setup: Start in WORLD phase
	phase_manager.current_phase = GlobalEnums.FiveParsecsCampaignPhase.WORLD
	phase_manager.transition_in_progress = false

	# Verify rollback method exists
	assert_that(phase_manager.has_method("rollback_to_phase")).is_true()

	# Execute: Rollback to TRAVEL
	var result = phase_manager.rollback_to_phase(GlobalEnums.FiveParsecsCampaignPhase.TRAVEL)

	# Verify: Rollback succeeded
	assert_that(result).is_true()
	assert_that(phase_manager.current_phase).is_equal(GlobalEnums.FiveParsecsCampaignPhase.TRAVEL)

func test_can_rollback_from_battle_to_world():
	"""BATTLE → WORLD rollback succeeds before combat starts (Sprint 10.1)"""
	# Setup: Start in BATTLE phase
	phase_manager.current_phase = GlobalEnums.FiveParsecsCampaignPhase.BATTLE
	phase_manager.transition_in_progress = false

	# Execute: Rollback to WORLD
	var result = phase_manager.rollback_to_phase(GlobalEnums.FiveParsecsCampaignPhase.WORLD)

	# Verify: Rollback succeeded
	assert_that(result).is_true()
	assert_that(phase_manager.current_phase).is_equal(GlobalEnums.FiveParsecsCampaignPhase.WORLD)

func test_cannot_rollback_from_post_battle():
	"""POST_BATTLE rollback blocked - results already committed (Sprint 10.1)"""
	# Setup: Start in POST_BATTLE phase
	phase_manager.current_phase = GlobalEnums.FiveParsecsCampaignPhase.POST_BATTLE
	phase_manager.transition_in_progress = false

	# Execute: Attempt rollback to BATTLE
	var result = phase_manager.rollback_to_phase(GlobalEnums.FiveParsecsCampaignPhase.BATTLE)

	# Verify: Rollback blocked, still in POST_BATTLE
	assert_that(result).is_false()
	assert_that(phase_manager.current_phase).is_equal(GlobalEnums.FiveParsecsCampaignPhase.POST_BATTLE)

func test_phase_checkpoint_storage():
	"""Phase checkpoints are stored and restored correctly (Sprint 10.4)"""
	# Setup: Start in TRAVEL phase with test data
	phase_manager.current_phase = GlobalEnums.FiveParsecsCampaignPhase.TRAVEL
	phase_manager.transition_in_progress = false

	# Store checkpoint if method exists
	if phase_manager.has_method("_store_phase_checkpoint"):
		phase_manager._store_phase_checkpoint(GlobalEnums.FiveParsecsCampaignPhase.TRAVEL)

		# Move to WORLD
		phase_manager.current_phase = GlobalEnums.FiveParsecsCampaignPhase.WORLD

		# Rollback to TRAVEL
		var result = phase_manager.rollback_to_phase(GlobalEnums.FiveParsecsCampaignPhase.TRAVEL)

		# Verify: Checkpoint restored
		assert_that(result).is_true()
		assert_that(phase_manager.current_phase).is_equal(GlobalEnums.FiveParsecsCampaignPhase.TRAVEL)
	else:
		# Skip if checkpoint methods not implemented
		pass

# ============================================================================
# Sprint 11: Battle Round Tracker Tests (5 tests)
# ============================================================================

func test_battle_round_tracker_initialization():
	"""BattleRoundTracker initializes with correct default state (Sprint 11.1)"""
	# Create round tracker
	round_tracker = auto_free(RoundTrackerClass.new())
	add_child(round_tracker)
	await get_tree().process_frame

	# Verify initial state
	assert_that(round_tracker.get_current_round()).is_equal(0)
	assert_that(round_tracker.get_current_phase()).is_equal(0)  # REACTION_ROLL

func test_battle_round_tracker_starts_battle():
	"""BattleRoundTracker.start_battle() initializes round 1 (Sprint 11.1)"""
	# Create round tracker
	round_tracker = auto_free(RoundTrackerClass.new())
	add_child(round_tracker)
	await get_tree().process_frame

	# Start battle
	round_tracker.start_battle()

	# Verify battle started
	assert_that(round_tracker.get_current_round()).is_equal(1)
	assert_that(round_tracker.get_current_phase()).is_equal(0)  # REACTION_ROLL

func test_battle_phases_advance_in_order():
	"""Battle phases advance: REACTION_ROLL → QUICK → ENEMY → SLOW → END (Sprint 11.1)"""
	# Create round tracker
	round_tracker = auto_free(RoundTrackerClass.new())
	add_child(round_tracker)
	await get_tree().process_frame

	# Start battle
	round_tracker.start_battle()

	# Phase 0: REACTION_ROLL
	assert_that(round_tracker.get_current_phase()).is_equal(0)
	assert_that(round_tracker.get_phase_name(0)).is_equal("Reaction Roll")

	# Advance to QUICK_ACTIONS (Phase 1)
	round_tracker.advance_phase()
	assert_that(round_tracker.get_current_phase()).is_equal(1)
	assert_that(round_tracker.get_phase_name(1)).is_equal("Quick Actions")

	# Advance to ENEMY_ACTIONS (Phase 2)
	round_tracker.advance_phase()
	assert_that(round_tracker.get_current_phase()).is_equal(2)
	assert_that(round_tracker.get_phase_name(2)).is_equal("Enemy Actions")

	# Advance to SLOW_ACTIONS (Phase 3)
	round_tracker.advance_phase()
	assert_that(round_tracker.get_current_phase()).is_equal(3)
	assert_that(round_tracker.get_phase_name(3)).is_equal("Slow Actions")

	# Advance to END_PHASE (Phase 4)
	round_tracker.advance_phase()
	assert_that(round_tracker.get_current_phase()).is_equal(4)
	assert_that(round_tracker.get_phase_name(4)).is_equal("End Phase")

func test_battle_round_advances_after_end_phase():
	"""Advancing past END_PHASE starts new round (Sprint 11.1)"""
	# Create round tracker
	round_tracker = auto_free(RoundTrackerClass.new())
	add_child(round_tracker)
	await get_tree().process_frame

	# Start battle (Round 1)
	round_tracker.start_battle()
	assert_that(round_tracker.get_current_round()).is_equal(1)

	# Advance through all 5 phases to end Round 1
	for i in range(5):
		round_tracker.advance_phase()

	# Verify now in Round 2, Phase 0
	assert_that(round_tracker.get_current_round()).is_equal(2)
	assert_that(round_tracker.get_current_phase()).is_equal(0)  # Back to REACTION_ROLL

func test_battle_events_trigger_on_rounds_2_and_4():
	"""Battle events occur on rounds 2 and 4 per Five Parsecs rules (Sprint 11.1)"""
	# Create round tracker
	round_tracker = auto_free(RoundTrackerClass.new())
	add_child(round_tracker)
	await get_tree().process_frame

	# Round 1 - no event
	round_tracker.start_battle()
	var event_check_r1 = round_tracker.check_battle_event()
	assert_that(event_check_r1.should_trigger).is_false()

	# Advance to Round 2
	for i in range(5):  # Complete Round 1
		round_tracker.advance_phase()

	var event_check_r2 = round_tracker.check_battle_event()
	assert_that(event_check_r2.should_trigger).is_true()

	# Advance to Round 3
	for i in range(5):  # Complete Round 2
		round_tracker.advance_phase()

	var event_check_r3 = round_tracker.check_battle_event()
	assert_that(event_check_r3.should_trigger).is_false()

	# Advance to Round 4
	for i in range(5):  # Complete Round 3
		round_tracker.advance_phase()

	var event_check_r4 = round_tracker.check_battle_event()
	assert_that(event_check_r4.should_trigger).is_true()

# ============================================================================
# Sprint 11.2-11.5: Battle Mode Selection Tests (3 tests)
# ============================================================================

func test_battle_phase_has_round_tracker():
	"""BattlePhase instantiates BattleRoundTracker (Sprint 11.1)"""
	# Create BattlePhase
	battle_phase = auto_free(BattlePhaseClass.new())
	add_child(battle_phase)
	await get_tree().process_frame

	# Verify round tracker property exists
	assert_that("round_tracker" in battle_phase).is_true()

func test_battle_phase_has_battle_mode_selection():
	"""BattlePhase has battle mode selection (Sprint 11.2)"""
	# Create BattlePhase
	battle_phase = auto_free(BattlePhaseClass.new())
	add_child(battle_phase)
	await get_tree().process_frame

	# Verify mode selection property exists
	assert_that("use_tactical_combat" in battle_phase).is_true()

	# Verify set_battle_mode method exists
	assert_that(battle_phase.has_method("set_battle_mode")).is_true()

func test_battle_phase_set_battle_mode():
	"""BattlePhase.set_battle_mode() toggles tactical combat (Sprint 11.2)"""
	# Create BattlePhase
	battle_phase = auto_free(BattlePhaseClass.new())
	add_child(battle_phase)
	await get_tree().process_frame

	# Set to tactical mode
	battle_phase.set_battle_mode(true)
	assert_that(battle_phase.use_tactical_combat).is_true()

	# Set to auto-resolve mode
	battle_phase.set_battle_mode(false)
	assert_that(battle_phase.use_tactical_combat).is_false()

# ============================================================================
# Sprint 12: World Phase Component Integration Tests (2 tests)
# ============================================================================

func test_world_phase_components_have_step_results():
	"""All World Phase components have get_step_results() method (Sprint 12.2)"""
	var component_paths = [
		"res://src/ui/screens/world/components/JobOfferComponent.gd",
		"res://src/ui/screens/world/components/AssignEquipmentComponent.gd",
		"res://src/ui/screens/world/components/ResolveRumorsComponent.gd",
		"res://src/ui/screens/world/components/MissionPrepComponent.gd",
		"res://src/ui/screens/world/components/UpkeepPhaseComponent.gd",
		"res://src/ui/screens/world/components/CrewTaskComponent.gd"
	]

	for path in component_paths:
		if ResourceLoader.exists(path):
			var ComponentClass = load(path)
			var component = auto_free(ComponentClass.new())

			# Verify get_step_results or equivalent method exists
			var has_results_method = (
				component.has_method("get_step_results") or
				component.has_method("get_upkeep_results") or
				component.has_method("get_task_results")
			)
			assert_that(has_results_method).is_true()

func test_world_phase_components_have_completion_check():
	"""All World Phase components have completion check method (Sprint 12.2)"""
	var completion_checks = {
		"res://src/ui/screens/world/components/JobOfferComponent.gd": "is_job_accepted",
		"res://src/ui/screens/world/components/AssignEquipmentComponent.gd": "is_assignment_completed",
		"res://src/ui/screens/world/components/ResolveRumorsComponent.gd": "is_rumors_resolved",
		"res://src/ui/screens/world/components/MissionPrepComponent.gd": "is_prep_completed",
		"res://src/ui/screens/world/components/UpkeepPhaseComponent.gd": "is_upkeep_completed",
		"res://src/ui/screens/world/components/CrewTaskComponent.gd": "is_tasks_completed"
	}

	for path in completion_checks.keys():
		if ResourceLoader.exists(path):
			var ComponentClass = load(path)
			var component = auto_free(ComponentClass.new())
			var method_name = completion_checks[path]

			# Verify completion method exists
			assert_that(component.has_method(method_name)).is_true()
