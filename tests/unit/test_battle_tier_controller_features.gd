class_name TestBattleTierControllerFeatures
extends GdUnitTestSuite

## Unit tests for BattleTierController - Components & Feature Flags
##
## Tests cumulative component enablement (5/12/14 per tier),
## is_component_enabled() queries, and feature flag accuracy.

const BattleTierControllerClass = preload("res://src/core/battle/BattleTierController.gd")

var controller: FPCM_BattleTierController

func before_test() -> void:
	seed(12345)
	controller = BattleTierControllerClass.new()

func after_test() -> void:
	controller = null

# =====================================================
# COMPONENT COUNT TESTS
# =====================================================

func test_components_log_only_count_5() -> void:
	## LOG_ONLY tier should enable exactly 5 components
	controller.set_tier(FPCM_BattleTierController.TrackingTier.LOG_ONLY, true)
	var components := controller.get_enabled_components()
	assert_int(components.size()).is_equal(5)

func test_components_assisted_count_12() -> void:
	## ASSISTED tier should enable exactly 12 components
	controller.set_tier(FPCM_BattleTierController.TrackingTier.ASSISTED, true)
	var components := controller.get_enabled_components()
	assert_int(components.size()).is_equal(12)

func test_components_full_oracle_count_14() -> void:
	## FULL_ORACLE tier should enable exactly 14 components
	controller.set_tier(FPCM_BattleTierController.TrackingTier.FULL_ORACLE, true)
	var components := controller.get_enabled_components()
	assert_int(components.size()).is_equal(14)

# =====================================================
# CUMULATIVE INCLUSION TESTS
# =====================================================

func test_log_only_components_present_at_assisted() -> void:
	## All LOG_ONLY components should still be present at ASSISTED
	controller.set_tier(FPCM_BattleTierController.TrackingTier.ASSISTED, true)
	var components := controller.get_enabled_components()
	assert_bool(&"BattleJournal" in components).is_true()
	assert_bool(&"DiceDashboard" in components).is_true()
	assert_bool(&"BattleRoundHUD" in components).is_true()
	assert_bool(&"CharacterStatusCard" in components).is_true()
	assert_bool(&"CombatCalculator" in components).is_true()

func test_assisted_components_present_at_full_oracle() -> void:
	## All ASSISTED components should still be present at FULL_ORACLE
	controller.set_tier(FPCM_BattleTierController.TrackingTier.FULL_ORACLE, true)
	var components := controller.get_enabled_components()
	# Check a selection of ASSISTED-specific components
	assert_bool(&"MoralePanicTracker" in components).is_true()
	assert_bool(&"ActivationTrackerPanel" in components).is_true()
	assert_bool(&"InitiativeCalculator" in components).is_true()
	assert_bool(&"PreBattleChecklist" in components).is_true()

# =====================================================
# is_component_enabled() BOUNDARY TESTS
# =====================================================

func test_morale_tracker_disabled_at_log_only() -> void:
	## MoralePanicTracker should be disabled at LOG_ONLY
	controller.set_tier(FPCM_BattleTierController.TrackingTier.LOG_ONLY, true)
	assert_bool(controller.is_component_enabled(&"MoralePanicTracker")).is_false()

func test_morale_tracker_enabled_at_assisted() -> void:
	## MoralePanicTracker should be enabled at ASSISTED
	controller.set_tier(FPCM_BattleTierController.TrackingTier.ASSISTED, true)
	assert_bool(controller.is_component_enabled(&"MoralePanicTracker")).is_true()

func test_enemy_intent_disabled_at_assisted() -> void:
	## EnemyIntentPanel should be disabled at ASSISTED
	controller.set_tier(FPCM_BattleTierController.TrackingTier.ASSISTED, true)
	assert_bool(controller.is_component_enabled(&"EnemyIntentPanel")).is_false()

func test_enemy_intent_enabled_at_full_oracle() -> void:
	## EnemyIntentPanel should be enabled at FULL_ORACLE
	controller.set_tier(FPCM_BattleTierController.TrackingTier.FULL_ORACLE, true)
	assert_bool(controller.is_component_enabled(&"EnemyIntentPanel")).is_true()

# =====================================================
# FEATURE FLAG TESTS
# =====================================================

func test_feature_ai_oracle_false_at_log_only() -> void:
	## ai_oracle feature should be false at LOG_ONLY
	controller.set_tier(FPCM_BattleTierController.TrackingTier.LOG_ONLY, true)
	assert_bool(controller.is_feature_enabled("ai_oracle")).is_false()

func test_feature_ai_oracle_false_at_assisted() -> void:
	## ai_oracle feature should be false at ASSISTED
	controller.set_tier(FPCM_BattleTierController.TrackingTier.ASSISTED, true)
	assert_bool(controller.is_feature_enabled("ai_oracle")).is_false()

func test_feature_ai_oracle_true_at_full_oracle() -> void:
	## ai_oracle feature should be true at FULL_ORACLE
	controller.set_tier(FPCM_BattleTierController.TrackingTier.FULL_ORACLE, true)
	assert_bool(controller.is_feature_enabled("ai_oracle")).is_true()

func test_feature_nonexistent_returns_false() -> void:
	## Nonexistent feature flag should return false
	assert_bool(controller.is_feature_enabled("nonexistent_feature")).is_false()
