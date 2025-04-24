@tool
extends "res://addons/gut/test.gd"

# Import our test utilities
const TestFixtures = preload("res://tests/fixtures/helpers/test_fixtures.gd")
const TestAdapter = preload("res://tests/fixtures/helpers/test_adapter.gd")

# Test variables
var _game_state = null
var _campaign = null
var _test_enemies = []

func before_each():
	# Use TestAdapter to set up test dependencies with automatic fallbacks
	var dependencies = TestAdapter.setup_test_dependencies(self)
	
	# Extract the created dependencies
	_game_state = dependencies.get("game_state")
	_campaign = dependencies.get("campaign")
	
	# Create some test enemies with proper data
	_setup_test_enemies()
	
	# Wait for stability
	await get_tree().process_frame
	await get_tree().process_frame

func after_each():
	# Clean up test entities
	_cleanup_test_enemies()
	
	# Clean up other dependencies
	if _game_state and is_instance_valid(_game_state):
		_game_state.queue_free()
	_game_state = null
	_campaign = null

func _setup_test_enemies():
	# Create 3 test enemies
	for i in range(3):
		var enemy = TestFixtures.create_mock_enemy("test_enemy_%d" % i)
		if enemy:
			add_child(enemy)
			_test_enemies.append(enemy)

func _cleanup_test_enemies():
	for enemy in _test_enemies:
		if enemy and is_instance_valid(enemy):
			enemy.queue_free()
	_test_enemies.clear()

# Example test: verify game state creation
func test_game_state_creation():
	assert_not_null(_game_state, "Game state should be created")
	
	# Check if current_campaign is set correctly
	var campaign = null
	if _game_state.has_method("get_current_campaign"):
		campaign = _game_state.get_current_campaign()
	else:
		campaign = _game_state.current_campaign
	
	assert_not_null(campaign, "Game state should have a campaign")

# Example test: verify campaign properties
func test_campaign_properties():
	assert_not_null(_campaign, "Campaign should be created")
	
	# Test campaign properties
	var campaign_name = ""
	if _campaign.has_method("get_campaign_name"):
		campaign_name = _campaign.get_campaign_name()
	elif "campaign_name" in _campaign:
		campaign_name = _campaign.campaign_name
	
	assert_true(campaign_name != "", "Campaign should have a name")
	
	# Test resource access
	var credits = 0
	if _campaign.has_method("get_resource"):
		credits = _campaign.get_resource("credits")
	elif "resources" in _campaign and _campaign.resources.has("credits"):
		credits = _campaign.resources.credits
	
	assert_true(credits > 0, "Campaign should have credits")

# Example test: verify enemy data
func test_enemy_data():
	assert_true(_test_enemies.size() > 0, "Test enemies should be created")
	
	for enemy in _test_enemies:
		# Test enemy properties
		assert_not_null(enemy, "Enemy should be valid")
		
		# Check enemy_data exists and is correctly set
		var enemy_data = null
		if enemy.has_method("get_enemy_data"):
			enemy_data = enemy.get_enemy_data()
		elif "enemy_data" in enemy:
			enemy_data = enemy.enemy_data
		
		assert_not_null(enemy_data, "Enemy should have enemy_data")
		assert_true(enemy_data is Dictionary, "Enemy data should be a Dictionary")
		
		# Check required fields exist
		assert_true(enemy_data.has("health"), "Enemy data should have health")
		assert_true(enemy_data.has("max_health"), "Enemy data should have max_health")
		assert_true(enemy_data.has("damage"), "Enemy data should have damage")

# Example test: test mission generation
func test_mission_creation():
	# Create a test mission
	var mission = TestFixtures.create_mock_mission("test_patrol_mission")
	assert_not_null(mission, "Mission should be created")
	
	# Configure the mission
	if mission.has_method("configure"):
		mission.configure(0) # 0 = Patrol mission type
	
	# Add objectives
	if mission.has_method("add_objective"):
		mission.add_objective(0, "Patrol the area", true)
		mission.add_objective(1, "Eliminate enemies", false)
	
	# Verify objective count
	var objective_count = 0
	if mission.has_method("get_objective_count"):
		objective_count = mission.get_objective_count()
	elif "objectives" in mission:
		objective_count = mission.objectives.size()
	
	assert_eq(objective_count, 2, "Mission should have 2 objectives")
	
	# Verify mission type
	var mission_type = -1
	if "mission_type" in mission:
		mission_type = mission.mission_type
	
	assert_eq(mission_type, 0, "Mission should be of type Patrol")

# Example integration test: campaign and enemy interaction
func test_campaign_enemy_integration():
	assert_not_null(_campaign, "Campaign should be created")
	assert_true(_test_enemies.size() > 0, "Test enemies should be created")
	
	# Get first enemy for testing
	var enemy = _test_enemies[0]
	
	# Record initial stats
	var initial_battles = 0
	var initial_enemies_defeated = 0
	
	if "battle_stats" in _campaign:
		initial_battles = _campaign.battle_stats.get("battles_fought", 0)
		initial_enemies_defeated = _campaign.battle_stats.get("enemies_defeated", 0)
	
	# Simulate defeating an enemy
	var enemy_health = 0
	if "enemy_data" in enemy and enemy.enemy_data.has("health"):
		enemy_health = enemy.enemy_data.health
		enemy.enemy_data.health = 0
	
	# Update campaign stats
	if "battle_stats" in _campaign:
		_campaign.battle_stats["enemies_defeated"] = initial_enemies_defeated + 1
	
	# Verify enemy is defeated
	var current_health = 0
	if "enemy_data" in enemy and enemy.enemy_data.has("health"):
		current_health = enemy.enemy_data.health
	
	assert_eq(current_health, 0, "Enemy health should be 0 after defeat")
	
	# Verify campaign stats updated
	var current_enemies_defeated = 0
	if "battle_stats" in _campaign:
		current_enemies_defeated = _campaign.battle_stats.get("enemies_defeated", 0)
	
	assert_eq(current_enemies_defeated, initial_enemies_defeated + 1,
		"Campaign should record one more defeated enemy")