@tool
extends RefCounted
class_name SimpleCampaign

## Simple Five Parsecs Campaign Data Manager
## Consolidates all Enhanced functionality into a simple, unified system
## No complex state machines, performance monitors, or architectural bloat

# Core campaign data - simple dictionary-based storage
var campaign_data: Dictionary = {
	"name": "",
	"turn": 1,
	"story_points": 1,
	"crew": [],
	"ship": {},
	"credits": 0,
	"debt": 0,
	"current_world": "",
	"phase": "upkeep"
}

# Planet database - consolidated from Enhanced system
var planet_database: Dictionary = {}

# Mission history - simplified from Enhanced system  
var mission_history: Array[Dictionary] = []

# Essential signals for UI communication
signal campaign_data_updated(data: Dictionary)
signal planet_discovered(planet_name: String, data: Dictionary) 
signal mission_completed(mission_data: Dictionary)
signal crew_status_changed(crew_data: Array)
signal credits_changed(credits: int, debt: int)

func _init() -> void:
	_initialize_default_data()

## Initialize default campaign data
func _initialize_default_data() -> void:
	# Simple ship data structure
	campaign_data["ship"] = {
		"name": "Default Ship",
		"hull": 6,
		"debt": 0,
		"components": []
	}


## Add crew member to campaign
func add_crew_member(character_data: Dictionary) -> void:
	campaign_data["crew"].append(character_data)
	crew_status_changed.emit(campaign_data["crew"])
	campaign_data_updated.emit(campaign_data)

## Update credits and debt
func update_credits(credits: int, debt: int = 0) -> void:
	campaign_data["credits"] = credits
	campaign_data["debt"] = debt
	credits_changed.emit(credits, debt)
	campaign_data_updated.emit(campaign_data)

## Log mission completion
func log_mission(mission_data: Dictionary) -> void:
	mission_history.append(mission_data)
	mission_completed.emit(mission_data)
	campaign_data_updated.emit(campaign_data)

## Add or update planet in database
func update_planet_data(planet_name: String, planet_data: Dictionary) -> void:
	planet_database[planet_name] = planet_data
	planet_discovered.emit(planet_name, planet_data)

## Get current campaign state for saving
func get_campaign_state() -> Dictionary:
	return {
		"campaign_data": campaign_data,
		"planet_database": planet_database,
		"mission_history": mission_history
	}

## Load campaign state from save
func load_campaign_state(state: Dictionary) -> void:
	if state.has("campaign_data"):
		campaign_data = state["campaign_data"]
	if state.has("planet_database"):
		planet_database = state["planet_database"]
	if state.has("mission_history"):
		mission_history = state["mission_history"]

	campaign_data_updated.emit(campaign_data)

## Advance to next turn
func advance_turn() -> void:
	campaign_data["turn"] += 1
	campaign_data["phase"] = "upkeep"  # Reset to first phase
	campaign_data_updated.emit(campaign_data)

## Get current phase
func get_current_phase() -> String:
	return campaign_data["phase"]

## Set campaign phase
func set_phase(phase: String) -> void:
	campaign_data["phase"] = phase
	campaign_data_updated.emit(campaign_data)