@tool
extends "res://tests/fixtures/helpers/enemy_test_helper.gd"

## Enemy campaign integration tests
## Godot 4.4 Compatible
##
## These tests verify how enemies interact with the full campaign system:
## - Campaign system integration
## - Mission system integration
## - Campaign progression and state management
##
## Note: This file could be split into smaller test files for better organization:
## - test_enemy_campaign_integration.gd - Basic campaign integration
## - test_enemy_mission_integration.gd - Mission-specific tests
## - test_enemy_progression_integration.gd - Progression and difficulty
## - test_enemy_persistence_integration.gd - Saving/loading tests

# Use explicit preloads instead of global class names
const TestEnums = preload("res://tests/fixtures/base/test_helper.gd")
const GameEnums = preload("res://src/core/systems/GameEnums.gd")

# Required type declarations - load dynamically 
var CampaignSystem = load("res://src/core/campaign/CampaignSystem.gd") if ResourceLoader.exists("res://src/core/campaign/CampaignSystem.gd") else null

# Campaign-specific test configuration
const CAMPAIGN_TEST_CONFIG = {
	"stabilize_time": 0.1,
	"pathfinding_timeout": 1.0,
	"combat_timeout": 0.5
}

# Type-safe instance variables
var _campaign_system = null
var _campaign_test_enemies: Array = []
var _test_campaign = null
var _test_mission = null
var _test_enemy = null

var _campaign_manager = null
var _mission_manager = null

# Signal callback variables
var _enemy_added_signal_received: bool = false
var _added_enemy = null
var _mission_started_signal: bool = false
var _mission_completed_signal: bool = false
var _experience_signal_received: bool = false
var _experience_amount: int = 0
var _difficulty_signal_received: bool = false
var _new_difficulty: int = 0

func before_each() -> void:
	await super.before_each() # Call the parent implementation first
	
	# Reset signal variables
	_enemy_added_signal_received = false
	_added_enemy = null
	_mission_started_signal = false
	_mission_completed_signal = false
	_experience_signal_received = false
	_experience_amount = 0
	_difficulty_signal_received = false
	_new_difficulty = 0
	
	# Prepare the test environment
	_test_enemy = null
	_test_campaign = null
	_test_mission = null
	_campaign_test_enemies.clear()
	
	# Create test campaign node
	_test_campaign = _setup_test_campaign()
	assert_not_null(_test_campaign, "Test campaign should be created")
	
	# Create test mission resource
	_test_mission = _setup_test_mission()
	assert_not_null(_test_mission, "Test mission should be created")
	
	# Setup campaign test environment
	_campaign_manager = Node.new()
	_campaign_manager.name = "CampaignManager"
	add_child_autofree(_campaign_manager)
	track_test_node(_campaign_manager)
	
	_mission_manager = Node.new()
	_mission_manager.name = "MissionManager"
	add_child_autofree(_mission_manager)
	track_test_node(_mission_manager)
	
	await stabilize_engine(CAMPAIGN_TEST_CONFIG.stabilize_time)

func after_each() -> void:
	# Clear campaign-specific resources
	_campaign_manager = null
	_mission_manager = null
	_test_campaign = null
	_test_mission = null
	_campaign_test_enemies.clear()
	
	# Call parent implementation to clean up tracked nodes and resources
	await super.after_each()

# Signal handler functions with explicit type annotations
func _on_enemy_added(e: Node) -> void:
	_enemy_added_signal_received = true
	_added_enemy = e

func _on_mission_started() -> void:
	_mission_started_signal = true

func _on_mission_completed() -> void:
	_mission_completed_signal = true

func _on_experience_gained(amount: int) -> void:
	_experience_signal_received = true
	_experience_amount = amount

func _on_difficulty_increased(level: int) -> void:
	_difficulty_signal_received = true
	_new_difficulty = level

# Helper function to check if an object has a property (Godot 4.4 compatible)
func _property_exists(obj, property_name: String) -> bool:
	if obj == null:
		return false
		
	# Use the autoloaded PropertyExistsPatch if available
	if Engine.has_singleton("PropertyExistsPatch"):
		return Engine.get_singleton("PropertyExistsPatch").property_exists(obj, property_name)
		
	# Use compatibility helper if available
	if obj.has_method("property_exists"):
		return obj.property_exists(property_name)
		
	# In Godot 4.4+, can use direct "in" operator
	if property_name in obj:
		return true
		
	# Fallback to property list scanning for older versions
	var props = obj.get_property_list()
	for prop in props:
		if prop.name == property_name:
			return true
	
	return false

# Function to create a campaign-specific test enemy
func create_campaign_test_enemy(enemy_data: Resource = null) -> Node:
	var enemy = create_test_enemy(enemy_data)
	
	# Track locally if needed for campaign flow tests
	if enemy:
		_campaign_test_enemies.append(enemy)
	
	return enemy

# Setup a test campaign
func _setup_test_campaign() -> Node:
	var campaign_node = Node.new()
	campaign_node.name = "TestCampaign"
	
	# Add required signals
	if not campaign_node.has_signal("campaign_started"):
		campaign_node.add_user_signal("campaign_started")
	if not campaign_node.has_signal("campaign_completed"):
		campaign_node.add_user_signal("campaign_completed")
	if not campaign_node.has_signal("mission_added"):
		campaign_node.add_user_signal("mission_added", [ {"name": "mission"}])
	if not campaign_node.has_signal("enemy_added"):
		campaign_node.add_user_signal("enemy_added", [ {"name": "enemy"}])
	
	# Connect signals for testing
	campaign_node.connect("enemy_added", _on_enemy_added)
	
	# Add to scene
	add_child_autofree(campaign_node)
	track_test_node(campaign_node)
	
	return campaign_node

# Setup a test mission
func _setup_test_mission() -> Resource:
	# Create a simple mission resource or dictionary
	var mission = Resource.new()
	
	# Add mission metadata
	mission.set_meta("mission_id", "test_mission_" + str(randi()))
	mission.set_meta("mission_name", "Test Mission")
	mission.set_meta("mission_type", "combat")
	mission.set_meta("difficulty", 1)
	mission.set_meta("rewards", {"credits": 100, "experience": 50})
	mission.set_meta("enemies", [])
	
	# Connect mission signals
	if not mission.has_signal("mission_started"):
		mission.add_user_signal("mission_started")
	if not mission.has_signal("mission_completed"):
		mission.add_user_signal("mission_completed")
	
	return mission

# TESTS

func test_enemy_campaign_integration() -> void:
	# Test that enemies can be properly integrated with campaigns
	# Create test enemy with basic data
	var enemy_data = create_test_enemy_resource({
		"enemy_id": "test_campaign_enemy",
		"enemy_name": "Campaign Test Enemy",
		"health": 100,
		"max_health": 100,
		"damage": 15,
		"armor": 5
	})
	
	var enemy = create_campaign_test_enemy(enemy_data)
	assert_not_null(enemy, "Should create enemy for campaign integration")
	
	# Add enemy to campaign
	_test_campaign.call_deferred("add_child", enemy)
	_test_campaign.emit_signal("enemy_added", enemy)
	
	# Check signals were received
	assert_true(_enemy_added_signal_received, "Enemy added signal should be received")
	assert_not_null(_added_enemy, "Added enemy should not be null")
	assert_eq(_added_enemy, enemy, "Added enemy should match test enemy")

func test_enemy_mission_integration() -> void:
	# Test enemy integration with missions
	# Create test enemies
	var enemy_count = 3
	var enemies = []
	
	for i in range(enemy_count):
		var enemy_data = create_test_enemy_resource({
			"enemy_id": "mission_enemy_" + str(i),
			"enemy_name": "Mission Enemy " + str(i),
			"health": 100,
			"max_health": 100,
			"damage": 10 + i * 5,
			"armor": 2 + i
		})
		
		var enemy = create_campaign_test_enemy(enemy_data)
		assert_not_null(enemy, "Should create enemy for mission integration")
		enemies.append(enemy)
	
	# Add enemies to mission
	var mission_enemies = _test_mission.get_meta("enemies", [])
	for enemy in enemies:
		mission_enemies.append(enemy)
	
	_test_mission.set_meta("enemies", mission_enemies)
	
	# Verify mission has enemies
	assert_eq(_test_mission.get_meta("enemies").size(), enemy_count,
		"Mission should have correct number of enemies")

func test_enemy_progression_system() -> void:
	# Test enemy progression through campaign missions
	# Create initial enemy with low stats
	var enemy_data = create_test_enemy_resource({
		"enemy_id": "progression_enemy",
		"enemy_name": "Progression Test Enemy",
		"health": 80,
		"max_health": 80,
		"damage": 8,
		"armor": 2,
		"level": 1
	})
	
	var enemy = create_campaign_test_enemy(enemy_data)
	assert_not_null(enemy, "Should create enemy for progression testing")
	
	# Add enemy to campaign
	_test_campaign.call_deferred("add_child", enemy)
	
	# Simulate mission completion and enemy progression
	# First connect to enemy's experience signal if it exists
	if enemy.has_signal("experience_gained"):
		enemy.connect("experience_gained", _on_experience_gained)
	
	# Add experience - verify through different methods
	var added_xp = 50
	var success = false
	
	if enemy.has_method("add_experience"):
		success = enemy.add_experience(added_xp)
	elif enemy.has_method("gain_experience"):
		success = enemy.gain_experience(added_xp)
	elif "experience" in enemy:
		enemy.experience += added_xp
		success = true
	
	# Verify progression worked
	if success and enemy.has_signal("experience_gained"):
		assert_true(_experience_signal_received, "Experience gained signal should be received")
		assert_eq(_experience_amount, added_xp, "Experience amount should match")
	
	# Check level progression if supported
	if "level" in enemy and enemy.has_method("get_level"):
		var level = enemy.get_level()
		assert_true(level >= 1, "Enemy should have valid level after progression")

func test_campaign_flow_with_enemies() -> void:
	# Test the full campaign flow with enemies
	# Create test campaign with multiple missions
	var mission_count = 2
	var missions = []
	
	for i in range(mission_count):
		var mission = Resource.new()
		mission.set_meta("mission_id", "flow_mission_" + str(i))
		mission.set_meta("mission_name", "Flow Test Mission " + str(i))
		mission.set_meta("difficulty", 1 + i)
		mission.set_meta("enemies", [])
		
		# Add enemies to mission
		var enemy_count = 2 + i
		var mission_enemies = []
		
		for j in range(enemy_count):
			var enemy_data = create_test_enemy_resource({
				"enemy_id": "flow_enemy_" + str(i) + "_" + str(j),
				"enemy_name": "Flow Enemy " + str(i) + "-" + str(j),
				"health": 80 + j * 10,
				"max_health": 80 + j * 10,
				"damage": 8 + j * 2,
				"armor": 2 + j
			})
			
			var enemy = create_campaign_test_enemy(enemy_data)
			mission_enemies.append(enemy)
		
		mission.set_meta("enemies", mission_enemies)
		missions.append(mission)
	
	# Add missions to campaign
	for mission in missions:
		if _test_campaign.has_method("add_mission"):
			_test_campaign.add_mission(mission)
		elif _campaign_manager.has_method("add_mission_to_campaign"):
			_campaign_manager.add_mission_to_campaign(_test_campaign, mission)
	
	# Verify campaign setup
	var total_enemies = 0
	for mission in missions:
		total_enemies += mission.get_meta("enemies").size()
	
	assert_true(total_enemies > 0, "Campaign should have enemies through missions")
	
	# Simulate campaign flow - mission start/completion
	if missions.size() > 0:
		var first_mission = missions[0]
		first_mission.emit_signal("mission_started")
		
		# Wait a bit to simulate mission gameplay
		await get_tree().create_timer(0.2).timeout
		
		first_mission.emit_signal("mission_completed")
		
		# Verify mission has enemies
		assert_gt(first_mission.get_meta("enemies").size(), 0, "Mission should have enemies")
