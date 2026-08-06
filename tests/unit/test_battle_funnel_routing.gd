extends GdUnitTestSuite
## The data funnel INTO and OUT OF the battle phase (Core Rules pp.85, 119-121).
##
## Every case here pins a JOIN, not a calculation. The audit that produced this
## suite found the same shape six times over: a post-battle consumer reading a
## key that no producer anywhere in the codebase ever wrote. The rule was
## implemented, correctly, and gated on data that never arrived — so it could
## not fire, and nothing errored, because a `.get(key, default)` on a missing key
## is a silent default rather than a fault.
##
## WHAT WAS UNREACHABLE BEFORE THESE FIXES:
##   p.85  Check for Rivals ....... never ran at all (see RIVAL CHECK below)
##   p.119 Resolve Rival Status ... removal roll unreachable; no Invasion /
##                                  Roving Threats skip
##   p.119 Resolve Patron Status .. BOTH branches inert (no patron_id)
##   p.120 Get Paid ............... "Invasion: no payment" unreachable
##   p.120 Battlefield Finds ...... no Hold-the-Field gate, no Invasion
##                                  exclusion, and one roll PER CREW MEMBER
##   p.121 Check for Invasion ..... never fired (no enemy_is_invasion_threat)
##   p.121 Gather the Loot ........ "Invasion: no Loot" unreachable

const RivalCheck = preload("res://src/core/campaign/RivalEncounterCheck.gd")
const Normalizer = preload("res://src/core/battle/BattleResultNormalizer.gd")
const PaymentProcessorClass = preload("res://src/core/campaign/phases/post_battle/PaymentProcessor.gd")
const RivalPatronResolverClass = preload("res://src/core/campaign/phases/post_battle/RivalPatronResolver.gd")
const ContextClass = preload("res://src/core/campaign/phases/post_battle/PostBattleContext.gd")

func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r

## A crew big enough that the OLD per-participant Finds loop would produce finds.
## An empty crew made the two gate assertions below vacuous: `for _i in range(0)`
## returns nothing, so they passed against the very code they were meant to catch.
const _CREW_SIZE := 6

func _ctx(battle_result: Dictionary) -> ContextClass:
	var c: ContextClass = ContextClass.new()
	c.battle_result = battle_result
	c.crew_participants = []
	for i in _CREW_SIZE:
		c.crew_participants.append({"character_id": "c%d" % i, "character_name": "Crew %d" % i})
	c.defeated_enemies = []
	return c

## Minimal stand-ins for the campaign the Rival step writes to. WITHOUT these,
## _create_new_rival_from_battle() returns "" at its first guard and no Rival is
## ever recorded — so a test asserting "no new Rival" passed no matter what the
## code did. The stub makes the un-skipped path actually able to create one,
## which is the only way the skip can be shown to be doing the work.
class StubCampaign:
	var rivals: Array = []

class StubGameState:
	var current_campaign: StubCampaign = null

func _ctx_with_campaign(battle_result: Dictionary) -> ContextClass:
	var c: ContextClass = _ctx(battle_result)
	var gs := StubGameState.new()
	gs.current_campaign = StubCampaign.new()
	c.game_state = gs
	c.campaign = gs.current_campaign
	return c

# ══════════════════════════════════════════════════════════════════════════
# RIVAL CHECK — Core Rules p.85, World Step 6 "Check for Rivals"
#
# "Tally up the number of Rivals you have, and roll a D6. If the roll is equal
# to or lower than the number of Rivals, one of them has tracked you down [...]
# Select the exact Rival at random from those on your list."
#
# This never executed. CampaignTurnController asked RivalBattleGenerator for
# `check_rival_encounter()` — a method with ZERO definitions repo-wide, so the
# guard was permanently false — and the fallback keyed off
# progress_data["rival_count"], which nothing writes, so it returned before
# rolling. Rivals could not track the crew down in any campaign.
# ══════════════════════════════════════════════════════════════════════════

func test_no_rivals_means_no_check() -> void:
	var out: Dictionary = RivalCheck.check([], 0, _rng(1))
	assert_bool(out["has_encounter"]).is_false()

func test_a_roll_at_or_below_the_rival_count_is_an_encounter() -> void:
	# 4 Rivals: a D6 can only exceed 4 on a 5 or 6, so across many seeds we must
	# see encounters, and every one must name a Rival that is actually on the list.
	var rivals: Array = ["Red Sal", "The Vulture", "Kite Syndicate", "Grix"]
	var encounters: int = 0
	for s in range(1, 60):
		var out: Dictionary = RivalCheck.check(rivals, 0, _rng(s))
		if out["has_encounter"]:
			encounters += 1
			assert_array(rivals).override_failure_message(
				"p.85: the Rival fought must be one from your list"
			).contains([out["rival_id"]])
	assert_int(encounters).override_failure_message(
		"p.85: with 4 Rivals a D6 must land <= 4 sometimes").is_greater(0)

func test_a_roll_above_the_rival_count_evades() -> void:
	# One Rival: the roll must be exactly 1 to be caught, so most seeds evade.
	var evaded: int = 0
	for s in range(1, 40):
		if not RivalCheck.check(["Solo Rival"], 0, _rng(s))["has_encounter"]:
			evaded += 1
	assert_int(evaded).is_greater(0)

func test_every_encounter_carries_the_id_the_removal_roll_needs() -> void:
	# THE POINT OF THE WHOLE FIX. Without an id, post-battle Step 1 cannot tell
	# that the fight WAS a Rival fight, so the p.119 removal roll never happens
	# and holding the field against a Rival can only ever ADD Rivals.
	var rivals: Array = [{"id": "rival_kite", "name": "Kite Syndicate"}]
	for s in range(1, 40):
		var out: Dictionary = RivalCheck.check(rivals, 0, _rng(s))
		if out["has_encounter"]:
			assert_str(str(out["rival_id"])).is_equal("rival_kite")
			assert_str(str(out["rival_name"])).is_equal("Kite Syndicate")
			return
	fail("Expected at least one encounter across 39 seeds with 1 Rival")

func test_decoys_add_to_the_roll_and_so_help_you_evade() -> void:
	# data/crew_tasks.json decoy (p.78): "+1 to the roll when checking if Rivals
	# track you down, per crew sent as Decoy". A HIGHER roll evades, so decoys
	# must strictly reduce the number of encounters over the same seeds.
	var rivals: Array = ["A", "B", "C", "D"]
	var caught_plain: int = 0
	var caught_decoyed: int = 0
	for s in range(1, 80):
		if RivalCheck.check(rivals, 0, _rng(s))["has_encounter"]:
			caught_plain += 1
		if RivalCheck.check(rivals, 2, _rng(s))["has_encounter"]:
			caught_decoyed += 1
	assert_int(caught_decoyed).override_failure_message(
		"p.78 Decoy: +1 per decoy makes being tracked down LESS likely"
	).is_less(caught_plain)

func test_rival_identity_reads_both_shapes_on_the_mixed_list() -> void:
	# campaign.rivals holds Strings AND Dictionaries — creation appends names,
	# events append dicts. Both must resolve or half the list is invisible.
	assert_str(RivalCheck.rival_id_of("Plain Name")).is_equal("Plain Name")
	assert_str(RivalCheck.rival_id_of({"id": "r1", "name": "Nice Name"})).is_equal("r1")
	assert_str(RivalCheck.rival_id_of({"name": "Only A Name"})).is_equal("Only A Name")
	assert_str(RivalCheck.rival_name_of({"id": "r1", "name": "Nice Name"})).is_equal("Nice Name")

func test_decoy_count_comes_from_the_resolved_crew_tasks() -> void:
	var tasks: Array = [
		{"task_id": "decoy", "success": true},
		{"task_id": "train", "success": true},
		{"task_id": "decoy", "success": true},
	]
	assert_int(RivalCheck.decoy_count_from_tasks(tasks)).is_equal(2)

func test_only_a_successful_track_that_names_a_rival_counts() -> void:
	# p.119 "+1 if you Tracked them down". A failed Track grants nothing, and a
	# success that names no Rival cannot be credited to one.
	var tasks: Array = [
		{"task_id": "track", "success": false, "rival_id": "r_fail"},
		{"task_id": "track", "success": true},
		{"task_id": "track", "success": true, "rival_id": "r_hit"},
	]
	assert_array(RivalCheck.tracked_rival_ids_from_tasks(tasks)).contains_exactly(["r_hit"])

# ══════════════════════════════════════════════════════════════════════════
# NORMALIZER — the single chokepoint every battle path crosses
# ══════════════════════════════════════════════════════════════════════════

func test_invasion_is_derived_from_mission_source_not_just_copied() -> void:
	# The only marker an Invasion battle reliably carried was mission_source.
	# BattleSetupRules already treats the two as equivalent at SETUP; the
	# post-battle side read a boolean nobody set, so "no payment" (p.120),
	# "no Loot" (p.121) and the p.119 Rival skip were all unreachable.
	var out: Dictionary = Normalizer.normalize({}, {"mission_source": "invasion"}, 3)
	assert_bool(out["is_invasion"]).override_failure_message(
		"p.120/121: an Invasion battle must be recognisable after the fight"
	).is_true()

func test_a_normal_mission_is_not_an_invasion() -> void:
	var out: Dictionary = Normalizer.normalize({}, {"mission_source": "patron"}, 3)
	assert_bool(out["is_invasion"]).is_false()

func test_the_invasion_threat_flag_and_its_modifier_reach_the_result() -> void:
	# p.121 Step 6 needs both: the flag to roll at all, and Converted
	# Acquisition's "Test at +1" (p.101) to roll correctly.
	var out: Dictionary = Normalizer.normalize({}, {
		"enemy_is_invasion_threat": true,
		"invasion_threat_modifier": 1,
	}, 1)
	assert_bool(out["enemy_is_invasion_threat"]).is_true()
	assert_int(int(out["invasion_threat_modifier"])).is_equal(1)

func test_the_patron_identity_reaches_the_result_on_a_patron_job() -> void:
	# Post-battle Step 2 is gated on patron_id in BOTH directions. The mission
	# carried only a display name, so a completed job recorded no contact and a
	# failed one dropped no Patron.
	var out: Dictionary = Normalizer.normalize({"mission_source": "patron"}, {
		"mission_source": "patron",
		"patron_id": "patron_kel",
		"patron": "Kel Vance",
		"patron_type": "Corporation",
	}, 5)
	assert_str(str(out["patron_id"])).is_equal("patron_kel")
	assert_str(str(out["patron_name"])).is_equal("Kel Vance")
	assert_str(str(out["patron_type"])).is_equal("Corporation")

func test_an_opportunity_mission_gets_no_patron_id() -> void:
	# Guard against the opposite error: attributing an Opportunity mission to a
	# Patron would add a contact you never worked for.
	var out: Dictionary = Normalizer.normalize({"mission_source": "opportunity"}, {
		"mission_source": "opportunity", "patron_id": "patron_kel",
	}, 5)
	assert_bool(out.has("patron_id")).is_false()

func test_the_rival_id_reaches_the_result_and_stamps_the_kills() -> void:
	# RivalPatronResolver recognises a Rival fight by walking defeated_enemies
	# for is_rival. The stamp is applied here, from the mission's rival_id.
	var out: Dictionary = Normalizer.normalize(
		{"defeated_enemies": [{"name": "Goon"}]},
		{"rival_id": "rival_kite"}, 2)
	assert_str(str(out["rival_id"])).is_equal("rival_kite")
	assert_bool(bool(out["defeated_enemies"][0]["is_rival"])).override_failure_message(
		"p.119: the removal roll only happens if the kills are known to be the Rival's"
	).is_true()

func test_place_and_enemy_category_reach_the_result() -> void:
	# planet_id: p.119 notes a new Rival "for this planet".
	# enemy_category: p.101 Roving Threats "never become Rivals".
	var out: Dictionary = Normalizer.normalize({}, {
		"planet_id": "planet_7", "location": "Kestrel", "enemy_category": "roving_threats",
	}, 1)
	assert_str(str(out["planet_id"])).is_equal("planet_7")
	assert_str(str(out["location"])).is_equal("Kestrel")
	assert_str(str(out["enemy_category"])).is_equal("roving_threats")

func test_the_normalizer_stays_add_only() -> void:
	# Producer keys are test-pinned elsewhere; the normalizer must never
	# overwrite one. A player-declared result outranks anything derived.
	var out: Dictionary = Normalizer.normalize(
		{"is_invasion": false, "planet_id": "declared"},
		{"mission_source": "invasion", "planet_id": "derived"}, 1)
	assert_bool(out["is_invasion"]).is_false()
	assert_str(str(out["planet_id"])).is_equal("declared")

# ══════════════════════════════════════════════════════════════════════════
# BATTLEFIELD FINDS — Core Rules pp.120-121, Step 5
# ══════════════════════════════════════════════════════════════════════════

func test_finds_require_holding_the_field() -> void:
	# p.120: "If you Held the Field after the battle, you had an opportunity
	# afterwards to search the battlefield." There was no gate — a crew that
	# fled the table still looted it.
	var p := PaymentProcessorClass.new()
	assert_array(p.process_battlefield_finds(_ctx({"held_field": false}))).is_empty()

func test_no_finds_after_an_invasion_battle() -> void:
	# p.120: "You cannot roll on this table after an Invasion battle."
	var p := PaymentProcessorClass.new()
	assert_array(p.process_battlefield_finds(
		_ctx({"held_field": true, "is_invasion": true}))).is_empty()

func test_finds_are_one_roll_per_battle_not_one_per_crew_member() -> void:
	# p.121: "Roll D100 ONCE on the table below." This rolled once per crew
	# PARTICIPANT, so a six-person crew took six finds from a one-find table.
	var p := PaymentProcessorClass.new()
	var ctx: ContextClass = _ctx({"held_field": true})
	ctx.crew_participants = [
		{"character_id": "c1"}, {"character_id": "c2"}, {"character_id": "c3"},
		{"character_id": "c4"}, {"character_id": "c5"}, {"character_id": "c6"},
	]
	assert_int(p.process_battlefield_finds(ctx).size()).override_failure_message(
		"p.121: exactly one Battlefield Find per battle, regardless of crew size"
	).is_less_equal(1)

# ══════════════════════════════════════════════════════════════════════════
# RIVAL STATUS SKIPS — Core Rules p.119 / p.101
# ══════════════════════════════════════════════════════════════════════════

## Both skips are asserted over MANY trials, because the un-skipped path only
## creates a Rival on a 1D6 roll of 1 (p.119). A single trial passes ~5 times in 6
## even with the skip deleted — it would be a coin-flip dressed as a test.
const _SKIP_TRIALS := 60

func _new_rivals_over_trials(battle_result: Dictionary) -> int:
	var r := RivalPatronResolverClass.new()
	var total: int = 0
	for i in _SKIP_TRIALS:
		var ctx: ContextClass = _ctx_with_campaign(battle_result.duplicate())
		var out: Dictionary = r.process_rival_status(ctx)
		total += (out["new_rivals"] as Array).size()
		total += (ctx.campaign.rivals as Array).size()
	return total

func test_the_trial_harness_can_actually_produce_a_rival() -> void:
	# CONTROL. Without it the two skip assertions below are unfalsifiable: if the
	# stub could never record a Rival, "no Rival was recorded" proves nothing.
	# A plain held-the-field win against a non-Rival MUST sometimes make one
	# (p.119: "roll 1D6. On a 1, the type of opponents you just fought become
	# your Rivals"), so across 60 trials this has to be non-zero.
	assert_int(_new_rivals_over_trials({"held_field": true, "enemy_type": "Raiders"})) \
		.override_failure_message(
			"Control failed: the stub cannot record a Rival, so the skip tests below prove nothing"
		).is_greater(0)

func test_an_invasion_battle_cannot_create_a_rival() -> void:
	# p.119: "Skip this step for Invasion battles."
	assert_int(_new_rivals_over_trials({
		"held_field": true, "enemy_type": "Raiders", "is_invasion": true,
	})).override_failure_message(
		"p.119: an Invasion battle must not saddle the crew with a Rival"
	).is_equal(0)

func test_roving_threats_never_become_rivals() -> void:
	# p.101, Roving Threats header: "Enemies from this list never become Rivals."
	# p.119 says the same from the other side. Neither skip existed, so a pack of
	# Razor Lizards could hold a grudge.
	assert_int(_new_rivals_over_trials({
		"held_field": true, "enemy_type": "Razor Lizards",
		"enemy_category": "roving_threats",
	})).override_failure_message(
		"p.101: Roving Threats are wildlife and hazards, not people who hold grudges"
	).is_equal(0)
