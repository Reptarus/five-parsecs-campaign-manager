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
	
	# Ensure mission has required methods for testing
	_mission = Compatibility.ensure_mission_compatibility(_mission)
	
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
	# Given a campaign with progression
	var campaign = Compatibility.safe_call_method(_campaign_system, "create_campaign", [ {
		"name": "Progression Test",
		"difficulty": 2,
		"track_progression": true
	}])
	Compatibility.ensure_campaign_compatibility(campaign)
	
	# And a mission
	var mission = Mission.new()
	mission = Compatibility.ensure_mission_compatibility(mission)
	
	# When I add the mission to the campaign
	Compatibility.safe_call_method(campaign, "add_mission", [mission])
	
	# Then the mission should be added to the campaign
	var missions = Compatibility.safe_call_method(campaign, "get_missions", [])
	if not is_array_contains_mission(missions, mission):
		fail_test("Mission was not added to campaign")
	
	# And the campaign should have a list of missions
	assert_eq(Compatibility.safe_call_method(campaign, "get_mission_count", []), 1, "Campaign should have 1 mission")

# Test campaign state changes when mission is completed
func test_campaign_progression() -> void:
	# Create campaign with progression tracking
	var campaign = create_campaign_with_progression()
	Compatibility.ensure_campaign_compatibility(campaign)
	
	# Create and add multiple missions
	var missions = []
	for i in range(3):
		var mission = Mission.new()
		mission = Compatibility.ensure_mission_compatibility(mission)
		Compatibility.safe_call_method(mission, "set_name", ["Mission %d" % i])
		missions.append(mission)
		Compatibility.safe_call_method(campaign, "add_mission", [mission])
	
	# Verify all missions are added
	var campaign_missions = Compatibility.safe_call_method(campaign, "get_missions", [])
	assert_eq(Compatibility.safe_call_method(campaign, "get_mission_count", []), 3,
		"Campaign should have 3 missions")
	
	# Complete each mission
	for mission in missions:
		Compatibility.safe_call_method(mission, "complete", [])
		verify_signal_emitted(mission, "mission_completed")
		assert_true(Compatibility.safe_call_method(mission, "is_completed", []),
			"Mission should be marked as completed")
	
	# Verify campaign is completed after all missions are done
	assert_true(Compatibility.safe_call_method(campaign, "is_completed", []),
		"Campaign should be completed after all missions are done")

func is_array_contains_mission(missions_array, target_mission) -> bool:
	if not missions_array or not missions_array is Array:
		return false
	
	for mission in missions_array:
		if mission == target_mission:
			return true
		
		# If direct comparison fails, try comparing resource paths
		if mission.resource_path != "" and target_mission.resource_path != "":
			if mission.resource_path == target_mission.resource_path:
				return true
	
	return false

func create_campaign_with_progression():
	# Create campaign with progression tracking enabled
	var campaign = Compatibility.safe_call_method(_campaign_system, "create_campaign", [ {
		"name": "Progression Test",
		"difficulty": 2,
		"track_progression": true
	}])
	
	assert_not_null(campaign, "Should create campaign with progression")
	
	# Set as active campaign
	var active_set = Compatibility.safe_call_method(_campaign_system, "set_active_campaign", [campaign])
	assert_true(active_set, "Should set active campaign")
	
	return campaign
