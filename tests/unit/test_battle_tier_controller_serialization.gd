class_name TestBattleTierControllerSerialization
extends GdUnitTestSuite

## Unit tests for BattleTierController - Serialization & Tier Info
##
## Tests round-trip serialize/deserialize, empty data defaults,
## and get_tier_info() display data.

const BattleTierControllerClass = preload("res://src/core/battle/BattleTierController.gd")

var controller: FPCM_BattleTierController

func before_test() -> void:
	seed(12345)
	controller = BattleTierControllerClass.new()

func after_test() -> void:
	controller = null

# =====================================================
# SERIALIZATION TESTS
# =====================================================

func test_serialize_returns_current_tier() -> void:
	## serialize() should include current tier value
	var data := controller.serialize()
	assert_int(data.get("current_tier", -1)).is_equal(FPCM_BattleTierController.TrackingTier.LOG_ONLY)

func test_serialize_after_set_tier() -> void:
	## serialize() after set_tier should reflect new tier
	controller.set_tier(FPCM_BattleTierController.TrackingTier.FULL_ORACLE, true)
	var data := controller.serialize()
	assert_int(data.get("current_tier", -1)).is_equal(FPCM_BattleTierController.TrackingTier.FULL_ORACLE)

func test_deserialize_restores_tier() -> void:
	## deserialize() should restore tier from saved data
	controller.deserialize({"current_tier": FPCM_BattleTierController.TrackingTier.FULL_ORACLE})
	assert_int(controller.get_current_tier()).is_equal(FPCM_BattleTierController.TrackingTier.FULL_ORACLE)

func test_deserialize_empty_dict_defaults_to_log_only() -> void:
	## deserialize() with empty dict should default to LOG_ONLY
	controller.set_tier(FPCM_BattleTierController.TrackingTier.FULL_ORACLE, true)
	controller.deserialize({})
	assert_int(controller.get_current_tier()).is_equal(FPCM_BattleTierController.TrackingTier.LOG_ONLY)

func test_roundtrip_serialize_deserialize() -> void:
	## Round-trip serialize then deserialize should preserve tier
	controller.set_tier(FPCM_BattleTierController.TrackingTier.ASSISTED, true)
	var data := controller.serialize()

	var restored := BattleTierControllerClass.new()
	restored.deserialize(data)
	assert_int(restored.get_current_tier()).is_equal(FPCM_BattleTierController.TrackingTier.ASSISTED)

# =====================================================
# TIER INFO TESTS
# =====================================================

func test_get_tier_info_log_only_name() -> void:
	## get_tier_info() for LOG_ONLY should return "Log Only"
	var info := controller.get_tier_info(FPCM_BattleTierController.TrackingTier.LOG_ONLY)
	assert_str(info.get("name", "")).is_equal("Log Only")

func test_get_tier_info_assisted_name() -> void:
	## get_tier_info() for ASSISTED should return "Assisted"
	var info := controller.get_tier_info(FPCM_BattleTierController.TrackingTier.ASSISTED)
	assert_str(info.get("name", "")).is_equal("Assisted")

func test_get_tier_info_full_oracle_name() -> void:
	## get_tier_info() for FULL_ORACLE should return "Full Oracle"
	var info := controller.get_tier_info(FPCM_BattleTierController.TrackingTier.FULL_ORACLE)
	assert_str(info.get("name", "")).is_equal("Full Oracle")

func test_get_tier_info_default_uses_current_tier() -> void:
	## get_tier_info() with no arg should use current tier
	controller.set_tier(FPCM_BattleTierController.TrackingTier.ASSISTED, true)
	var info := controller.get_tier_info()
	assert_str(info.get("name", "")).is_equal("Assisted")

func test_get_tier_info_invalid_returns_empty() -> void:
	## get_tier_info() with invalid tier should return empty dict
	var info := controller.get_tier_info(99)
	assert_int(info.size()).is_equal(0)
