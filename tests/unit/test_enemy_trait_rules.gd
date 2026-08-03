extends GdUnitTestSuite
## The three campaign-level enemy traits on the Interested Parties table
## (Core Rules p.99).
##
## WHAT WAS BROKEN: every encounter-table entry carries its trait as a
## `special_rules` string and PreBattleUI printed them. Three are campaign rules
## with real consequences, and none had a consumer:
##
##   Grudge     (Renegade Soldiers) "If encountered as Rivals, they bring one
##              additional figure" — a Renegade Soldier Rival brought the same
##              force as anyone else, every battle, for the whole campaign.
##   Persistent (Vigilantes) "all rolls to remove them from Rival status are at
##              -1" — the one enemy designed to be a long-term nuisance was as
##              easy to shake as any other: 50% on a 4+ instead of 33%.
##   Intrigue   (Bounty Hunters) "Roll 2D6 and add +1 if you killed a Lieutenant
##              and/or Unique Individual. On a 9+, you obtain a Quest Rumor" —
##              and Quest Rumors are one of only two doors into the Quest arc
##              (p.85), so this silently closed one of them.

const ETR = preload("res://src/core/systems/EnemyTraitRules.gd")


# ── The traits are found where the book puts them ───────────────────────────

func test_the_three_traits_resolve_from_the_data_file() -> void:
	assert_bool(ETR.enemy_has_trait("Renegade Soldiers", "Grudge")).is_true()
	assert_bool(ETR.enemy_has_trait("Vigilantes", "Persistent")).is_true()
	assert_bool(ETR.enemy_has_trait("Bounty Hunters", "Intrigue")).is_true()


## Matching is on the trait NAME before the colon, so a rewording of the prose
## after it cannot silently unwire the rule — and a trait must not leak onto an
## enemy that does not have it.
func test_traits_do_not_leak_between_enemies() -> void:
	assert_bool(ETR.enemy_has_trait("Renegade Soldiers", "Persistent")).is_false()
	assert_bool(ETR.enemy_has_trait("Vigilantes", "Grudge")).is_false()
	assert_bool(ETR.enemy_has_trait("Bounty Hunters", "Grudge")).is_false()
	assert_bool(ETR.enemy_has_trait("Gangers", "Intrigue")).is_false()
	# An unknown name must answer no, not error.
	assert_bool(ETR.enemy_has_trait("Nobody At All", "Grudge")).is_false()
	assert_array(ETR.rules_for("Nobody At All")).is_empty()


func test_trait_name_matching_is_case_insensitive() -> void:
	var rules: Array = ["Grudge: If encountered as Rivals, they bring one additional figure"]
	assert_bool(ETR.has_trait(rules, "grudge")).is_true()
	assert_bool(ETR.has_trait(rules, "GRUDGE")).is_true()
	# A trait name that merely appears mid-sentence is NOT the rule's name.
	assert_bool(ETR.has_trait(["Notes: a grudge is held"], "Grudge")).is_false()


# ── Grudge (Renegade Soldiers) ──────────────────────────────────────────────

## "If encountered AS RIVALS" — a Renegade Soldier opportunity job is an
## ordinary fight and must not gain the extra figure.
func test_grudge_applies_only_to_rival_battles() -> void:
	assert_int(ETR.rival_extra_figures("Renegade Soldiers", true)).is_equal(1)
	assert_int(ETR.rival_extra_figures("Renegade Soldiers", false)).is_equal(0)
	assert_int(ETR.rival_extra_figures("Gangers", true)).is_equal(0)


## Through the live generator, which is what the campaign actually calls.
## Asserting a MINIMUM gap over many draws rather than an exact count keeps this
## an invariant test that survives an unrelated change to the base dice.
func test_grudge_reaches_the_live_generator() -> void:
	var generator := EnemyGenerator.new()
	var iterations := 150
	var sum_rival := 0
	var sum_plain := 0
	for _i in range(iterations):
		sum_rival += generator.generate_enemies_as_dicts({
			"mission_source": "rival",
			"rival_id": "r1",
			"enemy_type": "Renegade Soldiers",
		}, 5).size()
		sum_plain += generator.generate_enemies_as_dicts({
			"mission_source": "opportunity",
			"enemy_type": "Renegade Soldiers",
		}, 5).size()
	assert_float(float(sum_rival) / iterations).override_failure_message(
		"Renegade Soldiers fought AS RIVALS must bring one more figure (p.99)"
	).is_greater(float(sum_plain) / iterations + 0.5)


# ── Persistent (Vigilantes) ─────────────────────────────────────────────────

## The p.119 removal roll succeeds on a 4+; -1 makes it an effective 5+.
func test_persistent_penalises_the_removal_roll() -> void:
	assert_int(ETR.rival_removal_modifier("Vigilantes")).is_equal(-1)
	assert_int(ETR.rival_removal_modifier("Gangers")).is_equal(0)
	assert_int(ETR.rival_removal_modifier("")).is_equal(0)


# ── Intrigue (Bounty Hunters) ───────────────────────────────────────────────

## "Roll 2D6 and add +1 if you killed a Lieutenant and/or Unique Individual. On
## a 9+, you obtain a Quest Rumor." The +1 is what makes an 8 pay out.
func test_intrigue_threshold_and_bonus() -> void:
	assert_bool(ETR.intrigue_succeeds(9, false)).is_true()
	assert_bool(ETR.intrigue_succeeds(8, false)).is_false()
	assert_bool(ETR.intrigue_succeeds(8, true)).is_true()
	assert_bool(ETR.intrigue_succeeds(7, true)).is_false()
	assert_int(ETR.INTRIGUE_TARGET).is_equal(9)


func test_only_bounty_hunters_have_intrigue() -> void:
	assert_bool(ETR.has_intrigue("Bounty Hunters")).is_true()
	assert_bool(ETR.has_intrigue("Vigilantes")).is_false()
	assert_bool(ETR.has_intrigue("")).is_false()
