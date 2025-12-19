extends GdUnitTestSuite
## Sprint 1: Story Point System Tests
## Tests StoryPointSystem implementation
## Core Rules Reference: p.66-67 (Story Points)
## gdUnit4 v6.0.1 compatible

# System under test
var StoryPointSystem
var story_system
var mock_campaign

func before():
	"""Suite-level setup - runs once before all tests"""
	StoryPointSystem = load("res://src/core/systems/StoryPointSystem.gd")

func after():
	"""Suite-level cleanup - runs once after all tests"""
	StoryPointSystem = null

func before_test():
	"""Test-level setup - runs before EACH test"""
	# Create mock campaign for difficulty checks
	# StoryPointSystem expects an object with a 'config' property
	var MockCampaign = GDScript.new()
	MockCampaign.source_code = "extends RefCounted\n\nvar config: Dictionary = {}\n"
	@warning_ignore("return_value_discarded")
	MockCampaign.reload()
	mock_campaign = auto_free(MockCampaign.new())
	mock_campaign.config = {"difficulty": 2}  # Default to standard difficulty

	# Initialize story system with mock campaign
	story_system = auto_free(StoryPointSystem.new(mock_campaign))

func after_test():
	"""Test-level cleanup - runs after EACH test"""
	story_system = null
	mock_campaign = null

# ============================================================================
# Starting Points Tests (1D6+1 base, with difficulty modifiers)
# ============================================================================

func test_starting_points_range_2_to_7():
	"""Starting points should be 1D6+1 (range 2-7) for standard difficulty"""
	mock_campaign.config = {"difficulty": 2}  # Standard mode

	# Test multiple rolls to ensure range
	var rolls_in_range := 0
	for i in range(20):
		story_system = StoryPointSystem.new(mock_campaign)
		var points = story_system.initialize_starting_points(2)
		if points >= 2 and points <= 7:
			rolls_in_range += 1

	# All rolls should be in valid range
	assert_that(rolls_in_range).is_equal(20)

func test_hardcore_reduces_starting_by_1():
	"""Hardcore mode should reduce starting story points by 1"""
	var GlobalEnums = load("res://src/core/systems/GlobalEnums.gd")
	var hardcore_difficulty = GlobalEnums.DifficultyLevel.HARDCORE
	mock_campaign.config = {"difficulty": hardcore_difficulty}

	# Initialize with hardcore difficulty
	var points = story_system.initialize_starting_points(hardcore_difficulty)

	# Result should be (1D6+1)-1 = range 1-6
	assert_that(points).is_between(1, 6)

func test_nightmare_returns_zero_points():
	"""Nightmare mode should disable story points entirely (0 starting points)"""
	# StoryPointSystem uses difficulty == NIGHTMARE (5) to disable story points
	mock_campaign.config = {"difficulty": 5}  # GlobalEnums.DifficultyLevel.NIGHTMARE

	# Create system with nightmare config
	story_system = StoryPointSystem.new(mock_campaign)
	var points = story_system.initialize_starting_points(5)

	assert_that(points).is_equal(0)
	assert_that(story_system.get_current_points()).is_equal(0)

# ============================================================================
# Earning Points Tests
# ============================================================================

func test_earn_point_every_third_turn():
	"""Should earn 1 story point on turns 3, 6, 9, 12, etc."""
	mock_campaign.config = {"difficulty": 2}  # Standard mode
	story_system.initialize_starting_points(2)

	# Turn 3 should earn point
	var earned_turn_3 = story_system.check_turn_earning(3)
	assert_that(earned_turn_3).is_equal(1)

	# Turn 6 should earn point
	var earned_turn_6 = story_system.check_turn_earning(6)
	assert_that(earned_turn_6).is_equal(1)

	# Turn 9 should earn point
	var earned_turn_9 = story_system.check_turn_earning(9)
	assert_that(earned_turn_9).is_equal(1)

	# Turn 4 should NOT earn point
	var earned_turn_4 = story_system.check_turn_earning(4)
	assert_that(earned_turn_4).is_equal(0)

func test_earn_point_on_held_field_with_death():
	"""Should earn 1 point if holding field after battle when character was killed"""
	mock_campaign.config = {"difficulty": 2}
	story_system.initialize_starting_points(2)

	# Held field AND character killed = earn point
	var earned = story_system.check_battle_earning(true, true)
	assert_that(earned).is_equal(1)

func test_no_point_if_held_field_without_death():
	"""Should NOT earn point if holding field but no character killed"""
	mock_campaign.config = {"difficulty": 2}
	story_system.initialize_starting_points(2)

	var earned = story_system.check_battle_earning(true, false)
	assert_that(earned).is_equal(0)

func test_no_point_if_death_without_held_field():
	"""Should NOT earn point if character killed but field not held"""
	mock_campaign.config = {"difficulty": 2}
	story_system.initialize_starting_points(2)

	var earned = story_system.check_battle_earning(false, true)
	assert_that(earned).is_equal(0)

# ============================================================================
# Spending Points Tests (Per-turn limits)
# ============================================================================

func test_credits_spend_once_per_turn():
	"""GET_CREDITS should only be usable once per turn"""
	mock_campaign.config = {"difficulty": 2}
	story_system.initialize_starting_points(2)
	story_system.add_points(5, "test")  # Ensure enough points

	# First spend should succeed
	var first_spend = story_system.spend_point(StoryPointSystem.SpendType.GET_CREDITS)
	assert_that(first_spend).is_true()

	# Second spend same turn should fail
	var second_spend = story_system.spend_point(StoryPointSystem.SpendType.GET_CREDITS)
	assert_that(second_spend).is_false()

	# After reset, should work again
	story_system.reset_turn_limits()
	var after_reset_spend = story_system.spend_point(StoryPointSystem.SpendType.GET_CREDITS)
	assert_that(after_reset_spend).is_true()

func test_xp_spend_once_per_turn():
	"""GET_XP should only be usable once per turn"""
	mock_campaign.config = {"difficulty": 2}
	story_system.initialize_starting_points(2)
	story_system.add_points(5, "test")

	var first_spend = story_system.spend_point(StoryPointSystem.SpendType.GET_XP)
	assert_that(first_spend).is_true()

	var second_spend = story_system.spend_point(StoryPointSystem.SpendType.GET_XP)
	assert_that(second_spend).is_false()

func test_extra_action_spend_once_per_turn():
	"""EXTRA_ACTION should only be usable once per turn"""
	mock_campaign.config = {"difficulty": 2}
	story_system.initialize_starting_points(2)
	story_system.add_points(5, "test")

	var first_spend = story_system.spend_point(StoryPointSystem.SpendType.EXTRA_ACTION)
	assert_that(first_spend).is_true()

	var second_spend = story_system.spend_point(StoryPointSystem.SpendType.EXTRA_ACTION)
	assert_that(second_spend).is_false()

func test_roll_twice_unlimited_per_turn():
	"""ROLL_TWICE_PICK_ONE should be unlimited uses per turn"""
	mock_campaign.config = {"difficulty": 2}
	story_system.initialize_starting_points(2)
	story_system.add_points(10, "test")  # Ensure enough points for multiple spends

	# Should succeed multiple times
	var spend_1 = story_system.spend_point(StoryPointSystem.SpendType.ROLL_TWICE_PICK_ONE)
	assert_that(spend_1).is_true()

	var spend_2 = story_system.spend_point(StoryPointSystem.SpendType.ROLL_TWICE_PICK_ONE)
	assert_that(spend_2).is_true()

	var spend_3 = story_system.spend_point(StoryPointSystem.SpendType.ROLL_TWICE_PICK_ONE)
	assert_that(spend_3).is_true()

func test_reroll_unlimited_per_turn():
	"""REROLL_RESULT should be unlimited uses per turn"""
	mock_campaign.config = {"difficulty": 2}
	story_system.initialize_starting_points(2)
	story_system.add_points(10, "test")

	var spend_1 = story_system.spend_point(StoryPointSystem.SpendType.REROLL_RESULT)
	assert_that(spend_1).is_true()

	var spend_2 = story_system.spend_point(StoryPointSystem.SpendType.REROLL_RESULT)
	assert_that(spend_2).is_true()

# ============================================================================
# Turn Limit Reset Tests
# ============================================================================

func test_reset_turn_limits():
	"""reset_turn_limits() should reset all per-turn spending flags"""
	mock_campaign.config = {"difficulty": 2}
	story_system.initialize_starting_points(2)
	story_system.add_points(10, "test")

	# Spend all limited abilities
	story_system.spend_point(StoryPointSystem.SpendType.GET_CREDITS)
	story_system.spend_point(StoryPointSystem.SpendType.GET_XP)
	story_system.spend_point(StoryPointSystem.SpendType.EXTRA_ACTION)

	# All should be blocked before reset
	assert_that(story_system.can_spend(StoryPointSystem.SpendType.GET_CREDITS)).is_false()
	assert_that(story_system.can_spend(StoryPointSystem.SpendType.GET_XP)).is_false()
	assert_that(story_system.can_spend(StoryPointSystem.SpendType.EXTRA_ACTION)).is_false()

	# Reset turn limits
	story_system.reset_turn_limits()

	# All should be available again
	assert_that(story_system.can_spend(StoryPointSystem.SpendType.GET_CREDITS)).is_true()
	assert_that(story_system.can_spend(StoryPointSystem.SpendType.GET_XP)).is_true()
	assert_that(story_system.can_spend(StoryPointSystem.SpendType.EXTRA_ACTION)).is_true()

# ============================================================================
# Hardcore Mode Tests (Reduced Points, Still Functional)
# ============================================================================

func test_hardcore_allows_spending():
	"""In Hardcore mode, story points should still work (just reduced starting amount)"""
	mock_campaign.config = {"difficulty": 4}  # HARDCORE
	story_system = StoryPointSystem.new(mock_campaign)
	story_system.initialize_starting_points(4)

	# Add points to ensure we have enough
	story_system.add_points(5, "test")

	# Spending should work normally
	assert_that(story_system.can_spend(StoryPointSystem.SpendType.ROLL_TWICE_PICK_ONE)).is_true()
	assert_that(story_system.can_spend(StoryPointSystem.SpendType.GET_CREDITS)).is_true()
	assert_that(story_system.spend_point(StoryPointSystem.SpendType.GET_CREDITS)).is_true()

func test_hardcore_allows_earning():
	"""In Hardcore mode, earning story points should still work"""
	mock_campaign.config = {"difficulty": 4}  # HARDCORE
	story_system = StoryPointSystem.new(mock_campaign)
	story_system.initialize_starting_points(4)

	# Turn earning should work
	var turn_earned = story_system.check_turn_earning(3)
	assert_that(turn_earned).is_equal(1)

	# Battle earning should work
	var battle_earned = story_system.check_battle_earning(true, true)
	assert_that(battle_earned).is_equal(1)

# ============================================================================
# Nightmare Mode Tests (Story Points Disabled)
# ============================================================================

func test_nightmare_cannot_spend_points():
	"""In Nightmare mode, all spending should be blocked"""
	mock_campaign.config = {"difficulty": 5}  # NIGHTMARE
	story_system = StoryPointSystem.new(mock_campaign)
	story_system.initialize_starting_points(5)

	# Try to add points manually (should be ignored)
	story_system.add_points(10, "test")

	# All spending should fail
	assert_that(story_system.can_spend(StoryPointSystem.SpendType.ROLL_TWICE_PICK_ONE)).is_false()
	assert_that(story_system.can_spend(StoryPointSystem.SpendType.GET_CREDITS)).is_false()
	assert_that(story_system.can_spend(StoryPointSystem.SpendType.GET_XP)).is_false()

func test_nightmare_cannot_earn_points():
	"""In Nightmare mode, turn and battle earning should return 0"""
	mock_campaign.config = {"difficulty": 5}  # NIGHTMARE
	story_system = StoryPointSystem.new(mock_campaign)
	story_system.initialize_starting_points(5)

	# Turn earning should return 0
	var turn_earned = story_system.check_turn_earning(3)
	assert_that(turn_earned).is_equal(0)

	# Battle earning should return 0
	var battle_earned = story_system.check_battle_earning(true, true)
	assert_that(battle_earned).is_equal(0)
