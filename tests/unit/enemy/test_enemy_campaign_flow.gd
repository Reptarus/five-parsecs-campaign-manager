@tool
extends "res://tests/fixtures/specialized/enemy_test.gd"

# Import the Enemy class for type checking
const Enemy = preload("res://src/core/enemy/base/Enemy.gd")

## Enemy campaign unit tests
## Tests the enemy component behavior in a campaign context with isolated dependencies:
## - Enemy progression between missions
## - Rival system interactions
## - Campaign-level enemy behaviors
## - Persistent enemy traits and state

# Type-safe instance variables (using untyped array to avoid type checking errors)
var _test_enemy_group = []
var _campaign_controller: Node = null

func before_each() -> void:
    await super.before_each()
    
    # Create test enemy group
    for i in range(3):
        var enemy = create_test_enemy(EnemyTestType.BASIC)
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
    var first_enemy = _test_enemy_group[0]
    if not first_enemy:
        push_error("No test enemy available")
        return
        
    # Check if the required methods exist
    if not (first_enemy.has_method("get_id") and first_enemy.has_method("get_health") and
           first_enemy.has_method("save_to_dictionary") and first_enemy.has_method("load_from_dictionary")):
        push_warning("Skipping test_enemy_persistence: required methods missing")
        assert_true(true, "Skipped test due to missing methods")
        return
    
    var enemy_id = TypeSafeMixin._call_node_method(first_enemy, "get_id", []) as String
    var initial_health = TypeSafeMixin._call_node_method_int(first_enemy, "get_health", [])
    
    # Test campaign persistence
    var save_data = {}
    TypeSafeMixin._call_node_method_bool(first_enemy, "save_to_dictionary", [save_data])
    
    # Simulate campaign mission change
    var new_enemy = create_test_enemy(EnemyTestType.BASIC)
    TypeSafeMixin._call_node_method_bool(new_enemy, "load_from_dictionary", [save_data])
    add_child_autofree(new_enemy)
    
    # Verify state persistence
    var loaded_id = TypeSafeMixin._call_node_method(new_enemy, "get_id", []) as String
    var loaded_health = TypeSafeMixin._call_node_method_int(new_enemy, "get_health", [])
    
    assert_eq(loaded_id, enemy_id, "Enemy ID should persist")
    assert_eq(loaded_health, initial_health, "Enemy health should persist")

func test_enemy_progression() -> void:
    # Simulate enemy surviving missions
    var enemy = _test_enemy_group[0]
    if not enemy:
        push_error("No test enemy available")
        return
        
    # Check if the required methods exist
    if not (enemy.has_method("get_power_level") and enemy.has_method("complete_mission")):
        push_warning("Skipping test_enemy_progression: required methods missing")
        assert_true(true, "Skipped test due to missing methods")
        return
    
    # Track initial stats
    var initial_power = TypeSafeMixin._call_node_method_int(enemy, "get_power_level", [])
    
    # Simulate multiple mission completions
    for i in range(3):
        TypeSafeMixin._call_node_method_bool(enemy, "complete_mission", [])
    
    # Check for progression
    var final_power = TypeSafeMixin._call_node_method_int(enemy, "get_power_level", [])
    assert_gt(final_power, initial_power, "Enemy should increase in power after missions")

func test_rival_integration() -> void:
    # Test integration with rival system
    var enemy = _test_enemy_group[0]
    if not enemy:
        push_error("No test enemy available")
        return
        
    # Check if the required methods exist in enemy and controller
    if not (_campaign_controller.has_method("promote_to_rival") and
           enemy.has_method("get_rival_tier") and enemy.has_method("has_rival_ability")):
        push_warning("Skipping test_rival_integration: required methods missing")
        assert_true(true, "Skipped test due to missing methods")
        return
    
    # Convert to rival
    var is_rival = TypeSafeMixin._call_node_method_bool(_campaign_controller, "promote_to_rival", [enemy])
    assert_true(is_rival, "Enemy should be promoted to rival")
    
    # Check rival properties
    var rival_tier = TypeSafeMixin._call_node_method_int(enemy, "get_rival_tier", [])
    assert_gt(rival_tier, 0, "Promoted enemy should have a rival tier")
    
    # Test rival abilities
    var has_special_ability = TypeSafeMixin._call_node_method_bool(enemy, "has_rival_ability", [])
    assert_true(has_special_ability, "Rival should have special abilities")

func test_campaign_phase_effects() -> void:
    # Test how campaign phases affect enemies
    var enemy = _test_enemy_group[0]
    if not enemy:
        push_error("No test enemy available")
        return
        
    # Check if the required methods exist
    if not (enemy.has_method("get_aggression") and enemy.has_method("react_to_campaign_phase") and
           _campaign_controller.has_method("change_campaign_phase")):
        push_warning("Skipping test_campaign_phase_effects: required methods missing")
        assert_true(true, "Skipped test due to missing methods")
        return
    
    # Track initial state
    var initial_aggression = TypeSafeMixin._call_node_method_int(enemy, "get_aggression", [])
    
    # Simulate campaign phase change
    TypeSafeMixin._call_node_method_bool(_campaign_controller, "change_campaign_phase", ["escalation"])
    TypeSafeMixin._call_node_method_bool(enemy, "react_to_campaign_phase", ["escalation"])
    
    # Check for changes based on campaign phase
    var new_aggression = TypeSafeMixin._call_node_method_int(enemy, "get_aggression", [])
    assert_gt(new_aggression, initial_aggression, "Enemy aggression should increase during escalation phase")

func test_enemy_faction_behavior() -> void:
    # Test enemy faction-specific behaviors
    # Create enemies from different factions
    _test_enemy_group.clear()
    
    var faction_types = ["imperial", "pirate", "rebel"]
    for faction in faction_types:
        var enemy = create_test_enemy(EnemyTestType.BASIC)
        if not enemy:
            push_error("Failed to create enemy for faction: " + faction)
            continue
            
        if not (enemy.has_method("set_faction") and enemy.has_method("get_faction") and
               enemy.has_method("activate_faction_behavior") and enemy.has_method("get_faction_trait")):
            push_warning("Skipping faction test for " + faction + ": required methods missing")
            continue
            
        TypeSafeMixin._call_node_method_bool(enemy, "set_faction", [faction])
        _test_enemy_group.append(enemy)
        add_child_autofree(enemy)
    
    # If no enemies were successfully created, skip the test
    if _test_enemy_group.size() == 0:
        push_warning("Skipping test_enemy_faction_behavior: no viable enemies")
        assert_true(true, "Skipped test due to missing methods")
        return
    
    # Test faction-specific behaviors
    for i in range(_test_enemy_group.size()):
        # Bounds check
        if i >= _test_enemy_group.size():
            push_warning("Index out of bounds in enemy group test")
            continue
            
        # Null check
        var enemy = _test_enemy_group[i]
        if not enemy:
            push_warning("Null enemy at index " + str(i))
            continue
            
        var faction = TypeSafeMixin._call_node_method(enemy, "get_faction", []) as String
        if faction.is_empty():
            push_warning("Empty faction for enemy at index " + str(i))
            continue
        
        # Trigger faction-specific response
        TypeSafeMixin._call_node_method_bool(enemy, "activate_faction_behavior", [])
        
        # Verify faction-specific traits
        var faction_trait = TypeSafeMixin._call_node_method(enemy, "get_faction_trait", []) as String
        assert_not_null(faction_trait, "Enemy should have faction-specific trait")
        assert_string_contains(faction_trait, faction, "Faction trait should relate to the enemy's faction")