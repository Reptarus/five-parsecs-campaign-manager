extends GdUnitTestSuite
## Stars of the Story System tests (Core Rules p.67)
##
## Tests the 5 book-accurate abilities (rebuilt May 2026):
##   - ITS_TIME_TO_GO          (battle-only)
##   - LOOKED_WORSE            (post-battle)
##   - DID_YOU_EVER_MEET       (battle-only)
##   - LUCKY_SHOT              (battle-only)
##   - RAINY_DAY_FUND          (dashboard)
##
## DRAMATIC_ESCAPE + IT_WASNT_THAT_BAD were fabricated/misnamed and DELETED.
## Elite Rank ×5 bonus is a setup-time PICK via apply_elite_rank_pick(),
## NOT a runtime accrual (book p.65).

const GlobalEnumsRef = preload("res://src/core/systems/GlobalEnums.gd")

var stars_system

func before_test():
	stars_system = auto_free(StarsOfTheStorySystem.new())

func after_test():
	stars_system = null

# ============================================================================
# Initial Uses Tests (Standard Difficulty)
# ============================================================================

func test_initial_uses_are_one_each():
	stars_system.initialize(GlobalEnumsRef.DifficultyLevel.NORMAL)
	assert_that(stars_system.get_uses_remaining(
		StarsOfTheStorySystem.StarAbility.ITS_TIME_TO_GO)).is_equal(1)
	assert_that(stars_system.get_uses_remaining(
		StarsOfTheStorySystem.StarAbility.LOOKED_WORSE)).is_equal(1)
	assert_that(stars_system.get_uses_remaining(
		StarsOfTheStorySystem.StarAbility.DID_YOU_EVER_MEET)).is_equal(1)
	assert_that(stars_system.get_uses_remaining(
		StarsOfTheStorySystem.StarAbility.LUCKY_SHOT)).is_equal(1)
	assert_that(stars_system.get_uses_remaining(
		StarsOfTheStorySystem.StarAbility.RAINY_DAY_FUND)).is_equal(1)

func test_max_uses_are_one_each_initially():
	stars_system.initialize(GlobalEnumsRef.DifficultyLevel.NORMAL)
	for ability in StarsOfTheStorySystem.StarAbility.values():
		assert_that(stars_system.get_max_uses(ability)).is_equal(1)

func test_all_five_abilities_exist():
	## Regression: ensure the enum has exactly 5 entries (book-accurate)
	assert_that(StarsOfTheStorySystem.StarAbility.values().size()).is_equal(5)

# ============================================================================
# Elite Rank Pick Tests (setup-time, not runtime — Core Rules p.65)
# ============================================================================

func test_elite_rank_pick_doubles_chosen_ability():
	stars_system.initialize(GlobalEnumsRef.DifficultyLevel.NORMAL)
	stars_system.apply_elite_rank_pick(
		StarsOfTheStorySystem.StarAbility.LUCKY_SHOT)
	assert_that(stars_system.get_max_uses(
		StarsOfTheStorySystem.StarAbility.LUCKY_SHOT)).is_equal(2)
	assert_that(stars_system.get_uses_remaining(
		StarsOfTheStorySystem.StarAbility.LUCKY_SHOT)).is_equal(2)
	# Other abilities unaffected
	assert_that(stars_system.get_max_uses(
		StarsOfTheStorySystem.StarAbility.RAINY_DAY_FUND)).is_equal(1)

func test_multiple_picks_can_target_distinct_abilities():
	stars_system.initialize(GlobalEnumsRef.DifficultyLevel.NORMAL)
	stars_system.apply_elite_rank_pick(
		StarsOfTheStorySystem.StarAbility.ITS_TIME_TO_GO)
	stars_system.apply_elite_rank_pick(
		StarsOfTheStorySystem.StarAbility.RAINY_DAY_FUND)
	assert_that(stars_system.get_max_uses(
		StarsOfTheStorySystem.StarAbility.ITS_TIME_TO_GO)).is_equal(2)
	assert_that(stars_system.get_max_uses(
		StarsOfTheStorySystem.StarAbility.RAINY_DAY_FUND)).is_equal(2)
	# Unpicked abilities still 1
	assert_that(stars_system.get_max_uses(
		StarsOfTheStorySystem.StarAbility.LUCKY_SHOT)).is_equal(1)

func test_insanity_picks_are_noops():
	stars_system.initialize(GlobalEnumsRef.DifficultyLevel.INSANITY)
	stars_system.apply_elite_rank_pick(
		StarsOfTheStorySystem.StarAbility.LUCKY_SHOT)
	assert_that(stars_system.get_max_uses(
		StarsOfTheStorySystem.StarAbility.LUCKY_SHOT)).is_equal(0)

# ============================================================================
# Insanity Mode Tests (Difficulty 8 — NOT 4! Fix from previous test bug)
# ============================================================================

func test_insanity_disables_all_abilities():
	## INSANITY = 8 in GlobalEnums.DifficultyLevel
	## (Previous test wrongly used `4` which is CHALLENGING — see CLAUDE.md gotchas)
	stars_system.initialize(GlobalEnumsRef.DifficultyLevel.INSANITY)
	for ability in StarsOfTheStorySystem.StarAbility.values():
		assert_that(stars_system.get_uses_remaining(ability)).is_equal(0)
	assert_that(stars_system.is_active()).is_false()

func test_insanity_prevents_ability_use():
	stars_system.initialize(GlobalEnumsRef.DifficultyLevel.INSANITY)
	for ability in StarsOfTheStorySystem.StarAbility.values():
		assert_that(stars_system.can_use(ability)).is_false()

# ============================================================================
# Use Ability Tests
# ============================================================================

func test_use_ability_decrements_count():
	stars_system.initialize(GlobalEnumsRef.DifficultyLevel.NORMAL)
	var result = stars_system.use_ability(
		StarsOfTheStorySystem.StarAbility.RAINY_DAY_FUND, {})
	assert_that(result.success).is_true()
	assert_that(stars_system.get_uses_remaining(
		StarsOfTheStorySystem.StarAbility.RAINY_DAY_FUND)).is_equal(0)

func test_cannot_use_when_zero_remaining():
	stars_system.initialize(GlobalEnumsRef.DifficultyLevel.NORMAL)
	stars_system.use_ability(
		StarsOfTheStorySystem.StarAbility.RAINY_DAY_FUND, {})
	assert_that(stars_system.can_use(
		StarsOfTheStorySystem.StarAbility.RAINY_DAY_FUND)).is_false()
	var result = stars_system.use_ability(
		StarsOfTheStorySystem.StarAbility.RAINY_DAY_FUND, {})
	assert_that(result.success).is_false()

# ============================================================================
# Per-Ability Handler Tests (book-accurate effects)
# ============================================================================

func test_its_time_to_go_evacuates_battle():
	stars_system.initialize(GlobalEnumsRef.DifficultyLevel.NORMAL)
	var battle = {"evacuated": false, "held_field": true}
	var result = stars_system.use_ability(
		StarsOfTheStorySystem.StarAbility.ITS_TIME_TO_GO,
		{"battle": battle})
	assert_that(result.success).is_true()
	assert_that(battle.evacuated).is_true()
	assert_that(battle.held_field).is_false()

func test_looked_worse_flags_injury_as_ignored():
	## Per Core Rules p.67: "Ignore A ROLL on the Injury Table"
	## (not "remove an existing injury")
	stars_system.initialize(GlobalEnumsRef.DifficultyLevel.NORMAL)
	var injury_data = {
		"character_id": "crew_1",
		"character_name": "Vex Cross",
		"recovery_turns": 3,
		"is_fatal": false
	}
	var result = stars_system.use_ability(
		StarsOfTheStorySystem.StarAbility.LOOKED_WORSE,
		{"injury_data": injury_data})
	assert_that(result.success).is_true()
	assert_that(injury_data.get("ignored", false)).is_true()
	assert_that(injury_data.get("star_used", "")).is_equal("LOOKED_WORSE")

func test_did_you_ever_meet_returns_new_unit_info():
	stars_system.initialize(GlobalEnumsRef.DifficultyLevel.NORMAL)
	var new_char = {"character_name": "Kai Rook", "character_id": "kai_001"}
	var result = stars_system.use_ability(
		StarsOfTheStorySystem.StarAbility.DID_YOU_EVER_MEET,
		{"new_character": new_char, "placement_tile": Vector2i(0, 0)})
	assert_that(result.success).is_true()
	assert_that(result.get("new_character_name", "")).is_equal("Kai Rook")
	assert_that(result.get("acts_immediately", false)).is_true()

func test_lucky_shot_flips_miss_to_hit():
	stars_system.initialize(GlobalEnumsRef.DifficultyLevel.NORMAL)
	var shot = {
		"hit": false,
		"shooter_name": "Nyx",
		"target_name": "Bandit"
	}
	var result = stars_system.use_ability(
		StarsOfTheStorySystem.StarAbility.LUCKY_SHOT,
		{"shot_result": shot})
	assert_that(result.success).is_true()
	assert_that(shot.hit).is_true()
	assert_that(shot.get("lucky", false)).is_true()

func test_lucky_shot_fails_on_already_hit_shot():
	stars_system.initialize(GlobalEnumsRef.DifficultyLevel.NORMAL)
	var shot = {"hit": true, "shooter_name": "X", "target_name": "Y"}
	var result = stars_system.use_ability(
		StarsOfTheStorySystem.StarAbility.LUCKY_SHOT,
		{"shot_result": shot})
	assert_that(result.success).is_false()

func test_rainy_day_fund_grants_credits():
	stars_system.initialize(GlobalEnumsRef.DifficultyLevel.NORMAL)
	var result = stars_system.use_ability(
		StarsOfTheStorySystem.StarAbility.RAINY_DAY_FUND, {})
	assert_that(result.success).is_true()
	assert_that(result.credits_gained).is_between(6, 11)

# ============================================================================
# Battle-only classification
# ============================================================================

func test_is_battle_only_correctly_classifies():
	## ITS_TIME_TO_GO, DID_YOU_EVER_MEET, LUCKY_SHOT are battle-only
	## LOOKED_WORSE is post-battle (still falls under non-battle UI)
	## RAINY_DAY_FUND is dashboard
	assert_that(StarsOfTheStorySystem.is_battle_only(
		StarsOfTheStorySystem.StarAbility.ITS_TIME_TO_GO)).is_true()
	assert_that(StarsOfTheStorySystem.is_battle_only(
		StarsOfTheStorySystem.StarAbility.DID_YOU_EVER_MEET)).is_true()
	assert_that(StarsOfTheStorySystem.is_battle_only(
		StarsOfTheStorySystem.StarAbility.LUCKY_SHOT)).is_true()
	assert_that(StarsOfTheStorySystem.is_battle_only(
		StarsOfTheStorySystem.StarAbility.LOOKED_WORSE)).is_false()
	assert_that(StarsOfTheStorySystem.is_battle_only(
		StarsOfTheStorySystem.StarAbility.RAINY_DAY_FUND)).is_false()

# ============================================================================
# Serialization Tests (v2 schema after rebuild)
# ============================================================================

func test_serialize_deserialize_preserves_state():
	stars_system.initialize(GlobalEnumsRef.DifficultyLevel.NORMAL)
	stars_system.apply_elite_rank_pick(
		StarsOfTheStorySystem.StarAbility.LUCKY_SHOT)
	stars_system.use_ability(
		StarsOfTheStorySystem.StarAbility.RAINY_DAY_FUND, {})

	var serialized = stars_system.serialize()

	var new_system = StarsOfTheStorySystem.new()
	new_system.deserialize(serialized)

	assert_that(new_system.get_uses_remaining(
		StarsOfTheStorySystem.StarAbility.RAINY_DAY_FUND)).is_equal(0)
	assert_that(new_system.get_max_uses(
		StarsOfTheStorySystem.StarAbility.LUCKY_SHOT)).is_equal(2)
	assert_that(new_system.is_active()).is_true()

# ============================================================================
# Book-Accurate Name & Description Tests
# ============================================================================

func test_ability_names_match_book():
	stars_system.initialize(GlobalEnumsRef.DifficultyLevel.NORMAL)
	assert_that(stars_system.get_ability_name(
		StarsOfTheStorySystem.StarAbility.ITS_TIME_TO_GO)).is_equal(
		"It's time to go!")
	assert_that(stars_system.get_ability_name(
		StarsOfTheStorySystem.StarAbility.LOOKED_WORSE)).is_equal(
		"Looked worse than it was!")
	assert_that(stars_system.get_ability_name(
		StarsOfTheStorySystem.StarAbility.DID_YOU_EVER_MEET)).is_equal(
		"Did you ever meet my mate?")
	assert_that(stars_system.get_ability_name(
		StarsOfTheStorySystem.StarAbility.LUCKY_SHOT)).is_equal(
		"Lucky shot!")
	assert_that(stars_system.get_ability_name(
		StarsOfTheStorySystem.StarAbility.RAINY_DAY_FUND)).is_equal(
		"Rainy day fund!")

func test_all_abilities_have_descriptions():
	stars_system.initialize(GlobalEnumsRef.DifficultyLevel.NORMAL)
	for ability in StarsOfTheStorySystem.StarAbility.values():
		var desc = stars_system.get_ability_description(ability)
		assert_that(desc).is_not_empty()
