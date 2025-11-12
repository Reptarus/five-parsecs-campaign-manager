extends Node
class_name FallbackCampaignManager

## FallbackCampaignManager - Emergency campaign system when autoload fails
## Provides minimal campaign functionality for campaign creation stability

signal campaign_created(campaign_data: Dictionary)
signal campaign_state_changed(state: Dictionary)

var current_campaign: Dictionary = {}
var game_state: Dictionary = {}
var is_fallback: bool = true

func _init():
	name = "FallbackCampaignManager"
	print("FallbackCampaignManager: Initialized with minimal functionality")

func create_new_campaign(campaign_data: Dictionary) -> bool:
	"""Create a new campaign with basic validation"""
	if campaign_data.is_empty():
		push_error("FallbackCampaignManager: Cannot create campaign with empty data")
		return false
	
	current_campaign = campaign_data.duplicate()
	game_state = _initialize_basic_game_state(campaign_data)
	
	print("FallbackCampaignManager: Created campaign: ", campaign_data.get("name", "Unknown"))
	campaign_created.emit(current_campaign)
	return true

func _initialize_basic_game_state(campaign_data: Dictionary) -> Dictionary:
	"""Initialize basic game state structure"""
	return {
		"campaign_name": campaign_data.get("name", "Emergency Campaign"),
		"turn": 0,
		"credits": campaign_data.get("starting_credits", 1000),
		"crew": campaign_data.get("crew", []),
		"ship": campaign_data.get("ship", {}),
		"location": campaign_data.get("starting_location", "Unknown World"),
		"story_points": 0,
		"patron_jobs": [],
		"rival_status": {},
		"victory_conditions": campaign_data.get("victory_conditions", [])
	}

func get_current_campaign() -> Dictionary:
	"""Get current campaign data"""
	return current_campaign

func get_game_state() -> Dictionary:
	"""Get current game state"""
	return game_state

func save_campaign() -> bool:
	"""Basic save functionality"""
	print("FallbackCampaignManager: Save requested (limited functionality)")
	return true

func load_campaign(campaign_name: String) -> bool:
	"""Basic load functionality"""
	print("FallbackCampaignManager: Load requested for: ", campaign_name)
	return false

func update_campaign_state(updates: Dictionary) -> void:
	"""Update campaign state"""
	for key in updates.keys():
		if game_state.has(key):
			game_state[key] = updates[key]
	
	campaign_state_changed.emit(game_state)

func is_campaign_active() -> bool:
	"""Check if a campaign is active"""
	return not current_campaign.is_empty()

func get_victory_progress() -> Dictionary:
	"""Get victory condition progress"""
	return {
		"conditions": [],
		"progress": 0.0,
		"completed": false
	}

# Compatibility for autoload interface
func is_fallback_manager() -> bool:
	return true