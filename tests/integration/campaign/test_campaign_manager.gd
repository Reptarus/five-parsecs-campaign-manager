@tool
extends "res://tests/fixtures/specialized/enemy_test_base.gd"

# Type-safe script references
const CampaignManagerScript := preload("res://src/core/managers/CampaignManager.gd")
const GameStateManagerScript := preload("res://src/core/managers/GameStateManager.gd")
const SaveManagerScript := preload("res://src/core/state/SaveManager.gd")

# Type-safe instance variables
# Note: _game_state is inherited from GameTest base class
var _campaign_manager: Node
var _save_manager: Node
var _test_enemies: Array[Node] = []

# Type-safe constants
const TEST_SAVE_SLOT := "test_campaign"

func before_each() -> void:
	await super.before_each()
	
	# Initialize test environment
	_game_state = Node.new()
	_game_state.set_script(GameStateManagerScript)
	if not _game_state:
		push_error("Failed to create game state")
		return
	add_child_autofree(_game_state)
	track_test_node(_game_state)
	
	_campaign_manager = Node.new()
	_campaign_manager.set_script(CampaignManagerScript)
	if not _campaign_manager:
		push_error("Failed to create campaign manager")
		return
	add_child_autofree(_campaign_manager)
	track_test_node(_campaign_manager)
	
	_save_manager = Node.new()
	_save_manager.set_script(SaveManagerScript)
	if not _save_manager:
		push_error("Failed to create save manager")
		return
	add_child_autofree(_save_manager)
	track_test_node(_save_manager)
	
	# Create test enemies
	_setup_test_enemies()
	
	await stabilize_engine(STABILIZE_TIME)

func after_each() -> void:
	_cleanup_test_enemies()
	
	if is_instance_valid(_campaign_manager):
		_campaign_manager.queue_free()
	if is_instance_valid(_game_state):
		_game_state.queue_free()
	if is_instance_valid(_save_manager):
		_save_manager.queue_free()
		
	_campaign_manager = null
	_game_state = null
	_save_manager = null
	
	# Clean up test save
	_call_node_method_bool(_save_manager, "delete_save", [TEST_SAVE_SLOT])
	
	await super.after_each()

# Helper Methods
func _setup_test_enemies() -> void:
	# Create a mix of enemy types
	var enemy_types := ["BASIC", "ELITE", "BOSS"]
	for type in enemy_types:
		var enemy := create_test_enemy(type)
		if not enemy:
			push_error("Failed to create enemy of type: %s" % type)
			continue
		_test_enemies.append(enemy)
		add_child_autofree(enemy)
		track_test_node(enemy)

func _cleanup_test_enemies() -> void:
	for enemy in _test_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_test_enemies.clear()

func _create_test_campaign_data() -> Dictionary:
	return {
		"name": "Test Campaign",
		"difficulty": 1,
		"credits": 1000,
		"supplies": 50,
		"crew": [],
		"enemies": [],
		"story_progress": 0,
		"completed_missions": 0
	}

# Test Methods
func test_campaign_creation() -> void:
	"""Test that a campaign can be created with valid data."""
	# Given valid campaign data
	var campaign_data := _create_test_campaign_data()
	
	# When creating a campaign
	assert_true(
		_call_node_method_bool(_campaign_manager, "create_campaign", [campaign_data]),
		"Should be able to create campaign with valid data"
	)
	
	# Then the campaign state should be initialized
	var state: Dictionary = _call_node_method_dict(_campaign_manager, "get_campaign_state", [])
	assert_not_null(state, "Campaign state should be initialized")
	assert_true(state.has("campaign_id"), "Campaign state should have ID")
	assert_true(state.has("difficulty_level"), "Campaign state should have difficulty")

func test_campaign_save_load() -> void:
	"""Test that a campaign can be saved and loaded."""
	# Given a campaign
	var campaign_data := _create_test_campaign_data()
	_call_node_method_bool(_campaign_manager, "create_campaign", [campaign_data])
	
	# When saving the campaign
	assert_true(
		_call_node_method_bool(_campaign_manager, "save_campaign", [TEST_SAVE_SLOT]),
		"Should be able to save campaign"
	)
	
	# Modify the campaign
	_call_node_method_bool(_campaign_manager, "modify_credits", [500])
	
	# When loading the campaign
	assert_true(
		_call_node_method_bool(_campaign_manager, "load_campaign", [TEST_SAVE_SLOT]),
		"Should be able to load campaign"
	)
	
	# Then the campaign state should be restored
	var state: Dictionary = _call_node_method_dict(_campaign_manager, "get_campaign_state", [])
	assert_not_null(state, "Campaign state should be loaded")
	assert_eq(state.campaign_id, campaign_data.id, "Campaign ID should match")

func test_enemy_registration() -> void:
	"""Test that enemies can be registered with the campaign."""
	# Given a campaign
	var campaign_data := _create_test_campaign_data()
	_call_node_method_bool(_campaign_manager, "create_campaign", [campaign_data])
	
	# When registering an enemy
	var enemy := _create_test_enemy()
	assert_true(
		_call_node_method_bool(_campaign_manager, "register_enemy", [enemy]),
		"Should be able to register enemy"
	)
	
	# Then the enemy should be in the registered enemies list
	var enemies: Array[Dictionary] = _call_node_method_array(_campaign_manager, "get_registered_enemies", [])
	assert_true(enemies.size() > 0, "Should have registered enemies")

func test_credit_management() -> void:
	"""Test that credits can be added and deducted."""
	# Given a campaign
	var campaign_data := _create_test_campaign_data()
	_call_node_method_bool(_campaign_manager, "create_campaign", [campaign_data])
	
	# Get initial credits
	var initial_credits: int = _call_node_method_int(_campaign_manager, "get_credits", [])
	
	# When modifying credits
	var credit_change := 100
	_call_node_method_bool(_campaign_manager, "modify_credits", [credit_change])
	
	# Then credits should be updated
	assert_eq(
		_call_node_method_int(_campaign_manager, "get_credits", []),
		initial_credits + credit_change,
		"Credits should be updated correctly"
	)

func test_supply_management() -> void:
	"""Test that supplies can be added and deducted."""
	# Given a campaign
	var campaign_data := _create_test_campaign_data()
	_call_node_method_bool(_campaign_manager, "create_campaign", [campaign_data])
	
	# Get initial supplies
	var initial_supplies: int = _call_node_method_int(_campaign_manager, "get_supplies", [])
	
	# When modifying supplies
	var supply_change := 10
	_call_node_method_bool(_campaign_manager, "modify_supplies", [supply_change])
	
	# Then supplies should be updated
	assert_eq(
		_call_node_method_int(_campaign_manager, "get_supplies", []),
		initial_supplies + supply_change,
		"Supplies should be updated correctly"
	)

func test_story_progression() -> void:
	"""Test that the story can progress."""
	# Given a campaign
	var campaign_data := _create_test_campaign_data()
	_call_node_method_bool(_campaign_manager, "create_campaign", [campaign_data])
	
	# When advancing the story
	_call_node_method_bool(_campaign_manager, "advance_story", [])
	
	# Then the story progress should be updated
	var progress: int = _call_node_method_int(_campaign_manager, "get_story_progress", [])
	assert_gt(progress, 0, "Story progress should be advanced")
	
	# Verify current story event
	var event: Dictionary = _call_node_method_dict(_campaign_manager, "get_current_story_event", [])
	assert_not_null(event, "Should have a current story event")
	
	# Resolve the story event
	assert_true(
		_call_node_method_bool(_campaign_manager, "resolve_story_event", [event]),
		"Should be able to resolve story event"
	)

func test_mission_generation() -> void:
	"""Test that missions can be generated."""
	# Given a campaign
	var campaign_data := _create_test_campaign_data()
	_call_node_method_bool(_campaign_manager, "create_campaign", [campaign_data])
	
	# When generating a mission
	var mission: Dictionary = _call_node_method_dict(_campaign_manager, "generate_mission", [])
	assert_not_null(mission, "Should generate a mission")
	
	# When accepting a mission
	assert_true(
		_call_node_method_bool(_campaign_manager, "accept_mission", [mission]),
		"Should be able to accept mission"
	)
	
	# Simulate mission completion
	var completion_data := {
		"success": true,
		"rewards": {
			"credits": 100,
			"experience": 50,
			"items": []
		},
		"casualties": []
	}
	
	# When completing a mission
	assert_true(
		_call_node_method_bool(_campaign_manager, "complete_mission", [completion_data]),
		"Should be able to complete mission"
	)
	
	# Then completed missions should be incremented
	var completed_missions: int = _call_node_method_int(_campaign_manager, "get_completed_missions", [])
	assert_gt(completed_missions, 0, "Should have completed missions")

func test_campaign_validation() -> void:
	"""Test that campaign validation works."""
	# Given a campaign
	var campaign_data := _create_test_campaign_data()
	_call_node_method_bool(_campaign_manager, "create_campaign", [campaign_data])
	
	# When validating a normal state
	var validation_result: Dictionary = _call_node_method_dict(_campaign_manager, "validate_state", [])
	assert_true(validation_result.valid, "Campaign state should be valid")
	
	# When creating an invalid state (negative credits)
	_call_node_method_bool(_campaign_manager, "modify_credits", [-2000]) # Create negative credits
	validation_result = _call_node_method_dict(_campaign_manager, "validate_state", [])
	assert_false(validation_result.valid, "Campaign state should be invalid")

func test_difficulty_scaling() -> void:
	"""Test that difficulty affects enemy scaling."""
	# Given a campaign
	var campaign_data := _create_test_campaign_data()
	_call_node_method_bool(_campaign_manager, "create_campaign", [campaign_data])
	
	# Complete a mission to increase difficulty
	var completion_data := {
		"success": true,
		"rewards": {
			"credits": 100,
			"experience": 50
		},
		"casualties": []
	}
	_call_node_method_bool(_campaign_manager, "complete_mission", [completion_data])
	
	# Then difficulty should increase
	var difficulty: int = _call_node_method_int(_campaign_manager, "get_difficulty", [])
	assert_gt(difficulty, 1, "Difficulty should increase after mission")
	
	# When scaling an enemy
	var enemy := _create_test_enemy()
	_call_node_method_bool(_campaign_manager, "register_enemy", [enemy])
	_call_node_method_bool(_campaign_manager, "scale_enemy", [enemy])
	
	# Then enemy level should be scaled
	var enemy_level: int = _call_node_method_int(enemy, "get_level", [])
	assert_gt(enemy_level, 1, "Enemy should scale with difficulty")

# Helper methods to create test objects
func _create_test_enemy() -> Node:
	var enemy: Node = Enemy.new()
	if not enemy:
		push_error("Failed to create test enemy")
		return null
	
	# Initialize with test data
	var enemy_data := {
		"id": "test_enemy",
		"name": "Test Enemy",
		"health": 10,
		"damage": 2,
		"speed": 3,
		"level": 1
	}
	
	_call_node_method_bool(enemy, "initialize", [enemy_data])
	track_test_node(enemy)
	return enemy
