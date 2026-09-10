extends GdUnitTestSuite
## Tactics pp.106-107 "CAMPAIGN PROGRESSION" - the Campaign Point award.
##
## Verified against docs/rules/tactics_source.txt (raw page marker minus 2 gives the
## printed folio; the book's own index also lists "Campaign Points (CP) 106"):
##   "CP are awarded after every campaign game played. Roll three D6s and drop the
##    lowest result. The sum of the two remaining dice is the base number of CP
##    awarded."
##   "If the scenario played uses victory points (see page 73), 1 CP is awarded for
##    every VP earned."
##   "If the scenario did not us[e] victory points, award: 3 additional CP for a
##    victory, 2 additional CP for a draw, and 1 additional CP for a defeat or
##    inconclusive battle where neither side achieved anything."
##   "Example: If the roll is a 2, 3, and 5, the base award is 8 CP. If I earned 3 VP
##    in the battle, I would receive a total of 11 CP."
##
## Before 2026-09-04 the award was a flat 1, +1 for a win, +1 for a "secondary
## objective" - a maximum of 3 CP - cited to "p.160", a page in the Lifeforms
## bestiary. The base roll alone averages ~8.5, so a Tactics campaign earned about a
## quarter of the progression currency the book grants, and "secondary objective" is
## not a book category at all. CP gates every unit upgrade, roster change and battle
## advantage, so this throttled the whole campaign layer.

const TacticsCore = preload("res://src/game/campaign/TacticsCampaignCore.gd")


func test_the_books_own_worked_example() -> void:
	## "If the roll is a 2, 3, and 5, the base award is 8 CP."
	## "If I earned 3 VP in the battle, I would receive a total of 11 CP."
	assert_int(TacticsCore.campaign_points_for({"victory_points": 3}, [2, 3, 5])) \
		.override_failure_message(
			"the book states this exact example on p.107: base 8, +3 VP, total 11"
		).is_equal(11)


func test_base_award_drops_the_lowest_die() -> void:
	# 2 + 3 + 5 -> drop the 2 -> 3 + 5 = 8, then the defeat row (+1).
	assert_int(TacticsCore.campaign_points_for({}, [2, 3, 5])).is_equal(9)
	# Order must not matter.
	assert_int(TacticsCore.campaign_points_for({}, [5, 2, 3])).is_equal(9)
	# All sixes: drop one, 6 + 6 = 12, +1 = 13.
	assert_int(TacticsCore.campaign_points_for({}, [6, 6, 6])).is_equal(13)


func test_victory_draw_and_defeat_ladder() -> void:
	# Base 8 from 2/3/5, plus each row of the no-VP ladder.
	assert_int(TacticsCore.campaign_points_for({"won": true}, [2, 3, 5])) \
		.override_failure_message("3 additional CP for a victory").is_equal(11)
	assert_int(TacticsCore.campaign_points_for({"draw": true}, [2, 3, 5])) \
		.override_failure_message("2 additional CP for a draw").is_equal(10)
	assert_int(TacticsCore.campaign_points_for({}, [2, 3, 5])) \
		.override_failure_message(
			"1 additional CP for a defeat or inconclusive battle"
		).is_equal(9)


func test_victory_points_replace_the_ladder_rather_than_stacking() -> void:
	## The book gives the VP branch and the victory/draw/defeat ladder as
	## alternatives - "If the scenario did not us[e] victory points, award: ..." -
	## so a won battle WITH victory points must not collect both.
	var with_vp: int = TacticsCore.campaign_points_for(
		{"won": true, "victory_points": 3}, [2, 3, 5])
	assert_int(with_vp).override_failure_message(
		"VP replaces the ladder: 8 + 3 = 11, not 8 + 3 + 3"
	).is_equal(11)


func test_zero_victory_points_is_still_the_vp_branch() -> void:
	# A VP scenario where the player scored nothing awards the base only.
	assert_int(TacticsCore.campaign_points_for({"victory_points": 0}, [2, 3, 5])) \
		.is_equal(8)


func test_award_is_never_the_old_flat_maximum_of_three() -> void:
	## Detection guard: the old rule could never exceed 3 CP. The book's minimum
	## possible award is 1+1 base (three 1s, drop one) + 1 defeat = 3, and its
	## maximum is 13 - so assert the SPREAD the old constants could not produce.
	var lowest: int = TacticsCore.campaign_points_for({}, [1, 1, 1])
	var highest: int = TacticsCore.campaign_points_for({"won": true}, [6, 6, 6])
	assert_int(lowest).is_equal(3)
	assert_int(highest).override_failure_message(
		"a flat 1/+1/+1 award caps at 3; the book's ceiling is 6+6+3"
	).is_equal(15)


## ---------------------------------------------------------------------------
## The SPEND side - Tactics pp.107-108. Added 2026-09-10 after deploy #35 showed
## the Advancement phase offering "Unit Upgrade (1 CP): Acquire a veteran skill"
## on real glass, beside p.107's **Gain Veteran Skill (4 CP)**.
##
## The award bug above and this one are the same defect on opposite sides of the
## ledger: a fabricated flat number standing in for a book table. That audit read
## what CP a player EARNS and never looked at what they PAY.
## ---------------------------------------------------------------------------

func test_gain_veteran_skill_is_four_cp_not_one() -> void:
	## p.107 "Gain Veteran Skill (4 CP)" - tactics_source.txt line 7099.
	## The headline case: this is the value that shipped as 1 CP.
	assert_int(TacticsCore.cp_cost("veteran_skill")).is_equal(4)


func test_every_catalogue_price_matches_the_book() -> void:
	## pp.107-108, verbatim. Every one of these is quoted in the book with its cost
	## in the heading, so a wrong value here is a wrong value a player is charged.
	var book := {
		"veteran_skill": 4, "retrain_unit": 2, "hero_trait": 2, "leader_trait": 4,
		"unit_refit": 1, "unit_customization": 1, "unit_replacement": 1,
		"roster_addition": 3, "replace_destroyed": 1,
		"battle_support": 2, "battle_finesse": 1, "battle_luck": 1,
		"battle_initiative": 1,
	}
	for purchase_id: String in book:
		assert_int(TacticsCore.cp_cost(purchase_id)) 			.override_failure_message(
				"%s should cost %d CP per Tactics pp.107-108"
				% [purchase_id, int(book[purchase_id])]) 			.is_equal(int(book[purchase_id]))
	## ...and the catalogue carries nothing the book does not price.
	assert_int(TacticsCore.CP_PURCHASES.size()).is_equal(book.size())


func test_no_purchase_is_free() -> void:
	## The INVARIANT, not the constants: the book prices every purchase at 1-4 CP,
	## so a 0 anywhere in the catalogue is a purchase the player gets for nothing.
	for entry: Dictionary in TacticsCore.CP_PURCHASES:
		var cost: int = int(entry.get("cost", 0))
		assert_bool(cost >= 1 and cost <= 4) 			.override_failure_message(
				"%s priced at %d CP - outside the book's 1-4 range"
				% [str(entry.get("id", "?")), cost]) 			.is_true()


func test_an_unknown_purchase_id_costs_zero_and_zero_means_refuse() -> void:
	## cp_cost() returns 0 for an id it does not know. The panel treats 0 as
	## REFUSE, never as free - a plausible wrong price is worse than no price.
	assert_int(TacticsCore.cp_cost("no_such_purchase")).is_equal(0)
	assert_dict(TacticsCore.cp_purchase("no_such_purchase")).is_empty()


func test_every_entry_carries_the_fields_the_panel_renders() -> void:
	## TacticsPostBattlePanel builds its card text AND its buttons from this array.
	## A missing key renders as an empty string next to a real price, which reads as
	## a purchase with no name rather than as a bug.
	for entry: Dictionary in TacticsCore.CP_PURCHASES:
		for key: String in ["id", "group", "name", "cost", "desc"]:
			assert_bool(entry.has(key)) 				.override_failure_message(
					"catalogue entry %s is missing '%s'"
					% [str(entry.get("id", "?")), key]) 				.is_true()


## ---------------------------------------------------------------------------
## The battle-history record. Measured on deploy #35: a Turn-1 victory that
## awarded 12 CP rendered as "Turn 0: Victory - CP earned: 0", because
## TacticsDashboard._build_battle_history() reads `turn` and `cp_earned` and the
## producer appended only {"won": true}. A consumer read with no producer write is
## a SILENT DEFAULT, never an error.
## ---------------------------------------------------------------------------

func test_record_battle_stamps_the_turn_the_history_view_reads() -> void:
	var core = TacticsCore.new()
	core.campaign_turn = 3
	core.record_battle({"won": true})
	assert_int(core.battle_history.size()).is_equal(1)
	assert_int(int(core.battle_history[0].get("turn", -1))).is_equal(3)


func test_record_battle_stamps_the_cp_it_actually_awarded() -> void:
	## The award is a 3D6 roll, so the VALUE is not assertable - but the stamped
	## `cp_earned` must equal the CP the campaign actually gained, whatever rolled.
	var core = TacticsCore.new()
	core.campaign_turn = 1
	var before: int = core.campaign_points_earned
	core.record_battle({"won": true})
	var gained: int = core.campaign_points_earned - before
	assert_int(int(core.battle_history[0].get("cp_earned", -1))).is_equal(gained)
	## ...and a victory can never award 0, so a 0 here would be the old silent default.
	assert_int(gained).is_greater(0)


func test_the_original_result_keys_survive_the_stamp() -> void:
	## The stamp must ADD to the entry, never replace it - `won` drives the
	## Victory/Defeat label and the colour.
	var core = TacticsCore.new()
	core.record_battle({"won": false, "victory_points": 2})
	var entry: Dictionary = core.battle_history[0]
	assert_bool(bool(entry.get("won", true))).is_false()
	assert_int(int(entry.get("victory_points", -1))).is_equal(2)

