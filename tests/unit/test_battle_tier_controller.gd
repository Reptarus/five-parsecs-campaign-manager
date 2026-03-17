class_name TestBattleTierController
extends GdUnitTestSuite

## Unit tests for BattleTierController - Tier State Machine
##
## Tests tier upgrades, downgrades, force overrides, invalid values,
## and signal emissions for the three-tier tracking system.

const BattleTierControllerClass = preload("res://src/core/battle/BattleTierController.gd")

var controller: FPCM_BattleTierController

func before_test() -> void:
	seed(12345)
	controller = BattleTierControllerClass.new()

func after_test() -> void:
	controller = null

# =====================================================
# DEFAULT STATE TESTS
# =====================================================

func test_initial_tier_is_log_only() -> void:
	## Default tier should be LOG_ONLY
	assert_int(controller.current_tier).is_equal(FPCM_BattleTierController.TrackingTier.LOG_ONLY)

func test_get_current_tier_matches_property() -> void:
	## get_current_tier() should match current_tier property
	assert_int(controller.get_current_tier()).is_equal(controller.current_tier)

# =====================================================
# UPGRADE TESTS
# =====================================================

func test_set_tier_upgrade_0_to_1_allowed() -> void:
	## Upgrade from LOG_ONLY to ASSISTED should succeed
	var result := controller.set_tier(FPCM_BattleTierController.TrackingTier.ASSISTED)
	assert_bool(result).is_true()
	assert_int(controller.current_tier).is_equal(FPCM_BattleTierController.TrackingTier.ASSISTED)

func test_set_tier_upgrade_1_to_2_allowed() -> void:
	## Upgrade from ASSISTED to FULL_ORACLE should succeed
	controller.set_tier(FPCM_BattleTierController.TrackingTier.ASSISTED)
	var result := controller.set_tier(FPCM_BattleTierController.TrackingTier.FULL_ORACLE)
	assert_bool(result).is_true()
	assert_int(controller.current_tier).is_equal(FPCM_BattleTierController.TrackingTier.FULL_ORACLE)

func test_set_tier_skip_upgrade_0_to_2_allowed() -> void:
	## Skip upgrade from LOG_ONLY to FULL_ORACLE should succeed
	var result := controller.set_tier(FPCM_BattleTierController.TrackingTier.FULL_ORACLE)
	assert_bool(result).is_true()
	assert_int(controller.current_tier).is_equal(FPCM_BattleTierController.TrackingTier.FULL_ORACLE)

# =====================================================
# DOWNGRADE TESTS
# =====================================================

func test_set_tier_downgrade_2_to_0_blocked() -> void:
	## Downgrade from FULL_ORACLE to LOG_ONLY should be blocked
	controller.set_tier(FPCM_BattleTierController.TrackingTier.FULL_ORACLE)
	var result := controller.set_tier(FPCM_BattleTierController.TrackingTier.LOG_ONLY)
	assert_bool(result).is_false()
	assert_int(controller.current_tier).is_equal(FPCM_BattleTierController.TrackingTier.FULL_ORACLE)

func test_set_tier_downgrade_1_to_0_blocked() -> void:
	## Downgrade from ASSISTED to LOG_ONLY should be blocked
	controller.set_tier(FPCM_BattleTierController.TrackingTier.ASSISTED)
	var result := controller.set_tier(FPCM_BattleTierController.TrackingTier.LOG_ONLY)
	assert_bool(result).is_false()
	assert_int(controller.current_tier).is_equal(FPCM_BattleTierController.TrackingTier.ASSISTED)

func test_set_tier_force_allows_downgrade() -> void:
	## Force flag should allow downgrade
	controller.set_tier(FPCM_BattleTierController.TrackingTier.FULL_ORACLE)
	var result := controller.set_tier(FPCM_BattleTierController.TrackingTier.LOG_ONLY, true)
	assert_bool(result).is_true()
	assert_int(controller.current_tier).is_equal(FPCM_BattleTierController.TrackingTier.LOG_ONLY)

# =====================================================
# EDGE CASE TESTS
# =====================================================

func test_set_tier_same_tier_returns_true() -> void:
	## Setting same tier should return true (no-op success)
	var result := controller.set_tier(FPCM_BattleTierController.TrackingTier.LOG_ONLY)
	assert_bool(result).is_true()

func test_set_tier_invalid_negative_returns_false() -> void:
	## Negative tier value should be rejected
	var result := controller.set_tier(-1)
	assert_bool(result).is_false()
	assert_int(controller.current_tier).is_equal(FPCM_BattleTierController.TrackingTier.LOG_ONLY)

func test_set_tier_invalid_too_high_returns_false() -> void:
	## Tier value above max should be rejected
	var result := controller.set_tier(3)
	assert_bool(result).is_false()
	assert_int(controller.current_tier).is_equal(FPCM_BattleTierController.TrackingTier.LOG_ONLY)

# =====================================================
# SIGNAL TESTS
# =====================================================

func test_set_tier_emits_tier_changed_signal() -> void:
	## tier_changed signal should fire with old and new tier values
	var signal_data := [false, -1, -1]  # [fired, old_tier, new_tier]
	controller.tier_changed.connect(func(old_t: int, new_t: int):
		signal_data[0] = true
		signal_data[1] = old_t
		signal_data[2] = new_t
	)
	controller.set_tier(FPCM_BattleTierController.TrackingTier.ASSISTED)
	assert_bool(signal_data[0]).is_true()
	assert_int(signal_data[1]).is_equal(FPCM_BattleTierController.TrackingTier.LOG_ONLY)
	assert_int(signal_data[2]).is_equal(FPCM_BattleTierController.TrackingTier.ASSISTED)

func test_set_tier_same_does_not_emit_signal() -> void:
	## Setting same tier should not emit tier_changed signal
	var signal_fired := [false]
	controller.tier_changed.connect(func(_old: int, _new: int): signal_fired[0] = true)
	controller.set_tier(FPCM_BattleTierController.TrackingTier.LOG_ONLY)
	assert_bool(signal_fired[0]).is_false()
