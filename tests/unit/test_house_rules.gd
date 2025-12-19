extends GdUnitTestSuite

## House Rules Integration Tests
## Validates house rules system and all 8 rule integrations
##
## Rules tested:
## - varied_armaments (combat)
## - wild_galaxy (world)
## - brutal_combat (combat)
## - narrative_injuries (character)
## - wealthy_patrons (economy)
## - rookie_crew (character)
## - expanded_rumors (story)
## - dangerous_fringe (world)

const HouseRulesHelper = preload("res://src/core/systems/HouseRulesHelper.gd")
const HouseRulesDefinitions = preload("res://src/data/house_rules_definitions.gd")
const CampaignConfig = preload("res://src/data/config/CampaignConfig.gd")
const InjurySystemService = preload("res://src/core/services/InjurySystemService.gd")

# ============================================
# Test: House Rules Definitions
# ============================================

func test_all_eight_rules_defined() -> void:
	"""Verify all 8 house rules are defined in HouseRulesDefinitions"""
	var all_rules = HouseRulesDefinitions.get_all_rules()

	var expected_rules := [
		"varied_armaments",
		"wild_galaxy",
		"brutal_combat",
		"narrative_injuries",
		"wealthy_patrons",
		"rookie_crew",
		"expanded_rumors",
		"dangerous_fringe"
	]

	for rule_id in expected_rules:
		var rule = HouseRulesDefinitions.get_rule(rule_id)
		assert_that(rule).is_not_empty()
		assert_that(rule.get("id", "")).is_equal(rule_id)

func test_rule_categories() -> void:
	"""Verify rules are categorized correctly"""
	var combat_rules = HouseRulesDefinitions.get_rules_by_category("combat")
	var world_rules = HouseRulesDefinitions.get_rules_by_category("world")
	var character_rules = HouseRulesDefinitions.get_rules_by_category("character")
	var economy_rules = HouseRulesDefinitions.get_rules_by_category("economy")
	var story_rules = HouseRulesDefinitions.get_rules_by_category("story")

	# Check counts
	assert_that(combat_rules.size()).is_equal(2)  # varied_armaments, brutal_combat
	assert_that(world_rules.size()).is_equal(2)   # wild_galaxy, dangerous_fringe
	assert_that(character_rules.size()).is_equal(2)  # narrative_injuries, rookie_crew
	assert_that(economy_rules.size()).is_equal(1)  # wealthy_patrons
	assert_that(story_rules.size()).is_equal(1)    # expanded_rumors

# ============================================
# Test: CampaignConfig Persistence
# ============================================

func test_campaign_config_stores_house_rules() -> void:
	"""Verify CampaignConfig stores house rules properly"""
	var config = CampaignConfig.new()
	config.house_rules = ["brutal_combat", "rookie_crew"] as Array[String]

	assert_that(config.house_rules.size()).is_equal(2)
	assert_that("brutal_combat" in config.house_rules).is_true()
	assert_that("rookie_crew" in config.house_rules).is_true()

func test_campaign_config_to_dictionary() -> void:
	"""Verify house rules serialize to dictionary"""
	var config = CampaignConfig.new()
	config.house_rules = ["wild_galaxy", "dangerous_fringe"] as Array[String]

	var dict = config.to_dictionary()

	assert_that(dict.has("house_rules")).is_true()
	assert_that(dict.house_rules).is_equal(["wild_galaxy", "dangerous_fringe"])

func test_campaign_config_from_dictionary() -> void:
	"""Verify house rules deserialize from dictionary"""
	var data := {
		"house_rules": ["wealthy_patrons", "expanded_rumors"]
	}

	var config = CampaignConfig.from_dictionary(data)

	assert_that(config.house_rules.size()).is_equal(2)
	assert_that("wealthy_patrons" in config.house_rules).is_true()
	assert_that("expanded_rumors" in config.house_rules).is_true()

func test_campaign_config_handles_missing_house_rules() -> void:
	"""Verify config handles missing house_rules gracefully"""
	var data := {
		"campaign_name": "Test Campaign"
	}

	var config = CampaignConfig.from_dictionary(data)

	assert_that(config.house_rules).is_empty()

# ============================================
# Test: Narrative Injuries Service
# ============================================

func test_narrative_injury_options_exclude_fatal() -> void:
	"""Verify narrative injury options don't include fatal injuries"""
	var options = InjurySystemService.get_narrative_injury_options()

	# Should have options
	assert_that(options.size()).is_greater(0)

	# None should be fatal
	for option in options:
		assert_that(option.get("is_fatal", false)).is_false()

func test_narrative_injury_includes_miraculous_escape() -> void:
	"""Verify Miraculous Escape is available as narrative choice"""
	var options = InjurySystemService.get_narrative_injury_options()

	var has_miraculous := false
	for option in options:
		if "miraculous" in option.get("name", "").to_lower():
			has_miraculous = true
			break

	assert_that(has_miraculous).is_true()

func test_create_narrative_injury_marks_as_narrative() -> void:
	"""Verify created narrative injury is marked as narrative_choice"""
	# Get first available injury type from options
	var options = InjurySystemService.get_narrative_injury_options()
	var injury_type: int = options[0].get("injury_type", 0)

	var result = InjurySystemService.create_narrative_injury(injury_type)

	assert_that(result.get("narrative_choice", false)).is_true()
	assert_that(result.get("roll", 0)).is_equal(-1)  # -1 indicates not rolled

func test_narrative_injury_has_valid_recovery_turns() -> void:
	"""Verify narrative injuries have valid recovery times"""
	var options = InjurySystemService.get_narrative_injury_options()

	for option in options:
		var recovery = option.get("recovery_turns", -1)
		# Recovery should be >= 0 (0 for miraculous escape, positive for others)
		assert_that(recovery).is_greater_equal(0)

# ============================================
# Test: Rule Effect Values
# ============================================

func test_wealthy_patrons_multiplier() -> void:
	"""Verify wealthy_patrons uses 1.5x multiplier"""
	var rule = HouseRulesDefinitions.get_rule("wealthy_patrons")
	var effects = rule.get("effects", [])

	var has_multiplier := false
	for effect in effects:
		if effect.has("value"):
			assert_that(effect.value).is_equal(1.5)
			has_multiplier = true

	assert_that(has_multiplier).is_true()

func test_brutal_combat_multiplier() -> void:
	"""Verify brutal_combat uses 2x damage multiplier"""
	var rule = HouseRulesDefinitions.get_rule("brutal_combat")
	var effects = rule.get("effects", [])

	var has_multiplier := false
	for effect in effects:
		if effect.has("value"):
			assert_that(effect.value).is_equal(2.0)
			has_multiplier = true

	assert_that(has_multiplier).is_true()

# ============================================
# Test: Helper Get Modifier
# ============================================

func test_helper_get_modifier_returns_default_when_disabled() -> void:
	"""Verify get_modifier returns default when rule is disabled"""
	# Since we don't have GameState mocked, this will return default
	var modifier = HouseRulesHelper.get_modifier("wealthy_patrons", 1.0)

	# Without active campaign, should return default
	assert_that(modifier).is_equal(1.0)

func test_helper_is_enabled_returns_false_when_no_game_state() -> void:
	"""Verify is_enabled returns false when GameState is not available"""
	# Without running game, GameState won't be in scene tree
	var enabled = HouseRulesHelper.is_enabled("brutal_combat")

	assert_that(enabled).is_false()
