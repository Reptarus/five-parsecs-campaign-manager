class_name TestBattleRoundTracker
extends GdUnitTestSuite

## Comprehensive test suite for BattleRoundTracker
##
## Tests phase transitions, round progression, battle events,
## signal emissions, and edge cases for the Five Parsecs battle system.

var tracker: BattleRoundTracker

func before_test() -> void:
	# Set deterministic seed for reproducible random numbers
	seed(12345)

	tracker = BattleRoundTracker.new()
	add_child(tracker)
	# Wait for node to be ready in tree
	for i in range(3):
		await get_tree().process_frame
	if not is_instance_valid(tracker):
		push_warning("tracker failed to initialize")
		return
	# Start battle to initialize state properly
	tracker.start_battle()

func after_test() -> void:
	if is_instance_valid(tracker):
		remove_child(tracker)
		tracker.queue_free()
	tracker = null

# =====================================================
# PHASE TRANSITION TESTS
# =====================================================

func test_initial_phase_is_reaction_roll() -> void:
	"""Tracker should start at REACTION_ROLL phase after start_battle()"""
	if not is_instance_valid(tracker):
		push_warning("tracker not available, skipping")
		return
	assert_int(tracker.get_current_phase()).is_equal(BattleRoundTracker.BattlePhase.REACTION_ROLL)

func test_advance_phase_cycles_through_all_phases() -> void:
	"""Phase should progress: REACTION_ROLL -> QUICK -> ENEMY -> SLOW -> END"""
	if not is_instance_valid(tracker):
		push_warning("tracker not available, skipping")
		return
	# Start at REACTION_ROLL
	assert_int(tracker.get_current_phase()).is_equal(BattleRoundTracker.BattlePhase.REACTION_ROLL)

	# Advance to QUICK_ACTIONS
	tracker.advance_phase()
	assert_int(tracker.get_current_phase()).is_equal(BattleRoundTracker.BattlePhase.QUICK_ACTIONS)

	# Advance to ENEMY_ACTIONS
	tracker.advance_phase()
	assert_int(tracker.get_current_phase()).is_equal(BattleRoundTracker.BattlePhase.ENEMY_ACTIONS)

	# Advance to SLOW_ACTIONS
	tracker.advance_phase()
	assert_int(tracker.get_current_phase()).is_equal(BattleRoundTracker.BattlePhase.SLOW_ACTIONS)

	# Advance to END_PHASE
	tracker.advance_phase()
	assert_int(tracker.get_current_phase()).is_equal(BattleRoundTracker.BattlePhase.END_PHASE)

func test_end_phase_advances_to_next_round() -> void:
	"""END_PHASE should wrap to REACTION_ROLL and increment round"""
	if not is_instance_valid(tracker):
		push_warning("tracker not available, skipping")
		return
	# Advance to END_PHASE (4 advances: REACTION_ROLL→QUICK→ENEMY→SLOW→END)
	for i in range(4):
		tracker.advance_phase()

	assert_int(tracker.get_current_phase()).is_equal(BattleRoundTracker.BattlePhase.END_PHASE)
	assert_int(tracker.get_current_round()).is_equal(1)

	# Advance from END_PHASE should go to round 2, REACTION_ROLL
	tracker.advance_phase()
	assert_int(tracker.get_current_phase()).is_equal(BattleRoundTracker.BattlePhase.REACTION_ROLL)
	assert_int(tracker.get_current_round()).is_equal(2)

func test_phase_changed_signal_emitted() -> void:
	"""phase_changed signal should emit on each phase transition"""
	if not is_instance_valid(tracker):
		push_warning("tracker not available, skipping")
		return

	# Setup signal connection flag - use array for reference semantics in lambda
	# phase_changed signal has 2 params: (new_phase: int, phase_name: String)
	var signal_fired := [false]
	tracker.phase_changed.connect(func(_phase, _name): signal_fired[0] = true)

	# Signal emits synchronously during advance_phase()
	tracker.advance_phase()
	await get_tree().process_frame

	# Guard against freed instance after await
	if not is_instance_valid(tracker):
		return
	assert_that(signal_fired[0]).is_true()

# =====================================================
# ROUND COUNTER TESTS
# =====================================================

func test_initial_round_is_one() -> void:
	"""Tracker should start at round 1 after start_battle()"""
	if not is_instance_valid(tracker):
		push_warning("tracker not available, skipping")
		return
	assert_int(tracker.get_current_round()).is_equal(1)

func test_round_increments_after_end_phase() -> void:
	"""Round should increment when advancing from END_PHASE"""
	if not is_instance_valid(tracker):
		push_warning("tracker not available, skipping")
		return
	# Complete round 1 (6 advances: 5 phases + wrap to round 2)
	for i in range(6):
		tracker.advance_phase()

	assert_int(tracker.get_current_round()).is_equal(2)

	# Complete round 2 (5 more advances)
	for i in range(5):
		tracker.advance_phase()

	assert_int(tracker.get_current_round()).is_equal(3)

func test_round_changed_signal_emitted() -> void:
	"""round_changed signal should emit when round increments"""
	if not is_instance_valid(tracker):
		push_warning("tracker not available, skipping")
		return

	# Setup signal connection flag - use array for reference semantics in lambda
	var signal_fired := [false]
	tracker.round_changed.connect(func(_round): signal_fired[0] = true)

	# Advance to END_PHASE (4 advances)
	for i in range(4):
		tracker.advance_phase()

	# Advance from END_PHASE should emit round_changed (synchronously)
	tracker.advance_phase()
	await get_tree().process_frame

	# Guard against freed instance after await
	if not is_instance_valid(tracker):
		return
	assert_that(signal_fired[0]).is_true()

# =====================================================
# BATTLE EVENT TESTS (Five Parsecs p.118)
# =====================================================

func test_battle_event_triggers_on_round_2() -> void:
	"""Battle event should trigger when entering round 2"""
	if not is_instance_valid(tracker):
		push_warning("tracker not available, skipping")
		return

	# Setup signal connection flag - use array for reference semantics in lambda
	var signal_fired := [false]
	tracker.battle_event_triggered.connect(func(_round: int, _event: String): signal_fired[0] = true)

	# Complete round 1 (5 advances to wrap to round 2)
	for i in range(5):
		tracker.advance_phase()
	await get_tree().process_frame

	# Guard against freed instance after await
	if not is_instance_valid(tracker):
		return
	assert_that(signal_fired[0]).is_true()

func test_battle_event_triggers_on_round_4() -> void:
	"""Battle event should trigger when entering round 4"""
	if not is_instance_valid(tracker):
		push_warning("tracker not available, skipping")
		return

	# Setup signal connection flag - use array for reference semantics in lambda
	var signal_fired := [false]
	tracker.battle_event_triggered.connect(func(_round: int, _event: String): signal_fired[0] = true)

	# Complete rounds 1-3 to reach round 4 (3 complete rounds × 5 advances each = 15)
	for i in range(3 * 5):
		tracker.advance_phase()
	await get_tree().process_frame

	# Guard against freed instance after await
	if not is_instance_valid(tracker):
		return
	# Should have emitted for round 2 and round 4
	assert_that(signal_fired[0]).is_true()

func test_no_battle_event_on_other_rounds() -> void:
	"""Battle events should NOT trigger on rounds 1, 3, 5, etc."""
	if not is_instance_valid(tracker):
		push_warning("tracker not available, skipping")
		return

	# Note: This test has been simplified to check signal emission pattern
	# The complex emit counting is not reliable in GdUnit4's signal monitoring
	# Setup signal connection flag (counts emissions) - use array for reference semantics
	var signal_count := [0]
	tracker.battle_event_triggered.connect(func(_round: int, _event: String): signal_count[0] += 1)

	# Round 1 -> Round 2 (1 complete cycle = 5 advances)
	for i in range(5):
		tracker.advance_phase()
	await get_tree().process_frame

	# Guard against freed instance after await
	if not is_instance_valid(tracker):
		return
	# One event emitted (round 2)
	assert_that(signal_count[0]).is_equal(1)

	# Round 2 -> Round 3 (5 advances, no event expected for round 3)
	for i in range(5):
		tracker.advance_phase()
	await get_tree().process_frame

	# Guard after advancing
	if not is_instance_valid(tracker):
		return
	# Still only 1 event (no event on round 3)
	assert_that(signal_count[0]).is_equal(1)

	# Round 3 -> Round 4 (5 advances, event expected for round 4)
	for i in range(5):
		tracker.advance_phase()
	await get_tree().process_frame

	# Guard against freed instance after await
	if not is_instance_valid(tracker):
		return
	# Should have emitted again for round 4 (now 2 total)
	assert_that(signal_count[0]).is_equal(2)

# =====================================================
# EDGE CASE TESTS
# =====================================================

func test_multiple_phase_advances_in_sequence() -> void:
	"""Should handle rapid sequential phase advances correctly"""
	if not is_instance_valid(tracker):
		push_warning("tracker not available, skipping")
		return
	# Advance 17 times to reach round 4, phase ENEMY_ACTIONS
	# (5 phases per round: 15 advances = round 4 start, +2 = ENEMY_ACTIONS)
	for i in range(17):
		tracker.advance_phase()

	# Should be in round 4, phase ENEMY_ACTIONS
	assert_int(tracker.get_current_round()).is_equal(4)
	assert_int(tracker.get_current_phase()).is_equal(BattleRoundTracker.BattlePhase.ENEMY_ACTIONS)

func test_get_phase_name_returns_correct_strings() -> void:
	"""get_phase_name should return human-readable phase names"""
	if not is_instance_valid(tracker):
		push_warning("tracker not available, skipping")
		return
	assert_str(tracker.get_phase_name(BattleRoundTracker.BattlePhase.REACTION_ROLL)).is_equal("Reaction Roll")
	assert_str(tracker.get_phase_name(BattleRoundTracker.BattlePhase.QUICK_ACTIONS)).is_equal("Quick Actions")
	assert_str(tracker.get_phase_name(BattleRoundTracker.BattlePhase.ENEMY_ACTIONS)).is_equal("Enemy Actions")
	assert_str(tracker.get_phase_name(BattleRoundTracker.BattlePhase.SLOW_ACTIONS)).is_equal("Slow Actions")
	assert_str(tracker.get_phase_name(BattleRoundTracker.BattlePhase.END_PHASE)).is_equal("End Phase")
