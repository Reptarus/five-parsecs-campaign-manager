extends Control

## Main Campaign Scene - Root Campaign Experience Orchestrator
## Manages the complete Five Parsecs campaign flow from creation to completion

# FIX 1: Safe autoload references using AutoloadManager
var CampaignManager: Node
var CharacterManagerAutoload: Node
var GameState: Node

# Core UI Components
@onready var campaign_turn_controller: Control = %CampaignTurnController
@onready var campaign_header: Control = %CampaignHeader
@onready var campaign_sidebar: Control = %CampaignSidebar
@onready var error_display: Control = %ErrorDisplay

# Campaign State
var current_campaign: Resource = null
var campaign_active: bool = false

# Signals
signal campaign_started(campaign_data: Dictionary)
signal campaign_ended(final_results: Dictionary)
signal campaign_error(error_message: String)

func _ready() -> void:
	## Initialize main campaign scene
	# FIX 1: Initialize autoloads safely first
	_initialize_autoloads()
	
	_setup_ui_components()
	_connect_campaign_signals()
	_validate_dependencies()
	
	# Check for pending campaign data from creation
	_check_for_pending_campaign_data()
	

func _initialize_autoloads() -> void:
	## FIX 1: Initialize all autoloads safely using AutoloadManager
	if AutoloadManager:
		GameState = AutoloadManager.get_autoload_safe("GameState")
		CampaignManager = AutoloadManager.get_autoload_safe("CampaignManager")
		CharacterManagerAutoload = AutoloadManager.get_autoload_safe("CharacterManagerAutoload") 
	else:
		push_warning("MainCampaignScene: AutoloadManager not available, using direct references")
		# Fallback to direct access (may fail)
		GameState = get_node_or_null("/root/GameState")
		CampaignManager = get_node_or_null("/root/CampaignManager")
		CharacterManagerAutoload = get_node_or_null("/root/CharacterManagerAutoload")

func _setup_ui_components() -> void:
	## Configure main UI components
	if error_display:
		error_display.hide()
	
	# Setup responsive layout
	_configure_responsive_layout()

func _configure_responsive_layout() -> void:
	## Configure responsive layout for different screen sizes
	var viewport_size = get_viewport().size
	
	# Adjust layout based on screen size
	if viewport_size.x < 1024:
		# Mobile/tablet layout
		if campaign_sidebar:
			campaign_sidebar.hide()
	else:
		# Desktop layout
		if campaign_sidebar:
			campaign_sidebar.show()

func _connect_campaign_signals() -> void:
	## Connect to campaign system signals
	if campaign_turn_controller:
		campaign_turn_controller.campaign_turn_started.connect(_on_campaign_turn_started)
		campaign_turn_controller.campaign_turn_completed.connect(_on_campaign_turn_completed)
		campaign_turn_controller.phase_transition_started.connect(_on_phase_transition_started)
		campaign_turn_controller.phase_transition_completed.connect(_on_phase_transition_completed)
	
	# Connect to global campaign signals
	if CampaignManager:
		CampaignManager.campaign_state_changed.connect(_on_campaign_state_changed)
	
	# Connect to GameState (now safely initialized)
	if GameState:
		GameState.game_state_changed.connect(_on_game_state_changed)
	
	# SPRINT 6.1: Connect to campaign creation completion signal
	_connect_to_campaign_creation_ui()

func _validate_dependencies() -> void:
	## Validate required dependencies are available
	var missing_deps = []
	
	if not campaign_turn_controller:
		missing_deps.append("CampaignTurnController")
	
	if not CampaignManager: # From autoload
		missing_deps.append("CampaignManager autoload")
	
	if not GameState: # From autoload
		missing_deps.append("GameState autoload")
	
	if missing_deps.size() > 0:
		var error_msg = "Missing dependencies: " + ", ".join(missing_deps)
		_show_error(error_msg)
		campaign_error.emit(error_msg)

func _check_for_pending_campaign_data() -> void:
	## Check for campaign data passed from creation scene
	## SPRINT 26.23: Check for finalized Resource first, then fall back to dictionary"""
	##
	## # SPRINT 26.23: Check for finalized Campaign resource first (preferred path)
	## if GameState and GameState.has_meta("pending_campaign_resource"):
	## var campaign_resource = GameState.get_meta("pending_campaign_resource")
	## var save_path = GameState.get_meta("pending_campaign_save_path", "")
	## GameState.set_meta("pending_campaign_resource", null)
	## GameState.set_meta("pending_campaign_save_path", null)
	##
	## if campaign_resource and campaign_resource is Resource:
	## print("MainCampaignScene: Received finalized campaign resource")
	## _start_with_campaign_resource(campaign_resource, save_path)
	## return
	##
	## # Legacy fallback: Dictionary-based handoff
	## if GameState and GameState.has_meta("pending_campaign_data"):
	## var campaign_data = GameState.get_meta("pending_campaign_data")
	## GameState.set_meta("pending_campaign_data", null) # Clear after use
	##
	## push_warning("MainCampaignScene: Using legacy dictionary handoff - prefer resource")
	## print("MainCampaignScene: Found pending campaign data, starting new campaign")
	## start_new_campaign(campaign_data)
	## else:
	## print("MainCampaignScene: No pending campaign data, ready for manual campaign load")
	##
	pass

func _start_with_campaign_resource(campaign: Resource, save_path: String) -> void:
	## SPRINT 26.23: New method for resource-based handoff
	current_campaign = campaign
	campaign_active = true

	# Initialize systems with the resource directly
	_initialize_campaign_systems_from_resource(campaign)

	# Show campaign interface
	_show_campaign_interface()

	# Hand off to CampaignPhaseManager
	var cpm = get_node_or_null("/root/CampaignPhaseManager")
	if cpm and cpm.has_method("set_campaign"):
		cpm.set_campaign(campaign)

	# Start first campaign turn
	if campaign_turn_controller:
		campaign_turn_controller.start_new_campaign_turn()

	# Emit signal with dictionary for compatibility
	campaign_started.emit(campaign.to_dictionary() if campaign.has_method("to_dictionary") else {})

func _initialize_campaign_systems_from_resource(campaign: Resource) -> void:
	## Initialize systems using the finalized campaign resource
	## SPRINT 26.23: New method for resource-based initialization"""
	##
	## # Set current campaign in GameState
	## if GameState and GameState.has_method("set_current_campaign"):
	## GameState.set_current_campaign(campaign)
	## print("MainCampaignScene: GameState.set_current_campaign() called")
	## elif GameState:
	## GameState.current_campaign = campaign
	## print("MainCampaignScene: GameState.current_campaign set directly")
	##
	## # Sync to GameStateManager
	## if GameStateManager:
	## # Sync crew members
	## if campaign.has_method("get_crew_members"):
	## var crew = campaign.get_crew_members()
	## if GameStateManager.has_method("set_crew"):
	## GameStateManager.set_crew(crew)
	## print("MainCampaignScene: Crew synced to GameStateManager (%d members)" % crew.size())
	##
	## # Sync resources/credits
	## if campaign.has_method("get_resources"):
	## var resources = campaign.get_resources()
	## GameStateManager.set_credits(resources.get("credits", 0))
	## print("MainCampaignScene: Credits synced to GameStateManager: %d" % resources.get("credits", 0))
	##
	## # Initialize CampaignManager if available
	## if CampaignManager and CampaignManager.has_method("set_campaign"):
	## CampaignManager.set_campaign(campaign)
	## print("MainCampaignScene: CampaignManager received campaign")
	pass

## SPRINT 6.1: Campaign Creation Signal Integration

func _connect_to_campaign_creation_ui() -> void:
	
	# Try to find CampaignCreationUI scene if it exists in scene tree
	var creation_ui = _find_campaign_creation_ui()
	if creation_ui and creation_ui.has_signal("campaign_completion_ready"):
		creation_ui.campaign_completion_ready.connect(_on_campaign_creation_completed)
	else:
		pass

func _find_campaign_creation_ui() -> Node:
	## Find CampaignCreationUI in scene tree
	# Check common paths where CampaignCreationUI might be located
	var search_paths = [
		"/root/CampaignCreationUI",
		"../CampaignCreationUI",
		"CampaignCreationUI"
	]
	
	for path in search_paths:
		var node = get_node_or_null(path)
		if node:
			return node
	
	# Search entire scene tree as fallback
	return _search_tree_for_type("CampaignCreationUI")

func _search_tree_for_type(type_name: String) -> Node:
	## Recursively search scene tree for node of specific type
	return _recursive_search(get_tree().root, type_name)

func _recursive_search(node: Node, type_name: String) -> Node:
	## Recursive helper for tree search
	if node.name.contains(type_name):
		return node
	
	for child in node.get_children():
		var result = _recursive_search(child, type_name)
		if result:
			return result
	
	return null

func _on_campaign_creation_completed(campaign_data: Dictionary) -> void:
	## Handle campaign creation completion signal
	# Store campaign data for immediate transition
	if GameState:
		GameState.set_meta("pending_campaign_data", campaign_data)
	
	# Immediately start the new campaign
	start_new_campaign(campaign_data)

## Public Interface

func start_new_campaign(campaign_data: Dictionary) -> void:
	## Start a new Five Parsecs campaign
	current_campaign = _create_campaign_resource(campaign_data)
	campaign_active = true
	
	# Initialize campaign systems
	_initialize_campaign_systems(campaign_data)
	
	# Show campaign interface
	_show_campaign_interface()
	
	# Start first campaign turn
	if campaign_turn_controller:
		campaign_turn_controller.start_new_campaign_turn()
	
	campaign_started.emit(campaign_data)

func load_existing_campaign(save_data: Dictionary) -> void:
	## Load an existing campaign from save data
	
	current_campaign = _restore_campaign_from_save(save_data)
	campaign_active = true
	
	# Restore campaign state
	_restore_campaign_state(save_data)
	
	# Show campaign interface
	_show_campaign_interface()
	
	campaign_started.emit(save_data)

func end_campaign(reason: String = "completed") -> void:
	## End the current campaign
	
	var final_results = _calculate_final_results()
	campaign_active = false
	
	# Save final campaign state
	_save_final_campaign_state()
	
	# Clean up campaign systems
	_cleanup_campaign_systems()
	
	campaign_ended.emit(final_results)

## Private Methods

func _create_campaign_resource(campaign_data: Dictionary) -> Resource:
	## Create a new campaign resource from creation data
	# SPRINT 6.2: Use proper FiveParsecsCampaign class with initialize_from_dict
	var campaign_resource = preload("res://src/core/campaign/Campaign.gd").new()
	
	# Initialize using the new method that understands campaign creation data
	campaign_resource.initialize_from_dict(campaign_data)
	
	return campaign_resource

func _restore_campaign_from_save(save_data: Dictionary) -> Resource:
	## Restore campaign resource from save data
	# Future: Implement proper save/load system
	var campaign_resource = Resource.new()
	
	for key in save_data:
		campaign_resource.set_meta(key, save_data[key])
	
	return campaign_resource

func _initialize_campaign_systems(campaign_data: Dictionary) -> void:
	## Initialize all campaign-related systems
	# Initialize game state with campaign data
	if GameState and GameState.has_method("initialize_new_campaign"):
		GameState.initialize_new_campaign(campaign_data)
	else:
		push_warning("MainCampaignScene: GameState.initialize_new_campaign() not available")

	# Pass campaign reference to CampaignPhaseManager for phase handlers
	var cpm = get_node_or_null("/root/CampaignPhaseManager")
	if cpm and cpm.has_method("set_campaign"):
		# Get the campaign resource from GameState (created by initialize_new_campaign)
		var campaign = null
		if GameState and GameState.has_method("get_current_campaign"):
			campaign = GameState.get_current_campaign()

		if campaign:
			cpm.set_campaign(campaign)
		else:
			# Fallback: Use our local current_campaign resource
			if current_campaign:
				cpm.set_campaign(current_campaign)
			else:
				push_warning("MainCampaignScene: No campaign resource available for CampaignPhaseManager")
	else:
		push_warning("MainCampaignScene: CampaignPhaseManager.set_campaign() not available")

	# Initialize campaign manager
	if CampaignManager and CampaignManager.has_method("start_new_campaign"):
		CampaignManager.start_new_campaign(campaign_data)

	# Initialize character system
	if CharacterManagerAutoload and CharacterManagerAutoload.has_method("initialize_for_campaign"):
		CharacterManagerAutoload.initialize_for_campaign(campaign_data)

func _restore_campaign_state(save_data: Dictionary) -> void:
	## Restore campaign state from save data
	if GameState:
		GameState.restore_from_save(save_data)
	
	if CampaignManager:
		CampaignManager.restore_from_save(save_data)

func _show_campaign_interface() -> void:
	## Show the main campaign interface
	if campaign_turn_controller:
		campaign_turn_controller.show()
	
	if campaign_header:
		campaign_header.show()
		_update_campaign_header()
	
	if campaign_sidebar:
		campaign_sidebar.show()
		_update_campaign_sidebar()

func _update_campaign_header() -> void:
	## Update campaign header with current information
	# Future: Update with actual campaign data
	pass

func _update_campaign_sidebar() -> void:
	## Update campaign sidebar with current status
	# Future: Update with actual campaign status
	pass

func _calculate_final_results() -> Dictionary:
	## Calculate final campaign results
	return {
		"campaign_name": current_campaign.get_meta("name", "Unknown") if current_campaign else "Unknown",
		"turns_completed": GameState.get_campaign_turn() if GameState else 0,
		"victory_achieved": false, # Future: Check actual victory conditions
		"final_crew_size": 4, # Future: Get actual crew size
		"credits_earned": 0, # Future: Get actual credits from campaign state
		"completion_date": Time.get_datetime_string_from_system()
	}

func _save_final_campaign_state() -> void:
	## Save final campaign state for history/statistics
	pass

func _cleanup_campaign_systems() -> void:
	## Clean up campaign systems when ending
	current_campaign = null
	
	# Future: Clean up other systems as needed

func _show_error(message: String) -> void:
	## Display error message to user
	
	if error_display:
		error_display.show_error(message)
		error_display.show()

## Signal Handlers

func _on_campaign_turn_started(turn_number: int) -> void:
	## Handle campaign turn start
	_update_campaign_header()

func _on_campaign_turn_completed(turn_number: int) -> void:
	## Handle campaign turn completion
	_update_campaign_header()

func _on_phase_transition_started(from_phase: String, to_phase: String) -> void:
	## Handle phase transition start
	pass

func _on_phase_transition_completed(phase: String) -> void:
	## Handle phase transition completion
	_update_campaign_sidebar()

func _on_campaign_state_changed(state_data: Dictionary) -> void:
	## Handle campaign state changes
	_update_campaign_header()
	_update_campaign_sidebar()

func _on_game_state_changed(state_data: Dictionary) -> void:
	## Handle game state changes
	_update_campaign_header()

## Viewport and Input Handling

func _on_viewport_size_changed() -> void:
	## Handle viewport size changes for responsive design
	_configure_responsive_layout()

func _input(event: InputEvent) -> void:
	## Handle global input events
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				# Future: Show pause/exit menu
				pass
			KEY_F1:
				# Future: Show help
				pass
			KEY_PAGEUP:
				# PHASE 7: Enhanced Debug Tools - Crew Debug Information
				_show_crew_debug_info()

# PHASE 7: Enhanced Debug Tools Implementation
func _show_crew_debug_info() -> void:
	## Show comprehensive crew debug information (PageUp key)
	## Debug output removed for public release
	pass
