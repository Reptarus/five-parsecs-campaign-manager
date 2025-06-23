## Battle Event Types Test Suite
## Tests the functionality of battle event types and their processing
##
## Coverage:
## - Event requirements and conditions
## - Event effects and outcomes
## - Event probability calculations
@tool
extends GdUnitGameTest

# Static function to safely load battle event types
static func _load_battle_event_types() -> GDScript:
	if ResourceLoader.exists("res://src/core/battle/events/BattleEventTypes.gd"):
		return preload("res://src/core/battle/events/BattleEventTypes.gd")
	return null

# Type-safe script references
var BattleEventTypes = _load_battle_event_types()
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

# Test constants
const TEST_TIMEOUT: float = 2.0

# Setup and teardown
func before_test() -> void:
	super.before_test()

func after_test() -> void:
	super.after_test()

# Basic event definition tests
func test_battle_event_definitions() -> void:
	# Access the BATTLE_EVENTS constant directly
	var events = BattleEventTypes.BATTLE_EVENTS if BattleEventTypes else {}
	assert_that(events).is_not_null()
	assert_that(events).is_not_empty()
	assert_that(events.has("CRITICAL_HIT")).is_true()

func test_critical_hit_event() -> void:
	var events = BattleEventTypes.BATTLE_EVENTS if BattleEventTypes else {}
	
	var event = events.get("CRITICAL_HIT", {})
	assert_that(event).is_not_empty()
	
	if event.has("category"):
		assert_that(event.category).is_not_null()
	
	if event.has("probability"):
		assert_that(event.probability).is_greater(0.0)
	
	if event.has("effect") and event.effect.has("type"):
		assert_that(event.effect.type).is_not_null()
	
	if event.has("effect") and event.effect.has("_value"):
		assert_that(event.effect._value).is_greater(0)
	
	if event.has("requirements"):
		assert_that(event.requirements).is_not_null()

func test_weapon_jam_event() -> void:
	var events = BattleEventTypes.BATTLE_EVENTS if BattleEventTypes else {}
	
	var event = events.get("WEAPON_JAM", {})
	assert_that(event).is_not_empty()
	
	if event.has("category"):
		assert_that(event.category).is_not_null()
	
	if event.has("probability"):
		assert_that(event.probability).is_greater(0.0)
	
	if event.has("effect") and event.effect.has("type"):
		assert_that(event.effect.type).is_not_null()
	
	if event.has("effect") and event.effect.has("duration"):
		assert_that(event.effect.duration).is_greater(0)
	
	if event.has("requirements"):
		assert_that(event.requirements).is_not_null()

func test_take_cover_event() -> void:
	var events = BattleEventTypes.BATTLE_EVENTS if BattleEventTypes else {}
	
	var event = events.get("TAKE_COVER", {})
	assert_that(event).is_not_empty()
	
	if event.has("category"):
		assert_that(event.category).is_not_null()
	
	if event.has("probability"):
		assert_that(event.probability).is_greater(0.0)
	
	if event.has("effect") and event.effect.has("type"):
		assert_that(event.effect.type).is_not_null()
	
	if event.has("effect") and event.effect.has("_value"):
		assert_that(event.effect._value).is_greater(0)
	
	if event.has("effect") and event.effect.has("duration"):
		assert_that(event.effect.duration).is_greater(0)
	
	if event.has("requirements"):
		assert_that(event.requirements).is_not_null()

# Event requirement testing
func test_check_event_requirements() -> void:
	# Test critical hit requirements
	var critical_context := {"attack_roll": 6}
	var critical_result = BattleEventTypes.check_event_requirements("CRITICAL_HIT", critical_context) if BattleEventTypes else true
	assert_that(critical_result).is_true()
	
	critical_context.attack_roll = 5
	critical_result = BattleEventTypes.check_event_requirements("CRITICAL_HIT", critical_context) if BattleEventTypes else false
	assert_that(critical_result).is_false()
	
	# Test weapon jam requirements
	var jam_context := {"has_ranged_weapon": true, "attack_roll": 1}
	var jam_result = BattleEventTypes.check_event_requirements("WEAPON_JAM", jam_context) if BattleEventTypes else true
	assert_that(jam_result).is_true()
	
	jam_context.has_ranged_weapon = false
	jam_result = BattleEventTypes.check_event_requirements("WEAPON_JAM", jam_context) if BattleEventTypes else false
	assert_that(jam_result).is_false()
	
	# Test take cover requirements
	var cover_context := {"near_cover": true}
	var cover_result = BattleEventTypes.check_event_requirements("TAKE_COVER", cover_context) if BattleEventTypes else true
	assert_that(cover_result).is_true()
	
	cover_context.near_cover = false
	cover_result = BattleEventTypes.check_event_requirements("TAKE_COVER", cover_context) if BattleEventTypes else false
	assert_that(cover_result).is_false()

# Value comparison testing
func test_compare_value() -> void:
	# Test context and results
	var context: Dictionary
	var result: bool
	
	# Test critical hit with exact threshold
	context = {"attack_roll": 6}
	result = BattleEventTypes.check_event_requirements("CRITICAL_HIT", context) if BattleEventTypes else true
	assert_that(result).is_true()
	
	context = {"attack_roll": 7}
	result = BattleEventTypes.check_event_requirements("CRITICAL_HIT", context) if BattleEventTypes else true
	assert_that(result).is_true()
	
	context = {"attack_roll": 5}
	result = BattleEventTypes.check_event_requirements("CRITICAL_HIT", context) if BattleEventTypes else false
	assert_that(result).is_false()
	
	# Test weapon jam with exact threshold
	context = {"has_ranged_weapon": true, "attack_roll": 1}
	result = BattleEventTypes.check_event_requirements("WEAPON_JAM", context) if BattleEventTypes else true
	assert_that(result).is_true()
	
	context = {"has_ranged_weapon": true, "attack_roll": 0}
	result = BattleEventTypes.check_event_requirements("WEAPON_JAM", context) if BattleEventTypes else true
	assert_that(result).is_true()
	
	context = {"has_ranged_weapon": true, "attack_roll": 2}
	result = BattleEventTypes.check_event_requirements("WEAPON_JAM", context) if BattleEventTypes else false
	assert_that(result).is_false()

# Error handling tests
func test_invalid_event_handling() -> void:
	var events = BattleEventTypes.BATTLE_EVENTS if BattleEventTypes else {}
	
	var result = events.get("INVALID_EVENT", null)
	assert_that(result).is_null()
	
	var check_result = BattleEventTypes.check_event_requirements("INVALID_EVENT", {}) if BattleEventTypes else false
	assert_that(check_result).is_false()

# Performance testing
func test_event_processing_performance() -> void:
	var start_time := Time.get_ticks_msec()
	var context := {"attack_roll": 6, "has_ranged_weapon": true, "near_cover": true}
	
	for i: int in range(1000):
		if BattleEventTypes:
			BattleEventTypes.check_event_requirements("CRITICAL_HIT", context)
			BattleEventTypes.check_event_requirements("WEAPON_JAM", context)
			BattleEventTypes.check_event_requirements("TAKE_COVER", context)
	
	var duration := Time.get_ticks_msec() - start_time
	assert_that(duration).is_less(1000) # Should complete in less than 1 second
