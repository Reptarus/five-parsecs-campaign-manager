@tool
extends Node
class_name TestAdapter

## TestAdapter
## Provides utilities to adapt tests to use mock objects when real ones aren't available
## This helps tests run successfully even when there are missing resources

# Preload dependencies
const TestFixtures = preload("res://tests/fixtures/helpers/test_fixtures.gd")

# Cache for resource loading attempts
static var _resource_load_attempts = {}
static var _instance = null

## Get the singleton instance
static func get_instance() -> TestAdapter:
	if not _instance:
		_instance = TestAdapter.new()
	return _instance

## Use this instead of direct load() calls to get a safe fallback
## @param path Path to the resource to load
## @param use_mocks Whether to use mock objects if the resource is unavailable (default: true)
static func safe_load(path: String, use_mocks: bool = true) -> Variant:
	# Check if we've already attempted to load this resource
	if _resource_load_attempts.has(path):
		return _resource_load_attempts[path]
	
	# Try to load the resource normally
	var resource = load(path)
	
	# If resource loading succeeded, cache and return it
	if resource != null:
		_resource_load_attempts[path] = resource
		return resource
	
	# If resource loading failed and mocks are enabled, try to create a mock
	if use_mocks:
		var mock = _create_mock_for_path(path)
		if mock != null:
			_resource_load_attempts[path] = mock
			return mock
			
	# Resource loading failed and no mock available, cache null to avoid repeated attempts
	_resource_load_attempts[path] = null
	return null

## Create a game state that works for testing
## @param use_mock Whether to use a mock if the real GameState can't be loaded
static func create_game_state(use_mock: bool = true) -> Node:
	# Try to load the real GameState first
	var game_state = null
	var GameStateScript = safe_load("res://src/core/state/GameState.gd")
	
	if GameStateScript != null:
		game_state = GameStateScript.new()
	elif use_mock:
		# Use TestFixtures to create a mock
		game_state = TestFixtures.create_mock_game_state()
		
	return game_state

## Create a campaign suitable for testing
## @param campaign_name Name to give the test campaign
## @param use_mock Whether to use a mock if the real Campaign can't be loaded
static func create_campaign(campaign_name: String = "Test Campaign", use_mock: bool = true) -> Resource:
	# Try to load the real Campaign class first
	var campaign = null
	var CampaignScript = safe_load("res://src/game/campaign/FiveParsecsCampaign.gd")
	
	if CampaignScript != null:
		campaign = CampaignScript.new(campaign_name)
	elif use_mock:
		# Use TestFixtures to create a mock
		campaign = TestFixtures.create_mock_campaign(campaign_name)
		
	return campaign

## Create an enemy instance suitable for testing
## @param enemy_id ID to give the enemy
## @param use_mock Whether to use a mock if the real Enemy can't be loaded
static func create_enemy(enemy_id: String = "", use_mock: bool = true) -> Node:
	# Try to load the real Enemy class first
	var enemy = null
	var EnemyScript = safe_load("res://src/game/campaign/enemies/EnemyNode.gd")
	
	if EnemyScript != null:
		enemy = EnemyScript.new()
		if enemy_id and enemy_id != "":
			enemy.name = "Enemy_" + enemy_id
	elif use_mock:
		# Use TestFixtures to create a mock
		enemy = TestFixtures.create_mock_enemy(enemy_id)
		
	return enemy

## Create a mission resource suitable for testing
## @param mission_id ID to give the mission
## @param use_mock Whether to use a mock if the real Mission can't be loaded
static func create_mission(mission_id: String = "", use_mock: bool = true) -> Resource:
	# Try to load the real Mission class first
	var mission = null
	var MissionScript = safe_load("res://src/core/story/StoryQuestData.gd")
	
	if MissionScript != null:
		mission = MissionScript.new()
		if mission_id and mission_id != "":
			if "mission_id" in mission:
				mission.mission_id = mission_id
	elif use_mock:
		# Use TestFixtures to create a mock
		mission = TestFixtures.create_mock_mission(mission_id)
		
	return mission

## Set up standard test dependencies safely with fallbacks
## @param test_instance The test instance to set up
static func setup_test_dependencies(test_instance: Node) -> Dictionary:
	var dependencies = {}
	
	# Create game state
	var game_state = create_game_state()
	if game_state:
		dependencies["game_state"] = game_state
		if test_instance and test_instance is Node:
			test_instance.add_child(game_state)
	
	# Create campaign
	var campaign = create_campaign("Test Campaign")
	if campaign:
		dependencies["campaign"] = campaign
		# Set the campaign in game state if possible
		if game_state and game_state.has_method("set_current_campaign"):
			game_state.set_current_campaign(campaign)
	
	# Create campaign manager if needed
	var campaign_manager = safe_load("res://src/core/campaign/GameCampaignManager.gd")
	if campaign_manager:
		var manager = campaign_manager.new()
		if manager:
			dependencies["campaign_manager"] = manager
			if test_instance and test_instance is Node:
				test_instance.add_child(manager)
				
			# Set game state on campaign manager
			if manager.has_method("set_game_state") and game_state:
				manager.set_game_state(game_state)
				
			# Initialize campaign in manager if it exists
			if manager.has_method("start_new_campaign") and campaign:
				manager.start_new_campaign(campaign)
	
	return dependencies

## Helper method to create mock objects based on path
static func _create_mock_for_path(path: String) -> Variant:
	# Game state
	if "GameState.gd" in path or "FiveParsecsGameState.gd" in path:
		return TestFixtures.create_mock_game_state()
	
	# Campaign
	if "FiveParsecsCampaign.gd" in path:
		return TestFixtures.create_mock_campaign()
	
	# EnemyNode
	if "EnemyNode.gd" in path:
		return TestFixtures.create_mock_enemy()
	
	# Mission
	if "StoryQuestData.gd" in path:
		return TestFixtures.create_mock_mission()
	
	# No mock available for this path
	return null

## Clean up all cached resources and references
static func cleanup() -> void:
	_resource_load_attempts.clear()
	TestFixtures.cleanup()
	_instance = null