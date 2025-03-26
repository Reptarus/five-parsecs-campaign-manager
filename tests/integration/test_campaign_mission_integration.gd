## Campaign-Mission Integration Test
## Tests the integration between the campaign system and mission system
@tool
extends "res://tests/fixtures/base/game_test.gd"

const CampaignSystem = preload("res://src/core/campaign/CampaignSystem.gd")
const Mission = preload("res://src/core/mission/base/Mission.gd")
const Compatibility = preload("res://tests/fixtures/helpers/test_compatibility_helper.gd")

# Instance variables
var _campaign_system: Node
var _mission: Resource

func before_each() -> void:
	await super.before_each()
	
	# Create proper game state - using the parent class's _game_state
	_game_state = load("res://src/core/state/GameState.gd").new()
	if not _game_state:
		push_error("Failed to create game state")
		return
	add_child_autofree(_game_state)
	track_test_node(_game_state)
	
	# Create campaign system
	_campaign_system = CampaignSystem.new()
	if not _campaign_system:
		push_error("Failed to create campaign system")
		return
	add_child_autofree(_campaign_system)
	track_test_node(_campaign_system)
	
	# Initialize campaign system - use direct call for critical initialization
	var init_success = _campaign_system.initialize(_game_state)
	if not init_success:
		push_error("Failed to initialize campaign system")
		return
	
	# Create mission with proper resource path
	_mission = Mission.new()
	if not _mission:
		push_error("Failed to create mission")
		return
	_mission = Compatibility.ensure_resource_path(_mission, "test_mission")
	
	# Setup mission properties using compatibility helper
	Compatibility.safe_call_method(_mission, "set_name", ["Test Mission"])
	Compatibility.safe_call_method(_mission, "set_description", ["Test Description"])
	Compatibility.safe_call_method(_mission, "set_difficulty", [3])
	
	# Watch signals
	watch_signals(_campaign_system)
	watch_signals(_mission)

func after_each() -> void:
	_campaign_system = null
	_mission = null
	# We don't need to set _game_state to null here as the parent class handles it
	await super.after_each()

# Test adding a mission to a campaign
func test_add_mission_to_campaign() -> void:
	# Create campaign
	var campaign = Compatibility.safe_call_method(_campaign_system, "create_campaign", [ {
		"name": "Test Campaign",
		"difficulty": 1
	}])
	
	assert_not_null(campaign, "Should create campaign successfully")
	
	# Set active campaign
	var active_set = Compatibility.safe_call_method(_campaign_system, "set_active_campaign", [campaign])
	assert_true(active_set, "Should set active campaign")
	
	# Add mission to campaign
	var mission_added = Compatibility.safe_call_method(campaign, "add_mission", [_mission])
	assert_true(mission_added, "Should add mission to campaign")
	
	# Verify mission is in campaign
	var missions = Compatibility.safe_call_method(campaign, "get_missions", [])
	assert_not_null(missions, "Should get missions from campaign")
	assert_true(missions.has(_mission), "Campaign should contain the mission")
	
	# Test mission completion
	Compatibility.safe_call_method(_mission, "complete", [])
	verify_signal_emitted(_mission, "mission_completed")
	
	var completed = Compatibility.safe_call_method(_mission, "is_completed", [])
	assert_true(completed, "Mission should be marked as completed")
	
	# Verify campaign updated its state
	verify_signal_emitted(_campaign_system, "mission_completed")

# Test campaign state changes when mission is completed
func test_campaign_progression() -> void:
	# Create campaign with progression
	var campaign = Compatibility.safe_call_method(_campaign_system, "create_campaign", [ {
		"name": "Progression Test",
		"difficulty": 2,
		"track_progression": true
	}])
	
	assert_not_null(campaign, "Should create campaign with progression")
	
	# Set as active
	Compatibility.safe_call_method(_campaign_system, "set_active_campaign", [campaign])
	
	# Add multiple missions
	for i in range(3):
		var mission = Mission.new()
		mission = Compatibility.ensure_resource_path(mission, "mission_%d" % i)
		Compatibility.safe_call_method(mission, "set_name", ["Mission %d" % i])
		Compatibility.safe_call_method(campaign, "add_mission", [mission])
	
	# Get mission count
	var count = Compatibility.safe_call_method(campaign, "get_mission_count", [])
	assert_eq(count, 3, "Campaign should have 3 missions")
	
	# Complete missions and check progression
	var missions = Compatibility.safe_call_method(campaign, "get_missions", [])
	for i in range(missions.size()):
		var mission = missions[i]
		Compatibility.safe_call_method(mission, "complete", [])
		
		var progress = Compatibility.safe_call_method(campaign, "get_progress", [])
		assert_eq(progress, float(i + 1) / missions.size(), "Progress should match completed mission ratio")
	
	# Check if campaign is completed
	var is_complete = Compatibility.safe_call_method(campaign, "is_completed", [])
	assert_true(is_complete, "Campaign should be completed after all missions are done")