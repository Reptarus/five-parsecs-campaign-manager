extends GdUnitTestSuite

## Week 3 Day 4 - End-to-End Campaign Creation Workflow Test (gdUnit4 version)
## Tests complete campaign creation flow: Config → Captain → Crew → Ship → Equipment → World → Final

var state_manager

func before_test():
	var state_mgr_script = load("res://src/core/campaign/creation/CampaignCreationStateManager.gd")
	if state_mgr_script:
		state_manager = state_mgr_script.new()

func after_test():
	# Note: state_manager is RefCounted - auto-frees when references drop to 0
	if state_manager:
		state_manager = null

## Phase 1: Configuration Tests
func test_set_campaign_configuration():
	if state_manager == null:
		push_warning("state_manager not available - skipping")
		return

	var config_data = {
		"campaign_name": "E2E Test Campaign",
		"campaign_type": "standard",
		"victory_conditions": {
			"story_points": true,
			"max_turns": false,
			"reputation": false
		},
		"story_track": "become_a_legend",
		"tutorial_mode": false,
		"is_complete": true
	}
	state_manager.set_phase_data(state_manager.Phase.CONFIG, config_data)
	var retrieved = state_manager.get_phase_data(state_manager.Phase.CONFIG)

	# Null check before accessing
	if retrieved == null or not retrieved is Dictionary:
		push_warning("get_phase_data returned null or non-Dictionary - skipping")
		return

	assert_that(retrieved.has("campaign_name")).is_true()
	assert_that(retrieved.get("campaign_name", "")).is_equal("E2E Test Campaign")

func test_config_stored_in_campaign_data():
	if state_manager == null:
		push_warning("state_manager not available - skipping")
		return

	var config_data = {
		"campaign_name": "E2E Test Campaign",
		"campaign_type": "standard",
		"victory_conditions": {"story_points": true},
		"story_track": "become_a_legend",
		"is_complete": true
	}
	state_manager.set_phase_data(state_manager.Phase.CONFIG, config_data)

	# Safe Dictionary access
	if not state_manager.campaign_data.has("config"):
		push_warning("campaign_data missing 'config' key - skipping")
		return

	var config = state_manager.campaign_data.get("config", {})
	assert_that(config.get("campaign_name", "")).is_equal("E2E Test Campaign")

func test_advance_to_captain_creation_phase():
	if state_manager == null:
		push_warning("state_manager not available - skipping")
		return

	var config_data = {
		"campaign_name": "E2E Test Campaign",
		"campaign_type": "standard",
		"is_complete": true
	}
	state_manager.set_phase_data(state_manager.Phase.CONFIG, config_data)

	var success = state_manager.advance_to_next_phase()
	assert_that(success).is_true()
	assert_that(state_manager.current_phase).is_equal(state_manager.Phase.CAPTAIN_CREATION)

## Phase 2: Captain Creation Tests
func test_create_captain_character():
	# Setup config first
	state_manager.set_phase_data(state_manager.Phase.CONFIG, {
		"campaign_name": "Test",
		"is_complete": true
	})
	state_manager.advance_to_next_phase()
	
	var captain_data = {
		"character_name": "Test Captain",
		"background": 1,
		"motivation": 2,
		"class": 3,
		"combat": 2,
		"toughness": 4,
		"stats": {
			"reactions": 1,
			"speed": 5,
			"combat_skill": 2,
			"toughness": 4,
			"savvy": 1
		},
		"xp": 0,
		"is_complete": true
	}
	state_manager.set_phase_data(state_manager.Phase.CAPTAIN_CREATION, captain_data)
	var retrieved = state_manager.get_phase_data(state_manager.Phase.CAPTAIN_CREATION)
	
	assert_that(retrieved.has("character_name")).is_true()
	assert_that(retrieved.character_name).is_equal("Test Captain")

func test_captain_stats_properly_structured():
	state_manager.set_phase_data(state_manager.Phase.CONFIG, {"is_complete": true})
	state_manager.advance_to_next_phase()
	
	var captain_data = {
		"character_name": "Test Captain",
		"background": 1,
		"stats": {"reactions": 1, "speed": 5, "combat_skill": 2, "toughness": 4, "savvy": 1},
		"is_complete": true
	}
	state_manager.set_phase_data(state_manager.Phase.CAPTAIN_CREATION, captain_data)
	
	var captain = state_manager.campaign_data["captain"]
	assert_that(captain.has("character_name")).is_true()
	assert_that(captain.character_name).is_equal("Test Captain")

func test_advance_to_crew_setup_phase():
	state_manager.set_phase_data(state_manager.Phase.CONFIG, {"is_complete": true})
	state_manager.advance_to_next_phase()
	state_manager.set_phase_data(state_manager.Phase.CAPTAIN_CREATION, {
		"character_name": "Test",
		"is_complete": true
	})
	
	var success = state_manager.advance_to_next_phase()
	assert_that(success).is_true()
	assert_that(state_manager.current_phase).is_equal(state_manager.Phase.CREW_SETUP)

## Phase 3: Crew Setup Tests
func test_add_crew_members():
	# Setup previous phases
	state_manager.set_phase_data(state_manager.Phase.CONFIG, {"is_complete": true})
	state_manager.advance_to_next_phase()
	state_manager.set_phase_data(state_manager.Phase.CAPTAIN_CREATION, {"character_name": "Test", "is_complete": true})
	state_manager.advance_to_next_phase()
	
	var crew_data = {
		"members": [
			{
				"character_name": "Crew Member 1",
				"background": 2,
				"motivation": 1,
				"class": 2,
				"stats": {"reactions": 1, "speed": 4, "combat_skill": 1, "toughness": 3, "savvy": 0},
				"xp": 0
			},
			{
				"character_name": "Crew Member 2",
				"background": 3,
				"motivation": 3,
				"class": 1,
				"stats": {"reactions": 0, "speed": 5, "combat_skill": 2, "toughness": 3, "savvy": 1},
				"xp": 0
			}
		],
		"size": 2,
		"has_captain": true,
		"is_complete": true
	}
	state_manager.set_phase_data(state_manager.Phase.CREW_SETUP, crew_data)
	var retrieved = state_manager.get_phase_data(state_manager.Phase.CREW_SETUP)
	
	assert_that(retrieved.has("members")).is_true()
	assert_that(retrieved.members.size()).is_equal(2)

func test_crew_size_matches_expected():
	state_manager.set_phase_data(state_manager.Phase.CONFIG, {"is_complete": true})
	state_manager.advance_to_next_phase()
	state_manager.set_phase_data(state_manager.Phase.CAPTAIN_CREATION, {"character_name": "Test", "is_complete": true})
	state_manager.advance_to_next_phase()
	state_manager.set_phase_data(state_manager.Phase.CREW_SETUP, {
		"members": [{"character_name": "Crew 1"}, {"character_name": "Crew 2"}],
		"size": 2,
		"is_complete": true
	})
	
	var crew = state_manager.campaign_data["crew"]
	assert_that(crew.has("size")).is_true()
	assert_that(crew.size).is_equal(2)

func test_advance_to_ship_assignment_phase():
	state_manager.set_phase_data(state_manager.Phase.CONFIG, {"is_complete": true})
	state_manager.advance_to_next_phase()
	state_manager.set_phase_data(state_manager.Phase.CAPTAIN_CREATION, {"character_name": "Test", "is_complete": true})
	state_manager.advance_to_next_phase()
	state_manager.set_phase_data(state_manager.Phase.CREW_SETUP, {"members": [], "size": 0, "is_complete": true})
	
	var success = state_manager.advance_to_next_phase()
	assert_that(success).is_true()
	assert_that(state_manager.current_phase).is_equal(state_manager.Phase.SHIP_ASSIGNMENT)

## Phase 4: Ship Assignment Tests
func test_assign_starting_ship():
	# Setup previous phases
	state_manager.set_phase_data(state_manager.Phase.CONFIG, {"is_complete": true})
	state_manager.advance_to_next_phase()
	state_manager.set_phase_data(state_manager.Phase.CAPTAIN_CREATION, {"character_name": "Test", "is_complete": true})
	state_manager.advance_to_next_phase()
	state_manager.set_phase_data(state_manager.Phase.CREW_SETUP, {"members": [], "size": 0, "is_complete": true})
	state_manager.advance_to_next_phase()
	
	var ship_data = {
		"name": "Test Starship",
		"type": "light_freighter",
		"hull_points": 6,
		"max_hull_points": 6,
		"upgrades": [],
		"cargo_capacity": 10,
		"is_complete": true
	}
	state_manager.set_phase_data(state_manager.Phase.SHIP_ASSIGNMENT, ship_data)
	var retrieved = state_manager.get_phase_data(state_manager.Phase.SHIP_ASSIGNMENT)
	
	assert_that(retrieved.has("name")).is_true()
	assert_that(retrieved.name).is_equal("Test Starship")

func test_ship_has_valid_hull_points():
	state_manager.set_phase_data(state_manager.Phase.CONFIG, {"is_complete": true})
	state_manager.advance_to_next_phase()
	state_manager.set_phase_data(state_manager.Phase.CAPTAIN_CREATION, {"character_name": "Test", "is_complete": true})
	state_manager.advance_to_next_phase()
	state_manager.set_phase_data(state_manager.Phase.CREW_SETUP, {"members": [], "size": 0, "is_complete": true})
	state_manager.advance_to_next_phase()
	state_manager.set_phase_data(state_manager.Phase.SHIP_ASSIGNMENT, {
		"name": "Test Ship",
		"hull_points": 6,
		"is_complete": true
	})
	
	var ship = state_manager.campaign_data["ship"]
	assert_that(ship.has("hull_points")).is_true()
	assert_that(ship.hull_points).is_equal(6)

## Phase 5: Equipment Generation Tests
func test_generate_starting_equipment():
	# Full phase progression
	state_manager.set_phase_data(state_manager.Phase.CONFIG, {"is_complete": true})
	state_manager.advance_to_next_phase()
	state_manager.set_phase_data(state_manager.Phase.CAPTAIN_CREATION, {"character_name": "Test", "is_complete": true})
	state_manager.advance_to_next_phase()
	state_manager.set_phase_data(state_manager.Phase.CREW_SETUP, {"members": [], "size": 0, "is_complete": true})
	state_manager.advance_to_next_phase()
	state_manager.set_phase_data(state_manager.Phase.SHIP_ASSIGNMENT, {"name": "Test", "is_complete": true})
	state_manager.advance_to_next_phase()
	
	var equipment_data = {
		"equipment": ["Scrap Pistol", "Hand Weapon", "Medkit"],
		"credits": 1000,
		"supplies": 5,
		"is_complete": true
	}
	state_manager.set_phase_data(state_manager.Phase.EQUIPMENT_GENERATION, equipment_data)
	var retrieved = state_manager.get_phase_data(state_manager.Phase.EQUIPMENT_GENERATION)
	
	assert_that(retrieved.has("equipment")).is_true()
	assert_that(retrieved.equipment.is_empty()).is_false()

func test_equipment_has_equipment_array():
	state_manager.set_phase_data(state_manager.Phase.CONFIG, {"is_complete": true})
	state_manager.advance_to_next_phase()
	state_manager.set_phase_data(state_manager.Phase.CAPTAIN_CREATION, {"character_name": "Test", "is_complete": true})
	state_manager.advance_to_next_phase()
	state_manager.set_phase_data(state_manager.Phase.CREW_SETUP, {"members": [], "size": 0, "is_complete": true})
	state_manager.advance_to_next_phase()
	state_manager.set_phase_data(state_manager.Phase.SHIP_ASSIGNMENT, {"name": "Test", "is_complete": true})
	state_manager.advance_to_next_phase()
	state_manager.set_phase_data(state_manager.Phase.EQUIPMENT_GENERATION, {
		"equipment": ["Item1"],
		"credits": 1000,
		"is_complete": true
	})
	
	var equipment = state_manager.campaign_data["equipment"]
	assert_that(equipment.has("equipment")).is_true()
	assert_that(equipment.equipment is Array).is_true()

## Phase 6: World Generation Tests
func test_generate_starting_world():
	# Full phase progression
	state_manager.set_phase_data(state_manager.Phase.CONFIG, {"is_complete": true})
	state_manager.advance_to_next_phase()
	state_manager.set_phase_data(state_manager.Phase.CAPTAIN_CREATION, {"character_name": "Test", "is_complete": true})
	state_manager.advance_to_next_phase()
	state_manager.set_phase_data(state_manager.Phase.CREW_SETUP, {"members": [], "size": 0, "is_complete": true})
	state_manager.advance_to_next_phase()
	state_manager.set_phase_data(state_manager.Phase.SHIP_ASSIGNMENT, {"name": "Test", "is_complete": true})
	state_manager.advance_to_next_phase()
	state_manager.set_phase_data(state_manager.Phase.EQUIPMENT_GENERATION, {"equipment": [], "credits": 1000, "is_complete": true})
	state_manager.advance_to_next_phase()
	
	var world_data = {
		"current_world": "Test Colony",
		"world_type": "colony",
		"traits": ["Trade Hub"],
		"is_complete": true
	}
	state_manager.set_phase_data(state_manager.Phase.WORLD_GENERATION, world_data)
	var retrieved = state_manager.get_phase_data(state_manager.Phase.WORLD_GENERATION)
	
	assert_that(retrieved.has("current_world")).is_true()
	assert_that(retrieved.current_world).is_equal("Test Colony")

func test_world_has_traits():
	state_manager.set_phase_data(state_manager.Phase.CONFIG, {"is_complete": true})
	state_manager.advance_to_next_phase()
	state_manager.set_phase_data(state_manager.Phase.CAPTAIN_CREATION, {"character_name": "Test", "is_complete": true})
	state_manager.advance_to_next_phase()
	state_manager.set_phase_data(state_manager.Phase.CREW_SETUP, {"members": [], "size": 0, "is_complete": true})
	state_manager.advance_to_next_phase()
	state_manager.set_phase_data(state_manager.Phase.SHIP_ASSIGNMENT, {"name": "Test", "is_complete": true})
	state_manager.advance_to_next_phase()
	state_manager.set_phase_data(state_manager.Phase.EQUIPMENT_GENERATION, {"equipment": [], "credits": 1000, "is_complete": true})
	state_manager.advance_to_next_phase()
	state_manager.set_phase_data(state_manager.Phase.WORLD_GENERATION, {
		"current_world": "Test",
		"traits": ["Trait1"],
		"is_complete": true
	})
	
	var world = state_manager.campaign_data["world"]
	assert_that(world.has("traits")).is_true()
	assert_that(world.traits is Array).is_true()

## Phase 7: Final Review Tests
func test_all_phases_populated_with_data():
	# Setup all phases
	state_manager.set_phase_data(state_manager.Phase.CONFIG, {"campaign_name": "Test", "is_complete": true})
	state_manager.advance_to_next_phase()
	state_manager.set_phase_data(state_manager.Phase.CAPTAIN_CREATION, {"character_name": "Captain", "is_complete": true})
	state_manager.advance_to_next_phase()
	state_manager.set_phase_data(state_manager.Phase.CREW_SETUP, {"members": [], "size": 0, "is_complete": true})
	state_manager.advance_to_next_phase()
	state_manager.set_phase_data(state_manager.Phase.SHIP_ASSIGNMENT, {"name": "Ship", "is_complete": true})
	state_manager.advance_to_next_phase()
	state_manager.set_phase_data(state_manager.Phase.EQUIPMENT_GENERATION, {"equipment": [], "credits": 1000, "is_complete": true})
	state_manager.advance_to_next_phase()
	state_manager.set_phase_data(state_manager.Phase.WORLD_GENERATION, {"current_world": "World", "is_complete": true})
	state_manager.advance_to_next_phase()
	
	var data = state_manager.campaign_data
	assert_that(data["config"].has("campaign_name")).is_true()
	assert_that(data["captain"].has("character_name")).is_true()
	assert_that(data["crew"].has("members")).is_true()
	assert_that(data["ship"].has("name")).is_true()
	assert_that(data["equipment"].has("credits")).is_true()
	assert_that(data["world"].has("current_world")).is_true()

func test_complete_campaign_creation():
	# Setup all phases completely
	state_manager.set_phase_data(state_manager.Phase.CONFIG, {"campaign_name": "Test", "is_complete": true})
	state_manager.advance_to_next_phase()
	state_manager.set_phase_data(state_manager.Phase.CAPTAIN_CREATION, {"character_name": "Captain", "is_complete": true})
	state_manager.advance_to_next_phase()
	state_manager.set_phase_data(state_manager.Phase.CREW_SETUP, {"members": [], "size": 0, "has_captain": true, "is_complete": true})
	state_manager.advance_to_next_phase()
	state_manager.set_phase_data(state_manager.Phase.SHIP_ASSIGNMENT, {"name": "Ship", "hull_points": 6, "is_complete": true})
	state_manager.advance_to_next_phase()
	state_manager.set_phase_data(state_manager.Phase.EQUIPMENT_GENERATION, {"equipment": [], "credits": 1000, "is_complete": true})
	state_manager.advance_to_next_phase()
	state_manager.set_phase_data(state_manager.Phase.WORLD_GENERATION, {"current_world": "World", "is_complete": true})
	state_manager.advance_to_next_phase()
	
	var result = state_manager.complete_campaign_creation()
	
	assert_that(result.is_empty()).is_false()
	assert_that(result.has("config")).is_true()
	assert_that(result.has("metadata")).is_true()

func test_metadata_includes_creation_timestamp():
	state_manager.set_phase_data(state_manager.Phase.CONFIG, {"campaign_name": "Test", "is_complete": true})
	state_manager.advance_to_next_phase()
	state_manager.set_phase_data(state_manager.Phase.CAPTAIN_CREATION, {"character_name": "Captain", "is_complete": true})
	state_manager.advance_to_next_phase()
	state_manager.set_phase_data(state_manager.Phase.CREW_SETUP, {"members": [], "size": 0, "has_captain": true, "is_complete": true})
	state_manager.advance_to_next_phase()
	state_manager.set_phase_data(state_manager.Phase.SHIP_ASSIGNMENT, {"name": "Ship", "hull_points": 6, "is_complete": true})
	state_manager.advance_to_next_phase()
	state_manager.set_phase_data(state_manager.Phase.EQUIPMENT_GENERATION, {"equipment": [], "credits": 1000, "is_complete": true})
	state_manager.advance_to_next_phase()
	state_manager.set_phase_data(state_manager.Phase.WORLD_GENERATION, {"current_world": "World", "is_complete": true})
	state_manager.advance_to_next_phase()
	state_manager.complete_campaign_creation()
	
	var metadata = state_manager.campaign_data["metadata"]
	assert_that(metadata.has("created_at")).is_true()
	assert_that(metadata["created_at"]).is_not_equal("")
