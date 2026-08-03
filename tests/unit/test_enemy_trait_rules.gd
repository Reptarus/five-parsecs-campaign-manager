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


# ── Cop killer (Enforcers, p.96) ────────────────────────────────────────────

## "If you ever fight Enforcers as Rivals, add +2 to their numbers." Twice
## Grudge, and the book's own punishment for making an enemy of the law.
func test_cop_killer_adds_two_to_rival_numbers() -> void:
	assert_int(ETR.rival_number_bonus("Enforcers", true)).is_equal(2)
	assert_int(ETR.rival_number_bonus("Enforcers", false)).is_equal(0)
	assert_int(ETR.rival_number_bonus("Renegade Soldiers", true)).is_equal(1)
	assert_int(ETR.rival_number_bonus("Gangers", true)).is_equal(0)


# ── Scavengers (p.97 Salvage Team, p.100 Black Ops Team) ────────────────────

func test_scavengers_doubles_battlefield_finds() -> void:
	assert_int(ETR.battlefield_finds_rolls("Salvage Team")).is_equal(2)
	assert_int(ETR.battlefield_finds_rolls("Gangers")).is_equal(1)
	assert_int(ETR.battlefield_finds_rolls("")).is_equal(1)


# ── Tough fight ─────────────────────────────────────────────────────────────

## Carried by Black Ops Team, Assassins and Krorg per the verified extraction.
## Named from the DATA rather than from a page scan on purpose: a trait line in
## the PDF sits after its row's description paragraph, so scanning by line number
## attributes it to the wrong enemy about as often as not.
func test_tough_fight_pays_one_bonus_xp() -> void:
	assert_int(ETR.bonus_survivor_xp("Black Ops Team")).is_equal(1)
	assert_int(ETR.bonus_survivor_xp("Gangers")).is_equal(0)


# ── Seize the Initiative traits (pp.95-101) ─────────────────────────────────

## "Careless: You are +1", "Alert: You are -1". Stated as modifiers to the
## PLAYER's roll, so the sign is from the crew's point of view.
func test_seize_modifiers() -> void:
	assert_int(ETR.seize_modifier("Punks")).is_equal(1)
	assert_int(ETR.seize_modifier("Gangers")).is_equal(0)
	assert_int(ETR.seize_modifier("")).is_equal(0)


## Prediction and Unpredictable are absolutes, not modifiers — a value could not
## express either one, which is why they are separate booleans.
func test_seize_absolutes_are_not_modifiers() -> void:
	assert_bool(ETR.blocks_seize("Precursor Exiles")).is_true()
	assert_bool(ETR.blocks_seize("Gangers")).is_false()
	assert_bool(ETR.seize_is_unmodified("Swift War Squad")).is_true()
	assert_bool(ETR.seize_is_unmodified("Gangers")).is_false()


## The generator must emit the category modifier PLUS the enemy's own trait.
## Reading the book's parenthetical totals ("for a final modifier of 0") as the
## trait's value instead would silently cancel the p.112 category rule.
func test_seize_modifier_reaches_the_generated_enemies() -> void:
	var generator := EnemyGenerator.new()
	var enemies: Array = generator.generate_enemies_as_dicts({
		"mission_source": "opportunity",
		"enemy_type": "Punks",
	}, 5)
	assert_array(enemies).is_not_empty()
	var found := false
	for e in enemies:
		if e is Dictionary and e.get("type", "") == "Punks":
			found = true
			assert_int(int(e["seize_initiative_modifier"])).override_failure_message(
				"Careless (+1) must reach the enemy record, on top of the category"
			).is_greater(-1)
			assert_bool(e.has("seize_blocked")).is_true()
	assert_bool(found).is_true()


## The resolver is DATA-DRIVEN: it must find each trait wherever enemy_types.json
## puts it, with no roster baked into the code. This walks the file and asserts
## every enemy carrying a given trait string answers true — so re-attributing a
## trait in the data cannot leave a stale hardcoded list behind.
func test_every_trait_bearer_in_the_data_is_recognised() -> void:
	var file := FileAccess.open("res://data/enemy_types.json", FileAccess.READ)
	assert_object(file).is_not_null()
	var json := JSON.new()
	assert_int(json.parse(file.get_as_text())).is_equal(OK)
	file.close()

	var traits := ["Grudge", "Persistent", "Intrigue", "Cop killer",
		"Scavengers", "Tough fight", "Careless", "Alert",
		"Prediction", "Unpredictable"]
	var missed: Array = []
	var found_any := false
	for category in json.data.get("enemy_categories", []):
		for enemy in category.get("enemies", []):
			var ename: String = str(enemy.get("name", ""))
			for rule in enemy.get("special_rules", []):
				for t in traits:
					if str(rule).to_lower().begins_with(t.to_lower() + ":"):
						found_any = true
						if not ETR.enemy_has_trait(ename, t):
							missed.append("%s / %s" % [ename, t])
	assert_bool(found_any).override_failure_message(
		"the data file carries none of these traits — the walk found nothing"
	).is_true()
	assert_array(missed).override_failure_message(
		"traits present in the data but not resolved: %s" % [missed]).is_empty()
