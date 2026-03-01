@tool
extends GdUnitTestSuite

## Sprint 9: Campaign Data Consistency Integration Tests
## Validates that all wizard data flows correctly through finalization to Turn 1

const FiveParsecsCampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")

# Test fixtures
var test_campaign: FiveParsecsCampaignCore

func before_test() -> void:
	test_campaign = FiveParsecsCampaignCore.new()

func after_test() -> void:
	if test_campaign:
		test_campaign = null

## =============================================================================
## Sprint 6.1: House Rules Persistence Tests
## =============================================================================

func test_house_rules_storage_in_campaign() -> void:
	# Given: A campaign with house rules
	var house_rules = ["brutal_combat", "wealthy_patrons", "easy_recovery"]

	# When: House rules are set
	test_campaign.set_house_rules(house_rules)

	# Then: They can be retrieved
	var retrieved = test_campaign.get_house_rules()
	assert_that(retrieved).is_not_null()
	assert_that(retrieved.size()).is_equal(3)
	assert_that(retrieved).contains("brutal_combat")
	assert_that(retrieved).contains("wealthy_patrons")
	assert_that(retrieved).contains("easy_recovery")

func test_house_rules_persist_through_serialization() -> void:
	# Given: A campaign with house rules
	var house_rules = ["brutal_combat", "no_retreat"]
	test_campaign.set_house_rules(house_rules)
	test_campaign.campaign_name = "Test Campaign"
	test_campaign.initialize_crew({"members": [{"name": "Test"}]})
	test_campaign.set_captain({"name": "Captain Test"})

	# When: Campaign is serialized and deserialized
	var serialized = test_campaign.to_dictionary()
	var new_campaign = FiveParsecsCampaignCore.new()
	new_campaign.from_dictionary(serialized)

	# Then: House rules are preserved
	var retrieved = new_campaign.get_house_rules()
	assert_that(retrieved.size()).is_equal(2)
	assert_that(retrieved).contains("brutal_combat")
	assert_that(retrieved).contains("no_retreat")

## =============================================================================
## Sprint 6.2: Story Track Persistence Tests
## =============================================================================

func test_story_track_enabled_storage() -> void:
	# Given: A campaign with story track setting

	# When: Story track is enabled
	test_campaign.set_story_track_enabled(true)

	# Then: It can be retrieved
	var retrieved = test_campaign.get_story_track_enabled()
	assert_that(retrieved).is_true()

	# And when disabled
	test_campaign.set_story_track_enabled(false)
	retrieved = test_campaign.get_story_track_enabled()
	assert_that(retrieved).is_false()

func test_story_track_persist_through_serialization() -> void:
	# Given: A campaign with story track enabled
	test_campaign.set_story_track_enabled(true)
	test_campaign.campaign_name = "Story Test Campaign"
	test_campaign.initialize_crew({"members": [{"name": "Test"}]})
	test_campaign.set_captain({"name": "Captain Test"})

	# When: Campaign is serialized and deserialized
	var serialized = test_campaign.to_dictionary()
	var new_campaign = FiveParsecsCampaignCore.new()
	new_campaign.from_dictionary(serialized)

	# Then: Story track setting is preserved
	assert_that(new_campaign.get_story_track_enabled()).is_true()

## =============================================================================
## Sprint 6.3: Victory Conditions Single Source Tests
## =============================================================================

func test_victory_conditions_storage() -> void:
	# Given: A campaign with victory conditions
	var victory_conditions = {
		"selected_conditions": [1, 3],  # Example victory type enums
		"custom_targets": {"turns": 30, "battles": 10},
		"is_complete": true
	}

	# When: Victory conditions are set
	test_campaign.set_victory_conditions(victory_conditions)

	# Then: They can be retrieved
	var retrieved = test_campaign.get_victory_conditions()
	assert_that(retrieved).is_not_empty()
	assert_that(retrieved.has("selected_conditions")).is_true()
	assert_that(retrieved.has("custom_targets")).is_true()

func test_victory_conditions_persist_through_serialization() -> void:
	# Given: A campaign with victory conditions
	var victory_conditions = {
		"selected_conditions": [2, 4],
		"custom_targets": {"credits": 5000}
	}
	test_campaign.set_victory_conditions(victory_conditions)
	test_campaign.campaign_name = "Victory Test"
	test_campaign.initialize_crew({"members": [{"name": "Test"}]})
	test_campaign.set_captain({"name": "Captain Test"})

	# When: Campaign is serialized and deserialized
	var serialized = test_campaign.to_dictionary()
	var new_campaign = FiveParsecsCampaignCore.new()
	new_campaign.from_dictionary(serialized)

	# Then: Victory conditions are preserved
	var retrieved = new_campaign.get_victory_conditions()
	assert_that(retrieved.has("selected_conditions")).is_true()
	assert_that(retrieved.selected_conditions).contains(2)
	assert_that(retrieved.selected_conditions).contains(4)

## =============================================================================
## Sprint 8: Complete Campaign Data Accessibility Tests
## =============================================================================

func test_all_campaign_data_sections_accessible() -> void:
	# Given: A fully configured campaign
	test_campaign.campaign_name = "Full Test Campaign"
	test_campaign.difficulty = 2
	test_campaign.ironman_mode = true

	test_campaign.initialize_crew({
		"members": [
			{"name": "Member 1", "background": "Soldier"},
			{"name": "Member 2", "background": "Scientist"}
		]
	})

	test_campaign.set_captain({
		"name": "Captain Test",
		"id": "captain_001",
		"background": "Military"
	})

	test_campaign.initialize_ship({
		"name": "Test Ship",
		"hull": 10,
		"debt": 5000
	})

	test_campaign.set_starting_equipment({
		"weapons": ["Infantry Laser", "Auto Rifle"],
		"gear": ["Med-kit", "Scanner"]
	})

	test_campaign.initialize_world({
		"current_planet": "Test World",
		"traits": ["Industrial", "Corrupt"]
	})

	test_campaign.set_house_rules(["brutal_combat"])
	test_campaign.set_story_track_enabled(true)
	test_campaign.set_victory_conditions({"selected_conditions": [1]})

	# When: All data is accessed
	# Then: Each section is retrievable
	assert_that(test_campaign.campaign_name).is_equal("Full Test Campaign")
	assert_that(test_campaign.difficulty).is_equal(2)
	assert_that(test_campaign.ironman_mode).is_true()

	# Crew
	var crew = test_campaign.get_crew_members()
	assert_that(crew.size()).is_equal(2)

	# Captain
	var captain = test_campaign.get_captain()
	assert_that(captain.has("name")).is_true()
	assert_that(captain.name).is_equal("Captain Test")

	# Ship
	var ship = test_campaign.get_ship()
	assert_that(ship.has("name")).is_true()
	assert_that(ship.name).is_equal("Test Ship")

	# House rules
	var house_rules = test_campaign.get_house_rules()
	assert_that(house_rules).contains("brutal_combat")

	# Story track
	assert_that(test_campaign.get_story_track_enabled()).is_true()

	# Victory conditions
	var victory = test_campaign.get_victory_conditions()
	assert_that(victory).is_not_empty()

func test_save_load_preserves_all_data() -> void:
	# Given: A fully configured campaign
	test_campaign.campaign_name = "Persistence Test"
	test_campaign.difficulty = 3
	test_campaign.ironman_mode = true

	test_campaign.initialize_crew({
		"members": [{"name": "Test Crew", "xp": 100}]
	})
	test_campaign.set_captain({"name": "Test Captain", "id": "cap_test"})
	test_campaign.initialize_ship({"name": "Test Vessel", "hull": 8})
	test_campaign.set_starting_equipment({"weapons": ["Laser Pistol"]})
	test_campaign.initialize_world({"planet": "Terra Nova"})
	test_campaign.set_house_rules(["easy_recovery", "wealthy_patrons"])
	test_campaign.set_story_track_enabled(true)
	test_campaign.set_victory_conditions({
		"selected_conditions": [1, 2, 3],
		"custom_targets": {"turns": 50}
	})
	test_campaign.initialize_resources({
		"credits": 2500,
		"story_points": 5,
		"patrons": [{"name": "Patron 1"}],
		"rivals": [{"name": "Rival 1"}],
		"quest_rumors": 3
	})

	# When: Campaign is serialized and deserialized
	var serialized = test_campaign.to_dictionary()
	var loaded_campaign = FiveParsecsCampaignCore.new()
	loaded_campaign.from_dictionary(serialized)

	# Then: ALL data is preserved
	# Meta
	assert_that(loaded_campaign.campaign_name).is_equal("Persistence Test")
	assert_that(loaded_campaign.difficulty).is_equal(3)
	assert_that(loaded_campaign.ironman_mode).is_true()

	# Crew
	var crew = loaded_campaign.get_crew_members()
	assert_that(crew.size()).is_equal(1)
	assert_that(crew[0].name).is_equal("Test Crew")

	# Captain
	var captain = loaded_campaign.get_captain()
	assert_that(captain.name).is_equal("Test Captain")

	# Ship
	var ship = loaded_campaign.get_ship()
	assert_that(ship.name).is_equal("Test Vessel")

	# House rules (SPRINT 6.1)
	var house_rules = loaded_campaign.get_house_rules()
	assert_that(house_rules.size()).is_equal(2)
	assert_that(house_rules).contains("easy_recovery")

	# Story track (SPRINT 6.2)
	assert_that(loaded_campaign.get_story_track_enabled()).is_true()

	# Victory conditions (SPRINT 6.3)
	var victory = loaded_campaign.get_victory_conditions()
	assert_that(victory.selected_conditions.size()).is_equal(3)
	assert_that(victory.custom_targets.turns).is_equal(50)

	# Resources
	var resources = loaded_campaign.get_resources()
	assert_that(resources.credits).is_equal(2500)
	assert_that(resources.story_points).is_equal(5)
	assert_that(resources.patrons.size()).is_equal(1)
	assert_that(resources.rivals.size()).is_equal(1)

## =============================================================================
## Campaign Validation Tests
## =============================================================================

func test_campaign_validation_passes_with_complete_data() -> void:
	# Given: A valid campaign with all required data
	test_campaign.campaign_name = "Valid Campaign"
	test_campaign.initialize_crew({
		"members": [{"name": "Crew Member 1"}]
	})
	test_campaign.set_captain({"name": "Captain Valid"})

	# Then: Validation passes
	assert_that(test_campaign.validate()).is_true()

	var errors = test_campaign.get_validation_errors()
	assert_that(errors).is_empty()

func test_campaign_validation_fails_without_name() -> void:
	# Given: A campaign without a name
	test_campaign.initialize_crew({"members": [{"name": "Test"}]})
	test_campaign.set_captain({"name": "Captain"})

	# Then: Validation fails
	assert_that(test_campaign.validate()).is_false()

	var errors = test_campaign.get_validation_errors()
	assert_that(errors).contains("Campaign name is required")

func test_campaign_validation_fails_without_crew() -> void:
	# Given: A campaign without crew
	test_campaign.campaign_name = "No Crew Campaign"
	test_campaign.set_captain({"name": "Captain"})

	# Then: Validation fails
	assert_that(test_campaign.validate()).is_false()

	var errors = test_campaign.get_validation_errors()
	assert_that(errors).contains("Crew data is missing")

func test_campaign_validation_fails_without_captain() -> void:
	# Given: A campaign without captain
	test_campaign.campaign_name = "No Captain Campaign"
	test_campaign.initialize_crew({"members": [{"name": "Crew"}]})

	# Then: Validation fails
	assert_that(test_campaign.validate()).is_false()

	var errors = test_campaign.get_validation_errors()
	assert_that(errors).contains("Captain data is missing")
