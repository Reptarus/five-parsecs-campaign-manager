@tool
extends "res://tests/fixtures/specialized/enemy_test.gd"

## Enemy campaign flow tests
## Tests the full lifecycle of enemies across campaign phases:
## - Enemy progression between missions
## - Rival system interactions
## - Campaign-level enemy behaviors
## - Persistent enemy traits and state

# Type-safe instance variables
var _test_enemy_group: Array[Enemy] = []
var _campaign_controller: Node = null

func before_each() -> void:
    await super.before_each()
    
    # Create test enemy group
    for i in range(3):
        var enemy: Enemy = create_test_enemy(EnemyTestType.BASIC)
        assert_not_null(enemy, "Should create test enemy")
        _test_enemy_group.append(enemy)
        add_child_autofree(enemy)
    
    # Create campaign controller
    _campaign_controller = Node.new()
    _campaign_controller.name = "CampaignController"
    add_child_autofree(_campaign_controller)
    track_test_node(_campaign_controller)
    
    await stabilize_engine(ENEMY_TEST_CONFIG.stabilize_time)

func after_each() -> void:
    _test_enemy_group.clear()
    _campaign_controller = null
    await super.after_each()

func test_enemy_persistence() -> void:
    # Setup initial enemy state
    var first_enemy: Enemy = _test_enemy_group[0]
    var enemy_id: String = TypeSafeMixin._call_node_method(first_enemy, "get_id", []) as String
    var initial_health: int = TypeSafeMixin._call_node_method_int(first_enemy, "get_health", [])
    
    # Test campaign persistence
    var save_data: Dictionary = {}
    TypeSafeMixin._call_node_method_bool(first_enemy, "save_to_dictionary", [save_data])
    
    # Simulate campaign mission change
    var new_enemy: Enemy = create_test_enemy(EnemyTestType.BASIC)
    TypeSafeMixin._call_node_method_bool(new_enemy, "load_from_dictionary", [save_data])
    add_child_autofree(new_enemy)
    
    # Verify state persistence
    var loaded_id: String = TypeSafeMixin._call_node_method(new_enemy, "get_id", []) as String
    var loaded_health: int = TypeSafeMixin._call_node_method_int(new_enemy, "get_health", [])
    
    assert_eq(loaded_id, enemy_id, "Enemy ID should persist")
    assert_eq(loaded_health, initial_health, "Enemy health should persist")

func test_enemy_progression() -> void:
    # Simulate enemy surviving missions
    var enemy: Enemy = _test_enemy_group[0]
    
    # Track initial stats
    var initial_power: int = TypeSafeMixin._call_node_method_int(enemy, "get_power_level", [])
    
    # Simulate multiple mission completions
    for i in range(3):
        TypeSafeMixin._call_node_method_bool(enemy, "complete_mission", [])
    
    # Check for progression
    var final_power: int = TypeSafeMixin._call_node_method_int(enemy, "get_power_level", [])
    assert_gt(final_power, initial_power, "Enemy should increase in power after missions")

func test_rival_integration() -> void:
    # Test integration with rival system
    var enemy: Enemy = _test_enemy_group[0]
    
    # Convert to rival
    var is_rival: bool = TypeSafeMixin._call_node_method_bool(_campaign_controller, "promote_to_rival", [enemy])
    assert_true(is_rival, "Enemy should be promoted to rival")
    
    # Check rival properties
    var rival_tier: int = TypeSafeMixin._call_node_method_int(enemy, "get_rival_tier", [])
    assert_gt(rival_tier, 0, "Promoted enemy should have a rival tier")
    
    # Test rival abilities
    var has_special_ability: bool = TypeSafeMixin._call_node_method_bool(enemy, "has_rival_ability", [])
    assert_true(has_special_ability, "Rival should have special abilities")

func test_campaign_phase_effects() -> void:
    # Test how campaign phases affect enemies
    var enemy: Enemy = _test_enemy_group[0]
    
    # Track initial state
    var initial_aggression: int = TypeSafeMixin._call_node_method_int(enemy, "get_aggression", [])
    
    # Simulate campaign phase change
    TypeSafeMixin._call_node_method_bool(_campaign_controller, "change_campaign_phase", ["escalation"])
    TypeSafeMixin._call_node_method_bool(enemy, "react_to_campaign_phase", ["escalation"])
    
    # Check for changes based on campaign phase
    var new_aggression: int = TypeSafeMixin._call_node_method_int(enemy, "get_aggression", [])
    assert_gt(new_aggression, initial_aggression, "Enemy aggression should increase during escalation phase")

func test_enemy_faction_behavior() -> void:
    # Test enemy faction-specific behaviors
    # Create enemies from different factions
    _test_enemy_group.clear()
    
    var faction_types := ["imperial", "pirate", "rebel"]
    for faction in faction_types:
        var enemy: Enemy = create_test_enemy(EnemyTestType.BASIC)
        TypeSafeMixin._call_node_method_bool(enemy, "set_faction", [faction])
        _test_enemy_group.append(enemy)
        add_child_autofree(enemy)
    
    # Test faction-specific behaviors
    for i in range(_test_enemy_group.size()):
        var enemy: Enemy = _test_enemy_group[i]
        var faction: String = TypeSafeMixin._call_node_method(enemy, "get_faction", []) as String
        
        # Trigger faction-specific response
        TypeSafeMixin._call_node_method_bool(enemy, "activate_faction_behavior", [])
        
        # Verify faction-specific traits
        var faction_trait: String = TypeSafeMixin._call_node_method(enemy, "get_faction_trait", []) as String
        assert_not_null(faction_trait, "Enemy should have faction-specific trait")
        assert_true(faction_trait.contains(faction), "Faction trait should relate to the enemy's faction")

# Helper function to check if string contains substring
func assert_string_contains(string_val: Variant, substring_val: Variant, text_or_show_strings: Variant = true) -> Variant:
    var str_value: String = str(string_val)
    var substr_value: String = str(substring_val)
    
    var message: String = ""
    if text_or_show_strings is String:
        message = text_or_show_strings
    elif text_or_show_strings is bool and text_or_show_strings:
        message = "Expected '%s' to contain '%s'" % [str_value, substr_value]
    else:
        message = "String should contain substring"
        
    assert_true(str_value.contains(substr_value), message)
    return null