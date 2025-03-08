## Campaign System Test Suite
## Tests the core functionality of the campaign system including:
## - Resource management (credits, reputation)
## - Mission tracking and progression
## - Campaign state management
## - Signal handling for campaign events
@tool
extends "res://tests/fixtures/base/game_test.gd"
# Use explicit preloads instead of global class names

# Type-safe script references
const Mission := preload("res://src/core/mission/base/mission.gd")
const CampaignSystem := preload("res://src/core/campaign/CampaignSystem.gd")
const GameState := preload("res://src/core/state/GameState.gd")

# Type-safe constants
const DEFAULT_TEST_CREDITS := 100
const DEFAULT_TEST_REPUTATION := 10

# Type-safe instance variables
var _campaign_system: Node = null
var _campaign_state: GameState = null

# Helper methods for common test scenarios
func _create_test_mission() -> Resource:
	var mission: Resource = TypeSafeMixin._safe_cast_to_resource(Mission.new(), "Mission")
	if not mission:
		push_error("Failed to create test mission")
		return null
	TypeSafeMixin._call_node_method_bool(mission, "set_type", [GameEnums.MissionType.PATROL])
	track_test_resource(mission)
	return mission

func _setup_basic_campaign_state() -> void:
	if not _campaign_state:
		push_error("Cannot setup campaign state: game state is null")
		return
	TypeSafeMixin._call_node_method_bool(_campaign_state, "add_credits", [DEFAULT_TEST_CREDITS])
	TypeSafeMixin._call_node_method_bool(_campaign_state, "add_reputation", [DEFAULT_TEST_REPUTATION])

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
	
	# Initialize campaign system
	_campaign_system = TypeSafeMixin._safe_cast_to_node(CampaignSystem.new())
	if not _campaign_system:
		push_error("Failed to create campaign system")
		return
	TypeSafeMixin._call_node_method_bool(_campaign_system, "initialize", [_campaign_state])
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
	
	_campaign_state.credits_changed.connect(func(): credits_changed_count += 1)
	_campaign_state.reputation_changed.connect(func(): reputation_changed_count += 1)
	
	_setup_basic_campaign_state()
	
	assert_eq(credits_changed_count, 1, "Should emit credits_changed signal once")
	assert_eq(reputation_changed_count, 1, "Should emit reputation_changed signal once")

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
	TypeSafeMixin._call_node_method_bool(_campaign_state, "add_credits", [- credits - 100])
	credits = TypeSafeMixin._call_node_method_int(_campaign_state, "get_credits", [])
	assert_eq(credits, 0, "Credits should not go below 0")
	
	TypeSafeMixin._call_node_method_bool(_campaign_state, "add_reputation", [- reputation - 50])
	reputation = TypeSafeMixin._call_node_method_int(_campaign_state, "get_reputation", [])
	assert_eq(reputation, 0, "Reputation should not go below 0")
