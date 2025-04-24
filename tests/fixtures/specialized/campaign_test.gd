@tool
extends "res://tests/fixtures/base/game_test.gd"

# Special constants for campaign tests
const CAMPAIGN_TIMEOUT = 2.0
const DEFAULT_CAMPAIGN_NAME = "Test Campaign"

# Campaign testing helpers
var _test_credits = 1000
var _test_supplies = 50
var _test_reputation = 5

# Campaign reference
var _campaign = null

# Setup methods
func _setup_campaign_test() -> void:
	# Setup any campaign-specific test resources here
	pass

func before_each():
	await super.before_each()
	_setup_campaign_test()
	
	# Create a test campaign for common use
	_campaign = create_test_campaign()
	if _campaign and _campaign is Resource:
		track_test_resource(_campaign)

func after_each():
	_campaign = null
	await super.after_each()

# Helper methods for campaign tests
func create_test_campaign():
	var CampaignScript = load("res://src/core/campaign/Campaign.gd")
	if not CampaignScript:
		push_warning("Campaign script not found, using mock instead")
		return create_mock_campaign()
		
	var campaign = CampaignScript.new()
	if not campaign:
		push_error("Failed to create campaign instance")
		return null
	
	# Initialize test campaign
	if campaign.has_method("set_name"):
		campaign.set_name(DEFAULT_CAMPAIGN_NAME)
	
	if campaign.has_method("set_credits"):
		campaign.set_credits(_test_credits)
		
	if campaign.has_method("set_supplies"):
		campaign.set_supplies(_test_supplies)
		
	track_test_resource(campaign)
	return campaign

func create_mock_campaign():
	# Create a minimal mock object when the real script can't be found
	var mock_campaign = Resource.new()
	mock_campaign.set_meta("name", DEFAULT_CAMPAIGN_NAME)
	mock_campaign.set_meta("credits", _test_credits)
	mock_campaign.set_meta("supplies", _test_supplies)
	mock_campaign.set_meta("reputation", _test_reputation)
	
	track_test_resource(mock_campaign)
	return mock_campaign

# Campaign-specific assertions
func assert_campaign_has_credits(campaign, expected_credits, message = ""):
	var credits = 0
	
	# Try several ways to get the credits value
	if campaign.has_method("get_credits"):
		credits = campaign.get_credits()
	elif "credits" in campaign:
		credits = campaign.credits
	elif campaign.has_meta("credits"):
		credits = campaign.get_meta("credits")
	
	if message.is_empty():
		message = "Campaign should have %d credits but had %d" % [expected_credits, credits]
	
	assert_eq(credits, expected_credits, message)

func assert_campaign_has_supplies(campaign, expected_supplies, message = ""):
	var supplies = 0
	
	# Try several ways to get the supplies value
	if campaign.has_method("get_supplies"):
		supplies = campaign.get_supplies()
	elif "supplies" in campaign:
		supplies = campaign.supplies
	elif campaign.has_meta("supplies"):
		supplies = campaign.get_meta("supplies")
	
	if message.is_empty():
		message = "Campaign should have %d supplies but had %d" % [expected_supplies, supplies]
	
	assert_eq(supplies, expected_supplies, message)

func assert_campaign_phase(campaign, expected_phase, message = ""):
	var phase = -1
	
	# Try several ways to get the phase value
	if campaign.has_method("get_phase"):
		phase = campaign.get_phase()
	elif campaign.has_method("get_campaign_phase"):
		phase = campaign.get_campaign_phase()
	elif "phase" in campaign:
		phase = campaign.phase
	elif campaign.has_meta("phase"):
		phase = campaign.get_meta("phase")
	
	if message.is_empty():
		message = "Campaign should be in phase %d but was in phase %d" % [expected_phase, phase]
	
	assert_eq(phase, expected_phase, message)

# Helpers for working with missions in campaigns
func create_test_mission():
	var MissionScript = load("res://src/core/mission/Mission.gd")
	if not MissionScript:
		push_warning("Mission script not found, using mock instead")
		return create_mock_mission()
		
	var mission = MissionScript.new()
	if not mission:
		push_error("Failed to create mission instance")
		return null
	
	track_test_resource(mission)
	return mission

func create_mock_mission():
	var mock_mission = Resource.new()
	mock_mission.set_meta("name", "Test Mission")
	mock_mission.set_meta("difficulty", 1)
	
	track_test_resource(mock_mission)
	return mock_mission

# Signal helpers with timeout handling
func wait_for_campaign_signal(campaign, signal_name, timeout = CAMPAIGN_TIMEOUT):
	if not campaign.has_signal(signal_name):
		push_warning("Campaign does not have signal %s" % signal_name)
		return false
		
	var signal_obj = Signal(campaign, signal_name)
	return await wait_for_signal(signal_obj, timeout)
    
# Campaign phase verification
func verify_campaign_phase_transition(campaign, from_phase, to_phase):
	if not is_instance_valid(campaign):
		push_error("Campaign is null")
		return
		
	var current_phase = -1
	if campaign.has_method("get_phase"):
		current_phase = campaign.get_phase()
	elif campaign.has_method("get_current_phase"):
		current_phase = campaign.get_current_phase()
	
	assert_eq(current_phase, from_phase, "Campaign should be in phase %d but was in phase %d" % [from_phase, current_phase])
	
	# Watch for phase change signals
	if campaign.has_signal("phase_changed"):
		watch_signals(campaign)
	
	# Attempt phase transition
	if campaign.has_method("set_phase"):
		campaign.set_phase(to_phase)
	
	# Verify the phase changed
	if campaign.has_method("get_phase"):
		current_phase = campaign.get_phase()
	elif campaign.has_method("get_current_phase"):
		current_phase = campaign.get_current_phase()
		
	assert_eq(current_phase, to_phase, "Campaign should be in phase %d but was in phase %d" % [to_phase, current_phase])
	
	if campaign.has_signal("phase_changed"):
		verify_signal_emitted(campaign, "phase_changed")