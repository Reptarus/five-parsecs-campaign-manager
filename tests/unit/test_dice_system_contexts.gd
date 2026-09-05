extends GdUnitTestSuite
## DiceSystem roll contexts (src/core/systems/DiceSystem.gd).
##
## Extracted 2026-09-04 from tests/integration/test_battle_ui_components.gd, which was
## deleted. That suite carried 13 cases, but 10 of them returned before asserting
## anything: its setup set `event_bus = null` because FPCM_BattleEventBus was removed in
## Feb 2026, and every signal-routing case was guarded by is_instance_valid(event_bus).
## Two more drove FPCM_BattleManager / FPCM_BattleState, both production-dead and
## deleted. This case was the suite's only real coverage — and DiceSystem has no other
## test suite anywhere (tests/helpers/MockDiceSystem.gd is a fixture, not a test), so
## losing it would have left the roller untested entirely.

const FPCM_DiceSystem = preload("res://src/core/systems/DiceSystem.gd")

var dice_system: FPCM_DiceSystem = null


func before_test() -> void:
	seed(12345)
	dice_system = auto_free(FPCM_DiceSystem.new())


func after_test() -> void:
	dice_system = null


func test_multiple_dice_rolls_tracked_independently() -> void:
	## Concurrent rolls must keep their own context tag — the context is how a
	## caller tells its roll apart from anyone else's.
	var results: Array[FPCM_DiceSystem.DiceRoll] = []
	for i in range(3):
		var result: FPCM_DiceSystem.DiceRoll = dice_system.roll_dice(
			FPCM_DiceSystem.DicePattern.D6, "multi_roll_" + str(i))
		results.append(result)

	assert_array(results).has_size(3)
	assert_str(results[0].context).is_equal("multi_roll_0")
	assert_str(results[1].context).is_equal("multi_roll_1")
	assert_str(results[2].context).is_equal("multi_roll_2")
