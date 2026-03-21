extends GdUnitTestSuite
## Tests for PlayerProfile Elite Ranks bonus system
## Covers all 4 NOT_TESTED Elite Rank formulas from QA_CORE_RULES_TEST_PLAN.md §9b
## Core Rules Reference: p.65 Elite Ranks

const PlayerProfile := preload("res://src/core/player/PlayerProfile.gd")

var profile: PlayerProfile

func before_test():
	"""Create fresh profile for each test"""
	profile = PlayerProfile.new()
	profile.elite_ranks = 0
	profile.completed_victory_conditions = []
	profile.total_campaigns_completed = 0
	profile.total_campaigns_started = 0

func after_test():
	profile = null

# ============================================================================
# Story Point Bonus (+1 per rank)
# ============================================================================

func test_story_point_bonus_zero_ranks():
	profile.elite_ranks = 0
	assert_that(profile.get_starting_story_point_bonus()).is_equal(0)

func test_story_point_bonus_one_rank():
	profile.elite_ranks = 1
	assert_that(profile.get_starting_story_point_bonus()).is_equal(1)

func test_story_point_bonus_five_ranks():
	profile.elite_ranks = 5
	assert_that(profile.get_starting_story_point_bonus()).is_equal(5)

func test_story_point_bonus_ten_ranks():
	profile.elite_ranks = 10
	assert_that(profile.get_starting_story_point_bonus()).is_equal(10)

# ============================================================================
# XP Bonus (+2 per rank)
# ============================================================================

func test_xp_bonus_zero_ranks():
	profile.elite_ranks = 0
	assert_that(profile.get_starting_xp_bonus()).is_equal(0)

func test_xp_bonus_one_rank():
	profile.elite_ranks = 1
	assert_that(profile.get_starting_xp_bonus()).is_equal(2)

func test_xp_bonus_five_ranks():
	profile.elite_ranks = 5
	assert_that(profile.get_starting_xp_bonus()).is_equal(10)

func test_xp_bonus_three_ranks():
	profile.elite_ranks = 3
	assert_that(profile.get_starting_xp_bonus()).is_equal(6)

# ============================================================================
# Extra Starting Characters (+1 per 3 ranks)
# ============================================================================

func test_extra_characters_zero_ranks():
	profile.elite_ranks = 0
	assert_that(profile.get_extra_starting_characters()).is_equal(0)

func test_extra_characters_one_rank():
	"""1 rank / 3 = 0 (rounded down)"""
	profile.elite_ranks = 1
	assert_that(profile.get_extra_starting_characters()).is_equal(0)

func test_extra_characters_two_ranks():
	"""2 / 3 = 0 (rounded down)"""
	profile.elite_ranks = 2
	assert_that(profile.get_extra_starting_characters()).is_equal(0)

func test_extra_characters_three_ranks():
	"""3 / 3 = 1 (first extra character)"""
	profile.elite_ranks = 3
	assert_that(profile.get_extra_starting_characters()).is_equal(1)

func test_extra_characters_six_ranks():
	"""6 / 3 = 2"""
	profile.elite_ranks = 6
	assert_that(profile.get_extra_starting_characters()).is_equal(2)

func test_extra_characters_nine_ranks():
	"""9 / 3 = 3"""
	profile.elite_ranks = 9
	assert_that(profile.get_extra_starting_characters()).is_equal(3)

func test_extra_characters_boundary_four_ranks():
	"""4 / 3 = 1 (integer division, rounds down)"""
	profile.elite_ranks = 4
	assert_that(profile.get_extra_starting_characters()).is_equal(1)

# ============================================================================
# Stars of the Story Bonus Uses (1 + rank/5)
# ============================================================================

func test_stars_uses_zero_ranks():
	"""Base = 1 use even with no elite ranks"""
	profile.elite_ranks = 0
	assert_that(profile.get_stars_of_story_bonus_uses()).is_equal(1)

func test_stars_uses_four_ranks():
	"""1 + 4/5 = 1 + 0 = 1"""
	profile.elite_ranks = 4
	assert_that(profile.get_stars_of_story_bonus_uses()).is_equal(1)

func test_stars_uses_five_ranks():
	"""1 + 5/5 = 1 + 1 = 2"""
	profile.elite_ranks = 5
	assert_that(profile.get_stars_of_story_bonus_uses()).is_equal(2)

func test_stars_uses_ten_ranks():
	"""1 + 10/5 = 1 + 2 = 3"""
	profile.elite_ranks = 10
	assert_that(profile.get_stars_of_story_bonus_uses()).is_equal(3)

func test_stars_uses_seven_ranks():
	"""1 + 7/5 = 1 + 1 = 2 (integer division)"""
	profile.elite_ranks = 7
	assert_that(profile.get_stars_of_story_bonus_uses()).is_equal(2)

# ============================================================================
# Award Elite Rank (duplicate prevention)
# ============================================================================

func test_award_first_rank():
	var result = profile.award_elite_rank(0)
	assert_that(result).is_true()
	assert_that(profile.elite_ranks).is_equal(1)
	assert_that(profile.total_campaigns_completed).is_equal(1)

func test_award_duplicate_rank_rejected():
	profile.award_elite_rank(0)
	var result = profile.award_elite_rank(0)
	assert_that(result).is_false()
	assert_that(profile.elite_ranks).is_equal(1)

func test_award_different_victories():
	profile.award_elite_rank(0)
	var result = profile.award_elite_rank(1)
	assert_that(result).is_true()
	assert_that(profile.elite_ranks).is_equal(2)

func test_has_completed_victory():
	profile.award_elite_rank(3)
	assert_that(profile.has_completed_victory(3)).is_true()
	assert_that(profile.has_completed_victory(4)).is_false()

# ============================================================================
# Reset Profile
# ============================================================================

func test_reset_clears_all():
	profile.elite_ranks = 5
	profile.completed_victory_conditions = [0, 1, 2]
	profile.total_campaigns_completed = 3
	profile.total_campaigns_started = 5
	profile.reset_profile()
	assert_that(profile.elite_ranks).is_equal(0)
	assert_that(profile.completed_victory_conditions.size()).is_equal(0)
	assert_that(profile.total_campaigns_completed).is_equal(0)
	assert_that(profile.total_campaigns_started).is_equal(0)

# ============================================================================
# Bonus Summary (integration)
# ============================================================================

func test_bonus_summary_structure():
	profile.elite_ranks = 6
	profile.total_campaigns_completed = 3
	profile.total_campaigns_started = 5
	var summary = profile.get_bonus_summary()
	assert_that(summary.elite_ranks).is_equal(6)
	assert_that(summary.story_points).is_equal(6)
	assert_that(summary.bonus_xp).is_equal(12)
	assert_that(summary.extra_characters).is_equal(2)
	assert_that(summary.stars_uses).is_equal(2)
	assert_that(summary.campaigns_completed).is_equal(3)
	assert_that(summary.campaigns_started).is_equal(5)

func test_bonus_summary_all_zero():
	var summary = profile.get_bonus_summary()
	assert_that(summary.elite_ranks).is_equal(0)
	assert_that(summary.story_points).is_equal(0)
	assert_that(summary.bonus_xp).is_equal(0)
	assert_that(summary.extra_characters).is_equal(0)
	assert_that(summary.stars_uses).is_equal(1)  # Base 1 even at rank 0

# ============================================================================
# Campaign Start Registration
# ============================================================================

func test_register_campaign_start():
	assert_that(profile.total_campaigns_started).is_equal(0)
	profile.register_campaign_start()
	assert_that(profile.total_campaigns_started).is_equal(1)
	profile.register_campaign_start()
	assert_that(profile.total_campaigns_started).is_equal(2)
