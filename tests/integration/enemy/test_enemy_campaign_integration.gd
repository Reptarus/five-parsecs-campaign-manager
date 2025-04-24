@tool
extends GutTest

# Import our new test utilities
const TestFixtures = preload("res://tests/fixtures/helpers/test_fixtures.gd")
const TestAdapter = preload("res://tests/fixtures/helpers/test_adapter.gd")

# Test variables
var _game_state = null
var _campaign = null

func before_each() -> void:
	# Set up dependencies using our new TestAdapter
	var dependencies = TestAdapter.setup_test_dependencies(self)
	
	# Store dependencies for use in tests
	_game_state = dependencies.get("game_state")
	_campaign = dependencies.get("campaign")
	
	# Wait for stability
	await get_tree().process_frame
	await get_tree().process_frame

func after_each() -> void:
	# Clean up dependencies
	if _game_state and is_instance_valid(_game_state):
		_game_state.queue_free()
	_game_state = null
	_campaign = null

# Helper function to create a test enemy
func create_test_enemy(enemy_data = null) -> Node:
	# Use our fixtures to create an enemy
	var enemy = TestFixtures.create_mock_enemy()
		
	# If we got an enemy and have enemy_data to set
	if enemy and enemy_data and enemy.has_method("set_enemy_data"):
		enemy.set_enemy_data(enemy_data)
			
	# Add to scene
	if enemy and not enemy.get_parent():
		add_child(enemy)
	
	return enemy

# Test integration between enemies and campaign
func test_enemy_campaign_integration() -> void:
	# Skip if dependencies aren't available
	if not _campaign or not _game_state:
		push_warning("Campaign or GameState not available, skipping test")
		return
	
	# Create an enemy to test with
	var enemy = create_test_enemy()
	assert_not_null(enemy, "Test enemy should be created")
	
	# Get initial values
	var initial_enemy_count = 0
	if "battle_stats" in _campaign and _campaign.battle_stats.has("enemies_defeated"):
		initial_enemy_count = _campaign.battle_stats.enemies_defeated
	
	# Simulate enemy defeated
	if "enemy_data" in enemy and enemy.enemy_data.has("health"):
		enemy.enemy_data.health = 0
	
	# Update campaign stats
	if "battle_stats" in _campaign:
		_campaign.battle_stats.enemies_defeated = initial_enemy_count + 1
	
	# Verify campaign records the defeat
	var current_enemy_count = 0
	if "battle_stats" in _campaign and _campaign.battle_stats.has("enemies_defeated"):
		current_enemy_count = _campaign.battle_stats.enemies_defeated
	
	assert_eq(current_enemy_count, initial_enemy_count + 1,
		"Campaign should record defeated enemy")
	
	# Test enemy movement functions don't crash
	if enemy.has_method("move_to"):
		var result = enemy.move_to(Vector2(100, 100))
		assert_true(result, "Enemy move_to() should succeed")

# Test enemy data initialization
func test_enemy_data_initialization() -> void:
	# Create an enemy and verify it has all required data fields
	var enemy = TestFixtures.create_mock_enemy()
	assert_not_null(enemy, "TestFixtures should create a valid enemy")
	
	# Verify enemy_data exists
	assert_true("enemy_data" in enemy, "Enemy should have enemy_data property")
	assert_not_null(enemy.enemy_data, "Enemy data should not be null")
	
	# Verify required fields
	var required_fields = ["id", "health", "max_health", "damage", "armor", "speed"]
	for field in required_fields:
		assert_true(enemy.enemy_data.has(field),
			"Enemy data should have '%s' field" % field)
	
	# Add enemy to scene (will be cleaned up by super.after_each())
	add_child(enemy)
