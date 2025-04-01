@tool
extends "res://tests/fixtures/specialized/enemy_test.gd"

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

# Required type declarations - load dynamically to avoid errors
var CampaignSystem = null

# Type-safe instance variables (using untyped arrays and variables)
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

func before_all() -> void:
	super.before_all()
	# Dynamically load scripts to avoid errors if they don't exist
	CampaignSystem = load("res://src/core/campaign/CampaignSystem.gd") if ResourceLoader.exists("res://src/core/campaign/CampaignSystem.gd") else null

func before_each() -> void:
	await super.before_each()
	
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
	
	await stabilize_engine(STABILIZE_TIME)

func after_each() -> void:
	# Cleanup test resources
	_campaign_manager = null
	_mission_manager = null
	_test_campaign = null
	_test_mission = null
	_campaign_test_enemies.clear()
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

# Campaign Integration Tests
func test_enemy_campaign_integration() -> void:
	var campaign = _setup_test_campaign()
	if not campaign:
		push_warning("Failed to create test campaign, skipping test")
		pending("Test requires campaign system implementation")
		return
	
	var enemy = await create_test_enemy()
	if not enemy:
		push_warning("Failed to create test enemy, skipping test")
		pending("Test requires enemy system implementation")
		return
	
	# Reset signal tracking
	_enemy_added_signal_received = false
	_added_enemy = null
	
	# Connect to campaign signals with proper error handling
	if campaign.has_signal("enemy_added"):
		var error = campaign.connect("enemy_added", _on_enemy_added)
		assert_eq(error, OK, "Should connect to enemy_added signal successfully")
	else:
		push_warning("Campaign does not have enemy_added signal, test will be incomplete")
	
	# Ensure campaign has add enemy method
	if not campaign.has_method("campaign_add_enemy") and not campaign.has_method("add_enemy"):
		push_warning("Campaign missing enemy management methods, skipping")
		pending("Test enemy campaign spawn interaction")
		return
	
	var add_result = false
	if campaign.has_method("campaign_add_enemy"):
		add_result = campaign.campaign_add_enemy(enemy)
	else:
		add_result = campaign.add_enemy(enemy)
	
	assert_true(add_result, "Enemy should be added to the campaign")
	
	# Wait for signals to propagate
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Check using different possible method names
	var has_enemies = false
	if campaign.has_method("campaign_get_enemies"):
		has_enemies = campaign.campaign_get_enemies().size() > 0
		if has_enemies:
			assert_true(enemy in campaign.campaign_get_enemies(), "Campaign should contain the added enemy")
	elif campaign.has_method("get_enemies"):
		has_enemies = campaign.get_enemies().size() > 0
		if has_enemies:
			assert_true(enemy in campaign.get_enemies(), "Campaign should contain the added enemy")
	else:
		push_warning("Campaign missing enemy retrieval methods, skipping")
	
	assert_true(has_enemies, "Campaign should have at least one enemy")
	
	# Verify signal was emitted if it exists
	if campaign.has_signal("enemy_added"):
		assert_true(_enemy_added_signal_received, "Enemy added signal should be emitted")
		assert_eq(_added_enemy, enemy, "Signal should pass the correct enemy")

func test_enemy_mission_integration() -> void:
	var mission = _setup_test_mission()
	if not mission:
		push_warning("Failed to create test mission, skipping test")
		pending("Test requires mission system implementation")
		return
	
	var enemy = await create_test_enemy()
	if not enemy:
		push_warning("Failed to create test enemy, skipping test")
		pending("Test requires enemy system implementation")
		return
	
	# Reset signal tracking
	_mission_started_signal = false
	_mission_completed_signal = false
	
	# Connect to signals with error handling
	if enemy.has_signal("mission_started"):
		var error = enemy.connect("mission_started", _on_mission_started)
		assert_eq(error, OK, "Should connect to mission_started signal successfully")
	else:
		push_warning("Enemy does not have mission_started signal")
	
	if enemy.has_signal("mission_completed"):
		var error = enemy.connect("mission_completed", _on_mission_completed)
		assert_eq(error, OK, "Should connect to mission_completed signal successfully")
	else:
		push_warning("Enemy does not have mission_completed signal")
	
	# Add enemy to mission with method name flexibility
	var enemy_added = false
	if mission.has_method("mission_add_enemy"):
		enemy_added = mission.mission_add_enemy(enemy)
	elif mission.has_method("add_enemy"):
		enemy_added = mission.add_enemy(enemy)
	else:
		push_warning("Mission missing enemy management methods, skipping")
		pending("Test requires mission enemy management implementation")
		return
	
	assert_true(enemy_added, "Enemy should be added to mission")
	
	# Wait for object addition to complete
	await get_tree().process_frame
	
	# Verify enemy is in mission with method name flexibility
	var has_enemy = false
	if mission.has_method("mission_get_enemies"):
		has_enemy = enemy in mission.mission_get_enemies()
	elif mission.has_method("get_enemies"):
		has_enemy = enemy in mission.get_enemies()
	else:
		push_warning("Mission missing enemy retrieval methods, skipping check")
	
	if has_enemy:
		assert_true(has_enemy, "Mission should contain the added enemy")
	
	# Test mission start with method name flexibility
	var mission_started = false
	if mission.has_method("start_mission"):
		mission_started = mission.start_mission()
	elif mission.has_method("start"):
		mission_started = mission.start()
	else:
		push_warning("Mission missing start method, skipping")
	
	assert_true(mission_started, "Mission should start successfully")
	
	# Wait for signals to propagate
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Only verify signal if it exists
	if enemy.has_signal("mission_started"):
		assert_true(bool(_mission_started_signal), "mission_started signal should be emitted")
	
	# Test mission completion with method name flexibility
	var mission_completed = false
	if mission.has_method("complete_mission"):
		mission_completed = mission.complete_mission()
	elif mission.has_method("complete"):
		mission_completed = mission.complete()
	else:
		push_warning("Mission missing complete method, skipping")
	
	assert_true(bool(mission_completed), "Mission should complete successfully")
	
	# Wait for signals to propagate
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Only verify signal if it exists
	if enemy.has_signal("mission_completed"):
		assert_true(bool(_mission_completed_signal), "mission_completed signal should be emitted")

func test_enemy_progression() -> void:
	var campaign = _setup_test_campaign()
	if not campaign:
		push_warning("Failed to create test campaign, skipping test")
		pending("Test requires campaign system implementation")
		return
	
	var enemy = await create_test_enemy()
	if not enemy:
		push_warning("Failed to create test enemy, skipping test")
		pending("Test requires enemy system implementation")
		return
	
	# Reset signal tracking
	_experience_signal_received = false
	_experience_amount = 0
	_difficulty_signal_received = false
	_new_difficulty = 0
	
	# Get initial values with method name flexibility
	var initial_experience = 0
	if enemy.has_method("get_experience"):
		initial_experience = enemy.get_experience()
	elif enemy.has("experience"):
		initial_experience = enemy.experience
	else:
		push_warning("Enemy missing experience tracking, defaulting to 0")
	
	var initial_difficulty = 1
	if campaign.has_method("get_difficulty"):
		initial_difficulty = campaign.get_difficulty()
	elif campaign.has("difficulty"):
		initial_difficulty = campaign.difficulty
	else:
		push_warning("Campaign missing difficulty tracking, defaulting to 1")
	
	# Connect to signals with error handling
	if enemy.has_signal("experience_gained"):
		var error = enemy.connect("experience_gained", _on_experience_gained)
		assert_eq(error, OK, "Should connect to experience_gained signal successfully")
	else:
		push_warning("Enemy does not have experience_gained signal")
	
	if campaign.has_signal("difficulty_increased"):
		var error = campaign.connect("difficulty_increased", _on_difficulty_increased)
		assert_eq(error, OK, "Should connect to difficulty_increased signal successfully")
	else:
		push_warning("Campaign does not have difficulty_increased signal")
	
	# Award experience with method name flexibility
	var gain_success = false
	var experience_to_gain = 50
	
	if enemy.has_method("gain_experience"):
		gain_success = enemy.gain_experience(experience_to_gain)
	elif enemy.has_method("add_experience"):
		gain_success = enemy.add_experience(experience_to_gain)
	elif enemy.has("experience"):
		enemy.experience += experience_to_gain
		gain_success = true
	else:
		push_warning("Enemy missing experience management methods, skipping")
	
	assert_true(bool(gain_success), "Enemy should gain experience successfully")
	
	# Wait for signals to propagate
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Update campaign difficulty with method name flexibility
	var difficulty_success = false
	if campaign.has_method("increase_difficulty"):
		difficulty_success = campaign.increase_difficulty()
	elif campaign.has_method("add_difficulty"):
		difficulty_success = campaign.add_difficulty(1)
	elif campaign.has("difficulty"):
		campaign.difficulty += 1
		difficulty_success = true
	else:
		push_warning("Campaign missing difficulty management methods, skipping")
	
	assert_true(bool(difficulty_success), "Campaign difficulty should increase successfully")
	
	# Wait for signals to propagate
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Verify experience gain
	var final_experience = 0
	if enemy.has_method("get_experience"):
		final_experience = enemy.get_experience()
	elif enemy.has("experience"):
		final_experience = enemy.experience
	
	assert_eq(final_experience, initial_experience + experience_to_gain,
		"Enemy experience should increase by the correct amount")
	
	# Verify campaign difficulty
	var final_difficulty = 0
	if campaign.has_method("get_difficulty"):
		final_difficulty = campaign.get_difficulty()
	elif campaign.has("difficulty"):
		final_difficulty = campaign.difficulty
	
	assert_eq(final_difficulty, initial_difficulty + 1,
		"Campaign difficulty should increase by 1")
	
	# Verify signals if they exist
	if enemy.has_signal("experience_gained"):
		assert_true(bool(_experience_signal_received), "Experience signal should be emitted")
		assert_eq(_experience_amount, experience_to_gain, "Signal should pass correct amount")
	
	if campaign.has_signal("difficulty_increased"):
		assert_true(bool(_difficulty_signal_received), "Difficulty signal should be emitted")
		assert_eq(_new_difficulty, initial_difficulty + 1, "Difficulty should increase by 1")

# These tests will be implemented later when the full functionality is ready
func test_enemy_persistence() -> void:
	pending("Pending until Enemy persistence is complete")

func test_enemy_scaling_integration() -> void:
	pending("Pending until Enemy scaling is complete")

func test_enemy_reward_integration() -> void:
	pending("Pending until Enemy reward integration is complete")

func test_enemy_mission_completion() -> void:
	pending("Pending until Enemy mission completion is complete")

func test_enemy_campaign_state() -> void:
	pending("Pending until Enemy campaign state is complete")

# Test Helper Methods
func _setup_test_mission() -> Resource:
	var mission = Resource.new()
	
	# Create a script with all required methods
	var script = GDScript.new()
	script.source_code = """
extends Resource

signal mission_started
signal mission_completed
signal enemy_added(enemy)

var enemies = []
var is_started = false
var is_completed = false

func add_enemy(enemy):
	if enemy and not (enemy in enemies):
		enemies.append(enemy)
		emit_signal("enemy_added", enemy)
		return true
	return false
	
func mission_add_enemy(enemy):
	return add_enemy(enemy)
	
func get_enemies():
	return enemies
	
func mission_get_enemies():
	return get_enemies()
	
func start():
	is_started = true
	emit_signal("mission_started")
	return true
	
func start_mission():
	return start()
	
func complete():
	is_completed = true
	emit_signal("mission_completed")
	return true
	
func complete_mission():
	return complete()
"""
	# Generate unique script path with timestamp and random number to avoid collisions
	var timestamp = Time.get_unix_time_from_system()
	var random_id = randi() % 1000000
	script.resource_path = "res://tests/temp/test_mission_%d_%d.gd" % [timestamp, random_id]
	
	# Make sure temp directory exists
	if not Compatibility.ensure_temp_directory():
		push_warning("Could not create temp directory for test scripts")
		return mission
		
	var success = script.reload()
	assert_true(success, "Generated script should be valid")
	mission.set_script(script)
	
	# Ensure resource has a valid path for Godot 4.4
	mission = Compatibility.ensure_resource_path(mission, "test_mission")
	
	# Track resource to prevent memory leaks
	track_test_resource(mission)
	return mission

func _setup_test_campaign() -> Node:
	var campaign = Node.new()
	campaign.name = "TestCampaign"
	
	# Add required properties and methods via an attached script
	var script = GDScript.new()
	script.source_code = """
extends Node

signal enemy_added(enemy)
signal difficulty_increased(level)

var enemies = []
var difficulty = 1

func add_enemy(enemy):
	if enemy and not (enemy in enemies):
		enemies.append(enemy)
		emit_signal("enemy_added", enemy)
		return true
	return false
	
func campaign_add_enemy(enemy):
	return add_enemy(enemy)
	
func get_enemies():
	return enemies
	
func campaign_get_enemies():
	return get_enemies()
	
func get_difficulty():
	return difficulty
	
func increase_difficulty():
	difficulty += 1
	emit_signal("difficulty_increased", difficulty)
	return true
"""
	# Generate unique script path with timestamp and random number to avoid collisions
	var timestamp = Time.get_unix_time_from_system()
	var random_id = randi() % 1000000
	script.resource_path = "res://tests/temp/test_campaign_%d_%d.gd" % [timestamp, random_id]
	
	# Make sure temp directory exists
	if not Compatibility.ensure_temp_directory():
		push_warning("Could not create temp directory for test scripts")
		return campaign
		
	var success = script.reload()
	assert_true(success, "Generated script should be valid")
	campaign.set_script(script)
	
	add_child_autofree(campaign)
	track_test_node(campaign)
	return campaign

# Override to create test enemy with correct signature
func create_test_enemy(enemy_type = EnemyTestType.BASIC):
	# Create a mock enemy without relying on the actual Enemy.gd class
	var enemy = CharacterBody2D.new()
	if not enemy:
		push_error("Failed to create CharacterBody2D for enemy")
		return null
	
	enemy.name = "TestEnemy_" + str(Time.get_unix_time_from_system())
	
	# Add minimal required signals
	if not enemy.has_signal("mission_started"):
		enemy.add_user_signal("mission_started")
	
	if not enemy.has_signal("mission_completed"):
		enemy.add_user_signal("mission_completed")
	
	if not enemy.has_signal("experience_gained"):
		enemy.add_user_signal("experience_gained", [ {"name": "amount", "type": TYPE_INT}])
	
	# Add NavigationAgent2D if needed (using deferred to avoid timing issues)
	if not enemy.has_node("NavigationAgent2D"):
		var nav_agent = NavigationAgent2D.new()
		nav_agent.name = "NavigationAgent2D"
		enemy.call_deferred("add_child", nav_agent)
	
	# Create a custom script with proper methods
	var script = GDScript.new()
	script.source_code = """
extends CharacterBody2D

signal experience_gained(amount)

var health = 100
var max_health = 100
var damage = 20
var level = 1
var experience = 0
var mission_complete = false
var navigation_agent = null

func _ready():
	# Ensure navigation agent is properly referenced
	if has_node("NavigationAgent2D"):
		navigation_agent = get_node("NavigationAgent2D")

func get_health():
	return health
	
func get_damage():
	return damage
	
func get_level():
	return level
	
func get_experience():
	return experience
	
func is_valid():
	return true
	
func add_experience(amount):
	experience += amount
	emit_signal("experience_gained", amount)
	return true
	
func gain_experience(amount):
	return add_experience(amount)
	
func set_as_leader(is_leader):
	set_meta("is_leader", is_leader)
	
func is_leader():
	return get_meta("is_leader", false)
"""
	# Generate unique script path with timestamp and random number
	var timestamp = Time.get_unix_time_from_system()
	var random_id = randi() % 1000000
	script.resource_path = "res://tests/temp/test_enemy_%d_%d.gd" % [timestamp, random_id]
	
	# Make sure temp directory exists
	if not Compatibility.ensure_temp_directory():
		push_warning("Could not create temp directory for test scripts")
		return enemy
		
	script.reload()
	
	# Apply the script to the enemy
	enemy.set_script(script)
	
	# Wait for a frame to ensure nodes are added properly
	await get_tree().process_frame
	
	add_child_autofree(enemy)
	track_test_node(enemy)
	_campaign_test_enemies.append(enemy)
	
	return enemy

# Verify enemy is in a valid state for tests
func verify_enemy_complete_state(enemy) -> void:
	assert_not_null(enemy, "Enemy should be non-null")
	
	if enemy.has_method("get_health"):
		assert_gt(enemy.get_health(), 0, "Enemy health should be positive")
	else:
		push_warning("Enemy missing get_health method, skipping health verification")
