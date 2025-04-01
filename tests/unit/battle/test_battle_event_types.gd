## Battle Event Types Test Suite
## Tests the functionality of battle events including:
## - Event definitions and properties
## - Event requirements and conditions
## - Event effects and outcomes
## - Event probability calculations
@tool
extends "res://tests/fixtures/base/game_test.gd"
# Use explicit preloads instead of global class names

# Type-safe script references
const BattleEventTypes: GDScript = preload("res://src/core/battle/events/BattleEventTypes.gd")

# Type-safe constants
const TEST_TIMEOUT: float = 2.0

# Type-safe instance variables
var _event_manager: Node = null

# Test Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	
	# Initialize event manager
	var event_manager_instance = BattleEventTypes.new()
	if not event_manager_instance:
		push_error("Failed to create event manager instance")
		return
		
	# Check if BattleEventTypes inherits from Node
	if event_manager_instance is Node:
		_event_manager = event_manager_instance
	else:
		# If it's not a Node, create a wrapper node
		_event_manager = Node.new()
		_event_manager.set_script(BattleEventTypes)
		
	if not _event_manager:
		push_error("Failed to create event manager")
		return
		
	add_child_autofree(_event_manager)
	track_test_node(_event_manager)
	
	watch_signals(_event_manager)
	await stabilize_engine(STABILIZE_TIME)

func after_each() -> void:
	_event_manager = null
	await super.after_each()

# Event Definition Tests
func test_battle_event_definitions() -> void:
	var events: Dictionary = TypeSafeMixin._call_node_method_dict(_event_manager, "get_battle_events", [])
	assert_not_null(events, "Battle events should be defined")
	assert_true(events.has("CRITICAL_HIT"), "Should have critical hit event")
	assert_true(events.has("WEAPON_JAM"), "Should have weapon jam event")
	assert_true(events.has("TAKE_COVER"), "Should have take cover event")

func test_critical_hit_event() -> void:
	var event: Dictionary = TypeSafeMixin._call_node_method_dict(_event_manager, "get_event", ["CRITICAL_HIT"])
	assert_not_null(event, "Critical hit event should exist")
	assert_eq(event.category, GameEnums.EventCategory.COMBAT, "Should be a combat event")
	assert_eq(event.probability, 0.15, "Should have 15% probability")
	assert_eq(event.effect.type, "damage_multiplier", "Should multiply damage")
	assert_eq(event.effect.value, 2.0, "Should double damage")
	assert_true(event.requirements.has("attack_roll >= 6"), "Should require attack roll >= 6")

func test_weapon_jam_event() -> void:
	var event: Dictionary = TypeSafeMixin._call_node_method_dict(_event_manager, "get_event", ["WEAPON_JAM"])
	assert_not_null(event, "Weapon jam event should exist")
	assert_eq(event.category, GameEnums.EventCategory.EQUIPMENT, "Should be an equipment event")
	assert_eq(event.probability, 0.1, "Should have 10% probability")
	assert_eq(event.effect.type, "disable_weapon", "Should disable weapon")
	assert_eq(event.effect.duration, 1, "Should last 1 turn")
	assert_true(event.requirements.has("has_ranged_weapon"), "Should require ranged weapon")
	assert_true(event.requirements.has("attack_roll <= 1"), "Should require attack roll <= 1")

func test_take_cover_event() -> void:
	var event: Dictionary = TypeSafeMixin._call_node_method_dict(_event_manager, "get_event", ["TAKE_COVER"])
	assert_not_null(event, "Take cover event should exist")
	assert_eq(event.category, GameEnums.EventCategory.TACTICAL, "Should be a tactical event")
	assert_eq(event.probability, 0.2, "Should have 20% probability")
	assert_eq(event.effect.type, "defense_bonus", "Should give defense bonus")
	assert_eq(event.effect.value, 2, "Should give +2 defense")
	assert_eq(event.effect.duration, 1, "Should last 1 turn")
	assert_true(event.requirements.has("near_cover"), "Should require nearby cover")

# Requirement Checking Tests
func test_check_event_requirements() -> void:
	# Test critical hit requirements
	var critical_context := {"attack_roll": 6}
	var critical_result: bool = TypeSafeMixin._call_node_method_bool(_event_manager, "check_event_requirements", ["CRITICAL_HIT", critical_context])
	assert_true(critical_result, "Should allow critical hit with roll of 6")
	
	critical_context.attack_roll = 5
	critical_result = TypeSafeMixin._call_node_method_bool(_event_manager, "check_event_requirements", ["CRITICAL_HIT", critical_context])
	assert_false(critical_result, "Should not allow critical hit with roll of 5")
	
	# Test weapon jam requirements
	var jam_context := {"has_ranged_weapon": true, "attack_roll": 1}
	var jam_result: bool = TypeSafeMixin._call_node_method_bool(_event_manager, "check_event_requirements", ["WEAPON_JAM", jam_context])
	assert_true(jam_result, "Should allow weapon jam with ranged weapon and roll of 1")
	
	jam_context.has_ranged_weapon = false
	jam_result = TypeSafeMixin._call_node_method_bool(_event_manager, "check_event_requirements", ["WEAPON_JAM", jam_context])
	assert_false(jam_result, "Should not allow weapon jam without ranged weapon")
	
	# Test take cover requirements
	var cover_context := {"near_cover": true}
	var cover_result: bool = TypeSafeMixin._call_node_method_bool(_event_manager, "check_event_requirements", ["TAKE_COVER", cover_context])
	assert_true(cover_result, "Should allow taking cover when near cover")
	
	cover_context.near_cover = false
	cover_result = TypeSafeMixin._call_node_method_bool(_event_manager, "check_event_requirements", ["TAKE_COVER", cover_context])
	assert_false(cover_result, "Should not allow taking cover when not near cover")

# Value Comparison Tests
func test_compare_value() -> void:
	var compare_result: bool
	
	compare_result = TypeSafeMixin._call_node_method_bool(_event_manager, "compare_value", [6, ">=", 6])
	assert_true(compare_result, "6 should be >= 6")
	
	compare_result = TypeSafeMixin._call_node_method_bool(_event_manager, "compare_value", [7, ">=", 6])
	assert_true(compare_result, "7 should be >= 6")
	
	compare_result = TypeSafeMixin._call_node_method_bool(_event_manager, "compare_value", [5, ">=", 6])
	assert_false(compare_result, "5 should not be >= 6")
	
	compare_result = TypeSafeMixin._call_node_method_bool(_event_manager, "compare_value", [1, "<=", 1])
	assert_true(compare_result, "1 should be <= 1")
	
	compare_result = TypeSafeMixin._call_node_method_bool(_event_manager, "compare_value", [0, "<=", 1])
	assert_true(compare_result, "0 should be <= 1")
	
	compare_result = TypeSafeMixin._call_node_method_bool(_event_manager, "compare_value", [2, "<=", 1])
	assert_false(compare_result, "2 should not be <= 1")

# Error Handling Tests
func test_invalid_event_handling() -> void:
	var result: Dictionary = TypeSafeMixin._call_node_method_dict(_event_manager, "get_event", ["INVALID_EVENT"])
	assert_null(result, "Should handle invalid event gracefully")
	
	var check_result: bool = TypeSafeMixin._call_node_method_bool(_event_manager, "check_event_requirements", ["INVALID_EVENT", {}])
	assert_false(check_result, "Should handle invalid event requirements gracefully")

# Performance Tests
func test_event_processing_performance() -> void:
	var start_time := Time.get_ticks_msec()
	var context := {"attack_roll": 6, "has_ranged_weapon": true, "near_cover": true}
	
	for i in range(1000):
		TypeSafeMixin._call_node_method_bool(_event_manager, "check_event_requirements", ["CRITICAL_HIT", context])
		TypeSafeMixin._call_node_method_bool(_event_manager, "check_event_requirements", ["WEAPON_JAM", context])
		TypeSafeMixin._call_node_method_bool(_event_manager, "check_event_requirements", ["TAKE_COVER", context])
	
	var duration := Time.get_ticks_msec() - start_time
	assert_true(duration < 1000, "Should process 3000 event checks within 1 second")
