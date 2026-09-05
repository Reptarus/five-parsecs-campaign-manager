extends GdUnitTestSuite
## Every Seize the Initiative modifier must reach the roll (Core Rules p.112:
## 2D6 + highest Savvy + modifiers >= 10).
##
## THE BUG THIS PINS (2026-09-04). There are two producers of a seize modifier
## and the context builder read only one of them:
##
##   WRITER                                          KEY            READ?
##   EnemyGenerator.gd:1580 (category + traits)      first_enemy    yes
##   CampaignTurnController:1172 Black Job +1 p.151  mission_data   NO
##   _stamp_narrative_battle_config Intro +/-1       mission_data   NO
##   CampaignTurnController:1692 no_seize_initiative mission_data   NO
##
## A repo-wide grep for a read of mission_data["seize_initiative_modifier"]
## returned only the two writes incrementing themselves. So the Black Job's +1 -
## which CLAUDE.md records as shipped on 2026-08-07 - was rolled, stored, printed
## on the prep card, and applied to nothing.
##
## Ordering was never the cause, though it looks like it from line numbers: the
## Intro stamp's BODY is at :1630-1694 but it is CALLED at :1153, well before the
## context is built at ~:1400. Both halves simply addressed different dicts.

const CTCScript = preload("res://src/ui/screens/campaign/CampaignTurnController.gd")
const BlackZoneSystemRef = preload("res://src/core/mission/BlackZoneSystem.gd")


func _ctc() -> Node:
	# Never added to the tree: _ready() would launch real campaign wiring. The
	# four functions under test are pure over their two Dictionary arguments.
	var n: Node = CTCScript.new()
	auto_free(n)
	return n


# --- the sum --------------------------------------------------------------

func test_the_enemy_modifier_alone_still_applies() -> void:
	var c := _ctc()
	assert_int(c._seize_modifier_total({"seize_initiative_modifier": -1}, {})).is_equal(-1)


func test_a_mission_modifier_alone_reaches_the_roll() -> void:
	# This is the case that was inert: nothing read the mission_data key.
	var c := _ctc()
	assert_int(c._seize_modifier_total({}, {"seize_initiative_modifier": 1})
		).override_failure_message(
			"a modifier stamped on mission_data must reach the roll — the Black"
			+ " Job +1 (p.151) and the Introductory Campaign both write here"
		).is_equal(1)


func test_both_producers_sum() -> void:
	# They are independent rules and can co-occur: a Black Job against an enemy
	# category that already carries a modifier.
	var c := _ctc()
	assert_int(c._seize_modifier_total(
		{"seize_initiative_modifier": -1}, {"seize_initiative_modifier": 1})
		).is_equal(0)


func test_absent_keys_are_zero_not_an_error() -> void:
	var c := _ctc()
	assert_int(c._seize_modifier_total({}, {})).is_equal(0)


func test_the_black_job_bonus_is_the_value_the_book_gives() -> void:
	# Core Rules p.151. Read from BlackZoneSystem rather than hardcoded here, so
	# this cannot drift from the data the mechanic uses.
	var setup: Dictionary = BlackZoneSystemRef.get_setup_rules()
	var bonus: int = int(setup.get("seize_initiative_bonus", 0))
	assert_int(bonus).override_failure_message(
		"BlackZoneSystem must still supply the p.151 Seize bonus"
	).is_equal(1)
	var c := _ctc()
	assert_int(c._seize_modifier_total({}, {"seize_initiative_modifier": bonus})
		).is_equal(1)


# --- the single suppression gate -----------------------------------------

func test_seizing_is_allowed_by_default() -> void:
	var c := _ctc()
	assert_bool(c._can_seize_initiative({}, {})).is_true()
	assert_str(c._cannot_seize_reason({}, {})).is_empty()


func test_a_rival_ambush_forbids_the_roll() -> void:
	# Core Rules p.91 — the only scenario in the battle chapter that bans it.
	var c := _ctc()
	assert_bool(c._can_seize_initiative({"can_seize_initiative": false}, {})).is_false()
	assert_str(c._cannot_seize_reason({"can_seize_initiative": false}, {})
		).contains("p.91")


func test_the_introductory_ban_is_enforced() -> void:
	# mission_data["no_seize_initiative"] was written at :1692 and had NO reader
	# anywhere, so the introductory scenario's ban did nothing.
	var c := _ctc()
	assert_bool(c._can_seize_initiative({}, {"no_seize_initiative": true})
		).override_failure_message(
			"an introductory battle that forbids Seize must actually forbid it"
		).is_false()
	assert_str(c._cannot_seize_reason({}, {"no_seize_initiative": true})).is_not_empty()


func test_either_ban_alone_is_enough() -> void:
	var c := _ctc()
	assert_bool(c._can_seize_initiative(
		{"can_seize_initiative": false}, {"no_seize_initiative": true})).is_false()
	# ...and an explicit "allowed" from one producer cannot override the other.
	assert_bool(c._can_seize_initiative(
		{"can_seize_initiative": true}, {"no_seize_initiative": true})
		).override_failure_message(
			"one producer permitting the roll must not overrule another forbidding it"
		).is_false()
