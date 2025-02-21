@tool
extends FiveParsecsEnemyTest

const TestedClass = preload("res://src/core/battle/events/BattleEventTypes.gd")

# Event Definition Tests
func test_battle_event_definitions() -> void:
	assert_has(TestedClass.BATTLE_EVENTS, "CRITICAL_HIT", "Should have critical hit event")
	assert_has(TestedClass.BATTLE_EVENTS, "WEAPON_JAM", "Should have weapon jam event")
	assert_has(TestedClass.BATTLE_EVENTS, "TAKE_COVER", "Should have take cover event")

func test_critical_hit_event() -> void:
	var event = TestedClass.BATTLE_EVENTS["CRITICAL_HIT"]
	assert_eq(event.category, GameEnums.EventCategory.COMBAT, "Should be a combat event")
	assert_eq(event.probability, 0.15, "Should have 15% probability")
	assert_eq(event.effect.type, "damage_multiplier", "Should multiply damage")
	assert_eq(event.effect.value, 2.0, "Should double damage")
	assert_has(event.requirements, "attack_roll >= 6", "Should require attack roll >= 6")

func test_weapon_jam_event() -> void:
	var event = TestedClass.BATTLE_EVENTS["WEAPON_JAM"]
	assert_eq(event.category, GameEnums.EventCategory.EQUIPMENT, "Should be an equipment event")
	assert_eq(event.probability, 0.1, "Should have 10% probability")
	assert_eq(event.effect.type, "disable_weapon", "Should disable weapon")
	assert_eq(event.effect.duration, 1, "Should last 1 turn")
	assert_has(event.requirements, "has_ranged_weapon", "Should require ranged weapon")
	assert_has(event.requirements, "attack_roll <= 1", "Should require attack roll <= 1")

func test_take_cover_event() -> void:
	var event = TestedClass.BATTLE_EVENTS["TAKE_COVER"]
	assert_eq(event.category, GameEnums.EventCategory.TACTICAL, "Should be a tactical event")
	assert_eq(event.probability, 0.2, "Should have 20% probability")
	assert_eq(event.effect.type, "defense_bonus", "Should give defense bonus")
	assert_eq(event.effect.value, 2, "Should give +2 defense")
	assert_eq(event.effect.duration, 1, "Should last 1 turn")
	assert_has(event.requirements, "near_cover", "Should require nearby cover")

# Requirement Checking Tests
func test_check_event_requirements() -> void:
	# Test critical hit requirements
	var critical_context = {"attack_roll": 6}
	assert_true(TestedClass.check_event_requirements("CRITICAL_HIT", critical_context),
		"Should allow critical hit with roll of 6")
	
	critical_context.attack_roll = 5
	assert_false(TestedClass.check_event_requirements("CRITICAL_HIT", critical_context),
		"Should not allow critical hit with roll of 5")
	
	# Test weapon jam requirements
	var jam_context = {"has_ranged_weapon": true, "attack_roll": 1}
	assert_true(TestedClass.check_event_requirements("WEAPON_JAM", jam_context),
		"Should allow weapon jam with ranged weapon and roll of 1")
	
	jam_context.has_ranged_weapon = false
	assert_false(TestedClass.check_event_requirements("WEAPON_JAM", jam_context),
		"Should not allow weapon jam without ranged weapon")
	
	# Test take cover requirements
	var cover_context = {"near_cover": true}
	assert_true(TestedClass.check_event_requirements("TAKE_COVER", cover_context),
		"Should allow taking cover when near cover")
	
	cover_context.near_cover = false
	assert_false(TestedClass.check_event_requirements("TAKE_COVER", cover_context),
		"Should not allow taking cover when not near cover")

# Value Comparison Tests
func test_compare_value() -> void:
	assert_true(TestedClass._compare_value(6, ">=", 6), "6 should be >= 6")
	assert_true(TestedClass._compare_value(7, ">=", 6), "7 should be >= 6")
	assert_false(TestedClass._compare_value(5, ">=", 6), "5 should not be >= 6")
	
	assert_true(TestedClass._compare_value(1, "<=", 1), "1 should be <= 1")
	assert_true(TestedClass._compare_value(0, "<=", 1), "0 should be <= 1")
	assert_false(TestedClass._compare_value(2, "<=", 1), "2 should not be <= 1")
	
	assert_true(TestedClass._compare_value(7, ">", 6), "7 should be > 6")
	assert_false(TestedClass._compare_value(6, ">", 6), "6 should not be > 6")
	
	assert_true(TestedClass._compare_value(5, "<", 6), "5 should be < 6")
	assert_false(TestedClass._compare_value(6, "<", 6), "6 should not be < 6")
	
	assert_true(TestedClass._compare_value(6, "==", 6), "6 should be == 6")
	assert_false(TestedClass._compare_value(5, "==", 6), "5 should not be == 6")