@tool
extends Resource
class_name FiveParsecsCampaign

# This file creates a mock FiveParsecsCampaign specifically for testing
# It provides the minimum functionality needed for tests without
# requiring the full implementation or dependencies

signal campaign_started
signal campaign_ended(victory: bool)
signal phase_changed(old_phase: int, new_phase: int)
signal resources_changed(resources: Dictionary)

# Common properties
var campaign_name: String = "Test Campaign"
var campaign_id: String = "test_campaign_id"
var campaign_type: int = 0
var campaign_difficulty: int = 0
var current_phase: int = 0
var resources: Dictionary = {"credits": 100, "supplies": 10, "story_progress": 0}

# Constructor
func _init(name: String = "Test Campaign") -> void:
    campaign_name = name
    # Generate unique ID for the campaign based on name and timestamp
    var timestamp = Time.get_unix_time_from_system()
    campaign_id = name.to_lower().replace(" ", "_") + "_" + str(timestamp)

# API methods used in tests
func get_campaign_id() -> String:
    return campaign_id

func get_campaign_name() -> String:
    return campaign_name

func get_difficulty() -> int:
    return campaign_difficulty

func start_campaign() -> void:
    campaign_started.emit()

func end_campaign(victory: bool = false) -> void:
    campaign_ended.emit(victory)

func set_current_phase(phase: int) -> void:
    var old_phase = current_phase
    current_phase = phase
    phase_changed.emit(old_phase, current_phase)

func add_resource(resource_type: String, amount: int) -> void:
    if resource_type in resources:
        resources[resource_type] += amount
    else:
        resources[resource_type] = amount
    resources_changed.emit(resources)

func remove_resource(resource_type: String, amount: int) -> bool:
    if not resource_type in resources:
        return false
        
    if resources[resource_type] < amount:
        return false
        
    resources[resource_type] -= amount
    resources_changed.emit(resources)
    return true

func get_resource(resource_type: String) -> int:
    return resources.get(resource_type, 0)

# Serialization methods
func serialize() -> Dictionary:
    return {
        "campaign_id": campaign_id,
        "name": campaign_name,
        "difficulty": campaign_difficulty,
        "resources": resources.duplicate(),
        "phase": current_phase
    }

func deserialize(data: Dictionary) -> Dictionary:
    if not data:
        return {"success": false, "message": "Invalid data"}
    
    if "campaign_id" in data:
        campaign_id = data.campaign_id
    
    if "name" in data:
        campaign_name = data.name
        
    if "difficulty" in data:
        campaign_difficulty = data.difficulty
        
    if "resources" in data:
        resources = data.resources.duplicate()
        
    if "phase" in data:
        current_phase = data.phase
        
    return {"success": true, "message": "Campaign data loaded successfully"}

# Helper method to create a test instance
static func create_test_campaign(name: String = "Test Campaign", difficulty: int = 1) -> FiveParsecsCampaign:
    var campaign = FiveParsecsCampaign.new(name)
    campaign.campaign_difficulty = difficulty
    campaign.resources = {
        "credits": 100,
        "supplies": 10,
        "story_progress": 0
    }
    return campaign

# For class compatibility during deserialization
func to_dict() -> Dictionary:
    return serialize()