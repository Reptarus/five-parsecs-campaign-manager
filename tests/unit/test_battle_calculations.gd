extends GdUnitTestSuite

## Unit tests for BattleCalculations
## Tests all pure battle math functions in isolation

# Preload the classes we're testing
const BattleCalculations = preload("res://src/core/battle/BattleCalculations.gd")
const BattleTestFactory = preload("res://tests/fixtures/BattleTestFactory.gd")

#region Hit Calculation Tests

func test_base_hit_threshold_open_range_is_5() -> void:
	# Open target within weapon range (beyond 6"): 5+ (Core Rules p.44 "To Hit").
	var threshold := BattleCalculations.calculate_hit_threshold(
		0,  # combat_skill
		false,  # target_in_cover
		false,  # attacker_elevated
		false,  # target_elevated
		12.0,  # range_inches
		24  # weapon_range
	)
	assert_int(threshold).is_equal(5)

func test_combat_skill_reduces_hit_threshold() -> void:
	# Combat skill 3 should reduce threshold by 3
	var threshold := BattleCalculations.calculate_hit_threshold(
		3,  # combat_skill
		false, false, false,
		12.0, 24
	)
	assert_int(threshold).is_equal(2)  # open-range 5+ (p.44), skill 3 added to roll -> 2+

func test_cover_increases_hit_threshold() -> void:
	# Target in Cover within weapon range (beyond 6"): 6+ (Core Rules p.44 "To Hit").
	var threshold := BattleCalculations.calculate_hit_threshold(
		0,  # combat_skill
		true,  # target_in_cover
		false, false,
		12.0, 24
	)
	assert_int(threshold).is_equal(6)

func test_cover_close_is_5_per_errata() -> void:
	# ⚠ This value has been flipped once by mistake already. Do not "correct" it
	# back to 6 by reading the printed tables.
	#
	# Both p.44 and the p.118 reference list only three rows and neither mentions
	# a covered target within 6", which reasonably reads as "cover is 6+ at every
	# range" — the inference an earlier pass made when it changed the constant to
	# 6 and pinned it here.
	#
	# The official errata v1.06 (docs/gameplay/rules/5P_errata_and_tweaks106.pdf)
	# states the missing row explicitly: "Correction p.118: Add to Firing table:
	# Covered target within 6": 5+. The main rules on p.44 are correct." The
	# close-range bonus DOES apply to covered targets.
	var threshold := BattleCalculations.calculate_hit_threshold(
		0,  # combat_skill
		true,  # target_in_cover
		false, false,
		3.0,  # within 6" (close band)
		24
	)
	assert_int(threshold).is_equal(5)

func test_cover_at_range_is_still_6() -> void:
	# The errata adds a row; it does not change this one (Core Rules p.44:
	# "Within weapon range and in Cover 6+").
	var threshold := BattleCalculations.calculate_hit_threshold(
		0, true, false, false,
		12.0,  # beyond the 6" close band, within weapon range
		24
	)
	assert_int(threshold).is_equal(6)

func test_elevation_does_not_change_the_threshold() -> void:
	# REPLACES test_elevation_bonus_helps_attacker (2026-08-02), which pinned a
	# fabricated rule. The p.44 To Hit table has EXACTLY three rows and none of
	# them mentions height:
	#   within 6" and in the open                          3+
	#   within range in the open, OR within 6" and in Cover 5+
	#   within range and in Cover                          6+
	# So an elevated attacker shoots on the same number as anyone else.
	var elevated := BattleCalculations.calculate_hit_threshold(
		0, false, true, false, 12.0, 24
	)
	var level := BattleCalculations.calculate_hit_threshold(
		0, false, false, false, 12.0, 24
	)
	assert_int(elevated).override_failure_message(
		"elevation must not modify the p.44 threshold"
	).is_equal(level)
	assert_int(elevated).is_equal(5)  # open target within range = 5+

func test_point_blank_bonus() -> void:
	# Within 2" gets point blank bonus
	var threshold := BattleCalculations.calculate_hit_threshold(
		0, false, false, false,
		1.5,  # within 2"
		24
	)
	assert_int(threshold).is_equal(3)  # 4 - 1 = 3

func test_no_long_range_penalty() -> void:
	# REPLACES test_long_range_penalty (2026-08-02), which pinned a fabricated
	# rule. There is no over-range to-hit penalty in either book. Every p.44 row
	# reads "within weapon range" — beyond it you simply cannot take the shot,
	# so there is nothing for a penalty to modify.
	var beyond := BattleCalculations.calculate_hit_threshold(
		0, false, false, false, 30.0, 24
	)
	var inside := BattleCalculations.calculate_hit_threshold(
		0, false, false, false, 12.0, 24
	)
	assert_int(beyond).override_failure_message(
		"there is no over-range to-hit penalty in the Core Rules"
	).is_equal(inside)

func test_threshold_clamped_to_valid_range() -> void:
	# Very high skill shouldn't go below 1
	var threshold := BattleCalculations.calculate_hit_threshold(
		10,  # very high skill
		false, false, false,
		12.0, 24
	)
	assert_int(threshold).is_equal(1)  # Minimum is 1

func test_worst_case_threshold_is_six_not_impossible() -> void:
	# REPLACES test_impossible_hit_threshold (2026-08-02). The old test stacked
	# three fabricated penalties (elevation, over-range, and a cover modifier)
	# to reach an "impossible" 7+. The book's worst case is a covered target at
	# range, which is 6+ — always rollable. Nothing in the p.44 table can push a
	# shot past 6+.
	var threshold := BattleCalculations.calculate_hit_threshold(
		0, true, false, true, 30.0, 24
	)
	assert_int(threshold).override_failure_message(
		"covered target at range is 6+ (p.44); no stack of modifiers makes a shot impossible"
	).is_equal(6)

func test_check_hit_success() -> void:
	assert_bool(BattleCalculations.check_hit(4, 4)).is_true()
	assert_bool(BattleCalculations.check_hit(5, 4)).is_true()
	assert_bool(BattleCalculations.check_hit(6, 4)).is_true()

func test_check_hit_failure() -> void:
	assert_bool(BattleCalculations.check_hit(3, 4)).is_false()
	assert_bool(BattleCalculations.check_hit(1, 4)).is_false()

#endregion

#region Resolving Hits (Core Rules p.46 — canonical casualty/Stun model)

func test_resolve_hit_outcome_meets_toughness_is_casualty() -> void:
	# 1D6 + Damage >= Toughness -> casualty. roll 3 + Damage 1 = 4 >= Toughness 4.
	var out := BattleCalculations.resolve_hit_outcome(1, 4, func(): return 3)
	assert_bool(out.get("casualty")).is_true()
	assert_bool(out.get("stunned")).is_false()

func test_resolve_hit_outcome_below_toughness_is_stun() -> void:
	# roll 2 + Damage 0 = 2 < Toughness 4 -> Stunned (not a casualty), no HP pool.
	var out := BattleCalculations.resolve_hit_outcome(0, 4, func(): return 2)
	assert_bool(out.get("casualty")).is_false()
	assert_bool(out.get("stunned")).is_true()

func test_resolve_hit_outcome_natural_6_always_casualty() -> void:
	# Natural 6 is an automatic casualty even vs very high Toughness (Core Rules p.46).
	var out := BattleCalculations.resolve_hit_outcome(0, 8, func(): return 6)
	assert_bool(out.get("casualty")).is_true()

#endregion

#region Damage Calculation Tests

func test_base_weapon_damage() -> void:
	var damage := BattleCalculations.calculate_weapon_damage(2, false)
	assert_int(damage).is_equal(2)

func test_critical_does_not_inflate_damage() -> void:
	# Sprint A Bug 5 (2026-05-24): Core Rules p.51 — Critical trait inflicts
	# a SECOND HIT on natural-6 to-hit, NOT inflated damage. Pre-fix code
	# returned damage=999 ("instant kill") which conflated Critical trait
	# (p.51: 2 hits) with damage-roll natural-6 auto-casualty (p.46).
	# Default behavior (no brutal_combat house rule): damage is unchanged
	# by the is_critical flag. The 2-hits behavior is verified by integration
	# tests of resolve_ranged_attack via the critical_extra_hit consumer.
	var damage := BattleCalculations.calculate_weapon_damage(2, true)
	assert_int(damage).is_equal(2)  # Critical does not modify damage by default

func test_minimum_damage_is_one() -> void:
	var damage := BattleCalculations.calculate_weapon_damage(0, false)
	assert_int(damage).is_equal(1)  # Minimum is 1

func test_damage_after_armor_basic() -> void:
	# Raw damage 2, toughness 3, no penetration
	var damage := BattleCalculations.calculate_damage_after_armor(2, 3, 0)
	assert_int(damage).is_equal(0)  # 2 - 3 = 0 (minimum)

func test_damage_after_armor_with_penetration() -> void:
	# Raw damage 2, toughness 3, penetration 2
	var damage := BattleCalculations.calculate_damage_after_armor(2, 3, 2)
	assert_int(damage).is_equal(1)  # 2 - (3-2) = 1

func test_damage_against_low_toughness() -> void:
	# Raw damage 3, toughness 1, no penetration
	var damage := BattleCalculations.calculate_damage_after_armor(3, 1, 0)
	assert_int(damage).is_equal(2)  # 3 - 1 = 2

#endregion

#region Armor Save Tests

func test_no_armor_save_threshold() -> void:
	var threshold := BattleCalculations.get_armor_save_threshold("none")
	assert_int(threshold).is_equal(7)  # Cannot save

func test_light_armor_save_threshold() -> void:
	var threshold := BattleCalculations.get_armor_save_threshold("light")
	assert_int(threshold).is_equal(6)

func test_combat_armor_save_threshold() -> void:
	var threshold := BattleCalculations.get_armor_save_threshold("combat")
	assert_int(threshold).is_equal(5)

func test_no_battle_suit_or_powered_armor_tier() -> void:
	# REPLACES test_battle_suit_save_threshold (2026-08-02). "battle suit" and
	# "powered armor" occur ZERO times in the Core Rules and ZERO times in the
	# Compendium, so the old 4+ and 3+ tiers were fabricated. Unknown armor
	# grants no save.
	assert_int(BattleCalculations.get_armor_save_threshold("battle_suit")).is_equal(
		BattleCalculations.ARMOR_SAVE_NONE)
	assert_int(BattleCalculations.get_armor_save_threshold("powered")).is_equal(
		BattleCalculations.ARMOR_SAVE_NONE)


func test_book_armor_saves() -> void:
	# Core Rules p.54 Protective Devices — every armor is 5+ or 6+.
	assert_int(BattleCalculations.get_armor_save_threshold("combat armor")).is_equal(5)
	assert_int(BattleCalculations.get_armor_save_threshold("battle dress")).is_equal(5)
	assert_int(BattleCalculations.get_armor_save_threshold("frag vest")).is_equal(6)
	# "improved to 5+ against any Area attack"
	assert_int(BattleCalculations.get_armor_save_vs_area("frag vest")).is_equal(5)


func test_innate_plating_values() -> void:
	# p.46: "Bot, Soulless, De-converted, and Assault Bot characters have
	# built-in armor plating, which grants them a 6+ Armor Saving Throw (5+ for
	# Assault Bots)."
	assert_int(BattleCalculations.get_innate_armor_save("bot")).is_equal(6)
	assert_int(BattleCalculations.get_innate_armor_save("soulless")).is_equal(6)
	assert_int(BattleCalculations.get_innate_armor_save("de_converted")).is_equal(6)
	assert_int(BattleCalculations.get_innate_armor_save("assault_bot")).is_equal(5)
	assert_int(BattleCalculations.get_innate_armor_save("human")).is_equal(
		BattleCalculations.ARMOR_SAVE_NONE)


func test_multiple_saving_throws_use_the_books_examples() -> void:
	# p.46: "If a character has two or more Saving Throws, only roll for the
	# best Saving Throw, but lower the target number by 1."
	#
	# The book prints both of these examples verbatim. Before 2026-08-02 the
	# code used min(), which silently dropped the -1 that stacking grants.
	assert_int(BattleCalculations.combine_saving_throws([6, 5])).override_failure_message(
		"Bot 6+ with a 5+ screen combines to 4+ (p.46 example)"
	).is_equal(4)
	assert_int(BattleCalculations.combine_saving_throws([5, 5])).override_failure_message(
		"two 5+ armor sources combine to 4+ (p.46 example)"
	).is_equal(4)
	# A single save is not improved.
	assert_int(BattleCalculations.combine_saving_throws([5])).is_equal(5)


func test_screen_generator_is_the_only_screen_save_and_not_vs_area_or_melee() -> void:
	# p.54: "Screen generator ... Receives a 5+ Saving Throw against gunfire.
	# No effect against Area or Melee attacks."
	assert_int(BattleCalculations.get_screen_save_threshold("screen generator")).is_equal(5)
	assert_bool(BattleCalculations.screen_applies("screen generator", false, false)).is_true()
	assert_bool(BattleCalculations.screen_applies("screen generator", true, false)).is_false()
	assert_bool(BattleCalculations.screen_applies("screen generator", false, true)).is_false()


func test_stun_is_a_marker_count_not_a_duration() -> void:
	# p.40: "If a character ever has 3 or more Stun markers at the same time,
	# they are knocked out and removed from play."
	assert_bool(BattleCalculations.is_knocked_out_by_stun(2)).is_false()
	assert_bool(BattleCalculations.is_knocked_out_by_stun(3)).is_true()
	# p.40/p.45: brawling a Stunned figure removes all its markers, but the
	# attacker gets +1 per marker removed.
	assert_int(BattleCalculations.brawl_bonus_from_stun(2)).is_equal(2)
	assert_int(BattleCalculations.brawl_bonus_from_stun(0)).is_equal(0)


func test_impact_only_applies_to_an_already_stunned_target() -> void:
	# p.51 verbatim: "Impact - If target is Stunned, place a second Stun marker."
	assert_bool(BattleCalculations.check_impact_stun(true, ["Impact"])).is_true()
	assert_bool(BattleCalculations.check_impact_stun(false, ["Impact"])).is_false()
	assert_bool(BattleCalculations.check_impact_stun(true, ["Melee"])).is_false()


func test_aiming_rerolls_ones_rather_than_granting_a_bonus() -> void:
	# p.46: "When using an Aimed shot, pick up any 1s on the To Hit dice and
	# roll them again once." It is a reroll, never a flat +1.
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var result: Array = BattleCalculations.apply_aim_reroll([1, 4, 1, 6], rng)
	assert_int(result.size()).is_equal(4)
	# Non-1 dice are untouched, in place.
	assert_int(result[1]).is_equal(4)
	assert_int(result[3]).is_equal(6)
	# Rerolled dice are still legal d6 results.
	for i in [0, 2]:
		assert_int(result[i]).is_greater_equal(1)
		assert_int(result[i]).is_less_equal(6)


func test_enemy_aim_behaviour_by_ai_type() -> void:
	# p.46: "Tactical, Cautious, and Defensive enemies will try to Aim when
	# shooting from Cover. Aggressive and Rampaging enemies will not Aim."
	for ai in ["Tactical", "Cautious", "Defensive"]:
		assert_bool(BattleCalculations.enemy_will_aim(ai)).override_failure_message(
			"%s enemies Aim from Cover (p.46)" % ai
		).is_true()
	for ai in ["Aggressive", "Rampaging"]:
		assert_bool(BattleCalculations.enemy_will_aim(ai)).override_failure_message(
			"%s enemies never Aim (p.46)" % ai
		).is_false()

func test_armor_save_success() -> void:
	assert_bool(BattleCalculations.check_armor_save(6, "light")).is_true()
	assert_bool(BattleCalculations.check_armor_save(5, "combat")).is_true()

func test_armor_save_failure() -> void:
	assert_bool(BattleCalculations.check_armor_save(5, "light")).is_false()
	assert_bool(BattleCalculations.check_armor_save(4, "combat")).is_false()

func test_save_threshold_is_static_regardless_of_damage() -> void:
	# Sprint A Bug 6 (2026-05-24): Core Rules p.46 — save thresholds are STATIC.
	# Pre-fix code at BattleCalculations.gd:274-276 added +1 to threshold when
	# damage >= 3 ("Harder to save against heavy damage") — fabricated, not in
	# the book. Light armor must save on 6+ regardless of incoming damage.
	# Piercing trait negates armor binary; damage value does NOT raise threshold.
	assert_bool(BattleCalculations.check_armor_save(6, "light", 1)).is_true()
	assert_bool(BattleCalculations.check_armor_save(6, "light", 3)).is_true()
	assert_bool(BattleCalculations.check_armor_save(6, "light", 99)).is_true()
	# A failing roll (5) on light armor still fails regardless of damage level.
	assert_bool(BattleCalculations.check_armor_save(5, "light", 1)).is_false()
	assert_bool(BattleCalculations.check_armor_save(5, "light", 3)).is_false()

#endregion

#region Combat Resolution Tests

func test_resolve_ranged_attack_hit() -> void:
	var attacker := BattleTestFactory.create_attacker(3, 12.0)
	var target := BattleTestFactory.create_target(3, "none", false)
	var weapon := BattleTestFactory.create_rifle()

	# Fixed dice roller: 5 for hit, 3 for armor
	var roller := BattleTestFactory.create_fixed_roller([5, 3])

	var result := BattleCalculations.resolve_ranged_attack(
		attacker, target, weapon, roller
	)

	assert_bool(result["hit"]).is_true()
	assert_int(result["hit_roll"]).is_equal(5)

func test_resolve_ranged_attack_miss() -> void:
	var attacker := BattleTestFactory.create_attacker(0, 12.0)  # No skill
	var target := BattleTestFactory.create_target(3, "none", true)  # In cover
	var weapon := BattleTestFactory.create_rifle()

	# Fixed dice roller: 4 (needs 5+ with cover and no skill)
	var roller := BattleTestFactory.create_constant_roller(4)

	var result := BattleCalculations.resolve_ranged_attack(
		attacker, target, weapon, roller
	)

	assert_bool(result["hit"]).is_false()

func test_resolve_ranged_attack_critical() -> void:
	var attacker := BattleTestFactory.create_attacker(2, 12.0)
	var target := BattleTestFactory.create_target(3, "none", false)
	var weapon := BattleTestFactory.create_rifle()

	# Natural 6 is critical
	var roller := BattleTestFactory.create_fixed_roller([6, 1])  # Hit, failed armor

	var result := BattleCalculations.resolve_ranged_attack(
		attacker, target, weapon, roller
	)

	assert_bool(result["hit"]).is_true()
	assert_bool(result["critical"]).is_true()

func test_resolve_ranged_attack_armor_saves() -> void:
	var attacker := BattleTestFactory.create_attacker(3, 12.0)
	var target := BattleTestFactory.create_target(3, "combat", false)  # Combat armor
	var weapon := BattleTestFactory.create_rifle()

	# 5 to hit, 5 for armor save (saves on 5+)
	var roller := BattleTestFactory.create_fixed_roller([5, 5])

	var result := BattleCalculations.resolve_ranged_attack(
		attacker, target, weapon, roller
	)

	assert_bool(result["hit"]).is_true()
	assert_bool(result["armor_saved"]).is_true()
	assert_int(result["wounds_inflicted"]).is_equal(0)

func test_resolve_brawl_attacker_wins() -> void:
	var attacker := {"combat_skill": 3}
	var defender := {"combat_skill": 1}

	# Attacker rolls 4+3=7, defender rolls 2+1=3
	var roller := BattleTestFactory.create_fixed_roller([4, 2])

	var result := BattleCalculations.resolve_brawl(attacker, defender, roller)

	assert_str(result["winner"]).is_equal("attacker")
	assert_int(result["damage_to_defender"]).is_equal(1)

func test_resolve_brawl_defender_wins() -> void:
	# Toughness 1 on the losing attacker makes the Resolving-Hits roll (Core Rules
	# p.46) a guaranteed casualty (1D6 + Damage 0 >= 1 always), so the result is
	# deterministic regardless of the casualty die. damage_to_attacker is the
	# CASUALTY COUNT under the canonical model (no HP pool).
	var attacker := {"combat_skill": 1, "toughness": 1}
	var defender := {"combat_skill": 3}

	# Brawl roll: attacker 2+1=3 vs defender 4+3=7 -> defender wins (1 Hit).
	var roller := BattleTestFactory.create_fixed_roller([2, 4, 6])

	var result := BattleCalculations.resolve_brawl(attacker, defender, roller)

	assert_str(result["winner"]).is_equal("defender")
	assert_int(result["damage_to_attacker"]).is_equal(1)

func test_resolve_brawl_draw() -> void:
	var attacker := {"combat_skill": 2}
	var defender := {"combat_skill": 2}

	# Both roll same: 3+2=5
	var roller := BattleTestFactory.create_constant_roller(3)

	var result := BattleCalculations.resolve_brawl(attacker, defender, roller)

	assert_str(result["winner"]).is_equal("draw")
	# Five Parsecs rule: Draw = both combatants take 1 hit
	assert_int(result["damage_to_attacker"]).is_equal(1)
	assert_int(result["damage_to_defender"]).is_equal(1)

#endregion

#region Experience Calculation Tests

func test_xp_for_participation() -> void:
	var xp := BattleCalculations.calculate_crew_xp(true, false, 0)
	# Participation (1) + defeat bonus (1) = 2
	assert_int(xp).is_equal(2)

func test_xp_for_victory() -> void:
	var xp := BattleCalculations.calculate_crew_xp(true, true, 0)
	# Participation (1) + victory bonus (2) = 3
	assert_int(xp).is_equal(3)

func test_xp_for_first_kill() -> void:
	var xp := BattleCalculations.calculate_crew_xp(true, true, 1)
	# Participation (1) + victory (2) + first casualty (1) = 4 (Core Rules p.123)
	assert_int(xp).is_equal(4)

func test_xp_has_no_fabricated_survival_bonus() -> void:
	# Core Rules p.123 has no "survived an injury" battle-XP source. "School of
	# hard knocks" (+1 XP) is an Injury Table result, applied in InjuryProcessor.
	var xp := BattleCalculations.calculate_crew_xp(true, true, 0)
	# Participation (1) + victory (2) = 3, regardless of any injury
	assert_int(xp).is_equal(3)

func test_no_xp_without_participation() -> void:
	var xp := BattleCalculations.calculate_crew_xp(false, true, 5)
	assert_int(xp).is_equal(0)

func test_calculate_battle_xp_for_crew() -> void:
	var crew_data := BattleTestFactory.create_crew_xp_data(3)
	var xp_awards := BattleCalculations.calculate_battle_xp(crew_data, true)

	assert_int(xp_awards.size()).is_equal(3)
	# Each should have at least participation + victory = 3
	for crew_id in xp_awards:
		assert_int(xp_awards[crew_id]).is_greater_equal(3)

#endregion

#region Loot Calculation Tests

func test_loot_rolls_on_victory() -> void:
	var rolls := BattleCalculations.calculate_loot_rolls(true, 3, true)
	# Base (1) + hold field (1) = 2
	assert_int(rolls).is_equal(2)

func test_loot_rolls_no_loot_on_defeat() -> void:
	var rolls := BattleCalculations.calculate_loot_rolls(false, 3, false)
	assert_int(rolls).is_equal(0)

func test_loot_rolls_no_fabricated_enemy_count_bonus() -> void:
	# Core Rules p.121: roll once on the Loot Table. There is no extra roll for
	# defeating 6+ enemies. Only holding the field adds a (Battlefield Finds) roll.
	var rolls := BattleCalculations.calculate_loot_rolls(true, 6, true)
	# Base (1) + hold field (1) = 2 — the enemy count is ignored
	assert_int(rolls).is_equal(2)

func test_calculate_battle_credits() -> void:
	# Core Rules p.120: pay is base + danger pay, no percentage multiplier
	var credits := BattleCalculations.calculate_battle_credits(10, 4)
	assert_int(credits).is_equal(14)

#endregion

#region Initiative Tests

func test_seize_initiative_success() -> void:
	# 4 + 4 + 2 = 10 (just enough, Core Rules p.95: >= 10)
	var result := BattleCalculations.check_seize_initiative(4, 4, 2)
	assert_bool(result["seized"]).is_true()
	assert_int(result["roll_total"]).is_equal(10)

func test_seize_initiative_failure() -> void:
	# 4 + 3 + 2 = 9 (not enough, need 10+)
	var result := BattleCalculations.check_seize_initiative(4, 3, 2)
	assert_bool(result["seized"]).is_false()
	assert_int(result["roll_total"]).is_equal(9)

func test_high_savvy_helps_initiative() -> void:
	# 2 + 3 + 5 = 10 (high savvy compensates)
	var result := BattleCalculations.check_seize_initiative(2, 3, 5)
	assert_bool(result["seized"]).is_true()

#endregion

#region Reaction Dice Tests

func test_reaction_dice_count() -> void:
	assert_int(BattleCalculations.get_reaction_dice_count(4)).is_equal(4)
	assert_int(BattleCalculations.get_reaction_dice_count(6)).is_equal(6)

func test_quick_action_threshold() -> void:
	# Core Rules p.96: roll <= Reaction stat = Quick Action
	# Reaction stat 4: rolls 1-4 are quick
	assert_bool(BattleCalculations.is_quick_action(1, 4)).is_true()
	assert_bool(BattleCalculations.is_quick_action(4, 4)).is_true()
	assert_bool(BattleCalculations.is_quick_action(3, 3)).is_true()

func test_slow_action_threshold() -> void:
	# Core Rules p.96: roll > Reaction stat = Slow Action
	assert_bool(BattleCalculations.is_quick_action(5, 4)).is_false()
	assert_bool(BattleCalculations.is_quick_action(6, 4)).is_false()
	assert_bool(BattleCalculations.is_quick_action(4, 3)).is_false()

#endregion

#region Utility Tests

func test_calculate_distance() -> void:
	var dist := BattleCalculations.calculate_distance(Vector2(0, 0), Vector2(3, 4))
	assert_float(dist).is_equal_approx(5.0, 0.01)

func test_calculate_grid_distance() -> void:
	var dist := BattleCalculations.calculate_grid_distance(Vector2i(0, 0), Vector2i(3, 4))
	assert_int(dist).is_equal(7)  # Manhattan distance

#endregion


# ── Core Rules p.51 weapon traits ────────────────────────────────────────────
# The p.51 list is CLOSED: Area, Clumsy, Critical, Elegant, Focused, Heavy,
# Impact, Melee, Piercing, Pistol, Single use, Snap shot, Stun, Terrifying.

func _fx(traits: Array, ctx: Dictionary = {}) -> Dictionary:
	return BattleCalculations.get_weapon_trait_effects(traits, ctx)


func test_fabricated_traits_do_nothing() -> void:
	# Each of these had a live effect before 2026-08-02 and occurs ZERO times in
	# the Core Rules AND the Compendium. They must now be inert, not silently
	# reinstated under a new name.
	for fake in ["accurate", "slow", "devastating", "powered", "high_penetration",
			"knockback", "burst_fire", "single_shot", "long_range", "suppressive"]:
		var e: Dictionary = _fx([fake])
		assert_int(e["hit_modifier"]).override_failure_message(
			"'%s' is not a Five Parsecs trait but still modifies to-hit" % fake
		).is_equal(0)
		assert_int(e["damage_modifier"]).override_failure_message(
			"'%s' is not a Five Parsecs trait but still modifies damage" % fake
		).is_equal(0)
		assert_array(e["traits_applied"]).override_failure_message(
			"'%s' is not a Five Parsecs trait but still applied an effect" % fake
		).is_empty()


func test_melee_and_pistol_brawl_bonuses() -> void:
	# p.51: Melee "+2 to Brawling rolls", Pistol "+1 to Brawling rolls".
	assert_int(_fx(["Melee"])["brawl_modifier"]).is_equal(2)
	assert_int(_fx(["Pistol"])["brawl_modifier"]).is_equal(1)


func test_clumsy_only_bites_against_a_faster_opponent() -> void:
	# p.51: "-1 to Brawling rolls, if opponent has higher Speed."
	assert_bool(_fx(["Clumsy"])["clumsy_if_opponent_faster"]).is_true()
	assert_int(BattleCalculations.brawl_clumsy_modifier(true, 4.0, 5.0)).is_equal(-1)
	assert_int(BattleCalculations.brawl_clumsy_modifier(true, 5.0, 4.0)).is_equal(0)
	assert_int(BattleCalculations.brawl_clumsy_modifier(true, 4.0, 4.0)).is_equal(0)
	assert_int(BattleCalculations.brawl_clumsy_modifier(false, 4.0, 6.0)).is_equal(0)


func test_elegant_grants_a_brawl_reroll() -> void:
	# p.51: "When Brawling, the fighter may reroll the die."
	assert_bool(_fx(["Elegant"])["allows_brawl_reroll"]).is_true()


func test_critical_is_two_hits_on_a_natural_six_not_a_damage_bonus() -> void:
	# p.51: "A natural 6 on the to Hit roll will inflict 2 Hits on the target."
	var e: Dictionary = _fx(["Critical"])
	assert_bool(e["natural_six_inflicts_two_hits"]).is_true()
	assert_int(e["damage_modifier"]).override_failure_message(
		"Critical is a second HIT, not extra damage"
	).is_equal(0)


func test_area_uses_the_core_rules_version_not_the_compendium_option() -> void:
	# Core Rules p.51: "Resolve all shots against the initial target. They cannot
	# be spread. Then resolve one bonus shot against every figure within 2\"."
	# The Compendium Game Options version (target point, 4+ per figure) is an
	# opt-in alternative and must NOT be the default.
	var e: Dictionary = _fx(["Area"])
	assert_bool(e["is_area_effect"]).is_true()
	assert_bool(e["force_single_target"]).override_failure_message(
		"Area shots 'cannot be spread' — they all hit the initial target first"
	).is_true()
	assert_float(e["area_bonus_shot_radius_inches"]).is_equal(2.0)


func test_impact_is_conditional_on_the_target_already_being_stunned() -> void:
	# p.51: "If target is Stunned, place a second Stun marker."
	var e: Dictionary = _fx(["Impact"])
	assert_bool(e["second_stun_if_already_stunned"]).is_true()
	assert_bool(e["causes_stun"]).override_failure_message(
		"Impact must not stun an unstunned target — that is the Stun trait"
	).is_false()


func test_outnumbering_side_gets_plus_one_in_a_brawl() -> void:
	# p.45 Multiple Opponents: "the outnumbering side getting a +1 bonus".
	assert_int(BattleCalculations.brawl_outnumbering_modifier(2, 1)).is_equal(1)
	assert_int(BattleCalculations.brawl_outnumbering_modifier(1, 2)).is_equal(0)
	assert_int(BattleCalculations.brawl_outnumbering_modifier(1, 1)).is_equal(0)


func test_panic_fire_halves_range_and_adds_two_shots() -> void:
	# p.46-47: half the weapon's BASE Range, +2 additional shots.
	var p: Dictionary = BattleCalculations.panic_fire_profile(24.0, 1, [])
	assert_float(p["range_inches"]).is_equal(12.0)
	assert_int(p["shots"]).is_equal(3)
	assert_bool(p["ammo_spent"]).is_true()


func test_single_use_weapons_and_enemies_cannot_panic_fire() -> void:
	# p.51: "The Panic Fire rule (p.46) cannot be used with Single use weapons."
	# p.47: "The Panic Fire option is never used by enemies."
	assert_bool(BattleCalculations.can_panic_fire(["Single use"])).is_false()
	assert_bool(BattleCalculations.can_panic_fire(["Melee"], true)).is_false()
	assert_bool(BattleCalculations.can_panic_fire(["Melee"], false)).is_true()
	assert_dict(BattleCalculations.panic_fire_profile(24.0, 1, ["Single use"])).is_empty()


# ── Core Rules p.54 consumables ──────────────────────────────────────────────

func test_rage_out_lasts_two_rounds_but_all_battle_for_a_kerin() -> void:
	# p.54: "+2\" Speed and +1 to all Brawling rolls for the rest of this and the
	# following round. A K'Erin user gets the benefits for the rest of the battle."
	var human := {"species_id": "human", "speed": 4, "brawl_bonus": 0}
	var r1: Dictionary = BattleCalculations.apply_consumable_effect("rage_out", human)
	assert_bool(r1["applied"]).is_true()
	assert_int(human["rage_out_rounds_remaining"]).is_equal(2)
	assert_str(r1["expires"]).is_equal("after_next_round")

	var kerin := {"species_id": "k_erin", "speed": 4, "brawl_bonus": 0}
	var r2: Dictionary = BattleCalculations.apply_consumable_effect("rage_out", kerin)
	assert_int(kerin["rage_out_rounds_remaining"]).override_failure_message(
		"a K'Erin keeps Rage Out for the whole battle (-1 = no expiry)"
	).is_equal(-1)
	assert_str(r2["expires"]).is_equal("end_of_battle")


func test_still_locks_movement_for_two_rounds() -> void:
	# p.54: "cannot Move during this and the next round" — not just this one.
	var u := {"species_id": "human"}
	BattleCalculations.apply_consumable_effect("still", u)
	assert_bool(u["cannot_move"]).is_true()
	assert_int(u["still_rounds_remaining"]).is_equal(2)


func test_booster_pills_clear_every_stun_marker() -> void:
	# p.54: "the character removes all Stun markers."
	var u := {"species_id": "human", "speed": 4, "stun_markers": 2, "is_stunned": true}
	BattleCalculations.apply_consumable_effect("booster_pills", u)
	assert_int(u["stun_markers"]).is_equal(0)
	assert_bool(u["is_stunned"]).is_false()
	assert_int(u["speed_multiplier_this_round"]).is_equal(2)


func test_kiranin_crystals_carry_all_three_book_exclusions() -> void:
	# p.54: no effect on characters that already acted, does not affect the user,
	# and a dazed character still defends normally in a Brawl. All three were
	# missing, which made the crystals far stronger than the book allows.
	var r: Dictionary = BattleCalculations.apply_consumable_effect(
		"kiranin_crystals", {"species_id": "human"})
	assert_float(r["area_daze_range"]).is_equal(4.0)
	assert_bool(r["excludes_user"]).is_true()
	assert_bool(r["excludes_already_acted"]).is_true()
	assert_bool(r["still_defends_in_brawl"]).is_true()


func test_stim_pack_is_reflexive_and_free() -> void:
	# p.54: "This item can be used reflexively upon becoming a casualty. It does
	# not require an action."
	var u := {"species_id": "human"}
	var r: Dictionary = BattleCalculations.apply_consumable_effect("stim_pack", u)
	assert_bool(u["has_stim_pack"]).is_true()
	assert_bool(r["reflexive"]).is_true()
	assert_bool(r["costs_action"]).is_false()


func test_skulker_resists_drugs_but_not_stim_packs_or_crystals() -> void:
	# Compendium p.17 biological resistance. Stim-packs and Kiranin Crystals are
	# explicitly NOT affected.
	for drug in ["booster_pills", "combat_serum", "rage_out", "still"]:
		var r: Dictionary = BattleCalculations.apply_consumable_effect(
			drug, {"species_id": "skulker", "speed": 4})
		assert_bool(r["applied"]).override_failure_message(
			"a Skulker should resist %s" % drug
		).is_false()
	for allowed in ["stim_pack", "kiranin_crystals"]:
		var r2: Dictionary = BattleCalculations.apply_consumable_effect(
			allowed, {"species_id": "skulker", "speed": 4})
		assert_bool(r2["applied"]).override_failure_message(
			"Skulker resistance must NOT block %s" % allowed
		).is_true()
