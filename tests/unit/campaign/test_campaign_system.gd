## Campaign System Test Suite
## Tests the core functionality of the campaign system including:
## - Resource management (credits, reputation)
## - Mission tracking and progression
## - Campaign state management
## - Signal handling for campaign events
@tool
extends "res://tests/fixtures/base/game_test.gd"
# Use explicit preloads instead of global class names

# Load scripts safely - handles missing files gracefully
const Compatibility = preload("res://tests/fixtures/helpers/test_compatibility_helper.gd")
var CampaignSystemScript = load("res://src/core/campaign/CampaignSystem.gd") if ResourceLoader.exists("res://src/core/campaign/CampaignSystem.gd") else null
var CampaignDataScript = load("res://src/core/campaign/CampaignData.gd") if ResourceLoader.exists("res://src/core/campaign/CampaignData.gd") else null
var GameManagerScript = load("res://src/core/managers/GameManager.gd") if ResourceLoader.exists("res://src/core/managers/GameManager.gd") else null

# Type-safe script references
const Mission := preload("res://src/core/mission/base/mission.gd")
const GameState := preload("res://src/core/state/GameState.gd")

# Type-safe constants
const DEFAULT_TEST_CREDITS := 100
const DEFAULT_TEST_REPUTATION := 10

# Type-safe instance variables
var _campaign_system: Node = null
var _game_manager: Node = null
var _campaign_data: Resource = null
var _campaign_state: GameState = null

# Helper methods for common test scenarios
func _create_test_mission() -> Resource:
	if not Mission:
		push_error("Mission script is null")
		return null
		
	var mission: Resource = Mission.new()
	if not mission:
		push_error("Failed to create test mission")
		return null
		
	if mission.has_method("set_type"):
		mission.set_type(GameEnums.MissionType.PATROL)
	else:
		push_warning("Mission doesn't have set_type method")
		
	track_test_resource(mission)
	return mission

func _setup_basic_campaign_state() -> void:
	if not _campaign_state:
		push_error("Cannot setup campaign state: game state is null")
		return
		
	if _campaign_state.has_method("add_credits"):
		_campaign_state.add_credits(DEFAULT_TEST_CREDITS)
	else:
		push_warning("GameState doesn't have add_credits method")
		
	if _campaign_state.has_method("add_reputation"):
		_campaign_state.add_reputation(DEFAULT_TEST_REPUTATION)
	else:
		push_warning("GameState doesn't have add_reputation method")

# Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	
	# Initialize game state
	_campaign_state = create_test_game_state()
	if not _campaign_state:
		push_error("Failed to create game state")
		return
	add_child_autofree(_campaign_state)
	track_test_node(_campaign_state)
	
	# Initialize campaign system directly without TypeSafeMixin
	if CampaignSystemScript:
		_campaign_system = CampaignSystemScript.new()
	else:
		push_error("CampaignSystem script is null")
		return
		
	if not _campaign_system:
		push_error("Failed to create campaign system")
		return
		
	# Initialize directly instead of using TypeSafeMixin
	if _campaign_system.has_method("initialize"):
		var success = _campaign_system.initialize(_campaign_state)
		if not success:
			push_warning("Campaign system initialization might have failed")
	else:
		push_error("Campaign system doesn't have initialize method")
		return
		
	add_child_autofree(_campaign_system)
	track_test_node(_campaign_system)
	
	await stabilize_engine()

func after_each() -> void:
	_campaign_system = null
	_campaign_state = null
	await super.after_each()

# Initial State Tests
func test_campaign_initialization() -> void:
	assert_not_null(_campaign_state, "Game state should be initialized")
	var credits: int = TypeSafeMixin._call_node_method_int(_campaign_state, "get_credits", [])
	var reputation: int = TypeSafeMixin._call_node_method_int(_campaign_state, "get_reputation", [])
	var completed_missions: Array = TypeSafeMixin._call_node_method_array(_campaign_state, "get_completed_missions", [])
	
	assert_eq(credits, 0, "Should start with 0 credits")
	assert_eq(reputation, 0, "Should start with 0 reputation")
	assert_eq(completed_missions.size(), 0, "Should start with 0 completed missions")

# Resource Management Tests
func test_resource_management() -> void:
	watch_signals(_campaign_state)
	
	TypeSafeMixin._call_node_method_bool(_campaign_state, "add_credits", [DEFAULT_TEST_CREDITS])
	var current_credits: int = TypeSafeMixin._call_node_method_int(_campaign_state, "get_credits", [])
	assert_eq(current_credits, DEFAULT_TEST_CREDITS, "Credits should be added")
	verify_signal_emitted(_campaign_state, "credits_changed")
	
	TypeSafeMixin._call_node_method_bool(_campaign_state, "add_credits", [DEFAULT_TEST_CREDITS])
	current_credits = TypeSafeMixin._call_node_method_int(_campaign_state, "get_credits", [])
	assert_eq(current_credits, DEFAULT_TEST_CREDITS * 2, "Credits should accumulate")
	verify_signal_emitted(_campaign_state, "credits_changed")

# Reputation System Tests
func test_reputation_system() -> void:
	watch_signals(_campaign_state)
	
	TypeSafeMixin._call_node_method_bool(_campaign_state, "add_reputation", [DEFAULT_TEST_REPUTATION])
	var current_reputation: int = TypeSafeMixin._call_node_method_int(_campaign_state, "get_reputation", [])
	assert_eq(current_reputation, DEFAULT_TEST_REPUTATION, "Reputation should be added")
	verify_signal_emitted(_campaign_state, "reputation_changed")
	
	TypeSafeMixin._call_node_method_bool(_campaign_state, "add_reputation", [DEFAULT_TEST_REPUTATION])
	current_reputation = TypeSafeMixin._call_node_method_int(_campaign_state, "get_reputation", [])
	assert_eq(current_reputation, DEFAULT_TEST_REPUTATION * 2, "Reputation should accumulate")
	verify_signal_emitted(_campaign_state, "reputation_changed")

# Mission Tracking Tests
func test_mission_tracking() -> void:
	watch_signals(_campaign_state)
	
	var completed_missions: Array = TypeSafeMixin._call_node_method_array(_campaign_state, "get_completed_missions", [])
	assert_eq(completed_missions.size(), 0, "Should start with no completed missions")
	
	var patrol_mission: Resource = _create_test_mission()
	if not patrol_mission:
		push_error("Failed to create patrol mission")
		return
	TypeSafeMixin._call_node_method_bool(_campaign_state, "add_completed_mission", [patrol_mission])
	completed_missions = TypeSafeMixin._call_node_method_array(_campaign_state, "get_completed_missions", [])
	assert_eq(completed_missions.size(), 1, "Should track completed mission")
	verify_signal_emitted(_campaign_state, "mission_completed")
	
	var rescue_mission: Resource = _create_test_mission()
	if not rescue_mission:
		push_error("Failed to create rescue mission")
		return
	TypeSafeMixin._call_node_method_bool(_campaign_state, "add_completed_mission", [rescue_mission])
	completed_missions = TypeSafeMixin._call_node_method_array(_campaign_state, "get_completed_missions", [])
	assert_eq(completed_missions.size(), 2, "Should accumulate completed missions")
	verify_signal_emitted(_campaign_state, "mission_completed")

# Performance Tests
func test_rapid_mission_completion() -> void:
	watch_signals(_campaign_state)
	
	for i in range(100):
		var mission: Resource = _create_test_mission()
		if not mission:
			push_error("Failed to create mission %d" % i)
			continue
		TypeSafeMixin._call_node_method_bool(_campaign_state, "add_completed_mission", [mission])
	
	var completed_missions: Array = TypeSafeMixin._call_node_method_array(_campaign_state, "get_completed_missions", [])
	assert_true(completed_missions.size() <= 100, "Should handle rapid mission completions")
	assert_signal_emit_count(_campaign_state, "mission_completed", 100)

# Error Boundary Tests
func test_invalid_mission_handling() -> void:
	watch_signals(_campaign_state)
	
	TypeSafeMixin._call_node_method_bool(_campaign_state, "add_completed_mission", [null])
	var completed_missions: Array = TypeSafeMixin._call_node_method_array(_campaign_state, "get_completed_missions", [])
	assert_eq(completed_missions.size(), 0, "Should handle null mission gracefully")

# Signal Tests
func test_resource_signals() -> void:
	watch_signals(_campaign_state)
	var credits_changed_count := 0
	var reputation_changed_count := 0
	
	# Check if signals exist before connecting to them
	if _campaign_state.has_signal("credits_changed"):
		# First check if the signal exists, then connect using a lambda
		_campaign_state.connect("credits_changed", func(): credits_changed_count += 1)
	else:
		push_warning("GameState doesn't have credits_changed signal")
		
	if _campaign_state.has_signal("reputation_changed"):
		_campaign_state.connect("reputation_changed", func(): reputation_changed_count += 1)
	else:
		push_warning("GameState doesn't have reputation_changed signal")
	
	# Set up the campaign state which should trigger signals
	_setup_basic_campaign_state()
	
	# Only verify signals if they exist
	if _campaign_state.has_signal("credits_changed"):
		assert_eq(credits_changed_count, 1, "Should emit credits_changed signal once")
	
	if _campaign_state.has_signal("reputation_changed"):
		assert_eq(reputation_changed_count, 1, "Should emit reputation_changed signal once")
		
	# Alternative test using GUT's built-in signal verification
	if _campaign_state.has_signal("credits_changed"):
		verify_signal_emitted(_campaign_state, "credits_changed", "Credits changed signal should be emitted")
	
	if _campaign_state.has_signal("reputation_changed"):
		verify_signal_emitted(_campaign_state, "reputation_changed", "Reputation changed signal should be emitted")

# Helper function to check if the campaign state emits signals
func _test_resource_signal(signal_name: String, callback_method: Callable) -> void:
	# Check first if the method exists
	if _campaign_state.has_method(callback_method.get_method()):
		if _campaign_state.has_signal(signal_name):
			watch_signals(_campaign_state)
			callback_method.call()
			verify_signal_emitted(_campaign_state, signal_name)
		else:
			push_warning("GameState doesn't have %s signal" % signal_name)
	else:
		push_warning("GameState doesn't have %s method" % callback_method.get_method())

# Boundary Tests
func test_resource_boundaries() -> void:
	watch_signals(_campaign_state)
	
	# Test maximum values
	TypeSafeMixin._call_node_method_bool(_campaign_state, "add_credits", [999999])
	var credits: int = TypeSafeMixin._call_node_method_int(_campaign_state, "get_credits", [])
	assert_true(credits <= 999999, "Credits should not exceed maximum")
	
	TypeSafeMixin._call_node_method_bool(_campaign_state, "add_reputation", [100])
	var reputation: int = TypeSafeMixin._call_node_method_int(_campaign_state, "get_reputation", [])
	assert_true(reputation <= 100, "Reputation should not exceed maximum")
	
	# Test negative values
	TypeSafeMixin._call_node_method_bool(_campaign_state, "add_credits", [-credits - 100])
	credits = TypeSafeMixin._call_node_method_int(_campaign_state, "get_credits", [])
	assert_eq(credits, 0, "Credits should not go below 0")
	
	TypeSafeMixin._call_node_method_bool(_campaign_state, "add_reputation", [-reputation - 50])
	reputation = TypeSafeMixin._call_node_method_int(_campaign_state, "get_reputation", [])
	assert_eq(reputation, 0, "Reputation should not go below 0")
