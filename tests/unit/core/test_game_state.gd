@tool
extends "res://tests/fixtures/base/game_test.gd"

## Tests the functionality of game state management
const GameStateClass: GDScript = preload("res://src/core/state/GameState.gd")
const ShipClass: GDScript = preload("res://src/core/ships/Ship.gd")

# Type-safe instance variables
var state: Node = null

# Type-safe instance variables for state testing
var _state_system: Node = null
var _test_state: Object = null

# Lifecycle Methods
func before_each() -> void:
    await super.before_each()
    
    # Create testing objects
    _state_system = Node.new()
    if not _state_system:
        push_error("Failed to create state system")
        return
    _state_system.name = "GameStateSystem"
    add_child_autofree(_state_system)
    
    await stabilize_engine(STABILIZE_TIME)

func after_each() -> void:
    _state_system = null
    _test_state = null
    await super.after_each()

# Helper methods for object and vector2 safety
func _call_node_method_object(obj: Object, method: String, args: Array = [], default: Object = null) -> Object:
    var result = _call_node_method(obj, method, args)
    if result == null:
        return default
    if result is Object:
        return result
    push_error(ERROR_TYPE_MISMATCH % ["Object", TypeSafeMixin.typeof_as_string(result)])
    return default
    
func _call_node_method_vector2(obj: Object, method: String, args: Array = [], default: Vector2 = Vector2.ZERO) -> Vector2:
    var result = _call_node_method(obj, method, args)
    if result == null:
        return default
    if result is Vector2:
        return result
    push_error(ERROR_TYPE_MISMATCH % ["Vector2", TypeSafeMixin.typeof_as_string(result)])
    return default

# Game State Creation Tests
func test_create_game_state() -> void:
    # Create initial state
    var state = _call_node_method(_state_system, "create_game_state", [])
    assert_not_null(state, "Should create a valid game state")
    
    # Test initial values
    var current_phase: int = _call_node_method_int(state, "get_current_phase", [], GameEnums.FiveParcsecsCampaignPhase.NONE)
    var turn_number: int = _call_node_method_int(state, "get_turn_number", [], 0)
    var story_points: int = _call_node_method_int(state, "get_story_points", [], 0)
    var reputation: int = _call_node_method_int(state, "get_reputation", [], 0)
    var active_quests: Array = _call_node_method_array(state, "get_active_quests", [], [])
    var current_location: Resource = _call_node_method_object(state, "get_current_location", [], null)
    var player_ship: Resource = _call_node_method_object(state, "get_player_ship", [], null)
    
    assert_eq(current_phase, GameEnums.FiveParcsecsCampaignPhase.NONE, "Should initialize with NONE phase")
    assert_eq(turn_number, 0, "Should initialize with turn 0")
    assert_eq(story_points, 0, "Should initialize with 0 story points")
    assert_eq(reputation, 0, "Should initialize with 0 reputation")
    assert_eq(active_quests.size(), 0, "Should initialize with no quests")
    assert_null(current_location, "Should initialize with no location")
    assert_null(player_ship, "Should initialize with no player ship")
    
    # Test initial settings
    var difficulty_level: int = _call_node_method_int(state, "get_difficulty_level", [], GameEnums.DifficultyLevel.NORMAL)
    var enable_permadeath: bool = _call_node_method_bool(state, "get_enable_permadeath", [], true)
    var use_story_track: bool = _call_node_method_bool(state, "get_use_story_track", [], true)
    var auto_save_enabled: bool = _call_node_method_bool(state, "get_auto_save_enabled", [], true)
    
    assert_eq(difficulty_level, GameEnums.DifficultyLevel.NORMAL, "Should initialize with normal difficulty")
    assert_true(enable_permadeath, "Should initialize with permadeath enabled")
    assert_true(use_story_track, "Should initialize with story track enabled")
    assert_true(auto_save_enabled, "Should initialize with auto save enabled")

func test_phase_management() -> void:
    # Test setting phase
    _call_node_method_bool(state, "set_phase", [GameEnums.FiveParcsecsCampaignPhase.SETUP])
    var current_phase: int = _call_node_method_int(state, "get_current_phase", [], GameEnums.FiveParcsecsCampaignPhase.NONE)
    assert_eq(current_phase, GameEnums.FiveParcsecsCampaignPhase.SETUP, "Should update current phase")
    
    # Test phase transitions
    var can_transition: bool = _call_node_method_bool(state, "can_transition_to", [GameEnums.FiveParcsecsCampaignPhase.CAMPAIGN], false)
    assert_true(can_transition, "Should allow valid phase transition")
    
    can_transition = _call_node_method_bool(state, "can_transition_to", [GameEnums.FiveParcsecsCampaignPhase.BATTLE_RESOLUTION], false)
    assert_false(can_transition, "Should prevent invalid phase transition")
    
    # Test phase completion
    _call_node_method_bool(state, "complete_phase", [])
    current_phase = _call_node_method_int(state, "get_current_phase", [], GameEnums.FiveParcsecsCampaignPhase.NONE)
    assert_eq(current_phase, GameEnums.FiveParcsecsCampaignPhase.CAMPAIGN, "Should advance to next phase")

func test_turn_management() -> void:
    # Test turn advancement
    _call_node_method_bool(state, "advance_turn", [])
    var turn_number: int = _call_node_method_int(state, "get_turn_number", [], 0)
    assert_eq(turn_number, 1, "Should increment turn number")
    
    # Test turn events
    var events: Array = _call_node_method_array(state, "get_turn_events", [], [])
    assert_not_null(events, "Should generate turn events")
    
    # Test turn limits
    for i in range(100):
        _call_node_method_bool(state, "advance_turn", [])
    turn_number = _call_node_method_int(state, "get_turn_number", [], 0)
    var max_turns: int = _call_node_method_int(state, "get_max_turns", [], 0)
    assert_true(turn_number <= max_turns, "Should not exceed maximum turns")

func test_resource_management() -> void:
    # Test adding resources
    var success: bool = _call_node_method_bool(state, "add_resource", [GameEnums.ResourceType.CREDITS, 100], false)
    assert_true(success, "Should add credits")
    
    var credits: int = _call_node_method_int(state, "get_resource", [GameEnums.ResourceType.CREDITS], 0)
    assert_eq(credits, 100, "Should track resource amount")
    
    # Test resource limits
    success = _call_node_method_bool(state, "add_resource", [GameEnums.ResourceType.CREDITS, -50], false)
    assert_false(success, "Should prevent negative resources")
    
    # Test removing resources
    success = _call_node_method_bool(state, "remove_resource", [GameEnums.ResourceType.CREDITS, 50], false)
    assert_true(success, "Should remove resources")
    
    credits = _call_node_method_int(state, "get_resource", [GameEnums.ResourceType.CREDITS], 0)
    assert_eq(credits, 50, "Should update resource amount")
    
    success = _call_node_method_bool(state, "remove_resource", [GameEnums.ResourceType.CREDITS, 100], false)
    assert_false(success, "Should prevent removing more than available")

func test_quest_management() -> void:
    var test_quest := {
        "id": "quest_1",
        "title": "Test Quest",
        "type": GameEnums.QuestType.MAIN,
        "status": GameEnums.QuestStatus.ACTIVE
    }
    
    # Test adding quests
    var success: bool = _call_node_method_bool(state, "add_quest", [test_quest], false)
    assert_true(success, "Should add quest")
    
    var active_quests: Array = _call_node_method_array(state, "get_active_quests", [], [])
    assert_eq(active_quests.size(), 1, "Should track active quests")
    
    # Test completing quests
    success = _call_node_method_bool(state, "complete_quest", [test_quest.id], false)
    assert_true(success, "Should complete quest")
    
    var completed_quests: Array = _call_node_method_array(state, "get_completed_quests", [], [])
    assert_eq(completed_quests.size(), 1, "Should track completed quests")
    
    active_quests = _call_node_method_array(state, "get_active_quests", [], [])
    assert_eq(active_quests.size(), 0, "Should remove from active quests")
    
    # Test quest limits
    for i in range(10):
        var quest := test_quest.duplicate()
        quest.id = "quest_%d" % (i + 2)
        _call_node_method_bool(state, "add_quest", [quest], false)
    
    success = _call_node_method_bool(state, "add_quest", [test_quest], false)
    assert_false(success, "Should prevent exceeding quest limit")

func test_location_management() -> void:
    var test_location: Resource = Resource.new()
    track_test_resource(test_location)
    _call_node_method_bool(state, "set_location", [test_location])
    
    var current_location: Resource = _call_node_method_object(state, "get_current_location", [], null)
    assert_not_null(current_location, "Should set current location")
    assert_eq(current_location.id, test_location.id, "Should store location data")
    
    # Test location history
    var visited_locations: Array = _call_node_method_array(state, "get_visited_locations", [], [])
    assert_true(test_location.id in visited_locations, "Should track visited locations")
    
    # Test location effects
    _call_node_method_bool(state, "apply_location_effects", [])
    var fuel: int = _call_node_method_int(state, "get_resource", [GameEnums.ResourceType.FUEL], 0)
    assert_eq(fuel, _call_node_method_int(state, "get_resource", [GameEnums.ResourceType.FUEL], 0) - test_location.fuel_cost,
             "Should apply location costs")

func test_ship_management() -> void:
    var ship: Resource = ShipClass.new()
    track_test_resource(ship)
    
    # Test setting player ship
    _call_node_method_bool(state, "set_player_ship", [ship])
    var player_ship: Resource = _call_node_method_object(state, "get_player_ship", [], null)
    assert_not_null(player_ship, "Should set player ship")
    
    # Test ship damage
    _call_node_method_bool(player_ship, "take_damage", [10])
    var health: int = _call_node_method_int(player_ship, "get_health", [], 0)
    assert_lt(health, TestEnums.SHIP_MAX_HEALTH, "Ship should take damage")

func test_reputation_system() -> void:
    # Test reputation gain
    _call_node_method_bool(state, "add_reputation", [10])
    var reputation: int = _call_node_method_int(state, "get_reputation", [], 0)
    assert_eq(reputation, 10, "Should increase reputation")
    
    # Test reputation loss
    _call_node_method_bool(state, "remove_reputation", [5])
    reputation = _call_node_method_int(state, "get_reputation", [], 0)
    assert_eq(reputation, 5, "Should decrease reputation")
    
    # Test reputation limits
    _call_node_method_bool(state, "add_reputation", [1000])
    reputation = _call_node_method_int(state, "get_reputation", [], 0)
    var max_reputation: int = _call_node_method_int(state, "get_max_reputation", [], 0)
    assert_eq(reputation, max_reputation, "Should cap maximum reputation")
    
    _call_node_method_bool(state, "remove_reputation", [1000])
    reputation = _call_node_method_int(state, "get_reputation", [], 0)
    assert_eq(reputation, 0, "Should prevent negative reputation")

func test_story_point_management() -> void:
    # Test story point gain
    _call_node_method_bool(state, "add_story_points", [1])
    var story_points: int = _call_node_method_int(state, "get_story_points", [], 0)
    assert_eq(story_points, 1, "Should add story points")
    
    # Test story point use
    var success: bool = _call_node_method_bool(state, "use_story_point", [], false)
    assert_true(success, "Should allow using story point")
    
    story_points = _call_node_method_int(state, "get_story_points", [], 0)
    assert_eq(story_points, 0, "Should decrease story points when used")
    
    success = _call_node_method_bool(state, "use_story_point", [], false)
    assert_false(success, "Should prevent using story points when none available")
    
    # Test story point limits
    for i in range(10):
        _call_node_method_bool(state, "add_story_points", [1])
    
    story_points = _call_node_method_int(state, "get_story_points", [], 0)
    var max_story_points: int = _call_node_method_int(state, "get_max_story_points", [], 0)
    assert_eq(story_points, max_story_points, "Should cap maximum story points")

func test_serialization() -> void:
    # Set up test state
    _call_node_method_bool(state, "set_current_phase", [GameEnums.FiveParcsecsCampaignPhase.CAMPAIGN])
    _call_node_method_bool(state, "set_turn_number", [5])
    _call_node_method_bool(state, "set_story_points", [10])
    _call_node_method_bool(state, "set_reputation", [20])
    
    var test_location: Resource = Resource.new()
    track_test_resource(test_location)
    _call_node_method_bool(state, "set_location", [test_location])
    
    var ship: Resource = ShipClass.new()
    track_test_resource(ship)
    _call_node_method_bool(state, "set_player_ship", [ship])
    
    # Serialize and deserialize
    var data: Dictionary = _call_node_method_dict(state, "serialize", [], {})
    var new_state: Node = GameStateClass.new()
    add_child(new_state)
    _call_node_method_bool(new_state, "deserialize", [data])
    
    # Verify state
    var current_phase: int = _call_node_method_int(new_state, "get_current_phase", [], GameEnums.FiveParcsecsCampaignPhase.NONE)
    var turn_number: int = _call_node_method_int(new_state, "get_turn_number", [], 0)
    var story_points: int = _call_node_method_int(new_state, "get_story_points", [], 0)
    var reputation: int = _call_node_method_int(new_state, "get_reputation", [], 0)
    var active_quests: Array = _call_node_method_array(new_state, "get_active_quests", [], [])
    var current_location: Resource = _call_node_method_object(new_state, "get_current_location", [], null)
    var player_ship: Resource = _call_node_method_object(new_state, "get_player_ship", [], null)
    
    assert_eq(current_phase, GameEnums.FiveParcsecsCampaignPhase.CAMPAIGN, "Should preserve current phase")
    assert_eq(turn_number, 5, "Should preserve turn number")
    assert_eq(story_points, 10, "Should preserve story points")
    assert_eq(reputation, 20, "Should preserve reputation")
    assert_eq(active_quests.size(), 0, "Should preserve active quests")
    assert_not_null(current_location, "Should preserve current location")
    assert_not_null(player_ship, "Should preserve player ship")