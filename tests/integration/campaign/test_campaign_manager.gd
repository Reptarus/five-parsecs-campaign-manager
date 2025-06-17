@tool
extends GdUnitGameTest

# Import GameEnums and create mock scripts for testing
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

# Type-safe mock script creation for testing
var MockCampaignManagerScript: GDScript
var MockGameStateManagerScript: GDScript
var MockSaveManagerScript: GDScript
var MockEnemyScript: GDScript

# Type-safe instance variables
var _test_game_state: Node
var _campaign_manager: Node
var _save_manager: Node
var _tracked_objects: Array[Node] = []

# Type-safe constants
const TEST_SAVE_SLOT := "test_campaign"

func before_test() -> void:
	super.before_test()
	
	# Create mock scripts
	_create_mock_scripts()
	
	# Initialize test environment with proper resource management
	await _initialize_test_environment()

func after_test() -> void:
	# Clean up all tracked objects
	for obj in _tracked_objects:
		if is_instance_valid(obj):
			obj.queue_free()
	_tracked_objects.clear()
	
	# Clean up main objects properly
	if is_instance_valid(_campaign_manager):
		_campaign_manager.queue_free()
		_campaign_manager = null
	if is_instance_valid(_test_game_state):
		_test_game_state.queue_free()
		_test_game_state = null
	if is_instance_valid(_save_manager):
		_save_manager.queue_free()
		_save_manager = null
	
	# Clear mock scripts
	MockCampaignManagerScript = null
	MockGameStateManagerScript = null
	MockSaveManagerScript = null
	MockEnemyScript = null
	
	# Wait for cleanup to complete
	await get_tree().process_frame
	
	super.after_test()

func _create_mock_scripts() -> void:
	# Create mock campaign manager script
	MockCampaignManagerScript = GDScript.new()
	MockCampaignManagerScript.source_code = '''
extends Node

signal campaign_created(campaign_data: Dictionary)
signal campaign_saved(save_data: Dictionary)
signal campaign_loaded(load_data: Dictionary)
signal enemy_registered(enemy_data: Dictionary)
signal credits_changed(new_amount: int)
signal supplies_changed(new_amount: int)
signal story_progressed(story_data: Dictionary)
signal mission_generated(mission_data: Dictionary)
signal difficulty_scaled(new_difficulty: int)

var campaign_data: Dictionary = {}
var credits: int = 0
var supplies: int = 0
var registered_enemies: Array = []
var story_progress: int = 0
var completed_missions: int = 0
var difficulty_level: int = 1

func initialize() -> void:
	campaign_data = {
		"name": "Test Campaign",
		"turn_count": 0,
		"phase": 0
	}

func create_campaign(data: Dictionary) -> bool:
	campaign_data = data.duplicate()
	credits = data.get("credits", 1000)
	supplies = data.get("supplies", 50)
	story_progress = data.get("story_progress", 0)
	completed_missions = data.get("completed_missions", 0)
	difficulty_level = data.get("difficulty", 1)
	campaign_created.emit(campaign_data)
	return true

func get_campaign_state() -> Dictionary:
	return {
		"campaign_id": str(Time.get_unix_time_from_system()),
		"difficulty_level": difficulty_level,
		"credits": credits,
		"supplies": supplies,
		"story_progress": story_progress,
		"completed_missions": completed_missions
	}

func save_campaign(slot_name: String) -> bool:
	var save_data := {
		"campaign": campaign_data,
		"credits": credits,
		"supplies": supplies,
		"slot": slot_name
	}
	campaign_saved.emit(save_data)
	return true

func load_campaign(slot_name: String) -> bool:
	# Simulate loading data
	campaign_data = {"name": "Loaded Campaign", "turn_count": 5}
	credits = 1500
	supplies = 15
	campaign_loaded.emit(campaign_data)
	return true

func register_enemy(enemy: Node) -> bool:
	if enemy:
		registered_enemies.append(enemy)
		enemy_registered.emit({"enemy": enemy.name})
		return true
	return false

func get_registered_enemies() -> Array:
	return registered_enemies

func modify_credits(amount: int) -> bool:
	credits += amount
	credits_changed.emit(credits)
	return true

func modify_supplies(amount: int) -> bool:
	supplies += amount
	supplies_changed.emit(supplies)
	return true

func get_credits() -> int:
	return credits

func get_supplies() -> int:
	return supplies

func advance_story() -> bool:
	story_progress += 1
	story_progressed.emit({"progress": story_progress})
	return true

func get_story_progress() -> int:
	return story_progress

func get_current_story_event() -> Dictionary:
	return {"event_id": "test_event", "description": "Test story event"}

func resolve_story_event(event: Dictionary) -> bool:
	return true

func generate_mission() -> Dictionary:
	var mission := {
		"mission_id": "test_mission",
		"name": "Test Mission",
		"difficulty": difficulty_level,
		"type": "patrol"
	}
	mission_generated.emit(mission)
	return mission

func accept_mission(mission: Dictionary) -> bool:
	return mission.has("mission_id")

func complete_mission(completion_data: Dictionary) -> bool:
	if completion_data.get("success", false):
		completed_missions += 1
		var rewards = completion_data.get("rewards", {})
		credits += rewards.get("credits", 0)
		credits_changed.emit(credits)
	return true

func get_completed_missions() -> int:
	return completed_missions

func validate_state() -> Dictionary:
	return {"valid": credits >= 0 and supplies >= 0}

func get_difficulty() -> int:
	return difficulty_level + completed_missions

func scale_enemy(enemy: Node) -> bool:
	if enemy and enemy.has_method("set_level"):
		enemy.call("set_level", get_difficulty())
		return true
	return false
'''
	MockCampaignManagerScript.reload() # Compile the script
	
	# Create mock game state manager script
	MockGameStateManagerScript = GDScript.new()
	MockGameStateManagerScript.source_code = '''
extends Node

var campaign_manager: Node = null

func initialize() -> void:
	pass

func get_campaign_manager() -> Node:
	return campaign_manager

func set_campaign_manager(manager: Node) -> void:
	campaign_manager = manager
'''
	MockGameStateManagerScript.reload() # Compile the script
	
	# Create mock save manager script
	MockSaveManagerScript = GDScript.new()
	MockSaveManagerScript.source_code = '''
extends Node

func save_data(data: Dictionary, slot: String) -> bool:
	return true

func load_data(slot: String) -> Dictionary:
	return {"loaded": true}
'''
	MockSaveManagerScript.reload() # Compile the script

	# Create mock enemy script
	MockEnemyScript = GDScript.new()
	MockEnemyScript.source_code = '''
extends Node

var health: int = 10
var damage: int = 2
var speed: int = 3
var level: int = 1
var enemy_data: Dictionary = {}

func initialize(data: Dictionary) -> void:
	enemy_data = data
	health = data.get("health", 10)
	damage = data.get("damage", 2)
	speed = data.get("speed", 3)
	level = data.get("level", 1)

func get_level() -> int:
	return level

func set_level(new_level: int) -> void:
	level = new_level

func get_health() -> int:
	return health

func get_damage() -> int:
	return damage

func get_speed() -> int:
	return speed

func get_enemy_data() -> Dictionary:
	return enemy_data
'''
	MockEnemyScript.reload() # Compile the script

func _initialize_test_environment() -> void:
	# Create game state with proper resource management
	_test_game_state = Node.new()
	_test_game_state.name = "TestGameState"
	_test_game_state.set_script(MockGameStateManagerScript)
	track_node(_test_game_state)
	_tracked_objects.append(_test_game_state)
	
	# Create campaign manager with proper resource management
	_campaign_manager = Node.new()
	_campaign_manager.name = "TestCampaignManager"
	_campaign_manager.set_script(MockCampaignManagerScript)
	track_node(_campaign_manager)
	_tracked_objects.append(_campaign_manager)
	
	# Create save manager with proper resource management
	_save_manager = Node.new()
	_save_manager.name = "TestSaveManager"
	_save_manager.set_script(MockSaveManagerScript)
	track_node(_save_manager)
	_tracked_objects.append(_save_manager)
	
	# Ensure everything is properly initialized
	await get_tree().process_frame

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

func _create_test_enemy() -> Node:
	var enemy: Node = Node.new()
	enemy.name = "TestEnemy_%d" % Time.get_unix_time_from_system()
	enemy.set_script(MockEnemyScript)
	
	# Initialize with test data
	var enemy_data := {
		"id": "test_enemy",
		"name": "Test Enemy",
		"health": 10,
		"damage": 2,
		"speed": 3,
		"level": 1
	}
	
	enemy.call("initialize", enemy_data)
	track_node(enemy)
	_tracked_objects.append(enemy)
	return enemy

# Test Methods
func test_campaign_creation():
	"""Test that a campaign can be created with valid data."""
	# Given valid campaign data
	var campaign_data := _create_test_campaign_data()
	
	# When creating a campaign
	assert_that(_campaign_manager.create_campaign(campaign_data)).is_true()
	
	# Then the campaign state should be initialized
	var state: Dictionary = _campaign_manager.get_campaign_state()
	assert_that(state).is_not_null()
	assert_that(state.has("campaign_id")).is_true()
	assert_that(state.has("difficulty_level")).is_true()

func test_campaign_save_load():
	"""Test that a campaign can be saved and loaded."""
	# Given a campaign
	var campaign_data := _create_test_campaign_data()
	_campaign_manager.create_campaign(campaign_data)
	
	# When saving the campaign
	assert_that(_campaign_manager.save_campaign(TEST_SAVE_SLOT)).is_true()
	
	# When loading the campaign
	assert_that(_campaign_manager.load_campaign(TEST_SAVE_SLOT)).is_true()

func test_enemy_registration():
	"""Test that enemies can be registered with the campaign."""
	# Given a campaign
	var campaign_data := _create_test_campaign_data()
	_campaign_manager.create_campaign(campaign_data)
	
	# When registering an enemy
	var enemy := _create_test_enemy()
	assert_that(_campaign_manager.register_enemy(enemy)).is_true()
	
	# Then the enemy should be in the registered enemies list
	var enemies: Array = _campaign_manager.get_registered_enemies()
	assert_that(enemies.size()).is_greater(0)

func test_credit_management():
	"""Test that credits can be added and deducted."""
	# Given a campaign
	var campaign_data := _create_test_campaign_data()
	_campaign_manager.create_campaign(campaign_data)
	
	# Get initial credits
	var initial_credits: int = _campaign_manager.get_credits()
	
	# When modifying credits
	var credit_change := 100
	_campaign_manager.modify_credits(credit_change)
	
	# Then credits should be updated
	assert_that(_campaign_manager.get_credits()).is_equal(initial_credits + credit_change)

func test_supply_management():
	"""Test that supplies can be added and deducted."""
	# Given a campaign
	var campaign_data := _create_test_campaign_data()
	_campaign_manager.create_campaign(campaign_data)
	
	# Get initial supplies
	var initial_supplies: int = _campaign_manager.get_supplies()
	
	# When modifying supplies
	var supply_change := 10
	_campaign_manager.modify_supplies(supply_change)
	
	# Then supplies should be updated
	assert_that(_campaign_manager.get_supplies()).is_equal(initial_supplies + supply_change)

func test_story_progression():
	"""Test that the story can progress."""
	# Given a campaign
	var campaign_data := _create_test_campaign_data()
	_campaign_manager.create_campaign(campaign_data)
	
	# When advancing the story
	_campaign_manager.advance_story()
	
	# Then the story progress should be updated
	var progress: int = _campaign_manager.get_story_progress()
	assert_that(progress).is_greater(0)
	
	# Verify current story event
	var event: Dictionary = _campaign_manager.get_current_story_event()
	assert_that(event).is_not_null()
	
	# Resolve the story event
	assert_that(_campaign_manager.resolve_story_event(event)).is_true()

func test_mission_generation():
	"""Test that missions can be generated."""
	# Given a campaign
	var campaign_data := _create_test_campaign_data()
	_campaign_manager.create_campaign(campaign_data)
	
	# When generating a mission
	var mission: Dictionary = _campaign_manager.generate_mission()
	assert_that(mission).is_not_null()
	
	# When accepting a mission
	assert_that(_campaign_manager.accept_mission(mission)).is_true()
	
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
	assert_that(_campaign_manager.complete_mission(completion_data)).is_true()
	
	# Then completed missions should be incremented
	var completed_missions: int = _campaign_manager.get_completed_missions()
	assert_that(completed_missions).is_greater(0)

func test_campaign_validation():
	"""Test that campaign validation works."""
	# Given a campaign
	var campaign_data := _create_test_campaign_data()
	_campaign_manager.create_campaign(campaign_data)
	
	# When validating a normal state
	var validation_result: Dictionary = _campaign_manager.validate_state()
	assert_that(validation_result.get("valid", false)).is_true()

func test_difficulty_scaling():
	"""Test that difficulty affects enemy scaling."""
	# Given a campaign
	var campaign_data := _create_test_campaign_data()
	_campaign_manager.create_campaign(campaign_data)
	
	# Complete a mission to increase difficulty
	var completion_data := {
		"success": true,
		"rewards": {
			"credits": 100,
			"experience": 50
		},
		"casualties": []
	}
	_campaign_manager.complete_mission(completion_data)
	
	# Then difficulty should increase
	var difficulty: int = _campaign_manager.get_difficulty()
	assert_that(difficulty).is_greater(1)
	
	# When scaling an enemy
	var enemy := _create_test_enemy()
	_campaign_manager.register_enemy(enemy)
	_campaign_manager.scale_enemy(enemy)
	
	# Then enemy level should be scaled
	var enemy_level: int = enemy.get_level()
	assert_that(enemy_level).is_greater(1)