extends "res://addons/gut/test.gd"

const GameState = preload("res://src/core/state/GameState.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const Ship = preload("res://src/core/ships/Ship.gd")
const TestHelper = preload("res://tests/fixtures/test_helper.gd")

var state: GameState

func before_each() -> void:
    state = GameState.new()
    var state_data = TestHelper.setup_test_game_state()
    
    # Set up game state properties
    state.difficulty_level = state_data.get("difficulty_level", GameEnums.DifficultyLevel.NORMAL)
    state.enable_permadeath = state_data.get("enable_permadeath", true)
    state.use_story_track = state_data.get("use_story_track", true)
    state.auto_save_enabled = state_data.get("auto_save_enabled", true)
    state.last_save_time = state_data.get("last_save_time", 0)

func after_each() -> void:
    if is_instance_valid(state):
        state.queue_free()
    state = null

func test_initialization() -> void:
    assert_eq(state.current_phase, GameEnums.FiveParcsecsCampaignPhase.NONE, "Should initialize with no phase")
    assert_eq(state.turn_number, 0, "Should initialize at turn 0")
    assert_eq(state.story_points, 0, "Should initialize with no story points")
    assert_eq(state.reputation, 0, "Should initialize with no reputation")
    assert_eq(state.resources.size(), 0, "Should initialize with no resources")
    assert_eq(state.active_quests.size(), 0, "Should initialize with no active quests")
    assert_eq(state.completed_quests.size(), 0, "Should initialize with no completed quests")
    assert_null(state.current_location, "Should initialize with no location")
    assert_null(state.player_ship, "Should initialize with no player ship")
    
    # Test initial settings
    assert_eq(state.difficulty_level, GameEnums.DifficultyLevel.NORMAL, "Should initialize with normal difficulty")
    assert_true(state.enable_permadeath, "Should initialize with permadeath enabled")
    assert_true(state.use_story_track, "Should initialize with story track enabled")
    assert_true(state.auto_save_enabled, "Should initialize with auto save enabled")

func test_phase_management() -> void:
    # Test setting phase
    state.set_phase(GameEnums.FiveParcsecsCampaignPhase.SETUP)
    assert_eq(state.current_phase, GameEnums.FiveParcsecsCampaignPhase.SETUP, "Should update current phase")
    
    # Test phase transitions
    assert_true(state.can_transition_to(GameEnums.FiveParcsecsCampaignPhase.CAMPAIGN), "Should allow valid phase transition")
    assert_false(state.can_transition_to(GameEnums.FiveParcsecsCampaignPhase.BATTLE_RESOLUTION), "Should prevent invalid phase transition")
    
    # Test phase completion
    state.complete_phase()
    assert_eq(state.current_phase, GameEnums.FiveParcsecsCampaignPhase.CAMPAIGN, "Should advance to next phase")

func test_turn_management() -> void:
    # Test turn advancement
    state.advance_turn()
    assert_eq(state.turn_number, 1, "Should increment turn number")
    
    # Test turn events
    var events = state.get_turn_events()
    assert_not_null(events, "Should generate turn events")
    
    # Test turn limits
    for i in range(100):
        state.advance_turn()
    assert_true(state.turn_number <= state.max_turns, "Should not exceed maximum turns")

func test_resource_management() -> void:
    # Test adding resources
    assert_true(state.add_resource(GameEnums.ResourceType.CREDITS, 100), "Should add credits")
    assert_eq(state.get_resource(GameEnums.ResourceType.CREDITS), 100, "Should track resource amount")
    
    # Test resource limits
    assert_false(state.add_resource(GameEnums.ResourceType.CREDITS, -50), "Should prevent negative resources")
    
    # Test removing resources
    assert_true(state.remove_resource(GameEnums.ResourceType.CREDITS, 50), "Should remove resources")
    assert_eq(state.get_resource(GameEnums.ResourceType.CREDITS), 50, "Should update resource amount")
    assert_false(state.remove_resource(GameEnums.ResourceType.CREDITS, 100), "Should prevent removing more than available")

func test_quest_management() -> void:
    var test_quest = {
        "id": "quest_1",
        "title": "Test Quest",
        "type": GameEnums.QuestType.MAIN,
        "status": GameEnums.QuestStatus.ACTIVE
    }
    
    # Test adding quests
    assert_true(state.add_quest(test_quest), "Should add quest")
    assert_eq(state.active_quests.size(), 1, "Should track active quests")
    
    # Test completing quests
    assert_true(state.complete_quest(test_quest.id), "Should complete quest")
    assert_eq(state.completed_quests.size(), 1, "Should track completed quests")
    assert_eq(state.active_quests.size(), 0, "Should remove from active quests")
    
    # Test quest limits
    for i in range(10):
        var quest = test_quest.duplicate()
        quest.id = "quest_%d" % (i + 2)
        state.add_quest(quest)
    assert_false(state.add_quest(test_quest), "Should prevent exceeding quest limit")

func test_location_management() -> void:
    var test_location = {
        "id": "loc_1",
        "name": "Test Location",
        "type": GameEnums.LocationType.TRADE_CENTER,
        "coordinates": Vector2(100, 100)
    }
    
    # Test setting location
    state.set_location(test_location)
    assert_not_null(state.current_location, "Should set current location")
    assert_eq(state.current_location.id, test_location.id, "Should store location data")
    
    # Test location history
    assert_true(test_location.id in state.visited_locations, "Should track visited locations")
    
    # Test location effects
    state.apply_location_effects()
    assert_eq(state.get_resource(GameEnums.ResourceType.FUEL),
             state.get_resource(GameEnums.ResourceType.FUEL) - test_location.fuel_cost,
             "Should apply location costs")

func test_ship_management() -> void:
    var ship = Ship.new()
    
    # Test setting player ship
    state.set_player_ship(ship)
    assert_not_null(state.player_ship, "Should set player ship")
    
    # Test ship damage
    var initial_hull = state.player_ship.get_component("hull").durability
    state.apply_ship_damage(20)
    assert_eq(state.player_ship.get_component("hull").durability, initial_hull - 20, "Should apply ship damage")
    
    # Test ship repairs
    state.repair_ship()
    assert_eq(state.player_ship.get_component("hull").durability, 100, "Should repair ship")

func test_reputation_system() -> void:
    # Test reputation gain
    state.add_reputation(10)
    assert_eq(state.reputation, 10, "Should increase reputation")
    
    # Test reputation loss
    state.remove_reputation(5)
    assert_eq(state.reputation, 5, "Should decrease reputation")
    
    # Test reputation limits
    state.add_reputation(1000)
    assert_eq(state.reputation, state.max_reputation, "Should cap maximum reputation")
    state.remove_reputation(1000)
    assert_eq(state.reputation, 0, "Should prevent negative reputation")

func test_story_point_management() -> void:
    # Test story point gain
    state.add_story_points(1)
    assert_eq(state.story_points, 1, "Should add story points")
    
    # Test story point use
    assert_true(state.use_story_point(), "Should allow using story point")
    assert_eq(state.story_points, 0, "Should decrease story points when used")
    assert_false(state.use_story_point(), "Should prevent using story points when none available")
    
    # Test story point limits
    for i in range(10):
        state.add_story_points(1)
    assert_eq(state.story_points, state.max_story_points, "Should cap maximum story points")

func test_serialization() -> void:
    # Setup game state
    state.set_phase(GameEnums.FiveParcsecsCampaignPhase.CAMPAIGN)
    state.turn_number = 5
    state.story_points = 3
    state.reputation = 50
    state.add_resource(GameEnums.ResourceType.CREDITS, 1000)
    
    var test_quest = {
        "id": "quest_1",
        "title": "Test Quest",
        "type": GameEnums.QuestType.MAIN,
        "status": GameEnums.QuestStatus.ACTIVE
    }
    state.add_quest(test_quest)
    
    var test_location = {
        "id": "loc_1",
        "name": "Test Location",
        "type": GameEnums.LocationType.TRADE_CENTER,
        "coordinates": Vector2(100, 100)
    }
    state.set_location(test_location)
    
    var ship = Ship.new()
    state.set_player_ship(ship)
    
    # Serialize and deserialize
    var data = state.serialize()
    var new_state = GameState.deserialize_new(data)
    
    # Verify state
    assert_eq(new_state.current_phase, state.current_phase, "Should preserve current phase")
    assert_eq(new_state.turn_number, state.turn_number, "Should preserve turn number")
    assert_eq(new_state.story_points, state.story_points, "Should preserve story points")
    assert_eq(new_state.reputation, state.reputation, "Should preserve reputation")
    assert_eq(new_state.get_resource(GameEnums.ResourceType.CREDITS), 1000, "Should preserve resources")
    assert_eq(new_state.active_quests.size(), state.active_quests.size(), "Should preserve active quests")
    assert_not_null(new_state.current_location, "Should preserve current location")
    assert_not_null(new_state.player_ship, "Should preserve player ship")