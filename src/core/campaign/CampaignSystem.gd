@tool
extends Node

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsCampaign = preload("res://src/game/campaign/FiveParsecsCampaign.gd")
const Campaign = preload("res://src/core/campaign/Campaign.gd")
const GameState = preload("res://src/core/state/GameState.gd")

## Signals
signal campaign_created(campaign)
signal campaign_loaded(campaign)
signal campaign_saved(save_data: Dictionary)
signal campaign_deleted(campaign_id: String)
signal story_progressed(progress: int)
signal resources_changed(total_resources: int)
signal reputation_changed(reputation: int)
signal missions_completed(completed_missions: int)

## Mission signals
signal mission_created(mission: Node)
signal mission_started() # No arguments
signal mission_setup_complete() # No arguments
signal mission_completed(success: bool)

## Variables
var campaign_type: int = GameEnums.FiveParcsecsCampaignType.STANDARD
var total_resources: int = 0
var reputation: int = 0
var completed_missions: int = 0
var active_crew: Array[Dictionary] = []
var active_rivals: Array[Dictionary] = []
var equipment: Array[Dictionary] = []
var story_progress: int = 0
var active_campaign = null
var game_state: GameState = null

## Mission state
var current_mission: Node = null
var mission_in_progress: bool = false

## Constructor
func _init(state: GameState = null) -> void:
	game_state = state if state else GameState.new()
	if not game_state:
		push_error("Failed to initialize GameState")
		return

## Initialize the campaign system with a game state
## Returns true if initialization was successful, false otherwise
## @param state The game state to initialize with
## @return Whether initialization was successful
func initialize(state) -> bool:
	# Strong type checking for GameState
	if state == null:
		push_error("Cannot initialize with null game state")
		return false
		
	if not is_instance_valid(state):
		push_error("Cannot initialize with invalid game state object")
		return false
	
	# Check if state is the expected type
	if not (state is GameState or (state.get_script() != null and state.get_script() == GameState)):
		push_error("Invalid GameState object type provided to initialize")
		return false
		
	# Store the valid game state
	game_state = state
	
	# Load active campaign from game state if it exists
	if game_state.current_campaign:
		active_campaign = game_state.current_campaign
		campaign_loaded.emit(active_campaign)
	
	return true

## Get the total number of completed missions
## @return The number of completed missions
func get_completed_missions_count() -> int:
	return completed_missions

## Get the total resources
## @return The total resources
func get_total_resources() -> int:
	return total_resources

## Get current reputation
## @return Current reputation
func get_reputation() -> int:
	return reputation

## Get number of active crew members
## @return Number of active crew members
func get_active_crew_count() -> int:
	return active_crew.size()

## Get number of active rivals
## @return Number of active rivals
func get_active_rivals_count() -> int:
	return active_rivals.size()

## Check if crew has exploration capability
## @return Whether any crew member has exploration
func has_exploration_capability() -> bool:
	for crew_member in active_crew:
		# Replace .has() with 'in' operator for Godot 4.4 compatibility
		if "exploration" in crew_member.get("skills", []):
			return true
	return false

## Check if crew has advanced equipment
## @return Whether any equipment is advanced
func has_advanced_equipment() -> bool:
	for item in equipment:
		if item.get("tier", 0) >= 2:
			return true
	return false

## Check if there is story progress
## @return Whether story progress exists
func has_story_progress() -> bool:
	return story_progress > 0

## Add resources
## @param amount Amount of resources to add
func add_resources(amount: int) -> void:
	total_resources += amount
	resources_changed.emit(total_resources)

## Add reputation
## @param amount Amount of reputation to add
func add_reputation(amount: int) -> void:
	reputation += amount
	reputation_changed.emit(reputation)

## Complete a mission
func complete_mission() -> void:
	completed_missions += 1
	missions_completed.emit(completed_missions)

## Add crew member
## @param member Crew member data to add
func add_crew_member(member: Dictionary) -> void:
	active_crew.append(member)

## Add rival
## @param rival Rival data to add
func add_rival(rival: Dictionary) -> void:
	active_rivals.append(rival)

## Add equipment
## @param item Equipment data to add
func add_equipment(item: Dictionary) -> void:
	equipment.append(item)

## Advance story progress
func advance_story() -> void:
	story_progress += 1
	story_progressed.emit(story_progress)

## Create a new campaign
## @param config Campaign configuration parameters
## @return The created campaign instance
func create_campaign(config: Dictionary) -> Object:
	var campaign = FiveParsecsCampaign.new()
	
	# Add null checks for safety
	if not is_instance_valid(campaign):
		push_error("Failed to create FiveParsecsCampaign instance")
		return null
		
	campaign.campaign_name = config.get("name", "New Campaign")
	campaign.campaign_difficulty = config.get("difficulty", GameEnums.DifficultyLevel.NORMAL)
	
	# Use type-safe property assignment with fallback to dictionary
	_set_campaign_property(campaign, "victory_condition",
		config.get("victory_condition", GameEnums.FiveParcsecsCampaignVictoryType.STANDARD))
	
	_set_campaign_property(campaign, "crew_size",
		config.get("crew_size", GameEnums.CrewSize.FOUR))
	
	_set_campaign_property(campaign, "use_story_track",
		config.get("use_story_track", true))
	
	active_campaign = campaign
	campaign_created.emit(campaign)
	return campaign

## Helper function to set a campaign property, using method if available or falling back to property dictionary
## @param campaign The campaign to set property on
## @param property_name The name of the property to set
## @param value The value to set
func _set_campaign_property(campaign, property_name: String, value) -> void:
	if campaign == null:
		push_error("Cannot set property on null campaign")
		return
		
	# Try to use setter method if available
	var setter_method = "set_" + property_name
	if campaign.has_method(setter_method):
		campaign.call(setter_method, value)
		return
	
	# Try direct property assignment as fallback
	if property_name in campaign:
		campaign.set(property_name, value)
		return
		
	# Final fallback: use properties dictionary if it exists or can be created
	# Check for properties as a direct property
	if not "properties" in campaign:
		# Create the properties dictionary directly
		var properties_dict = {}
		campaign.set("properties", properties_dict)
		# Store the value
		properties_dict[property_name] = value
		return
	
	# Get a reference to the properties dictionary if it exists
	var properties = campaign.get("properties")
	
	# Validate the dictionary
	if properties == null:
		# Try creating a new properties dictionary
		var new_properties = {}
		campaign.set("properties", new_properties)
		new_properties[property_name] = value
		return
	
	if not properties is Dictionary:
		push_error("Properties is not a dictionary")
		# Convert it to a dictionary if possible
		var new_properties = {}
		new_properties[property_name] = value
		campaign.set("properties", new_properties)
		return
		
	# Finally, set the property in the dictionary
	properties[property_name] = value

## Load an existing campaign from save data
## @param save_data The save data to load
## @return The loaded campaign instance
func load_campaign(save_data: Dictionary) -> Object:
	var campaign = FiveParsecsCampaign.new()
	
	# Add null check
	if not is_instance_valid(campaign):
		push_error("Failed to create FiveParsecsCampaign instance")
		return null
		
	# Add error handling for deserialize
	var deserialize_result = campaign.deserialize(save_data)
	if not deserialize_result.get("success", false):
		push_error("Failed to deserialize campaign: " + deserialize_result.get("message", "Unknown error"))
		return null
		
	active_campaign = campaign
	campaign_loaded.emit(campaign)
	return campaign

## Save the current campaign
func save_campaign() -> void:
	if not active_campaign:
		push_error("No active campaign to save")
		return
		
	if not is_instance_valid(active_campaign):
		push_error("Active campaign is not a valid instance")
		return
	
	var save_data = active_campaign.serialize()
	campaign_saved.emit(save_data)

## Delete a campaign
## @param campaign_id ID of the campaign to delete
func delete_campaign(campaign_id: String) -> void:
	if not campaign_id:
		push_error("Invalid campaign ID")
		return
	
	# Add deletion logic here
	campaign_deleted.emit(campaign_id)

## Get the active campaign with safety checks
## @return The active campaign instance or null if none/invalid
func get_active_campaign() -> Object:
	if not active_campaign:
		return null
		
	if not is_instance_valid(active_campaign):
		push_error("Active campaign is not a valid instance")
		active_campaign = null
		return null
		
	return active_campaign

## Cleanup resources when the node exits the tree
func _exit_tree() -> void:
	if is_instance_valid(game_state):
		if not game_state.is_queued_for_deletion() and game_state.get_parent() == null:
			game_state.queue_free()
	game_state = null
	active_campaign = null

## Start a new mission with proper error handling
func start_mission() -> void:
	if not game_state or not active_campaign:
		push_error("Cannot start mission without active campaign")
		return
		
	if not is_instance_valid(game_state) or not is_instance_valid(active_campaign):
		push_error("Game state or active campaign is not a valid instance")
		return
	
	if mission_in_progress:
		push_error("Cannot start new mission while another is in progress")
		return
	
	# Create and setup mission
	# Mission creation logic here...
	mission_in_progress = true
	mission_started.emit()

## End current mission
func end_mission(success: bool = true) -> void:
	if not mission_in_progress:
		push_error("No mission in progress to end")
		return
	
	mission_in_progress = false
	mission_completed.emit(success)
	
	if current_mission:
		current_mission.queue_free()
		current_mission = null

## Get current mission phase
func get_mission_phase() -> int:
	if not current_mission:
		return GameEnums.BattlePhase.NONE
	return current_mission.get_meta("phase", GameEnums.BattlePhase.NONE)

## Set mission phase
func set_mission_phase(phase: int) -> void:
	if current_mission:
		current_mission.set_meta("phase", phase)

## Check if mission is in progress
func is_mission_in_progress() -> bool:
	return mission_in_progress

## Get current mission
func get_current_mission() -> Node:
	return current_mission
