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


# ============================================================================
# T11-19 — the seam must reach the BACKEND Character Event, not just the button
# ============================================================================
#
# THE DEFECT (device, deploy #19). Queueing a Character Event value did nothing.
# PostBattleSequence's per-crew button already routed through
# DiceManager.roll_d100("Character Event: <name>") (:2171) — but the path that
# actually fires when the orchestrator resolves step 13,
# CharacterEventEffects.process_character_event(), used a bare randi_range(1, 100).
# So the fix that was supposed to unblock T9-51 (rows 88-91 / 92-94, desk-verified
# only since 2026-08-14) could not be exercised in play.
#
# ⚠ THIS CASE MUST USE THE AUTOLOAD, not the fresh _dm instance the rest of the suite
# builds. CharacterEventEffects is RefCounted and reaches /root/DiceManager through
# Engine.get_main_loop().root — a bare get_node_or_null("/root/...") from a RefCounted
# ERRORS and aborts the enclosing function rather than returning null. Queueing on a
# detached instance would therefore assert against a DiceManager the production code
# never consults, and pass whether or not the fix is present.

const CampaignEventEffectsScript = preload(
	"res://src/core/campaign/phases/post_battle/CampaignEventEffects.gd")
const CharacterEventEffectsScript = preload(
	"res://src/core/campaign/phases/post_battle/CharacterEventEffects.gd")
const PostBattleContextClass = preload(
	"res://src/core/campaign/phases/post_battle/PostBattleContext.gd")
const CampaignCoreScript = preload(
	"res://src/game/campaign/FiveParsecsCampaignCore.gd")


func _ctx_with_one_human() -> Variant:
	var campaign = CampaignCoreScript.new()
	campaign.from_dictionary({
		"campaign_id": "t11_19",
		"crew": {"members": [
			# Human, so the Precursor double-roll branch cannot fire and consume a
			# second queued value — the single-roll path is what is under test.
			{"character_id": "c1", "character_name": "Bryn Ito",
				"origin": "human", "species_id": "human"},
		]},
	})
	var ctx = PostBattleContextClass.new()
	ctx.campaign = campaign
	ctx.crew_participants = ["c1"]
	ctx.battle_result = {"victory": true, "won": true, "turn": 1}
	return ctx


func test_a_forced_value_reaches_the_backend_character_event() -> void:
	var autoload_dm: Node = get_node_or_null("/root/DiceManager")
	assert_object(autoload_dm).override_failure_message(
		"/root/DiceManager autoload missing — the production path cannot be tested."
	).is_not_null()
	autoload_dm.clear_forced_results()
	# Matching is a case-insensitive SUBSTRING, so this is the key a tester types.
	autoload_dm.queue_forced_result("character event", 88)

	var effects = CharacterEventEffectsScript.new()
	var event: Dictionary = effects.process_character_event(_ctx_with_one_human())
	autoload_dm.clear_forced_results()

	assert_int(int(event.get("roll", -1))).override_failure_message(
		"The backend Character Event rolled %s instead of the queued 88 — the "
		% [event.get("roll", "?")] + "forced-roll seam does not reach it."
	).is_equal(88)
	# ...and 88 must land on the row the book puts there, not merely be echoed back.
	# character_events.json: [88, 91] = "Don't Make Them Like They Used To"
	# (type item_damage). Asserting the ROW proves the value drove the lookup.
	assert_str(str(event.get("name", ""))).is_equal(
		"Don't Make Them Like They Used To")
	assert_str(str(event.get("type", ""))).is_equal("item_damage")


func test_the_92_94_row_is_reachable_too() -> void:
	var autoload_dm: Node = get_node_or_null("/root/DiceManager")
	autoload_dm.clear_forced_results()
	autoload_dm.queue_forced_result("character event", 93)

	var effects = CharacterEventEffectsScript.new()
	var event: Dictionary = effects.process_character_event(_ctx_with_one_human())
	autoload_dm.clear_forced_results()

	assert_int(int(event.get("roll", -1))).is_equal(93)
	assert_str(str(event.get("name", ""))).is_equal("Where Did It Go")


## T11-19b - the CAMPAIGN event is a different roll on a different step from the
## CHARACTER event above, and it was the one the seam did not reach. Without it
## T11-25 (Old Nemesis) and T11-35 (Got Noticed) are 3-in-100 per battle and
## cannot be walked on device.
func test_a_forced_value_reaches_the_backend_campaign_event() -> void:
	var autoload_dm: Node = get_node_or_null("/root/DiceManager")
	assert_object(autoload_dm).override_failure_message(
		"/root/DiceManager autoload missing - the production path cannot be tested."
	).is_not_null()
	autoload_dm.clear_forced_results()
	autoload_dm.queue_forced_result("campaign event", 21)

	var effects = CampaignEventEffectsScript.new()
	var event: Dictionary = effects.process_campaign_event(_ctx_with_one_human())
	autoload_dm.clear_forced_results()

	assert_int(int(event.get("roll", -1))).override_failure_message(
		"The backend Campaign Event rolled %s instead of the queued 21 - the "
		% [event.get("roll", "?")] + "forced-roll seam does not reach it."
	).is_equal(21)
	# 21 must land on the row the BOOK puts there, not merely be echoed back.
	# campaign_events.json [21, 23] = "Old Nemesis" (Core Rules p.126).
	# Asserting the ROW proves the value drove the lookup.
	assert_str(str(event.get("name", ""))).is_equal("Old Nemesis")


func test_the_got_noticed_row_is_reachable_too() -> void:
	var autoload_dm: Node = get_node_or_null("/root/DiceManager")
	autoload_dm.clear_forced_results()
	autoload_dm.queue_forced_result("campaign event", 89)

	var effects = CampaignEventEffectsScript.new()
	var event: Dictionary = effects.process_campaign_event(_ctx_with_one_human())
	autoload_dm.clear_forced_results()

	assert_int(int(event.get("roll", -1))).is_equal(89)
	# The rolls are 89-91, NOT the 88-91 an earlier working note claimed.
	assert_str(str(event.get("name", ""))).is_equal("Got Noticed")


## Both keys contain the word "Event", and matching is a case-insensitive
## SUBSTRING, so this is the case that would catch one queue eating the other.
func test_the_campaign_and_character_queues_do_not_consume_each_other() -> void:
	var autoload_dm: Node = get_node_or_null("/root/DiceManager")
	autoload_dm.clear_forced_results()
	autoload_dm.queue_forced_result("campaign event", 21)
	autoload_dm.queue_forced_result("character event", 88)

	var campaign_effects = CampaignEventEffectsScript.new()
	var campaign_event: Dictionary = campaign_effects.process_campaign_event(
		_ctx_with_one_human())
	var character_effects = CharacterEventEffectsScript.new()
	var character_event: Dictionary = character_effects.process_character_event(
		_ctx_with_one_human())
	autoload_dm.clear_forced_results()

	assert_int(int(campaign_event.get("roll", -1))).override_failure_message(
		"The campaign event took %s - the character-event queue was consumed by it."
		% [campaign_event.get("roll", "?")]).is_equal(21)
	assert_int(int(character_event.get("roll", -1))).override_failure_message(
		"The character event took %s - the campaign-event queue was consumed by it."
		% [character_event.get("roll", "?")]).is_equal(88)
	assert_str(str(campaign_event.get("name", ""))).is_equal("Old Nemesis")
	assert_str(str(character_event.get("name", ""))).is_equal(
		"Don't Make Them Like They Used To")
