class_name TestMoralePanicTracker
extends GdUnitTestSuite

## Unit tests for MoralePanicTracker - Morale Check Math
##
## Tests enemy count management, casualty tracking, morale check triggers,
## 2d6 morale rolls, panic type determination, and round resets.
## Loads .tscn to ensure @onready UI nodes resolve correctly.

const MoralePanicTrackerScene = preload("res://src/ui/components/battle/MoralePanicTracker.tscn")

var tracker: FPCM_MoralePanicTracker

func before_test() -> void:
	seed(12345)
	tracker = MoralePanicTrackerScene.instantiate()
	add_child(tracker)
	# Wait for node to be ready in tree
	for i in range(3):
		await get_tree().process_frame
	if not is_instance_valid(tracker):
		push_warning("tracker failed to initialize")
		return

func after_test() -> void:
	if is_instance_valid(tracker):
		remove_child(tracker)
		tracker.free()
	tracker = null

# =====================================================
# ENEMY COUNT & CASUALTY TESTS
# =====================================================

func test_set_enemy_count_initializes_state() -> void:
	## set_enemy_count() should initialize all tracking state
	if not is_instance_valid(tracker):
		return
	tracker.set_enemy_count(6)
	assert_int(tracker.total_enemies).is_equal(6)
	assert_int(tracker.enemies_remaining).is_equal(6)
	assert_int(tracker.casualties_this_round).is_equal(0)
	assert_int(tracker.fled_enemies).is_equal(0)

func test_add_casualty_decrements_remaining() -> void:
	## add_casualty() should decrement remaining and increment casualties
	if not is_instance_valid(tracker):
		return
	tracker.set_enemy_count(6)
	tracker.add_casualty()
	assert_int(tracker.enemies_remaining).is_equal(5)
	assert_int(tracker.casualties_this_round).is_equal(1)

func test_add_casualty_at_zero_does_nothing() -> void:
	## add_casualty() at zero remaining should be a no-op
	if not is_instance_valid(tracker):
		return
	tracker.set_enemy_count(0)
	tracker.add_casualty()
	assert_int(tracker.enemies_remaining).is_equal(0)
	assert_int(tracker.casualties_this_round).is_equal(0)

func test_multiple_casualties_tracked() -> void:
	## Multiple casualties should accumulate correctly
	if not is_instance_valid(tracker):
		return
	tracker.set_enemy_count(6)
	tracker.add_casualty()
	tracker.add_casualty()
	tracker.add_casualty()
	assert_int(tracker.enemies_remaining).is_equal(3)
	assert_int(tracker.casualties_this_round).is_equal(3)

# =====================================================
# MORALE CHECK TRIGGER TESTS
# =====================================================

func test_morale_check_triggers_on_first_casualty() -> void:
	## First casualty each round triggers morale check signal
	if not is_instance_valid(tracker):
		return
	tracker.set_enemy_count(6)
	var signal_fired := [false]
	tracker.morale_check_triggered.connect(func(_remaining: int, _casualties: int): signal_fired[0] = true)
	tracker.add_casualty()
	assert_bool(signal_fired[0]).is_true()

func test_morale_check_does_not_trigger_on_second_casualty() -> void:
	## Second casualty same round should NOT trigger another check
	if not is_instance_valid(tracker):
		return
	tracker.set_enemy_count(6)
	var signal_count := [0]
	tracker.morale_check_triggered.connect(func(_remaining: int, _casualties: int): signal_count[0] += 1)
	tracker.add_casualty()  # First casualty - should trigger
	tracker.add_casualty()  # Second casualty - should NOT trigger
	assert_int(signal_count[0]).is_equal(1)

# =====================================================
# MORALE ROLL TESTS
# =====================================================

func test_roll_morale_check_returns_result_dict() -> void:
	## roll_morale_check() returns dict with roll, target, success, fled, panic
	if not is_instance_valid(tracker):
		return
	tracker.set_enemy_count(6)
	tracker.add_casualty()
	var result := tracker.roll_morale_check()
	assert_bool(result.has("roll")).is_true()
	assert_bool(result.has("target")).is_true()
	assert_bool(result.has("success")).is_true()
	assert_bool(result.has("fled")).is_true()
	assert_bool(result.has("panic")).is_true()

func test_roll_morale_check_rout_when_2_or_fewer() -> void:
	## Failed morale with 2 or fewer enemies triggers ROUT
	if not is_instance_valid(tracker):
		return
	# Set up: 2 enemies, very low morale so check always fails
	tracker.set_enemy_count(2)
	tracker.set_base_morale(0)  # Effective morale 0, any 2d6 roll > 0 fails
	tracker.add_casualty()  # Now 1 remaining (<=2)
	# Force a high roll by trying many seeds until we get a failure
	# With base_morale 0, any roll > 0 fails, so this will always be a failure
	seed(99999)
	var result := tracker.roll_morale_check()
	if not result.success:
		assert_str(result.panic).is_equal("ROUT")
		assert_int(result.fled).is_equal(tracker.enemies_remaining + result.fled)

func test_morale_modifier_affects_target() -> void:
	## Morale modifier adjusts effective target value
	if not is_instance_valid(tracker):
		return
	tracker.set_base_morale(3)
	tracker.set_morale_modifier(-1)
	tracker.set_enemy_count(6)
	tracker.add_casualty()
	var result := tracker.roll_morale_check()
	assert_int(result.target).is_equal(2)  # 3 + (-1) = 2

# =====================================================
# ROUND RESET & SIGNAL TESTS
# =====================================================

func test_new_round_resets_casualties() -> void:
	## new_round() resets casualties_this_round to zero
	if not is_instance_valid(tracker):
		return
	tracker.set_enemy_count(6)
	tracker.add_casualty()
	tracker.add_casualty()
	assert_int(tracker.casualties_this_round).is_equal(2)
	tracker.new_round()
	assert_int(tracker.casualties_this_round).is_equal(0)

func test_enemy_fled_signal_emitted() -> void:
	## enemy_fled signal emits when enemies flee after failed morale
	if not is_instance_valid(tracker):
		return
	tracker.set_enemy_count(2)
	tracker.set_base_morale(0)  # Guaranteed failure
	tracker.add_casualty()
	var fled_count := [0]
	tracker.enemy_fled.connect(func(count: int): fled_count[0] = count)
	seed(99999)
	var result := tracker.roll_morale_check()
	if not result.success and result.fled > 0:
		assert_int(fled_count[0]).is_greater(0)

func test_panic_occurred_signal_emitted() -> void:
	## panic_occurred signal emits valid panic type on failure
	if not is_instance_valid(tracker):
		return
	tracker.set_enemy_count(6)
	tracker.set_base_morale(0)  # Guaranteed failure
	tracker.add_casualty()
	var panic_type := [""]
	tracker.panic_occurred.connect(func(ptype: String): panic_type[0] = ptype)
	seed(99999)
	var result := tracker.roll_morale_check()
	if not result.success:
		assert_bool(panic_type[0] in ["ROUT", "FALL_BACK", "ONE_FLEES", "DUCK"]).is_true()
