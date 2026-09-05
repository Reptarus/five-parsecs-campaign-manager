extends GdUnitTestSuite
## The debug-only forced-roll seam (DiceManager.queue_forced_result).
##
## WHY IT EXISTS: three fixes have been stuck desk-verified since 2026-08-14
## because no in-app tool can force a table roll -
## docs/qa/PICKUP_2026-08-14.md section 3. Rival AMBUSH is a D10 of 1; the two
## crew-task rows are D100 51-53 and 76-78; the character-event rows are 88-91
## and 92-94. Widening the shipped roll_range was declined twice, because it
## means testing a build whose rules data differs from ship.
##
## WHAT IS NOT TESTED HERE: the release-build branch. OS.is_debug_build() is
## true under the test runner, so the early return can only be read, not run.
## Stated rather than papered over.

const DiceManagerScript = preload("res://src/core/managers/DiceManager.gd")
const MissionTables = preload("res://src/core/mission/MissionTableManager.gd")

var _dm: Node = null


func before_test() -> void:
	# A fresh instance, not the /root/DiceManager autoload: a suite-level object
	# would leak queued values between cases, which is exactly the shared-state
	# flake this project has been bitten by before.
	_dm = DiceManagerScript.new()
	add_child(_dm)
	auto_free(_dm)


func test_a_queued_value_is_returned_by_the_next_matching_roll() -> void:
	assert_bool(_dm.queue_forced_result("Rival Attack Type", 1)).is_true()
	assert_int(_dm.roll_d10("Rival Attack Type")).is_equal(1)


func test_a_queued_value_is_consumed_exactly_once() -> void:
	_dm.queue_forced_result("Trade Table", 77)
	assert_int(_dm.roll_d100("Trade Table")).is_equal(77)
	# The queue is now empty, so the next roll must be random again. 40 rolls
	# that all came back 77 by chance is (1/100)^40 - if this ever fires, the
	# value is stuck, not unlucky.
	var stuck: bool = true
	for i: int in range(40):
		if _dm.roll_d100("Trade Table") != 77:
			stuck = false
			break
	assert_bool(stuck).override_failure_message(
		"forced value was not consumed - it kept being returned").is_false()


func test_matching_is_case_insensitive_and_substring() -> void:
	# The live context carries runtime detail: PostBattleSequence rolls with
	# "Character Event: <crew name>", so QA must be able to queue on the stem.
	_dm.queue_forced_result("character event", 90)
	assert_int(_dm.roll_d100("Character Event: Bryn Ito")).is_equal(90)


func test_a_different_context_does_not_consume_the_value() -> void:
	_dm.queue_forced_result("Rival Attack Type", 1)
	# An unrelated roll must not eat it...
	_dm.roll_d10("Danger Pay")
	# ...so it is still there for the roll it was meant for.
	assert_int(_dm.roll_d10("Rival Attack Type")).is_equal(1)


func test_values_for_one_context_come_back_in_order() -> void:
	_dm.queue_forced_result("Loot Category", 12)
	_dm.queue_forced_result("Loot Category", 34)
	assert_int(_dm.roll_d100("Loot Category")).is_equal(12)
	assert_int(_dm.roll_d100("Loot Category")).is_equal(34)


func test_a_value_outside_the_die_is_discarded_not_clamped() -> void:
	# Clamping would silently hand QA a different table row than it asked for,
	# which is worse than rolling: the tester would record a verified row that
	# was never actually exercised.
	_dm.queue_forced_result("Rival Attack Type", 55)
	var rolled: int = _dm.roll_d10("Rival Attack Type")
	assert_int(rolled).override_failure_message(
		"out-of-range forced value leaked into a D10").is_between(1, 10)
	# NOT "rolled != 10": discarding means the roll is genuinely random, and a
	# random D10 returns 10 one time in ten - that assertion was a 10%% flake.
	# What actually separates discard from clamp is that the entry is gone and
	# so cannot come back on a later roll.
	assert_dict(_dm.get_forced_results()).override_failure_message(
		"the illegal value is still queued and will fire on a later roll"
		).is_empty()
	var stuck_at_ten: bool = true
	for i: int in range(40):
		if _dm.roll_d10("Rival Attack Type") != 10:
			stuck_at_ten = false
			break
	assert_bool(stuck_at_ten).override_failure_message(
		"55 was clamped to 10 instead of discarded").is_false()


func test_clearing_removes_queued_values() -> void:
	_dm.queue_forced_result("Mission Objective", 3)
	_dm.clear_forced_results()
	assert_dict(_dm.get_forced_results()).is_empty()


func test_an_empty_key_is_rejected() -> void:
	assert_bool(_dm.queue_forced_result("   ", 5)).is_false()
	assert_dict(_dm.get_forced_results()).is_empty()


func test_the_forced_roll_is_labelled_in_the_roll_history() -> void:
	# The ledger entry for a device run has to be able to show that a row was
	# reached by forcing, not by luck.
	_dm.queue_forced_result("Exploration Table", 52)
	_dm.roll_d100("Exploration Table")
	var history: Array = _dm.get_roll_history_data(1)
	assert_int(history.size()).is_equal(1)
	assert_str(str(history[0].get("dice_type", ""))).contains("forced")


## T9-48: prove the seam actually reaches the Rival Attack Type roll. This is
## the routing test - the contract cases above would all pass with the roll site
## still calling randi_range() directly.
##
## MissionTableManager is RefCounted and always built detached with .new(), so it
## reaches the autoload via Engine.get_main_loop(); a bare get_node_or_null()
## there would ERROR and abort the roll. Hence this case uses the real autoload.
func test_rival_attack_type_honours_a_forced_roll() -> void:
	var autoload_dm: Node = get_node_or_null("/root/DiceManager")
	if autoload_dm == null or not autoload_dm.has_method("queue_forced_result"):
		fail("DiceManager autoload missing - the routing cannot be verified")
		return
	autoload_dm.clear_forced_results()
	autoload_dm.queue_forced_result("Rival Attack Type", 1)
	var tables = MissionTables.new()
	var attack: Dictionary = tables.roll_rival_attack_type(false)
	autoload_dm.clear_forced_results()
	assert_int(int(attack.get("roll", -1))).override_failure_message(
		"the roll site is not routed through DiceManager").is_equal(1)
	assert_str(str(attack.get("type", ""))).override_failure_message(
		"D10 of 1 must select AMBUSH (Core Rules p.91)").is_equal("AMBUSH")


## A forced roll must still resolve through the real shipped table, not a
## shortcut - otherwise the device run would verify a fiction.
func test_a_forced_rival_roll_still_reads_the_shipped_table() -> void:
	var autoload_dm: Node = get_node_or_null("/root/DiceManager")
	if autoload_dm == null:
		fail("DiceManager autoload missing")
		return
	var tables = MissionTables.new()
	autoload_dm.clear_forced_results()
	autoload_dm.queue_forced_result("Rival Attack Type", 9)
	var raid: Dictionary = tables.roll_rival_attack_type(false)
	autoload_dm.clear_forced_results()
	assert_str(str(raid.get("type", ""))).override_failure_message(
		"D10 of 9 must select RAID (rival_involvement.json roll_range 9-10)"
		).is_equal("RAID")
