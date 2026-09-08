extends GdUnitTestSuite
## Tactics pp.95-99 "THE OPERATIONAL SYSTEM" — the rules that had no resolver.
##
## Verified against docs/rules/tactics_source.txt. That file marks the RAW page in
## `=== PAGE N ===` and prints the FOLIO on the next line, so the offset is raw-2;
## confirmed here at raw PAGE 94 -> printed 92 "THE OPERATIONAL SYSTEM". Applying
## another book's offset lands 63 pages away in the Lifeforms bestiary, which is exactly
## how this chapter came to be miscited in four separate files.
##
## Book text these cases pin, quoted:
##
## Step 2, Player Battle Points (p.96):
##   "Award 1 Player Battle Point (1 PBP) for every tabletop battle victory in an
##    Operational Zone."
##   "If a battle was inconclusive or a draw, award 0 PBP."
##   "If both sides earned points in the same Zone, they cancel out on a 1-for-1 basis.
##    For example, if Faction A earned 3 wins and Faction B earned 1, the end result is
##    that Faction A earned 2 PBP."
##   "a specific army cannot gain more than 2 PBP in a single operational turn, and
##    cannot have more than 3 saved up overall. Any excess points are discarded without
##    any effects."
##
## Step 3, Operational Combat (p.97):
##   "Each faction in the battle begins with 1 Combat Die."
##   "Add +1 Combat Die if the enemy is not adjacent to their own territory."
##   "Add +1 Combat Die if Army Strength is 2+ higher than the opposing side."
##   "Both sides may spend available PBP. Each point spent grants +1 Combat Die."
##   "consult the table below, starting at the top and working down until you find a
##    matching result dice roll. If your roll matches multiple outcomes, use only the
##    first matching entry on the table."
##
## Step 5, Commando Raids (p.99):
##   "Allocate any desired PBP and roll 1D6 for each point spent against a region:
##    If any of the dice roll 1-2, all PBP committed to that region are lost. For every
##    6, adjust the Army Strength of the target army by -1. This damage applies even if
##    the committed PBP are lost. Any other result has no effect."
##
## Step 9, Cohesion (p.99) — ABSENT from the book's own 8-step summary list on p.96:
##   "Each time a region is lost, the Cohesion score of the losing faction is reduced
##    by 1." / "When Cohesion reaches 0, that faction has been defeated" / "The campaign
##    is won when only one faction remains. In the event all remaining factions reach 0
##    at the same time, the war is inconclusive."
##
## Army Strength (p.95):
##   "If the Zone is in or adjacent to friendly territory, roll two D6s and pick the
##    highest die. If the Zone is not connected directly to friendly territory, roll
##    one D6."

const Rules = preload("res://src/core/campaign/TacticsOperationalRules.gd")


# MARK: - The data actually loads (premise first)

func test_the_config_is_reachable_and_carries_the_nine_steps() -> void:
	## Instrument the premise: every case below reads this JSON, so if it failed to
	## load they would all pass vacuously against the hardcoded fallbacks.
	var steps: Array = Rules.turn_steps()
	assert_int(steps.size()) \
		.override_failure_message(
			"tactics_campaign_config.json did not load, or lost a step. Every other "
			+ "case in this suite would then be testing the fallback constants "
			+ "rather than the data.") \
		.is_equal(9)
	assert_str(str(steps[8].get("name", ""))).contains("Cohesion")


func test_step_nine_exists_because_the_books_summary_list_omits_it() -> void:
	## The p.96 list stops at 8; the body carries "Step 9: Adjust Cohesion scores" on
	## p.99. A turn loop built from the summary alone has no end condition.
	var steps: Array = Rules.turn_steps()
	var ninth: Dictionary = steps[8]
	assert_int(int(ninth.get("step", 0))).is_equal(9)
	assert_int(int(ninth.get("page", 0))).is_equal(99)


# MARK: - Step 2, Player Battle Points (p.96)

func test_one_pbp_per_victory_and_none_for_a_draw() -> void:
	assert_int(int(Rules.award_battle_points(1, 0).get("awarded", -1))).is_equal(1)
	assert_int(int(Rules.award_battle_points(0, 0).get("awarded", -1))).is_equal(0)


func test_the_books_own_cancellation_example() -> void:
	## "if Faction A earned 3 wins and Faction B earned 1, the end result is that
	## Faction A earned 2 PBP."
	assert_int(int(Rules.award_battle_points(3, 1).get("awarded", -1))) \
		.override_failure_message(
			"p.96 states this exact example: 3 wins against 1 nets 2 PBP") \
		.is_equal(2)


func test_a_side_cannot_gain_more_than_two_in_one_operational_turn() -> void:
	## Five clean wins is still 2. Without the cap this returned 5.
	var res: Dictionary = Rules.award_battle_points(5, 0)
	assert_int(int(res.get("awarded", -1))).is_equal(2)
	assert_int(int(res.get("discarded", 0))).is_greater(0)


func test_a_side_cannot_hold_more_than_three_saved() -> void:
	## Already holding 3, win two more: the total stays 3 and the excess is discarded
	## "without any effects".
	var res: Dictionary = Rules.award_battle_points(2, 0, 3)
	assert_int(int(res.get("total", -1))).is_equal(3)
	assert_int(int(res.get("discarded", 0))).is_greater(0)


func test_cancellation_happens_before_the_cap_not_after() -> void:
	## 4 wins against 3 is a net of 1, so the per-turn cap of 2 must not bind. If the
	## cap were applied to the gross 4 first and cancellation second, this would be 0.
	assert_int(int(Rules.award_battle_points(4, 3).get("awarded", -1))).is_equal(1)


# MARK: - Step 3, the Combat Dice tally (p.97)

func test_each_faction_begins_with_one_combat_die() -> void:
	assert_int(Rules.combat_dice(3, 3, 0, false)).is_equal(1)


func test_army_strength_advantage_needs_a_gap_of_two() -> void:
	## "+1 Combat Die if Army Strength is 2+ higher" — so a gap of 1 grants nothing.
	assert_int(Rules.combat_dice(4, 3, 0, false)).is_equal(1)
	assert_int(Rules.combat_dice(5, 3, 0, false)).is_equal(2)


func test_each_pbp_spent_grants_one_die_and_the_bonuses_stack() -> void:
	## base 1 + not-adjacent 1 + strength 1 + 2 PBP = 5
	assert_int(Rules.combat_dice(5, 3, 2, true)).is_equal(5)


# MARK: - Step 3, the outcome table (p.97) — pure, no RNG

func test_both_sides_with_two_sixes_is_a_devastating_major_battle() -> void:
	var r: Dictionary = Rules.classify_combat_outcome([6, 6, 1], [6, 6, 2])
	assert_str(str(r.get("id", ""))).is_equal("both_multiple_sixes")
	assert_int(int(r.get("player_delta", 0))).is_equal(-1)
	assert_int(int(r.get("enemy_delta", 0))).is_equal(-1)
	assert_bool(bool(r.get("refight", false))).is_true()


func test_one_side_with_two_sixes_is_a_grand_tactical_success() -> void:
	var r: Dictionary = Rules.classify_combat_outcome([6, 6, 1], [6, 3])
	assert_str(str(r.get("id", ""))).is_equal("one_multiple_sixes")
	assert_int(int(r.get("player_delta", 0))).is_equal(1)
	assert_int(int(r.get("enemy_delta", 0))).is_equal(-1)


func test_the_table_is_first_match_wins_in_printed_order() -> void:
	## ⭐ This is the case that pins the book's ordering instruction. [6,6,4] vs [6,4]
	## satisfies row 2 (only one side has 2+ sixes) AND row 4 (highest die tied at 6).
	## The book says "use only the first matching entry", so row 2 must win. A `match`
	## on some derived key, or an if-chain in the wrong order, returns "tie_high" here.
	var r: Dictionary = Rules.classify_combat_outcome([6, 6, 4], [6, 4])
	assert_str(str(r.get("id", ""))) \
		.override_failure_message(
			"p.97: 'If your roll matches multiple outcomes, use only the first "
			+ "matching entry on the table.' Row 2 precedes row 4.") \
		.is_equal("one_multiple_sixes")


func test_a_higher_single_die_gives_the_upper_hand_and_only_the_loser_pays() -> void:
	var r: Dictionary = Rules.classify_combat_outcome([5, 2], [4, 4])
	assert_str(str(r.get("id", ""))).is_equal("single_high_die")
	assert_int(int(r.get("player_delta", 0))).is_equal(0)
	assert_int(int(r.get("enemy_delta", 0))).is_equal(-1)


func test_a_tied_high_die_of_five_or_six_is_brutal_attrition() -> void:
	var r: Dictionary = Rules.classify_combat_outcome([5, 1], [5, 3])
	assert_str(str(r.get("id", ""))).is_equal("tie_high")
	assert_int(int(r.get("player_delta", 0))).is_equal(-1)
	assert_int(int(r.get("enemy_delta", 0))).is_equal(-1)


func test_a_tied_low_die_is_inconclusive_and_costs_nobody_anything() -> void:
	var r: Dictionary = Rules.classify_combat_outcome([4, 2], [4, 1])
	assert_str(str(r.get("id", ""))).is_equal("tie_low")
	assert_int(int(r.get("player_delta", 0))).is_equal(0)
	assert_int(int(r.get("enemy_delta", 0))).is_equal(0)


# MARK: - Step 4, the D6 Operational Orders table (p.98)

func test_all_six_operational_orders_are_present_and_named_as_the_book_names_them() -> void:
	var expected: Array = [
		"Construct Defense", "Continued Offensive", "New Offensive",
		"Renewed Effort", "Raiding", "Bolster Positions",
	]
	for i in range(6):
		var row: Dictionary = Rules.operational_order_for(i + 1)
		assert_str(str(row.get("name", ""))) \
			.override_failure_message(
				"p.98 D6 row " + str(i + 1) + " should be " + str(expected[i])) \
			.is_equal(str(expected[i]))


func test_an_out_of_range_order_roll_returns_nothing_rather_than_a_guess() -> void:
	assert_bool(Rules.operational_order_for(7).is_empty()).is_true()
	assert_bool(Rules.operational_order_for(0).is_empty()).is_true()


# MARK: - Step 5, Commando Raids (p.99)

func test_a_six_costs_the_target_one_army_strength() -> void:
	var rng := RandomNumberGenerator.new()
	# Seed until we get a pool containing a 6 but no 1-2, to assert the clean case.
	var found := false
	for s in range(400):
		rng.seed = s
		var res: Dictionary = Rules.resolve_commando_raid(2, rng)
		var rolls: Array = res.get("rolls", [])
		if rolls.has(6) and not rolls.has(1) and not rolls.has(2):
			assert_int(int(res.get("army_strength_damage", 0))).is_greater(0)
			assert_int(int(res.get("pbp_lost", -1))).is_equal(0)
			found = true
			break
	assert_bool(found) \
		.override_failure_message(
			"no seed in 400 produced a 2-die pool with a 6 and no 1-2; the search, "
			+ "not the rule, is what failed") \
		.is_true()


func test_damage_lands_even_when_the_points_are_lost() -> void:
	## "This damage applies even if the committed PBP are lost." A pool holding both a
	## 6 and a 1-2 must report BOTH the loss and the damage.
	var rng := RandomNumberGenerator.new()
	var found := false
	for s in range(400):
		rng.seed = s
		var res: Dictionary = Rules.resolve_commando_raid(3, rng)
		var rolls: Array = res.get("rolls", [])
		if rolls.has(6) and (rolls.has(1) or rolls.has(2)):
			assert_int(int(res.get("pbp_lost", 0))).is_equal(3)
			assert_int(int(res.get("army_strength_damage", 0))) \
				.override_failure_message(
					"p.99: the -1 applies even when the committed PBP are lost") \
				.is_greater(0)
			found = true
			break
	assert_bool(found).is_true()


func test_committing_nothing_rolls_nothing() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var res: Dictionary = Rules.resolve_commando_raid(0, rng)
	assert_int((res.get("rolls", []) as Array).size()).is_equal(0)
	assert_int(int(res.get("army_strength_damage", 0))).is_equal(0)


# MARK: - Army Strength (p.95)

func test_friendly_territory_rolls_two_dice_and_keeps_the_highest() -> void:
	## Over many seeds the connected form must average higher than the unconnected one;
	## max(2d6) has mean ~4.47 against 1d6's 3.5. Asserting the DISTRIBUTION rather than
	## one roll is what makes this a real check of "pick the highest die".
	var rng := RandomNumberGenerator.new()
	var connected_total := 0
	var lone_total := 0
	for s in range(300):
		rng.seed = s
		connected_total += Rules.generate_army_strength(true, rng)
		rng.seed = s + 10000
		lone_total += Rules.generate_army_strength(false, rng)
	assert_int(connected_total) \
		.override_failure_message(
			"max(2d6) must outscore 1d6 over 300 samples; got "
			+ str(connected_total) + " vs " + str(lone_total)) \
		.is_greater(lone_total)


func test_army_strength_is_always_a_legal_die_result() -> void:
	var rng := RandomNumberGenerator.new()
	for s in range(60):
		rng.seed = s
		assert_int(Rules.generate_army_strength(true, rng)).is_between(1, 6)
		assert_int(Rules.generate_army_strength(false, rng)).is_between(1, 6)


# MARK: - Step 9, Cohesion (p.99)

func test_each_region_lost_costs_one_cohesion() -> void:
	assert_int(Rules.cohesion_after_region_loss(5)).is_equal(4)
	assert_int(Rules.cohesion_after_region_loss(5, 3)).is_equal(2)


func test_cohesion_does_not_go_below_zero() -> void:
	assert_int(Rules.cohesion_after_region_loss(1, 5)).is_equal(0)


func test_zero_cohesion_defeats_a_faction() -> void:
	assert_bool(Rules.is_faction_defeated(0)).is_true()
	assert_bool(Rules.is_faction_defeated(1)).is_false()


func test_the_campaign_result_covers_all_four_states() -> void:
	assert_str(Rules.campaign_result(5, 5)).is_equal("")
	assert_str(Rules.campaign_result(5, 0)).is_equal("player")
	assert_str(Rules.campaign_result(0, 5)).is_equal("enemy")
	assert_str(Rules.campaign_result(0, 0)) \
		.override_failure_message(
			"p.99: 'In the event all remaining factions reach 0 at the same time, the "
			+ "war is inconclusive, with both sides completely exhausted.'") \
		.is_equal("inconclusive")
