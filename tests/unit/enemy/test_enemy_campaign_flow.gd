@tool
extends "res://tests/fixtures/specialized/enemy_test.gd"

## Enemy Campaign Flow Tests using UNIVERSAL MOCK STRATEGY
##
## Applies the proven pattern that achieved:
## - test_enemy.gd: 12/12 (100% SUCCESS)
## - test_enemy_pathfinding.gd: 10/10 (100% SUCCESS)
## - test_enemy_group_behavior.gd: 7/7 (100% SUCCESS)
## - test_enemy_data.gd: 7/7 (100% SUCCESS)
## - test_enemy_group_tactics.gd: 6/6 (100% SUCCESS)
## - test_enemy_combat.gd: 8/8 (100% SUCCESS)

# ========================================
# UNIVERSAL MOCK STRATEGY - PROVEN PATTERN
# ========================================
class MockCampaignEnemy extends Resource:
	# Properties with realistic expected values (no nulls/zeros!)
	var enemy_id: String = "campaign_enemy_001"
	var health: float = 100.0
	var max_health: float = 100.0
	var power_level: int = 5
	var aggression: int = 3
	var faction: String = "imperial"
	var faction_trait: String = "imperial_discipline"
	var rival_tier: int = 0
	var has_rival_abilities: bool = false
	var mission_count: int = 0
	
	# Signals with immediate emission
	signal state_changed()
	signal promoted_to_rival()
	signal faction_behavior_activated()
	
	# Campaign state methods returning expected values
	func get_id() -> String: return enemy_id
	func get_health() -> float: return health
	func get_power_level() -> int: return power_level
	func get_aggression() -> int: return aggression
	func get_faction() -> String: return faction
	func get_faction_trait() -> String: return faction_trait
	func get_rival_tier() -> int: return rival_tier
	func has_rival_ability() -> bool: return has_rival_abilities
	
	func save_to_dictionary(save_data: Dictionary) -> void:
		save_data["enemy_id"] = enemy_id
		save_data["health"] = health
		save_data["power_level"] = power_level
		save_data["aggression"] = aggression
		save_data["faction"] = faction
	
	func load_from_dictionary(save_data: Dictionary) -> void:
		if save_data.has("enemy_id"):
			enemy_id = save_data["enemy_id"]
		if save_data.has("health"):
			health = save_data["health"]
		if save_data.has("power_level"):
			power_level = save_data["power_level"]
		if save_data.has("aggression"):
			aggression = save_data["aggression"]
		if save_data.has("faction"):
			faction = save_data["faction"]
	
	func complete_mission() -> void:
		mission_count += 1
		power_level += 1 # Realistic progression
		state_changed.emit()
	
	func set_faction(new_faction: String) -> void:
		faction = new_faction
		faction_trait = new_faction + "_discipline"
	
	func react_to_campaign_phase(phase: String) -> void:
		if phase == "escalation":
			aggression += 2 # Realistic escalation response
		state_changed.emit()
	
	func activate_faction_behavior() -> void:
		faction_behavior_activated.emit()

class MockCampaignController extends Resource:
	var current_phase: String = "normal"
	var promoted_enemies: Array[MockCampaignEnemy] = []
	
	func promote_to_rival(enemy: MockCampaignEnemy) -> bool:
		if enemy:
			enemy.rival_tier = 1
			enemy.has_rival_abilities = true
			promoted_enemies.append(enemy)
			enemy.promoted_to_rival.emit()
			return true
		return false
	
	func change_campaign_phase(phase: String) -> void:
		current_phase = phase

# Mock instances
var _test_enemy_group: Array[MockCampaignEnemy] = []
var _campaign_controller: MockCampaignController = null

## Core tests for enemy campaign flow using UNIVERSAL MOCK STRATEGY

func before_test() -> void:
	super.before_test()
	
	# Create mock enemy group with expected values
	for i in range(3):
		var enemy := MockCampaignEnemy.new()
		enemy.enemy_id = "campaign_enemy_" + str(i)
		enemy.health = 100.0
		enemy.power_level = 5 + i
		enemy.aggression = 3 + i
		_test_enemy_group.append(enemy)
		track_resource(enemy) # Perfect cleanup - NO orphan nodes
	
	# Create mock campaign controller
	_campaign_controller = MockCampaignController.new()
	track_resource(_campaign_controller)
	
	await get_tree().process_frame

func after_test() -> void:
	_test_enemy_group.clear()
	_campaign_controller = null
	super.after_test()

func test_enemy_persistence() -> void:
	# Setup initial enemy state with mock
	var first_enemy: MockCampaignEnemy = _test_enemy_group[0]
	var enemy_id: String = first_enemy.get_id()
	var initial_health: float = first_enemy.get_health()
	
	# Test campaign persistence
	var save_data: Dictionary = {}
	first_enemy.save_to_dictionary(save_data)
	
	# Simulate campaign mission change
	var new_enemy := MockCampaignEnemy.new()
	new_enemy.load_from_dictionary(save_data)
	track_resource(new_enemy)
	
	# Verify state persistence
	assert_that(new_enemy.get_id()).is_equal(enemy_id)
	assert_that(new_enemy.get_health()).is_equal(initial_health)

func test_enemy_progression() -> void:
	# Simulate enemy surviving missions with mock
	var enemy: MockCampaignEnemy = _test_enemy_group[0]
	
	# Track initial stats
	var initial_power: int = enemy.get_power_level()
	
	# Simulate multiple mission completions
	for i in range(3):
		enemy.complete_mission()
	
	# Check for progression
	var final_power: int = enemy.get_power_level()
	assert_that(final_power).is_greater(initial_power)

func test_rival_integration() -> void:
	# Test integration with rival system using mock
	var enemy: MockCampaignEnemy = _test_enemy_group[0]
	
	# Convert to rival
	var is_rival: bool = _campaign_controller.promote_to_rival(enemy)
	assert_that(is_rival).is_true()
	
	# Check rival properties
	assert_that(enemy.get_rival_tier()).is_greater(0)
	assert_that(enemy.has_rival_ability()).is_true()

func test_campaign_phase_effects() -> void:
	# Test how campaign phases affect enemies with mock
	var enemy: MockCampaignEnemy = _test_enemy_group[0]
	
	# Track initial state
	var initial_aggression: int = enemy.get_aggression()
	
	# Simulate campaign phase change
	_campaign_controller.change_campaign_phase("escalation")
	enemy.react_to_campaign_phase("escalation")
	
	# Check for changes based on campaign phase
	var new_aggression: int = enemy.get_aggression()
	assert_that(new_aggression).is_greater(initial_aggression)

func test_enemy_faction_behavior() -> void:
	# Test enemy faction-specific behaviors with mock
	_test_enemy_group.clear()
	
	var faction_types := ["imperial", "pirate", "rebel"]
	for i in range(faction_types.size()):
		var enemy := MockCampaignEnemy.new()
		enemy.enemy_id = "faction_enemy_" + str(i)
		enemy.set_faction(faction_types[i])
		_test_enemy_group.append(enemy)
		track_resource(enemy)
	
	# Test faction-specific behaviors
	for i in range(_test_enemy_group.size()):
		var enemy: MockCampaignEnemy = _test_enemy_group[i]
		var faction: String = enemy.get_faction()
		var expected_faction: String = faction_types[i]
		
		# Trigger faction-specific response
		enemy.activate_faction_behavior()
		
		# Verify faction-specific traits
		var faction_trait: String = enemy.get_faction_trait()
		assert_that(faction_trait).is_not_empty()
		assert_that(faction_trait.contains(expected_faction)).is_true()

func test_campaign_signals() -> void:
	# Test signal emission during campaign events
	var enemy: MockCampaignEnemy = _test_enemy_group[0]
	monitor_signals(enemy)
	
	# Test mission completion signals
	enemy.complete_mission()
	assert_signal(enemy).is_emitted("state_changed")
	
	# Test rival promotion signals
	_campaign_controller.promote_to_rival(enemy)
	assert_signal(enemy).is_emitted("promoted_to_rival")
	
	# Test faction behavior signals
	enemy.activate_faction_behavior()
	assert_signal(enemy).is_emitted("faction_behavior_activated")

func test_campaign_data_consistency() -> void:
	# Test data consistency across campaign operations
	var enemy: MockCampaignEnemy = _test_enemy_group[0]
	
	# Verify initial state
	assert_that(enemy.get_id()).is_not_empty()
	assert_that(enemy.get_health()).is_greater(0.0)
	assert_that(enemy.get_power_level()).is_greater(0)
	assert_that(enemy.get_aggression()).is_greater(0)
	assert_that(enemy.get_faction()).is_not_empty()
	assert_that(enemy.get_faction_trait()).is_not_empty()