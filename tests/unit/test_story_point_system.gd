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

func test_starting_points_are_owned_by_the_finalization_service():
	"""p.66 1D6+1 is granted ONCE, by CampaignFinalizationService.

	⚠ THIS CASE USED TO DRIVE StoryPointSystem.initialize_starting_points(),
	a SECOND grant site that rolled its own 1D6+1 off raw randi() and was
	removed 2026-09-10 with zero callers. The creation invariant is one grant
	site per rule, so testing the roll here was testing the wrong function.
	The roll's own invariant is pinned in far more depth (400 iterations, both
	extremes) by test_creation_resource_ledger.gd; this case exists only to
	assert that the owner is reachable and in range."""
	var FinalizationService = load(
		"res://src/core/campaign/creation/CampaignFinalizationService.gd")
	for _i in range(20):
		assert_that(FinalizationService.roll_starting_story_points()).is_between(2, 7)

func test_hardcore_reduces_starting_by_1():
	"""Hardcore reduces the p.66 starting points, via DifficultyModifiers.

	The modifier is NOT part of the roll — CampaignFinalizationService rolls
	1D6+1 and DifficultyModifiers.apply_starting_story_points_modifier() then
	adjusts it from data/difficulty_modifiers.json. That split is deliberate and
	documented at roll_starting_story_points(); assert it where it lives."""
	var DifficultyModifiers = load("res://src/core/systems/DifficultyModifiers.gd")
	var GlobalEnums = load("res://src/core/systems/GlobalEnums.gd")
	var hardcore: int = GlobalEnums.DifficultyLevel.HARDCORE
	var normal: int = GlobalEnums.DifficultyLevel.NORMAL

	# Asserted as a RELATIONSHIP, not a constant: the rule is "Hardcore is worse
	# than Normal by exactly one", which stays true if the JSON value is retuned
	# and fails if the modifier stops being applied at all.
	for base in [2, 4, 7]:
		var at_normal: int = DifficultyModifiers.apply_starting_story_points_modifier(
			base, normal)
		var at_hardcore: int = DifficultyModifiers.apply_starting_story_points_modifier(
			base, hardcore)
		assert_that(at_normal).is_equal(base)
		assert_that(at_hardcore).is_equal(base - 1)

func test_starting_points_never_go_negative():
	"""maxi(0, ...) — a base of 0 under Hardcore must floor at 0, not -1."""
	var DifficultyModifiers = load("res://src/core/systems/DifficultyModifiers.gd")
	var GlobalEnums = load("res://src/core/systems/GlobalEnums.gd")
	assert_that(DifficultyModifiers.apply_starting_story_points_modifier(
		0, GlobalEnums.DifficultyLevel.HARDCORE)).is_equal(0)

func test_insanity_returns_zero_starting_points():
	"""Insanity disables story points entirely (Core Rules p.65)."""
	var DifficultyModifiers = load("res://src/core/systems/DifficultyModifiers.gd")
	var GlobalEnums = load("res://src/core/systems/GlobalEnums.gd")
	assert_that(DifficultyModifiers.apply_starting_story_points_modifier(
		7, GlobalEnums.DifficultyLevel.INSANITY)).is_equal(0)

	# ...and the runtime system agrees, so the two cannot disagree about a mode.
	mock_campaign.config = {"difficulty": 5}
	story_system = StoryPointSystem.new(mock_campaign)
	story_system.add_points(7, "test")
	assert_that(story_system.get_current_points()).is_equal(0)

func test_earn_point_every_third_turn():
	"""Should earn 1 story point on turns 3, 6, 9, 12, etc."""
	mock_campaign.config = {"difficulty": 2}  # Standard mode
	story_system.add_points(8, "test setup")

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

## ⚠ THE THREE BATTLE-EARNING CASES THAT SAT HERE WERE REMOVED 2026-09-10.
## They drove StoryPointSystem.check_battle_earning(), a zero-caller duplicate of
## the live rule. Core Rules p.66's "+1 for holding the field after a crew member
## was killed" is implemented by PostBattlePhase._check_bitter_day_story_point()
## and is pinned by tests/tools/verify_post_battle.gd (_row_bitter_day_story_point),
## which asserts it against BOTH casualty payload shapes — coverage this suite
## never had.

# ============================================================================
# Spending Points Tests (Per-turn limits)
# ============================================================================

func test_credits_spend_once_per_turn():
	"""GET_CREDITS should only be usable once per turn"""
	mock_campaign.config = {"difficulty": 2}
	story_system.add_points(8, "test setup")
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
	story_system.add_points(8, "test setup")
	story_system.add_points(5, "test")

	var first_spend = story_system.spend_point(StoryPointSystem.SpendType.GET_XP)
	assert_that(first_spend).is_true()

	var second_spend = story_system.spend_point(StoryPointSystem.SpendType.GET_XP)
	assert_that(second_spend).is_false()

func test_extra_action_spend_once_per_turn():
	"""EXTRA_ACTION should only be usable once per turn"""
	mock_campaign.config = {"difficulty": 2}
	story_system.add_points(8, "test setup")
	story_system.add_points(5, "test")

	var first_spend = story_system.spend_point(StoryPointSystem.SpendType.EXTRA_ACTION)
	assert_that(first_spend).is_true()

	var second_spend = story_system.spend_point(StoryPointSystem.SpendType.EXTRA_ACTION)
	assert_that(second_spend).is_false()

func test_roll_twice_unlimited_per_turn():
	"""ROLL_TWICE_PICK_ONE should be unlimited uses per turn"""
	mock_campaign.config = {"difficulty": 2}
	story_system.add_points(8, "test setup")
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
	story_system.add_points(8, "test setup")
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
	story_system.add_points(8, "test setup")
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
	story_system.add_points(8, "test setup")

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
	story_system.add_points(8, "test setup")

	# Turn earning should work
	var turn_earned = story_system.check_turn_earning(3)
	assert_that(turn_earned).is_equal(1)

	# (Battle earning is PostBattlePhase._check_bitter_day_story_point()'s job —
	# see the note above the Spending section.)

# ============================================================================
# Nightmare Mode Tests (Story Points Disabled)
# ============================================================================

func test_nightmare_cannot_spend_points():
	"""In Nightmare mode, all spending should be blocked"""
	mock_campaign.config = {"difficulty": 5}  # NIGHTMARE
	story_system = StoryPointSystem.new(mock_campaign)
	story_system.add_points(8, "test setup")

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
	story_system.add_points(8, "test setup")

	# Turn earning should return 0
	var turn_earned = story_system.check_turn_earning(3)
	assert_that(turn_earned).is_equal(0)

	# ...and nothing can be added by hand either, which is the same clause.
	story_system.add_points(10, "test")
	assert_that(story_system.get_current_points()).is_equal(0)
