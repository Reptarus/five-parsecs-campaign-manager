extends GdUnitTestSuite
## The starting-resource ledger: every book grant counted EXACTLY ONCE.
##
## Core Rules p.28 (credits) and p.66 (story points) are each granted at one
## site. They used to be granted at three and zero respectively:
##
##   credits — the Equipment step computed `crew_size × 1cr + Σ bonus_credits`
##     (the complete book total), and finalization then ADDED `bonus_credits`
##     again AND re-rolled a fresh 1D6 for every WEALTH member, on top of the
##     1D6 character creation had already rolled into creation_bonuses. A crew
##     walked in with roughly double what the review screen promised.
##
##   story points — "begin the game with 1D6+1 story points" was implemented
##     nowhere, so a crew whose creation tables granted none opened on zero.
##
## These assert the ARITHMETIC through the pure statics rather than running
## finalization, which registers a campaign start against the player's on-disk
## profile and resets half a dozen autoloads.

const FinalizationService = preload(
	"res://src/core/campaign/creation/CampaignFinalizationService.gd")

# ── Credits (Core Rules p.28) ────────────────────────────────────────────

func test_equipment_total_is_the_credits_total() -> void:
	# 17 = 6 crew × 1cr + 11 rolled bonus credits, already summed by the
	# equipment step. Adding crew_data's copy of the same 11 would give 28.
	var equipment := {"credits": 17}
	var crew := {"bonus_credits": 11, "members": [{}, {}, {}, {}, {}, {}]}
	assert_int(FinalizationService.compute_starting_credits(equipment, crew)) \
		.override_failure_message(
			"the equipment step's total IS the book total — bonus credits must not be added twice"
		).is_equal(17)

func test_crew_bonus_credits_are_never_added_on_top() -> void:
	# Same equipment total, wildly different crew bonus: the answer cannot move.
	var equipment := {"credits": 17}
	var lean := FinalizationService.compute_starting_credits(
		equipment, {"bonus_credits": 0, "members": [{}, {}, {}, {}, {}, {}]})
	var rich := FinalizationService.compute_starting_credits(
		equipment, {"bonus_credits": 40, "members": [{}, {}, {}, {}, {}, {}]})
	assert_int(rich).is_equal(lean)

func test_starting_credits_accepts_either_spelling() -> void:
	# get_panel_data() exports "credits"; the campaign payload uses
	# "starting_credits". Both must resolve to the same total.
	var crew := {"bonus_credits": 5, "members": [{}, {}, {}]}
	assert_int(FinalizationService.compute_starting_credits({"starting_credits": 12}, crew)) \
		.is_equal(12)
	assert_int(FinalizationService.compute_starting_credits({"credits": 12}, crew)) \
		.is_equal(12)

func test_credits_are_reconstructed_when_the_equipment_step_never_ran() -> void:
	# The only path where the crew-level figures are still needed: no equipment
	# total at all. Then it is 1cr per crew member plus the rolled bonus.
	var crew := {"bonus_credits": 11, "members": [{}, {}, {}, {}, {}, {}]}
	assert_int(FinalizationService.compute_starting_credits({}, crew)) \
		.override_failure_message("6 crew × 1cr + 11 bonus = 17").is_equal(17)

func test_reconstruction_prefers_the_resources_credits_when_present() -> void:
	var crew := {"bonus_credits": 11, "members": [{}, {}, {}, {}, {}, {}]}
	assert_int(FinalizationService.compute_starting_credits({}, crew, {"credits": 20})) \
		.is_equal(26)

# ── Story points (Core Rules p.66) ───────────────────────────────────────

func test_starting_story_points_are_1d6_plus_1() -> void:
	# The rule is a roll, so assert the INVARIANT (every result in range, and
	# the full range is reachable) rather than any single value.
	var low_seen := false
	var high_seen := false
	for _i in range(400):
		var rolled: int = FinalizationService.roll_starting_story_points()
		assert_int(rolled).override_failure_message(
			"1D6+1 can only ever produce 2..7, got %d" % rolled
		).is_between(2, 7)
		if rolled == 2:
			low_seen = true
		if rolled == 7:
			high_seen = true
	assert_bool(low_seen).override_failure_message(
		"a 1D6+1 that never produces 2 is not a 1D6+1").is_true()
	assert_bool(high_seen).override_failure_message(
		"a 1D6+1 that never produces 7 is not a 1D6+1").is_true()

func test_starting_story_points_are_never_zero() -> void:
	# The regression this exists to catch: no roll at all, so a crew whose
	# tables granted nothing began the campaign unable to use story points.
	for _i in range(200):
		assert_int(FinalizationService.roll_starting_story_points()).is_greater(0)
