extends GdUnitTestSuite
## Fake ID (+1) on the p.72 forged-licence attempt.
##
## BOOK, verbatim:
##   p.72 - "You may attempt to obtain a forged License. Select a crew member and
##   roll 1D6+Savvy. If the score is a 6+, you obtain a License for free. If the
##   roll is a 1 before modifiers, you must add a Rival on this world... Only one
##   attempt is permitted."
##   p.57 - Fake ID: "Add +1 to all attempts to obtain a license or other legal
##   document."
##
## WHAT THIS CAUGHT (2026-09-04). "all attempts" reached the p.75 Interdiction
## roll (InterdictionRule.gd:156 calls OnboardItemService.license_bonus) but NOT
## this p.72 roll, which computed `roll + savvy` and nothing else. So a Fake ID did
## nothing on the one roll the item is named for. The bonus is now resolved inside
## attempt_forged_licence(), not supplied by the caller, because a caller-supplied
## bonus is exactly what went missing.
##
## This suite used to drive src/core/campaign/phases/TravelPhase.gd - a file with
## ZERO instantiations, whose only remaining reference was this test. Its copy of
## the rule also read the book differently and WRONGLY: it returned early on a
## natural 1 with success=false. The book states two INDEPENDENT clauses, so a
## natural 1 that still totals 6+ both succeeds AND adds a Rival. The live
## implementation is the literal one; the dead one was not.

const NewWorldArrivalRef = preload("res://src/core/campaign/NewWorldArrival.gd")

const PLANET := "test_world_p72"


class FakeCampaign extends Resource:
	var equipment_data: Dictionary = {"equipment": []}
	var progress_data: Dictionary = {}
	var rivals: Array = []


func _campaign(stash: Array = []) -> FakeCampaign:
	var c := FakeCampaign.new()
	c.equipment_data = {"equipment": stash.duplicate(true)}
	c.progress_data = {"turns_played": 5}
	return c


## A seeded RNG whose first randi_range(1, 6) is `want`. Seeded rather than
## looped-until-lucky so the natural-1 case is deterministic instead of a flake.
func _rng_rolling(want: int) -> RandomNumberGenerator:
	for seed_value: int in range(1, 4000):
		var probe := RandomNumberGenerator.new()
		probe.seed = seed_value
		if probe.randi_range(1, 6) == want:
			var out := RandomNumberGenerator.new()
			out.seed = seed_value
			return out
	fail("no seed in 1..4000 rolls a %d - cannot build a deterministic case" % want)
	return RandomNumberGenerator.new()


func test_no_fake_id_means_no_bonus() -> void:
	var c := _campaign()
	var r: Dictionary = NewWorldArrivalRef.attempt_forged_licence(
		c, PLANET, 2, _rng_rolling(3))
	assert_int(int(r["fake_id_bonus"])).is_equal(0)
	assert_int(int(r["total"])).is_equal(int(r["roll"]) + 2)


func test_fake_id_in_stash_adds_one() -> void:
	var c := _campaign([{"id": "fake_id", "name": "Fake ID", "type": "Gear"}])
	var r: Dictionary = NewWorldArrivalRef.attempt_forged_licence(
		c, PLANET, 2, _rng_rolling(3))
	assert_int(int(r["fake_id_bonus"])).override_failure_message(
		"p.57 says +1 to ALL attempts to obtain a license").is_equal(1)
	assert_int(int(r["total"])).is_equal(int(r["roll"]) + 2 + 1)


func test_fake_id_is_matched_by_name_not_only_by_id() -> void:
	# Fake ID is acquirable off the Gear table and the ship-items loot table, and
	# those rows carry a name, not the on-board id.
	var c := _campaign([{"name": "fake id"}])
	var r: Dictionary = NewWorldArrivalRef.attempt_forged_licence(
		c, PLANET, 0, _rng_rolling(3))
	assert_int(int(r["fake_id_bonus"])).is_equal(1)


func test_the_bonus_turns_a_five_into_a_pass() -> void:
	# The whole point of the item: 1D6 of 4 + Savvy 1 = 5, one short of the 6+
	# target, and the Fake ID carries it.
	var without := _campaign()
	var r1: Dictionary = NewWorldArrivalRef.attempt_forged_licence(
		without, PLANET, 1, _rng_rolling(4))
	assert_int(int(r1["total"])).is_equal(5)
	assert_bool(bool(r1["success"])).is_false()

	var with_id := _campaign([{"name": "Fake ID"}])
	var r2: Dictionary = NewWorldArrivalRef.attempt_forged_licence(
		with_id, PLANET, 1, _rng_rolling(4))
	assert_int(int(r2["total"])).is_equal(6)
	assert_bool(bool(r2["success"])).override_failure_message(
		"1D6 4 + Savvy 1 + Fake ID 1 = 6 must clear the 6+ target").is_true()


func test_fake_id_does_not_protect_against_a_natural_one() -> void:
	# "If the roll is a 1 BEFORE MODIFIERS" - the raw die, so no amount of Savvy or
	# forgery kit keeps the law off you. That asymmetry IS the gamble.
	var c := _campaign([{"name": "Fake ID"}])
	var r: Dictionary = NewWorldArrivalRef.attempt_forged_licence(
		c, PLANET, 4, _rng_rolling(1))
	assert_int(int(r["roll"])).is_equal(1)
	assert_bool(bool(r["natural_one"])).is_true()
	assert_bool(bool(r["adds_rival"])).override_failure_message(
		"a natural 1 must add a Rival even with a Fake ID").is_true()
	# ...and the two clauses are INDEPENDENT: 1 + Savvy 4 + Fake ID 1 = 6, so this
	# attempt both succeeds and gets you a Rival. The dead TravelPhase copy
	# returned early here and reported failure, which the book does not say.
	assert_int(int(r["total"])).is_equal(6)
	assert_bool(bool(r["success"])).is_true()


func test_only_one_attempt_is_permitted_per_world() -> void:
	var c := _campaign()
	NewWorldArrivalRef.attempt_forged_licence(c, PLANET, 2, _rng_rolling(3))
	var second: Dictionary = NewWorldArrivalRef.attempt_forged_licence(
		c, PLANET, 2, _rng_rolling(3))
	assert_str(str(second["reason"])).override_failure_message(
		"p.72: Only one attempt is permitted").contains("Only one attempt")
	assert_int(int(second["roll"])).is_equal(0)


func test_a_successful_forgery_grants_the_licence() -> void:
	var c := _campaign([{"name": "Fake ID"}])
	var r: Dictionary = NewWorldArrivalRef.attempt_forged_licence(
		c, PLANET, 3, _rng_rolling(5))
	assert_bool(bool(r["success"])).is_true()
	assert_bool(NewWorldArrivalRef.requires_freelancer_licence(c, PLANET)).override_failure_message(
		"a passed forgery must record the licence as held (p.72, in perpetuity)"
		).is_false()
