extends GdUnitTestSuite
## Sprint 1: Stars of the Story System Tests
## Tests StarsOfTheStorySystem implementation (one-time emergency abilities)
## Core Rules Reference: p.67 (Stars of the Story)
## gdUnit4 v6.0.1 compatible

# System under test
var StarsOfTheStorySystem
var stars_system

func before():
	"""Suite-level setup - runs once before all tests"""
	StarsOfTheStorySystem = load("res://src/core/systems/StarsOfTheStorySystem.gd")

func after():
	"""Suite-level cleanup - runs once after all tests"""
	StarsOfTheStorySystem = null

func before_test():
	"""Test-level setup - runs before EACH test"""
	stars_system = auto_free(StarsOfTheStorySystem.new())

func after_test():
	"""Test-level cleanup - runs after EACH test"""
	stars_system = null

# ============================================================================
# Initial Uses Tests (Standard Difficulty)
# ============================================================================

func test_initial_uses_are_one_each():
	"""Each ability should start with 1 use in standard difficulty"""
	stars_system.initialize(0, 2)  # 0 elite ranks, standard difficulty

	assert_that(stars_system.get_uses_remaining(StarsOfTheStorySystem.StarAbility.IT_WASNT_THAT_BAD)).is_equal(1)
	assert_that(stars_system.get_uses_remaining(StarsOfTheStorySystem.StarAbility.DRAMATIC_ESCAPE)).is_equal(1)
	assert_that(stars_system.get_uses_remaining(StarsOfTheStorySystem.StarAbility.ITS_TIME_TO_GO)).is_equal(1)
	assert_that(stars_system.get_uses_remaining(StarsOfTheStorySystem.StarAbility.RAINY_DAY_FUND)).is_equal(1)

func test_max_uses_are_one_each_initially():
	"""Max uses should be 1 for each ability without elite ranks"""
	stars_system.initialize(0, 2)

	assert_that(stars_system.get_max_uses(StarsOfTheStorySystem.StarAbility.IT_WASNT_THAT_BAD)).is_equal(1)
	assert_that(stars_system.get_max_uses(StarsOfTheStorySystem.StarAbility.DRAMATIC_ESCAPE)).is_equal(1)
	assert_that(stars_system.get_max_uses(StarsOfTheStorySystem.StarAbility.ITS_TIME_TO_GO)).is_equal(1)
	assert_that(stars_system.get_max_uses(StarsOfTheStorySystem.StarAbility.RAINY_DAY_FUND)).is_equal(1)

# ============================================================================
# Elite Ranks Bonus Uses Tests (Every 5 ranks = +1 use)
# ============================================================================

func test_elite_ranks_5_adds_extra_use():
	"""Every 5 elite ranks should grant 1 bonus use to one ability"""
	# Initialize with 5 elite ranks
	stars_system.initialize(5, 2)  # 5 elite ranks, standard difficulty

	# At least one ability should have 2 uses now
	var total_uses := 0
	total_uses += stars_system.get_max_uses(StarsOfTheStorySystem.StarAbility.IT_WASNT_THAT_BAD)
	total_uses += stars_system.get_max_uses(StarsOfTheStorySystem.StarAbility.DRAMATIC_ESCAPE)
	total_uses += stars_system.get_max_uses(StarsOfTheStorySystem.StarAbility.ITS_TIME_TO_GO)
	total_uses += stars_system.get_max_uses(StarsOfTheStorySystem.StarAbility.RAINY_DAY_FUND)

	# Total should be 5 (4 base + 1 bonus)
	assert_that(total_uses).is_equal(5)

func test_elite_ranks_10_adds_two_extra_uses():
	"""10 elite ranks should grant 2 bonus uses distributed across abilities"""
	stars_system.initialize(10, 2)

	var total_uses := 0
	total_uses += stars_system.get_max_uses(StarsOfTheStorySystem.StarAbility.IT_WASNT_THAT_BAD)
	total_uses += stars_system.get_max_uses(StarsOfTheStorySystem.StarAbility.DRAMATIC_ESCAPE)
	total_uses += stars_system.get_max_uses(StarsOfTheStorySystem.StarAbility.ITS_TIME_TO_GO)
	total_uses += stars_system.get_max_uses(StarsOfTheStorySystem.StarAbility.RAINY_DAY_FUND)

	# Total should be 6 (4 base + 2 bonus)
	assert_that(total_uses).is_equal(6)

func test_elite_ranks_4_no_bonus():
	"""Elite ranks below 5 should not grant bonus uses"""
	stars_system.initialize(4, 2)

	var total_uses := 0
	total_uses += stars_system.get_max_uses(StarsOfTheStorySystem.StarAbility.IT_WASNT_THAT_BAD)
	total_uses += stars_system.get_max_uses(StarsOfTheStorySystem.StarAbility.DRAMATIC_ESCAPE)
	total_uses += stars_system.get_max_uses(StarsOfTheStorySystem.StarAbility.ITS_TIME_TO_GO)
	total_uses += stars_system.get_max_uses(StarsOfTheStorySystem.StarAbility.RAINY_DAY_FUND)

	# Total should be 4 (no bonus)
	assert_that(total_uses).is_equal(4)

# ============================================================================
# Insanity Mode Tests (Difficulty 4)
# ============================================================================

func test_insanity_disables_all_abilities():
	"""Insanity mode should disable all Stars of the Story abilities"""
	stars_system.initialize(0, 4)  # Difficulty 4 = Insanity

	# All abilities should have 0 uses
	assert_that(stars_system.get_uses_remaining(StarsOfTheStorySystem.StarAbility.IT_WASNT_THAT_BAD)).is_equal(0)
	assert_that(stars_system.get_uses_remaining(StarsOfTheStorySystem.StarAbility.DRAMATIC_ESCAPE)).is_equal(0)
	assert_that(stars_system.get_uses_remaining(StarsOfTheStorySystem.StarAbility.ITS_TIME_TO_GO)).is_equal(0)
	assert_that(stars_system.get_uses_remaining(StarsOfTheStorySystem.StarAbility.RAINY_DAY_FUND)).is_equal(0)

	# System should not be active
	assert_that(stars_system.is_active()).is_false()

func test_insanity_prevents_ability_use():
	"""In Insanity mode, all abilities should return false for can_use()"""
	stars_system.initialize(0, 4)

	assert_that(stars_system.can_use(StarsOfTheStorySystem.StarAbility.IT_WASNT_THAT_BAD)).is_false()
	assert_that(stars_system.can_use(StarsOfTheStorySystem.StarAbility.DRAMATIC_ESCAPE)).is_false()
	assert_that(stars_system.can_use(StarsOfTheStorySystem.StarAbility.ITS_TIME_TO_GO)).is_false()
	assert_that(stars_system.can_use(StarsOfTheStorySystem.StarAbility.RAINY_DAY_FUND)).is_false()

# ============================================================================
# Use Ability Tests
# ============================================================================

func test_use_ability_decrements_count():
	"""Using an ability should decrement its remaining uses"""
	stars_system.initialize(0, 2)

	var initial_uses = stars_system.get_uses_remaining(StarsOfTheStorySystem.StarAbility.RAINY_DAY_FUND)
	assert_that(initial_uses).is_equal(1)

	# Use the ability
	var result = stars_system.use_ability(
		StarsOfTheStorySystem.StarAbility.RAINY_DAY_FUND,
		{}
	)

	assert_that(result.success).is_true()

	# Uses should be decremented
	var remaining_uses = stars_system.get_uses_remaining(StarsOfTheStorySystem.StarAbility.RAINY_DAY_FUND)
	assert_that(remaining_uses).is_equal(0)

func test_cannot_use_when_zero_remaining():
	"""Cannot use an ability when it has 0 uses remaining"""
	stars_system.initialize(0, 2)

	# Use ability once
	stars_system.use_ability(StarsOfTheStorySystem.StarAbility.RAINY_DAY_FUND, {})

	# Second use should fail
	var can_use_again = stars_system.can_use(StarsOfTheStorySystem.StarAbility.RAINY_DAY_FUND)
	assert_that(can_use_again).is_false()

	# Attempt to use should return failure
	var result = stars_system.use_ability(StarsOfTheStorySystem.StarAbility.RAINY_DAY_FUND, {})
	assert_that(result.success).is_false()

# ============================================================================
# Specific Ability Functionality Tests
# ============================================================================

func test_it_wasnt_that_bad_removes_injury():
	"""'It Wasn't That Bad' should remove injury from character"""
	stars_system.initialize(0, 2)

	var test_character = {
		"name": "Test Hero",
		"injuries": ["Broken Arm", "Concussion"]
	}

	var context = {
		"character": test_character,
		"injury": "Broken Arm"
	}

	var result = stars_system.use_ability(StarsOfTheStorySystem.StarAbility.IT_WASNT_THAT_BAD, context)

	assert_that(result.success).is_true()
	assert_that(test_character.injuries).does_not_contain("Broken Arm")
	assert_that(test_character.injuries).contains("Concussion")

func test_dramatic_escape_sets_hp_to_1():
	"""'Dramatic Escape' should set character HP to 1"""
	stars_system.initialize(0, 2)

	var test_character = {
		"name": "Test Hero",
		"current_hp": 0
	}

	var context = {"character": test_character}

	var result = stars_system.use_ability(StarsOfTheStorySystem.StarAbility.DRAMATIC_ESCAPE, context)

	assert_that(result.success).is_true()
	assert_that(test_character.current_hp).is_equal(1)

func test_its_time_to_go_evacuates_battle():
	"""'It's Time To Go' should set evacuated flag and clear held_field"""
	stars_system.initialize(0, 2)

	var test_battle = {
		"evacuated": false,
		"held_field": true
	}

	var context = {"battle": test_battle}

	var result = stars_system.use_ability(StarsOfTheStorySystem.StarAbility.ITS_TIME_TO_GO, context)

	assert_that(result.success).is_true()
	assert_that(test_battle.evacuated).is_true()
	assert_that(test_battle.held_field).is_false()

func test_rainy_day_fund_grants_credits():
	"""'Rainy Day Fund' should grant 1D6+5 credits (6-11 range)"""
	stars_system.initialize(0, 2)

	var result = stars_system.use_ability(StarsOfTheStorySystem.StarAbility.RAINY_DAY_FUND, {})

	assert_that(result.success).is_true()
	assert_that(result.credits_gained).is_between(6, 11)

# ============================================================================
# Serialization Tests
# ============================================================================

func test_serialize_deserialize_preserves_state():
	"""Serialize/deserialize should preserve all system state"""
	stars_system.initialize(5, 2)

	# Use one ability
	stars_system.use_ability(StarsOfTheStorySystem.StarAbility.RAINY_DAY_FUND, {})

	# Serialize
	var serialized = stars_system.serialize()

	# Create new system and deserialize
	var new_system = StarsOfTheStorySystem.new()
	new_system.deserialize(serialized)

	# State should match
	assert_that(new_system.get_uses_remaining(StarsOfTheStorySystem.StarAbility.RAINY_DAY_FUND)).is_equal(
		stars_system.get_uses_remaining(StarsOfTheStorySystem.StarAbility.RAINY_DAY_FUND)
	)
	assert_that(new_system.is_active()).is_equal(stars_system.is_active())

# ============================================================================
# Ability Name and Description Tests
# ============================================================================

func test_ability_names_are_correct():
	"""All abilities should have correct display names"""
	stars_system.initialize(0, 2)

	assert_that(stars_system.get_ability_name(StarsOfTheStorySystem.StarAbility.IT_WASNT_THAT_BAD)).is_equal("It Wasn't That Bad!")
	assert_that(stars_system.get_ability_name(StarsOfTheStorySystem.StarAbility.DRAMATIC_ESCAPE)).is_equal("Dramatic Escape")
	assert_that(stars_system.get_ability_name(StarsOfTheStorySystem.StarAbility.ITS_TIME_TO_GO)).is_equal("It's Time To Go")
	assert_that(stars_system.get_ability_name(StarsOfTheStorySystem.StarAbility.RAINY_DAY_FUND)).is_equal("Rainy Day Fund")

func test_ability_descriptions_exist():
	"""All abilities should have descriptions"""
	stars_system.initialize(0, 2)

	var desc1 = stars_system.get_ability_description(StarsOfTheStorySystem.StarAbility.IT_WASNT_THAT_BAD)
	assert_that(desc1).is_not_empty()

	var desc2 = stars_system.get_ability_description(StarsOfTheStorySystem.StarAbility.DRAMATIC_ESCAPE)
	assert_that(desc2).is_not_empty()

	var desc3 = stars_system.get_ability_description(StarsOfTheStorySystem.StarAbility.ITS_TIME_TO_GO)
	assert_that(desc3).is_not_empty()

	var desc4 = stars_system.get_ability_description(StarsOfTheStorySystem.StarAbility.RAINY_DAY_FUND)
	assert_that(desc4).is_not_empty()
