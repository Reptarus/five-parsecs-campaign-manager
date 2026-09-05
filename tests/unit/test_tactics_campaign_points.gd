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
