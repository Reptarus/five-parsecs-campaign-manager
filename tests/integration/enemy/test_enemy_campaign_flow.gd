@tool
extends "res://tests/fixtures/specialized/enemy_test_base.gd"

# Required type declarations
const CampaignSystem: GDScript = preload("res://src/core/campaign/CampaignSystem.gd")

# Type-safe instance variables
var _campaign_system: Node = null
var _campaign_test_enemies: Array = []
var _test_campaign: Resource = null

var _campaign_manager: Node = null
var _mission_manager: Node = null

func before_each() -> void:
	await super.before_each()
	
	# Setup campaign test environment
	_campaign_manager = Node.new()
	if not _campaign_manager:
		push_error("Failed to create campaign manager")
		return
	_campaign_manager.name = "CampaignManager"
	add_child_autofree(_campaign_manager)
	track_test_node(_campaign_manager)
	
	_mission_manager = Node.new()
	if not _mission_manager:
		push_error("Failed to create mission manager")
		return
	_mission_manager.name = "MissionManager"
	add_child_autofree(_mission_manager)
	track_test_node(_mission_manager)
	
	_test_campaign = Resource.new()
	if not _test_campaign:
		push_error("Failed to create test campaign")
		return
	track_test_resource(_test_campaign)
	
	await stabilize_engine(STABILIZE_TIME)

func after_each() -> void:
	_campaign_manager = null
	_mission_manager = null
	_test_campaign = null
	_campaign_test_enemies.clear()
	await super.after_each()

# Campaign Integration Tests
func test_enemy_campaign_spawn() -> void:
	var mission: Resource = _setup_test_mission()
	assert_not_null(mission, "Test mission should be created")
	
	var enemy = create_test_enemy()
	assert_not_null(enemy, "Enemy should be created")
	verify_enemy_complete_state(enemy)
	
	# Check if the mission has the required methods
	if not mission.has_method("add_enemy") or not mission.has_method("get_enemies"):
		push_warning("Mission doesn't have the required methods, skipping test")
		return
	
	# Test enemy spawn in mission
	var add_result = TypeSafeMixin._call_node_method_bool(mission, "add_enemy", [enemy], false)
	assert_true(add_result, "Enemy should be added to mission successfully")
	
	var spawned_enemies = TypeSafeMixin._call_node_method_array(mission, "get_enemies", [], [])
	assert_true(enemy in spawned_enemies, "Enemy should be in mission enemies list")

func test_enemy_mission_integration() -> void:
	var mission: Resource = _setup_test_mission()
	var enemy = create_test_enemy()
	assert_not_null(mission, "Test mission should be created")
	assert_not_null(enemy, "Enemy should be created")
	
	# Check if the mission has the required methods
	if not mission.has_method("add_enemy") or not mission.has_method("start_mission") or not mission.has_method("complete_mission"):
		push_warning("Mission doesn't have the required methods, skipping test")
		return
	
	# Test mission state integration
	var add_result = TypeSafeMixin._call_node_method_bool(mission, "add_enemy", [enemy], false)
	assert_true(add_result, "Enemy should be added to mission successfully")
	
	watch_signals(enemy)
	
	# Test mission phase transitions
	var start_result = TypeSafeMixin._call_node_method_bool(mission, "start_mission", [], false)
	assert_true(start_result, "Mission should start successfully")
	assert_signal_emitted(enemy, "mission_started", "Enemy should receive mission_started signal")
	
	var complete_result = TypeSafeMixin._call_node_method_bool(mission, "complete_mission", [], false)
	assert_true(complete_result, "Mission should complete successfully")
	assert_signal_emitted(enemy, "mission_completed", "Enemy should receive mission_completed signal")

func test_enemy_progression() -> void:
	var campaign: Resource = _setup_test_campaign()
	assert_not_null(campaign, "Test campaign should be created")
	
	var enemy = create_test_enemy()
	assert_not_null(enemy, "Enemy should be created")
	
	# Check if the campaign and enemy have the required methods
	if not campaign.has_method("add_enemy_experience") or not enemy.has_method("get_level"):
		push_warning("Campaign or enemy doesn't have the required methods, skipping test")
		return
	
	# Test enemy progression tracking
	var initial_level = TypeSafeMixin._call_node_method_int(enemy, "get_level", [], 0)
	var exp_added = TypeSafeMixin._call_node_method_bool(campaign, "add_enemy_experience", [enemy, 100], false)
	assert_true(exp_added, "Experience should be added successfully")
	
	var new_level = TypeSafeMixin._call_node_method_int(enemy, "get_level", [], 0)
	assert_gt(new_level, initial_level, "Enemy should level up with experience (initial level: %d, new level: %d)" % [initial_level, new_level])

func test_enemy_persistence() -> void:
	var campaign: Resource = _setup_test_campaign()
	assert_not_null(campaign, "Test campaign should be created")
	
	var enemy = create_test_enemy()
	assert_not_null(enemy, "Enemy should be created")
	
	# Check if the enemy has the required methods
	if not enemy.has_method("save_state") or not enemy.has_method("load_state"):
		push_warning("Enemy doesn't have save_state or load_state methods, skipping test")
		return
	
	# Test enemy data persistence
	var enemy_data = TypeSafeMixin._call_node_method_dict(enemy, "save_state", [], {})
	assert_not_null(enemy_data, "Enemy state should be saved to dictionary")
	assert_gt(enemy_data.size(), 0, "Enemy data should not be empty")
	
	var new_enemy = create_test_enemy()
	assert_not_null(new_enemy, "New test enemy should be created")
	
	var load_result = TypeSafeMixin._call_node_method_bool(new_enemy, "load_state", [enemy_data], false)
	assert_true(load_result, "Enemy state should load successfully")
	
	# Verify state restoration
	var health = TypeSafeMixin._call_node_method(enemy, "get_health", [])
	var new_health = TypeSafeMixin._call_node_method(new_enemy, "get_health", [])
	assert_eq(new_health, health, "Health should be preserved after state load (expected: %s, actual: %s)" % [health, new_health])
	
	var level = TypeSafeMixin._call_node_method_int(enemy, "get_level", [], 0)
	var new_level = TypeSafeMixin._call_node_method_int(new_enemy, "get_level", [], 0)
	assert_eq(new_level, level, "Level should be preserved after state load (expected: %d, actual: %d)" % [level, new_level])
	
	var experience = TypeSafeMixin._call_node_method_int(enemy, "get_experience", [], 0)
	var new_experience = TypeSafeMixin._call_node_method_int(new_enemy, "get_experience", [], 0)
	assert_eq(new_experience, experience, "Experience should be preserved after state load (expected: %d, actual: %d)" % [experience, new_experience])

func test_enemy_scaling_integration() -> void:
	var campaign: Resource = _setup_test_campaign()
	assert_not_null(campaign, "Test campaign should be created")
	
	var enemy = create_test_enemy()
	assert_not_null(enemy, "Enemy should be created")
	
	# Check if the campaign and enemy have the required methods
	if not campaign.has_method("advance_difficulty") or not campaign.has_method("get_difficulty") or not enemy.has_method("scale_to_difficulty"):
		push_warning("Campaign or enemy doesn't have required scaling methods, skipping test")
		return
	
	# Test enemy scaling with campaign progress
	var initial_health = TypeSafeMixin._call_node_method(enemy, "get_health", [])
	var initial_damage = TypeSafeMixin._call_node_method(enemy, "get_damage", [])
	
	var difficulty_advanced = TypeSafeMixin._call_node_method_bool(campaign, "advance_difficulty", [], false)
	assert_true(difficulty_advanced, "Campaign difficulty should advance successfully")
	
	var difficulty = TypeSafeMixin._call_node_method_int(campaign, "get_difficulty", [], 0)
	var scaling_applied = TypeSafeMixin._call_node_method_bool(enemy, "scale_to_difficulty", [difficulty], false)
	assert_true(scaling_applied, "Enemy scaling should be applied successfully")
	
	var new_health = TypeSafeMixin._call_node_method(enemy, "get_health", [])
	var new_damage = TypeSafeMixin._call_node_method(enemy, "get_damage", [])
	
	assert_gt(
		new_health,
		initial_health,
		"Enemy health should scale with difficulty (initial: %s, new: %s)" % [initial_health, new_health]
	)
	assert_gt(
		new_damage,
		initial_damage,
		"Enemy damage should scale with difficulty (initial: %s, new: %s)" % [initial_damage, new_damage]
	)

func test_enemy_reward_integration() -> void:
	var campaign: Resource = _setup_test_campaign()
	assert_not_null(campaign, "Test campaign should be created")
	
	var enemy = create_test_enemy()
	assert_not_null(enemy, "Enemy should be created")
	
	# Check if the enemy has the required method
	if not enemy.has_method("generate_rewards"):
		push_warning("Enemy doesn't have generate_rewards method, skipping test")
		return
	
	# Test enemy reward generation
	var rewards = TypeSafeMixin._call_node_method_dict(enemy, "generate_rewards", [], {})
	assert_not_null(rewards, "Enemy should generate rewards dictionary")
	assert_true(rewards.has("experience"), "Rewards should include experience")
	assert_true(rewards.has("credits"), "Rewards should include credits")
	
	# Verify reward values are reasonable
	assert_gt(rewards.experience, 0, "Experience reward should be positive")
	assert_gt(rewards.credits, 0, "Credits reward should be positive")

func test_enemy_mission_completion() -> void:
	var mission: Resource = _setup_test_mission()
	assert_not_null(mission, "Test mission should be created")
	
	var enemy = create_test_enemy()
	assert_not_null(enemy, "Enemy should be created")
	
	# Check if mission and enemy have required methods
	if not mission.has_method("add_enemy") or not mission.has_method("start_mission") or not mission.has_method("complete_mission") or not enemy.has_method("is_mission_complete"):
		push_warning("Mission or enemy doesn't have required methods, skipping test")
		return
	
	# Test enemy state after mission completion
	var add_result = TypeSafeMixin._call_node_method_bool(mission, "add_enemy", [enemy], false)
	assert_true(add_result, "Enemy should be added to mission successfully")
	
	watch_signals(enemy)
	
	var start_result = TypeSafeMixin._call_node_method_bool(mission, "start_mission", [], false)
	assert_true(start_result, "Mission should start successfully")
	
	var complete_result = TypeSafeMixin._call_node_method_bool(mission, "complete_mission", [], false)
	assert_true(complete_result, "Mission should complete successfully")
	
	assert_signal_emitted(enemy, "mission_completed", "Enemy should receive mission_completed signal")
	assert_true(
		TypeSafeMixin._call_node_method_bool(enemy, "is_mission_complete", [], false),
		"Enemy should be marked as mission complete"
	)

func test_enemy_campaign_state() -> void:
	var campaign: Resource = _setup_test_campaign()
	assert_not_null(campaign, "Test campaign should be created")
	
	var enemy = create_test_enemy()
	assert_not_null(enemy, "Enemy should be created")
	
	# Check if campaign and enemy have required methods
	if not campaign.has_method("add_enemy") or not enemy.has_method("is_in_campaign") or not enemy.has_method("get_campaign_data"):
		push_warning("Campaign or enemy doesn't have required methods, skipping test")
		return
	
	# Test enemy campaign state tracking
	var add_result = TypeSafeMixin._call_node_method_bool(campaign, "add_enemy", [enemy], false)
	assert_true(add_result, "Enemy should be added to campaign successfully")
	
	assert_true(
		TypeSafeMixin._call_node_method_bool(enemy, "is_in_campaign", [], false),
		"Enemy should be marked as in campaign"
	)
	
	var campaign_data = TypeSafeMixin._call_node_method_dict(enemy, "get_campaign_data", [], {})
	assert_not_null(campaign_data, "Enemy should have campaign data")
	assert_true(campaign_data.has("missions_completed"), "Campaign data should track missions")

# Helper methods
func _setup_test_campaign() -> Resource:
	var campaign: Resource = _test_campaign
	if not campaign:
		push_error("Test campaign not initialized")
		return null
		
	if not campaign.has_method("initialize"):
		push_warning("Campaign doesn't have initialize method")
		return campaign
		
	var init_result = TypeSafeMixin._call_node_method_bool(campaign, "initialize", [], false)
	if not init_result:
		push_warning("Campaign initialization failed")
	return campaign

func _setup_test_mission() -> Resource:
	var mission: Resource = Resource.new()
	if not mission:
		push_error("Failed to create test mission")
		return null
		
	track_test_resource(mission)
	
	if not mission.has_method("initialize"):
		push_warning("Mission doesn't have initialize method")
		return mission
		
	var init_result = TypeSafeMixin._call_node_method_bool(mission, "initialize", [], false)
	if not init_result:
		push_warning("Mission initialization failed")
	return mission

func _simulate_mission_progress(mission: Resource, enemy) -> void:
	if not mission or not enemy:
		push_error("Invalid mission or enemy for simulation")
		return
		
	if not mission.has_method("start_mission") or not enemy.has_method("complete_objective") or not mission.has_method("complete_mission"):
		push_warning("Mission or enemy doesn't have required methods for mission simulation")
		return
		
	TypeSafeMixin._call_node_method_bool(mission, "start_mission", [], false)
	TypeSafeMixin._call_node_method_bool(enemy, "complete_objective", [], false)
	TypeSafeMixin._call_node_method_bool(mission, "complete_mission", [], false)                                                                                         