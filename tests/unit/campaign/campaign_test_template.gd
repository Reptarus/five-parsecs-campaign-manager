@tool
extends "res://tests/fixtures/specialized/campaign_test.gd"

# Override this comment with a description of your campaign test
# Test class for testing specific campaign functionality

# Test variables (with explicit types)
var _test_mission = null
var _test_crew = []
var _campaign_resources = {}

# Campaign test configuration
var _test_config = {
    "campaign_name": "Test Campaign",
    "credits": 1000,
    "supplies": 100,
    "reputation": 10
}

# Lifecycle methods
func before_each():
    await super.before_each()
    
    # Initialize test campaign objects and resources
    _setup_campaign_test_objects()
    
    await stabilize_engine()

func after_each():
    # Clean up test objects
    _test_mission = null
    _test_crew.clear()
    _campaign_resources.clear()
    
    await super.after_each()

# Helper methods
func _setup_campaign_test_objects():
    # Create a test mission
    _test_mission = create_test_mission()
    
    # Create test crew members
    for i in range(3):
        var crew_member = Resource.new()
        crew_member.set_meta("name", "Crew Member %d" % i)
        crew_member.set_meta("skill", 5 + i)
        _test_crew.append(crew_member)
        track_test_resource(crew_member)
    
    # Initialize test resources
    _campaign_resources = {
        "credits": _test_config.credits,
        "supplies": _test_config.supplies,
        "reputation": _test_config.reputation
    }
    
    # Set up the campaign with test values
    if _campaign:
        if _campaign.has_method("set_name"):
            _campaign.set_name(_test_config.campaign_name)
        
        if _campaign.has_method("set_credits"):
            _campaign.set_credits(_test_config.credits)
            
        if _campaign.has_method("set_supplies"):
            _campaign.set_supplies(_test_config.supplies)
            
        if _campaign.has_method("set_reputation"):
            _campaign.set_reputation(_test_config.reputation)

# Test methods - each method should start with "test_"
func test_campaign_initialization():
    # Skip test if campaign object is missing
    if not _campaign:
        push_warning("Campaign object missing, skipping test")
        pending("Test skipped - campaign object missing")
        return
    
    # Test campaign initialization
    assert_campaign_has_credits(_campaign, _test_config.credits)
    assert_campaign_has_supplies(_campaign, _test_config.supplies)
    
    # Test additional campaign properties
    if _campaign.has_method("get_reputation"):
        var reputation = _campaign.get_reputation()
        assert_eq(reputation, _test_config.reputation,
            "Campaign should have the expected reputation")
    
    if _campaign.has_method("get_name"):
        var name = _campaign.get_name()
        assert_eq(name, _test_config.campaign_name,
            "Campaign should have the expected name")

# Test method for campaign resource management
func test_campaign_resource_management():
    # Skip test if campaign object is missing
    if not _campaign:
        push_warning("Campaign object missing, skipping test")
        pending("Test skipped - campaign object missing")
        return
    
    # Test adding resources
    var added_credits = 100
    if _campaign.has_method("add_credits"):
        _campaign.add_credits(added_credits)
        var new_credits = _campaign.get_credits() if _campaign.has_method("get_credits") else 0
        assert_eq(new_credits, _test_config.credits + added_credits,
            "Campaign should correctly add credits")
    
    # Test spending resources
    var spent_supplies = 10
    if _campaign.has_method("spend_supplies"):
        _campaign.spend_supplies(spent_supplies)
        var new_supplies = _campaign.get_supplies() if _campaign.has_method("get_supplies") else 0
        assert_eq(new_supplies, _test_config.supplies - spent_supplies,
            "Campaign should correctly spend supplies")

# Test method for campaign phase transitions
func test_campaign_phase_transitions():
    # Skip test if campaign object is missing
    if not _campaign:
        push_warning("Campaign object missing, skipping test")
        pending("Test skipped - campaign object missing")
        return
    
    if not _campaign.has_method("set_phase") or not _campaign.has_method("get_phase"):
        push_warning("Campaign lacks phase methods, skipping test")
        pending("Test skipped - campaign lacks phase methods")
        return
    
    # Test phase transitions
    # Determine phases based on your campaign system
    # For example:
    var setup_phase = 0
    var exploration_phase = 1
    var combat_phase = 2
    var resolution_phase = 3
    
    # Set initial phase
    _campaign.set_phase(setup_phase)
    assert_campaign_phase(_campaign, setup_phase)
    
    # Test phase transition
    _campaign.set_phase(exploration_phase)
    assert_campaign_phase(_campaign, exploration_phase)
    
    # Test another phase transition
    _campaign.set_phase(combat_phase)
    assert_campaign_phase(_campaign, combat_phase)
    
    # Test final phase transition
    _campaign.set_phase(resolution_phase)
    assert_campaign_phase(_campaign, resolution_phase)

# Test method for campaign mission integration
func test_campaign_mission_integration():
    # Skip test if campaign or mission objects are missing
    if not _campaign or not _test_mission:
        push_warning("Campaign or mission objects missing, skipping test")
        pending("Test skipped - required objects missing")
        return
    
    # Test adding mission to campaign
    if _campaign.has_method("add_mission"):
        _campaign.add_mission(_test_mission)
        
        # Test mission retrieval if available
        if _campaign.has_method("get_current_mission"):
            var current_mission = _campaign.get_current_mission()
            assert_eq(current_mission, _test_mission,
                "Campaign should return the correct current mission")
        
        # Test mission completion if available
        if _campaign.has_method("complete_mission"):
            _campaign.complete_mission(_test_mission)
            
            # Test completed mission tracking if available
            if _campaign.has_method("get_completed_missions"):
                var completed_missions = _campaign.get_completed_missions()
                assert_true(completed_missions.has(_test_mission),
                    "Campaign should track completed missions")