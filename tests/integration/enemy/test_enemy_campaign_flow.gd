@tool
extends "res://tests/fixtures/specialized/enemy_test_base.gd"

# Required type declarations
const CampaignSystem: GDScript = preload("res://src/core/campaign/CampaignSystem.gd")

# Type-safe instance variables
var _campaign_system: Node = null
var _test_enemies: Array = []
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
	track_test_resource(_test_campaign)
	
	await stabilize_engine(STABILIZE_TIME)

func after_each() -> void:
	_campaign_manager = null
	_mission_manager = null
	_test_campaign = null
	await super.after_each()

# Campaign Integration Tests
func test_enemy_campaign_spawn() -> void:
	var mission: Resource = _setup_test_mission()
	assert_not_null(mission, "Test mission should be created")
	
	var enemy: Enemy = create_test_enemy()
	assert_not_null(enemy, "Enemy should be created")
	verify_enemy_complete_state(enemy)
	
	# Test enemy spawn in mission
	TypeSafeMixin._call_node_method_bool(mission, "add_enemy", [enemy])
	var spawned_enemies: Array = TypeSafeMixin._call_node_method_array(mission, "get_enemies", [])
	assert_true(enemy in spawned_enemies, "Enemy should be added to mission")

func test_enemy_mission_integration() -> void:
	var mission: Resource = _setup_test_mission()
	var enemy: Enemy = create_test_enemy()
	
	# Test mission state integration
	TypeSafeMixin._call_node_method_bool(mission, "add_enemy", [enemy])
	watch_signals(enemy)
	
	# Test mission phase transitions
	TypeSafeMixin._call_node_method_bool(mission, "start_mission", [])
	assert_signal_emitted(enemy, "mission_started")
	
	TypeSafeMixin._call_node_method_bool(mission, "complete_mission", [])
	assert_signal_emitted(enemy, "mission_completed")

func test_enemy_progression() -> void:
	var campaign: Resource = _setup_test_campaign()
	var enemy: Enemy = create_test_enemy()
	
	# Test enemy progression tracking
	var initial_level: int = TypeSafeMixin._call_node_method_int(enemy, "get_level", [])
	TypeSafeMixin._call_node_method_bool(campaign, "add_enemy_experience", [enemy, 100])
	
	var new_level: int = TypeSafeMixin._call_node_method_int(enemy, "get_level", [])
	assert_gt(new_level, initial_level, "Enemy should level up with experience")

func test_enemy_persistence() -> void:
	var campaign: Resource = _setup_test_campaign()
	var enemy: Enemy = create_test_enemy()
	
	# Test enemy data persistence
	var enemy_data: Dictionary = TypeSafeMixin._call_node_method_dict(enemy, "save_state", [])
	assert_not_null(enemy_data, "Enemy state should be saved")
	
	var new_enemy: Enemy = create_test_enemy()
	TypeSafeMixin._call_node_method_bool(new_enemy, "load_state", [enemy_data])
	
	# Verify state restoration
	verify_enemy_state(new_enemy, {
		"health": TypeSafeMixin._call_node_method(enemy, "get_health", []),
		"level": TypeSafeMixin._call_node_method_int(enemy, "get_level", []),
		"experience": TypeSafeMixin._call_node_method_int(enemy, "get_experience", [])
	})

func test_enemy_scaling_integration() -> void:
	var campaign: Resource = _setup_test_campaign()
	var enemy: Enemy = create_test_enemy()
	
	# Test enemy scaling with campaign progress
	var initial_stats: Dictionary = {
		"health": TypeSafeMixin._call_node_method(enemy, "get_health", []),
		"damage": TypeSafeMixin._call_node_method(enemy, "get_damage", [])
	}
	
	TypeSafeMixin._call_node_method_bool(campaign, "advance_difficulty", [])
	TypeSafeMixin._call_node_method_bool(enemy, "scale_to_difficulty", [TypeSafeMixin._call_node_method_int(campaign, "get_difficulty", [])])
	
	assert_gt(
		TypeSafeMixin._call_node_method(enemy, "get_health", []),
		initial_stats.health,
		"Enemy health should scale with difficulty"
	)
	assert_gt(
		TypeSafeMixin._call_node_method(enemy, "get_damage", []),
		initial_stats.damage,
		"Enemy damage should scale with difficulty"
	)

func test_enemy_reward_integration() -> void:
	var campaign: Resource = _setup_test_campaign()
	var enemy: Enemy = create_test_enemy()
	
	# Test enemy reward generation
	var rewards: Dictionary = TypeSafeMixin._call_node_method_dict(enemy, "generate_rewards", [])
	assert_not_null(rewards, "Enemy should generate rewards")
	assert_true(rewards.has("experience"), "Rewards should include experience")
	assert_true(rewards.has("credits"), "Rewards should include credits")

func test_enemy_mission_completion() -> void:
	var mission: Resource = _setup_test_mission()
	var enemy: Enemy = create_test_enemy()
	
	# Test enemy state after mission completion
	TypeSafeMixin._call_node_method_bool(mission, "add_enemy", [enemy])
	watch_signals(enemy)
	
	TypeSafeMixin._call_node_method_bool(mission, "start_mission", [])
	TypeSafeMixin._call_node_method_bool(mission, "complete_mission", [])
	
	assert_signal_emitted(enemy, "mission_completed")
	assert_true(TypeSafeMixin._call_node_method_bool(enemy, "is_mission_complete", []), "Enemy should be marked as mission complete")

func test_enemy_campaign_state() -> void:
	var campaign: Resource = _setup_test_campaign()
	var enemy: Enemy = create_test_enemy()
	
	# Test enemy campaign state tracking
	TypeSafeMixin._call_node_method_bool(campaign, "add_enemy", [enemy])
	assert_true(TypeSafeMixin._call_node_method_bool(enemy, "is_in_campaign", []), "Enemy should be marked as in campaign")
	
	var campaign_data: Dictionary = TypeSafeMixin._call_node_method_dict(enemy, "get_campaign_data", [])
	assert_not_null(campaign_data, "Enemy should have campaign data")
	assert_true(campaign_data.has("missions_completed"), "Campaign data should track missions")

# Helper methods
func _setup_test_campaign() -> Resource:
	var campaign: Resource = _test_campaign
	TypeSafeMixin._call_node_method_bool(campaign, "initialize", [])
	return campaign

func _setup_test_mission() -> Resource:
	var mission: Resource = Resource.new()
	track_test_resource(mission)
	TypeSafeMixin._call_node_method_bool(mission, "initialize", [])
	return mission

func _simulate_mission_progress(mission: Resource, enemy: Enemy) -> void:
	TypeSafeMixin._call_node_method_bool(mission, "start_mission", [])
	TypeSafeMixin._call_node_method_bool(enemy, "complete_objective", [])
	TypeSafeMixin._call_node_method_bool(mission, "complete_mission", [])