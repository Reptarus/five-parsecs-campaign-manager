@tool
extends "res://tests/fixtures/base/game_test.gd"

## Tests the functionality of game state management
const GameStateClass: GDScript = preload("res://src/core/state/GameState.gd")
const ShipClass: GDScript = preload("res://src/core/ships/Ship.gd")

# Type-safe instance variables
var state: Node = null

func before_each() -> void:
    await super.before_each()
    state = GameStateClass.new()
    if not state:
        push_error("Failed to create game state")
        return
    
    var state_data: Dictionary = TestHelper.setup_test_game_state()
    
    # Set up game state properties with type safety
    TypeSafeMixin._safe_method_call_bool(state, "set_difficulty_level", [state_data.get("difficulty_level", GameEnums.DifficultyLevel.NORMAL)])
    TypeSafeMixin._safe_method_call_bool(state, "set_enable_permadeath", [state_data.get("enable_permadeath", true)])
    TypeSafeMixin._safe_method_call_bool(state, "set_use_story_track", [state_data.get("use_story_track", true)])
    TypeSafeMixin._safe_method_call_bool(state, "set_auto_save_enabled", [state_data.get("auto_save_enabled", true)])
    TypeSafeMixin._safe_method_call_bool(state, "set_last_save_time", [state_data.get("last_save_time", 0)])
    
    add_child(state)
    await get_tree().process_frame

func after_each() -> void:
    await super.after_each()
    state = null

func test_initial_state() -> void:
    # Test initial values
    var current_phase: int = TypeSafeMixin._safe_method_call_int(state, "get_current_phase", [], GameEnums.FiveParcsecsCampaignPhase.NONE)
    var turn_number: int = TypeSafeMixin._safe_method_call_int(state, "get_turn_number", [], 0)
    var story_points: int = TypeSafeMixin._safe_method_call_int(state, "get_story_points", [], 0)
    var reputation: int = TypeSafeMixin._safe_method_call_int(state, "get_reputation", [], 0)
    var active_quests: Array = TypeSafeMixin._safe_method_call_array(state, "get_active_quests", [], [])
    var current_location: Resource = TypeSafeMixin._safe_method_call_object(state, "get_current_location", [], null)
    var player_ship: Resource = TypeSafeMixin._safe_method_call_object(state, "get_player_ship", [], null)
    
    assert_eq(current_phase, GameEnums.FiveParcsecsCampaignPhase.NONE, "Should initialize with NONE phase")
    assert_eq(turn_number, 0, "Should initialize with turn 0")
    assert_eq(story_points, 0, "Should initialize with 0 story points")
    assert_eq(reputation, 0, "Should initialize with 0 reputation")
    assert_eq(active_quests.size(), 0, "Should initialize with no quests")
    assert_null(current_location, "Should initialize with no location")
    assert_null(player_ship, "Should initialize with no player ship")
    
    # Test initial settings
    var difficulty_level: int = TypeSafeMixin._safe_method_call_int(state, "get_difficulty_level", [], GameEnums.DifficultyLevel.NORMAL)
    var enable_permadeath: bool = TypeSafeMixin._safe_method_call_bool(state, "get_enable_permadeath", [], true)
    var use_story_track: bool = TypeSafeMixin._safe_method_call_bool(state, "get_use_story_track", [], true)
    var auto_save_enabled: bool = TypeSafeMixin._safe_method_call_bool(state, "get_auto_save_enabled", [], true)
    
    assert_eq(difficulty_level, GameEnums.DifficultyLevel.NORMAL, "Should initialize with normal difficulty")
    assert_true(enable_permadeath, "Should initialize with permadeath enabled")
    assert_true(use_story_track, "Should initialize with story track enabled")
    assert_true(auto_save_enabled, "Should initialize with auto save enabled")

func test_phase_management() -> void:
    # Test setting phase
    TypeSafeMixin._safe_method_call_bool(state, "set_phase", [GameEnums.FiveParcsecsCampaignPhase.SETUP])
    var current_phase: int = TypeSafeMixin._safe_method_call_int(state, "get_current_phase", [], GameEnums.FiveParcsecsCampaignPhase.NONE)
    assert_eq(current_phase, GameEnums.FiveParcsecsCampaignPhase.SETUP, "Should update current phase")
    
    # Test phase transitions
    var can_transition: bool = TypeSafeMixin._safe_method_call_bool(state, "can_transition_to", [GameEnums.FiveParcsecsCampaignPhase.CAMPAIGN], false)
    assert_true(can_transition, "Should allow valid phase transition")
    
    can_transition = TypeSafeMixin._safe_method_call_bool(state, "can_transition_to", [GameEnums.FiveParcsecsCampaignPhase.BATTLE_RESOLUTION], false)
    assert_false(can_transition, "Should prevent invalid phase transition")
    
    # Test phase completion
    TypeSafeMixin._safe_method_call_bool(state, "complete_phase", [])
    current_phase = TypeSafeMixin._safe_method_call_int(state, "get_current_phase", [], GameEnums.FiveParcsecsCampaignPhase.NONE)
    assert_eq(current_phase, GameEnums.FiveParcsecsCampaignPhase.CAMPAIGN, "Should advance to next phase")

func test_turn_management() -> void:
    # Test turn advancement
    TypeSafeMixin._safe_method_call_bool(state, "advance_turn", [])
    var turn_number: int = TypeSafeMixin._safe_method_call_int(state, "get_turn_number", [], 0)
    assert_eq(turn_number, 1, "Should increment turn number")
    
    # Test turn events
    var events: Array = TypeSafeMixin._safe_method_call_array(state, "get_turn_events", [], [])
    assert_not_null(events, "Should generate turn events")
    
    # Test turn limits
    for i in range(100):
        TypeSafeMixin._safe_method_call_bool(state, "advance_turn", [])
    turn_number = TypeSafeMixin._safe_method_call_int(state, "get_turn_number", [], 0)
    var max_turns: int = TypeSafeMixin._safe_method_call_int(state, "get_max_turns", [], 0)
    assert_true(turn_number <= max_turns, "Should not exceed maximum turns")

func test_resource_management() -> void:
    # Test adding resources
    var success: bool = TypeSafeMixin._safe_method_call_bool(state, "add_resource", [GameEnums.ResourceType.CREDITS, 100], false)
    assert_true(success, "Should add credits")
    
    var credits: int = TypeSafeMixin._safe_method_call_int(state, "get_resource", [GameEnums.ResourceType.CREDITS], 0)
    assert_eq(credits, 100, "Should track resource amount")
    
    # Test resource limits
    success = TypeSafeMixin._safe_method_call_bool(state, "add_resource", [GameEnums.ResourceType.CREDITS, -50], false)
    assert_false(success, "Should prevent negative resources")
    
    # Test removing resources
    success = TypeSafeMixin._safe_method_call_bool(state, "remove_resource", [GameEnums.ResourceType.CREDITS, 50], false)
    assert_true(success, "Should remove resources")
    
    credits = TypeSafeMixin._safe_method_call_int(state, "get_resource", [GameEnums.ResourceType.CREDITS], 0)
    assert_eq(credits, 50, "Should update resource amount")
    
    success = TypeSafeMixin._safe_method_call_bool(state, "remove_resource", [GameEnums.ResourceType.CREDITS, 100], false)
    assert_false(success, "Should prevent removing more than available")

func test_quest_management() -> void:
    var test_quest := {
        "id": "quest_1",
        "title": "Test Quest",
        "type": GameEnums.QuestType.MAIN,
        "status": GameEnums.QuestStatus.ACTIVE
    }
    
    # Test adding quests
    var success: bool = TypeSafeMixin._safe_method_call_bool(state, "add_quest", [test_quest], false)
    assert_true(success, "Should add quest")
    
    var active_quests: Array = TypeSafeMixin._safe_method_call_array(state, "get_active_quests", [], [])
    assert_eq(active_quests.size(), 1, "Should track active quests")
    
    # Test completing quests
    success = TypeSafeMixin._safe_method_call_bool(state, "complete_quest", [test_quest.id], false)
    assert_true(success, "Should complete quest")
    
    var completed_quests: Array = TypeSafeMixin._safe_method_call_array(state, "get_completed_quests", [], [])
    assert_eq(completed_quests.size(), 1, "Should track completed quests")
    
    active_quests = TypeSafeMixin._safe_method_call_array(state, "get_active_quests", [], [])
    assert_eq(active_quests.size(), 0, "Should remove from active quests")
    
    # Test quest limits
    for i in range(10):
        var quest := test_quest.duplicate()
        quest.id = "quest_%d" % (i + 2)
        TypeSafeMixin._safe_method_call_bool(state, "add_quest", [quest], false)
    
    success = TypeSafeMixin._safe_method_call_bool(state, "add_quest", [test_quest], false)
    assert_false(success, "Should prevent exceeding quest limit")

func test_location_management() -> void:
    var test_location: Resource = Resource.new()
    track_test_resource(test_location)
    TypeSafeMixin._safe_method_call_bool(state, "set_location", [test_location])
    
    var current_location: Resource = TypeSafeMixin._safe_method_call_object(state, "get_current_location", [], null)
    assert_not_null(current_location, "Should set current location")
    assert_eq(current_location.id, test_location.id, "Should store location data")
    
    # Test location history
    var visited_locations: Array = TypeSafeMixin._safe_method_call_array(state, "get_visited_locations", [], [])
    assert_true(test_location.id in visited_locations, "Should track visited locations")
    
    # Test location effects
    TypeSafeMixin._safe_method_call_bool(state, "apply_location_effects", [])
    var fuel: int = TypeSafeMixin._safe_method_call_int(state, "get_resource", [GameEnums.ResourceType.FUEL], 0)
    assert_eq(fuel, TypeSafeMixin._safe_method_call_int(state, "get_resource", [GameEnums.ResourceType.FUEL], 0) - test_location.fuel_cost,
             "Should apply location costs")

func test_ship_management() -> void:
    var ship: Resource = ShipClass.new()
    track_test_resource(ship)
    
    # Test setting player ship
    TypeSafeMixin._safe_method_call_bool(state, "set_player_ship", [ship])
    var player_ship: Resource = TypeSafeMixin._safe_method_call_object(state, "get_player_ship", [], null)
    assert_not_null(player_ship, "Should set player ship")
    
    # Test ship damage
    TypeSafeMixin._safe_method_call_bool(player_ship, "take_damage", [10])
    var health: int = TypeSafeMixin._safe_method_call_int(player_ship, "get_health", [], 0)
    assert_lt(health, GameEnums.SHIP_MAX_HEALTH, "Ship should take damage")

func test_reputation_system() -> void:
    # Test reputation gain
    TypeSafeMixin._safe_method_call_bool(state, "add_reputation", [10])
    var reputation: int = TypeSafeMixin._safe_method_call_int(state, "get_reputation", [], 0)
    assert_eq(reputation, 10, "Should increase reputation")
    
    # Test reputation loss
    TypeSafeMixin._safe_method_call_bool(state, "remove_reputation", [5])
    reputation = TypeSafeMixin._safe_method_call_int(state, "get_reputation", [], 0)
    assert_eq(reputation, 5, "Should decrease reputation")
    
    # Test reputation limits
    TypeSafeMixin._safe_method_call_bool(state, "add_reputation", [1000])
    reputation = TypeSafeMixin._safe_method_call_int(state, "get_reputation", [], 0)
    var max_reputation: int = TypeSafeMixin._safe_method_call_int(state, "get_max_reputation", [], 0)
    assert_eq(reputation, max_reputation, "Should cap maximum reputation")
    
    TypeSafeMixin._safe_method_call_bool(state, "remove_reputation", [1000])
    reputation = TypeSafeMixin._safe_method_call_int(state, "get_reputation", [], 0)
    assert_eq(reputation, 0, "Should prevent negative reputation")

func test_story_point_management() -> void:
    # Test story point gain
    TypeSafeMixin._safe_method_call_bool(state, "add_story_points", [1])
    var story_points: int = TypeSafeMixin._safe_method_call_int(state, "get_story_points", [], 0)
    assert_eq(story_points, 1, "Should add story points")
    
    # Test story point use
    var success: bool = TypeSafeMixin._safe_method_call_bool(state, "use_story_point", [], false)
    assert_true(success, "Should allow using story point")
    
    story_points = TypeSafeMixin._safe_method_call_int(state, "get_story_points", [], 0)
    assert_eq(story_points, 0, "Should decrease story points when used")
    
    success = TypeSafeMixin._safe_method_call_bool(state, "use_story_point", [], false)
    assert_false(success, "Should prevent using story points when none available")
    
    # Test story point limits
    for i in range(10):
        TypeSafeMixin._safe_method_call_bool(state, "add_story_points", [1])
    
    story_points = TypeSafeMixin._safe_method_call_int(state, "get_story_points", [], 0)
    var max_story_points: int = TypeSafeMixin._safe_method_call_int(state, "get_max_story_points", [], 0)
    assert_eq(story_points, max_story_points, "Should cap maximum story points")

func test_serialization() -> void:
    # Set up test state
    TypeSafeMixin._safe_method_call_bool(state, "set_current_phase", [GameEnums.FiveParcsecsCampaignPhase.CAMPAIGN])
    TypeSafeMixin._safe_method_call_bool(state, "set_turn_number", [5])
    TypeSafeMixin._safe_method_call_bool(state, "set_story_points", [10])
    TypeSafeMixin._safe_method_call_bool(state, "set_reputation", [20])
    
    var test_location: Resource = Resource.new()
    track_test_resource(test_location)
    TypeSafeMixin._safe_method_call_bool(state, "set_location", [test_location])
    
    var ship: Resource = ShipClass.new()
    track_test_resource(ship)
    TypeSafeMixin._safe_method_call_bool(state, "set_player_ship", [ship])
    
    # Serialize and deserialize
    var data: Dictionary = TypeSafeMixin._safe_method_call_dict(state, "serialize", [], {})
    var new_state: Node = GameStateClass.new()
    add_child(new_state)
    TypeSafeMixin._safe_method_call_bool(new_state, "deserialize", [data])
    
    # Verify state
    var current_phase: int = TypeSafeMixin._safe_method_call_int(new_state, "get_current_phase", [], GameEnums.FiveParcsecsCampaignPhase.NONE)
    var turn_number: int = TypeSafeMixin._safe_method_call_int(new_state, "get_turn_number", [], 0)
    var story_points: int = TypeSafeMixin._safe_method_call_int(new_state, "get_story_points", [], 0)
    var reputation: int = TypeSafeMixin._safe_method_call_int(new_state, "get_reputation", [], 0)
    var active_quests: Array = TypeSafeMixin._safe_method_call_array(new_state, "get_active_quests", [], [])
    var current_location: Resource = TypeSafeMixin._safe_method_call_object(new_state, "get_current_location", [], null)
    var player_ship: Resource = TypeSafeMixin._safe_method_call_object(new_state, "get_player_ship", [], null)
    
    assert_eq(current_phase, GameEnums.FiveParcsecsCampaignPhase.CAMPAIGN, "Should preserve current phase")
    assert_eq(turn_number, 5, "Should preserve turn number")
    assert_eq(story_points, 10, "Should preserve story points")
    assert_eq(reputation, 20, "Should preserve reputation")
    assert_eq(active_quests.size(), 0, "Should preserve active quests")
    assert_not_null(current_location, "Should preserve current location")
    assert_not_null(player_ship, "Should preserve player ship")