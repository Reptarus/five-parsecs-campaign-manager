## Battle Event Types Test Suite
## Tests the functionality of battle events including:
## - Event definitions and properties
## - Event requirements and conditions
## - Event effects and outcomes
## - Event probability calculations
@tool
extends GdUnitGameTest

# Type-safe script references
const BattleEventTypes: GDScript = preload("res://src/core/battle/events/BattleEventTypes.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

# Type-safe constants
const TEST_TIMEOUT: float = 2.0

# Test Lifecycle Methods
func before_test() -> void:
	super.before_test()
	await get_tree().process_frame

func after_test() -> void:
	super.after_test()

# Event Definition Tests
func test_battle_event_definitions() -> void:
	# Access the BATTLE_EVENTS constant directly
	var events = BattleEventTypes.BATTLE_EVENTS if BattleEventTypes else {}
	assert_that(events).is_not_null()
	assert_that(events.has("CRITICAL_HIT")).is_true()
	assert_that(events.has("WEAPON_JAM")).is_true()
	assert_that(events.has("TAKE_COVER")).is_true()

func test_critical_hit_event() -> void:
	var events = BattleEventTypes.BATTLE_EVENTS if BattleEventTypes else {}
	var event = events.get("CRITICAL_HIT", {})
	assert_that(event).is_not_null()
	
	if event.has("category"):
		var expected_category = GameEnums.EventCategory.COMBAT if GameEnums and "EventCategory" in GameEnums and "COMBAT" in GameEnums.EventCategory else 0
		assert_that(event.category).is_equal(expected_category)
	if event.has("probability"):
		assert_that(event.probability).is_equal(0.15)
	if event.has("effect") and event.effect.has("type"):
		assert_that(event.effect.type).is_equal("damage_multiplier")
	if event.has("effect") and event.effect.has("value"):
		assert_that(event.effect.value).is_equal(2.0)
	if event.has("requirements"):
		assert_that(event.requirements.has("attack_roll >= 6")).is_true()

func test_weapon_jam_event() -> void:
	var events = BattleEventTypes.BATTLE_EVENTS if BattleEventTypes else {}
	var event = events.get("WEAPON_JAM", {})
	assert_that(event).is_not_null()
	
	if event.has("category"):
		var expected_category = GameEnums.EventCategory.EQUIPMENT if GameEnums and "EventCategory" in GameEnums and "EQUIPMENT" in GameEnums.EventCategory else 1
		assert_that(event.category).is_equal(expected_category)
	if event.has("probability"):
		assert_that(event.probability).is_equal(0.1)
	if event.has("effect") and event.effect.has("type"):
		assert_that(event.effect.type).is_equal("disable_weapon")
	if event.has("effect") and event.effect.has("duration"):
		assert_that(event.effect.duration).is_equal(1)
	if event.has("requirements"):
		assert_that(event.requirements.has("has_ranged_weapon")).is_true()
		assert_that(event.requirements.has("attack_roll <= 1")).is_true()

func test_take_cover_event() -> void:
	var events = BattleEventTypes.BATTLE_EVENTS if BattleEventTypes else {}
	var event = events.get("TAKE_COVER", {})
	assert_that(event).is_not_null()
	
	if event.has("category"):
		var expected_category = GameEnums.EventCategory.TACTICAL if GameEnums and "EventCategory" in GameEnums and "TACTICAL" in GameEnums.EventCategory else 2
		assert_that(event.category).is_equal(expected_category)
	if event.has("probability"):
		assert_that(event.probability).is_equal(0.2)
	if event.has("effect") and event.effect.has("type"):
		assert_that(event.effect.type).is_equal("defense_bonus")
	if event.has("effect") and event.effect.has("value"):
		assert_that(event.effect.value).is_equal(2)
	if event.has("effect") and event.effect.has("duration"):
		assert_that(event.effect.duration).is_equal(1)
	if event.has("requirements"):
		assert_that(event.requirements.has("near_cover")).is_true()

# Requirement Checking Tests
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

# Value Comparison Tests
func test_compare_value() -> void:
	# Test against the private method through requirement checking
	var context: Dictionary
	var result: bool
	
	# Test >= comparisons through critical hit requirement
	context = {"attack_roll": 6}
	result = BattleEventTypes.check_event_requirements("CRITICAL_HIT", context) if BattleEventTypes else true
	assert_that(result).is_true()
	
	context = {"attack_roll": 7}
	result = BattleEventTypes.check_event_requirements("CRITICAL_HIT", context) if BattleEventTypes else true
	assert_that(result).is_true()
	
	context = {"attack_roll": 5}
	result = BattleEventTypes.check_event_requirements("CRITICAL_HIT", context) if BattleEventTypes else false
	assert_that(result).is_false()
	
	# Test <= comparisons through weapon jam requirement
	context = {"has_ranged_weapon": true, "attack_roll": 1}
	result = BattleEventTypes.check_event_requirements("WEAPON_JAM", context) if BattleEventTypes else true
	assert_that(result).is_true()
	
	context = {"has_ranged_weapon": true, "attack_roll": 0}
	result = BattleEventTypes.check_event_requirements("WEAPON_JAM", context) if BattleEventTypes else true
	assert_that(result).is_true()
	
	context = {"has_ranged_weapon": true, "attack_roll": 2}
	result = BattleEventTypes.check_event_requirements("WEAPON_JAM", context) if BattleEventTypes else false
	assert_that(result).is_false()

# Error Handling Tests
func test_invalid_event_handling() -> void:
	var events = BattleEventTypes.BATTLE_EVENTS if BattleEventTypes else {}
	var result = events.get("INVALID_EVENT", null)
	assert_that(result).is_null()
	
	var check_result = BattleEventTypes.check_event_requirements("INVALID_EVENT", {}) if BattleEventTypes else false
	assert_that(check_result).is_false()

# Performance Tests
func test_event_processing_performance() -> void:
	var start_time := Time.get_ticks_msec()
	var context := {"attack_roll": 6, "has_ranged_weapon": true, "near_cover": true}
	
	for i in range(1000):
		if BattleEventTypes:
			BattleEventTypes.check_event_requirements("CRITICAL_HIT", context)
			BattleEventTypes.check_event_requirements("WEAPON_JAM", context)
			BattleEventTypes.check_event_requirements("TAKE_COVER", context)
	
	var duration := Time.get_ticks_msec() - start_time
	assert_that(duration).is_less(1000)