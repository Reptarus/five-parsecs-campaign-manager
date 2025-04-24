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
const BattleEventTypes = preload("res://src/core/battle/events/BattleEventTypes.gd")

# Type-safe constants
const TEST_TIMEOUT: float = 2.0

# Test Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	await stabilize_engine(STABILIZE_TIME)

func after_each() -> void:
	await super.after_each()

# Event Definition Tests
func test_battle_event_definitions() -> void:
	var events = BattleEventTypes.get_battle_events()
	assert_not_null(events, "Battle events should be defined")
	assert_true("CRITICAL_HIT" in events, "Should have critical hit event")
	assert_true("WEAPON_JAM" in events, "Should have weapon jam event")
	assert_true("TAKE_COVER" in events, "Should have take cover event")

func test_critical_hit_event() -> void:
	var event = BattleEventTypes.get_event("CRITICAL_HIT")
	assert_not_null(event, "Critical hit event should exist")
	assert_eq(event["category"], GameEnums.EventCategory.COMBAT, "Should be a combat event")
	assert_eq(event["probability"], 0.15, "Should have 15% probability")
	assert_eq(event["effect"]["type"], "damage_multiplier", "Should multiply damage")
	assert_eq(event["effect"]["value"], 2.0, "Should double damage")
	assert_true(event["requirements"][0] == "attack_roll >= 6", "Should require attack roll >= 6")

func test_weapon_jam_event() -> void:
	var event = BattleEventTypes.get_event("WEAPON_JAM")
	assert_not_null(event, "Weapon jam event should exist")
	assert_eq(event["category"], GameEnums.EventCategory.EQUIPMENT, "Should be an equipment event")
	assert_eq(event["probability"], 0.1, "Should have 10% probability")
	assert_eq(event["effect"]["type"], "disable_weapon", "Should disable weapon")
	assert_eq(event["effect"]["duration"], 1, "Should last 1 turn")
	assert_true(event["requirements"][0] == "has_ranged_weapon", "Should require ranged weapon")
	assert_true(event["requirements"][1] == "attack_roll <= 1", "Should require attack roll <= 1")

func test_take_cover_event() -> void:
	var event = BattleEventTypes.get_event("TAKE_COVER")
	assert_not_null(event, "Take cover event should exist")
	assert_eq(event["category"], GameEnums.EventCategory.TACTICAL, "Should be a tactical event")
	assert_eq(event["probability"], 0.2, "Should have 20% probability")
	assert_eq(event["effect"]["type"], "defense_bonus", "Should give defense bonus")
	assert_eq(event["effect"]["value"], 2, "Should give +2 defense")
	assert_eq(event["effect"]["duration"], 1, "Should last 1 turn")
	assert_true(event["requirements"][0] == "near_cover", "Should require nearby cover")

# Requirement Checking Tests
func test_check_event_requirements() -> void:
	# Test critical hit requirements
	var critical_context := {"attack_roll": 6}
	var critical_result = BattleEventTypes.check_event_requirements("CRITICAL_HIT", critical_context)
	assert_true(critical_result, "Should allow critical hit with roll of 6")
	
	critical_context.attack_roll = 5
	critical_result = BattleEventTypes.check_event_requirements("CRITICAL_HIT", critical_context)
	assert_false(critical_result, "Should not allow critical hit with roll of 5")
	
	# Test weapon jam requirements
	var jam_context := {"has_ranged_weapon": true, "attack_roll": 1}
	var jam_result = BattleEventTypes.check_event_requirements("WEAPON_JAM", jam_context)
	assert_true(jam_result, "Should allow weapon jam with ranged weapon and roll of 1")
	
	jam_context.has_ranged_weapon = false
	jam_result = BattleEventTypes.check_event_requirements("WEAPON_JAM", jam_context)
	assert_false(jam_result, "Should not allow weapon jam without ranged weapon")
	
	# Test take cover requirements
	var cover_context := {"near_cover": true}
	var cover_result = BattleEventTypes.check_event_requirements("TAKE_COVER", cover_context)
	assert_true(cover_result, "Should allow taking cover when near cover")
	
	cover_context.near_cover = false
	cover_result = BattleEventTypes.check_event_requirements("TAKE_COVER", cover_context)
	assert_false(cover_result, "Should not allow taking cover when not near cover")

# Value Comparison Tests
func test_compare_value() -> void:
	var compare_result: bool
	
	compare_result = BattleEventTypes._compare_value(6, ">=", 6)
	assert_true(compare_result, "6 should be >= 6")
	
	compare_result = BattleEventTypes._compare_value(7, ">=", 6)
	assert_true(compare_result, "7 should be >= 6")
	
	compare_result = BattleEventTypes._compare_value(5, ">=", 6)
	assert_false(compare_result, "5 should not be >= 6")
	
	compare_result = BattleEventTypes._compare_value(1, "<=", 1)
	assert_true(compare_result, "1 should be <= 1")
	
	compare_result = BattleEventTypes._compare_value(0, "<=", 1)
	assert_true(compare_result, "0 should be <= 1")
	
	compare_result = BattleEventTypes._compare_value(2, "<=", 1)
	assert_false(compare_result, "2 should not be <= 1")

# Error Handling Tests
func test_invalid_event_handling() -> void:
	var result = BattleEventTypes.get_event("INVALID_EVENT")
	assert_eq(result, {}, "Should return empty dictionary for invalid event")
	
	var check_result = BattleEventTypes.check_event_requirements("INVALID_EVENT", {})
	assert_false(check_result, "Should handle invalid event requirements gracefully")

# Performance Tests
func test_event_processing_performance() -> void:
	var start_time := Time.get_ticks_msec()
	var context := {"attack_roll": 6, "has_ranged_weapon": true, "near_cover": true}
	
	for i in range(1000):
		BattleEventTypes.check_event_requirements("CRITICAL_HIT", context)
		BattleEventTypes.check_event_requirements("WEAPON_JAM", context)
		BattleEventTypes.check_event_requirements("TAKE_COVER", context)
	
	var duration := Time.get_ticks_msec() - start_time
	assert_true(duration < 1000, "Should process 3000 event checks within 1 second")
