extends Control

## Main Campaign Scene - Root Campaign Experience Orchestrator
## Manages the complete Five Parsecs campaign flow from creation to completion

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
	"""Initialize main campaign scene"""
	_setup_ui_components()
	_connect_campaign_signals()
	_validate_dependencies()
	
	print("MainCampaignScene: Initialized successfully")

func _setup_ui_components() -> void:
	"""Configure main UI components"""
	if error_display:
		error_display.hide()
	
	# Setup responsive layout
	_configure_responsive_layout()

func _configure_responsive_layout() -> void:
	"""Configure responsive layout for different screen sizes"""
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
	"""Connect to campaign system signals"""
	if campaign_turn_controller:
		campaign_turn_controller.campaign_turn_started.connect(_on_campaign_turn_started)
		campaign_turn_controller.campaign_turn_completed.connect(_on_campaign_turn_completed)
		campaign_turn_controller.phase_transition_started.connect(_on_phase_transition_started)
		campaign_turn_controller.phase_transition_completed.connect(_on_phase_transition_completed)
	
	# Connect to global campaign signals
	if CampaignManager:
		CampaignManager.campaign_state_changed.connect(_on_campaign_state_changed)
	
	if GameState:
		GameState.game_state_changed.connect(_on_game_state_changed)

func _validate_dependencies() -> void:
	"""Validate required dependencies are available"""
	var missing_deps = []
	
	if not campaign_turn_controller:
		missing_deps.append("CampaignTurnController")
	
	if not CampaignManager:  # From autoload
		missing_deps.append("CampaignManager autoload")
	
	if not GameState:  # From autoload
		missing_deps.append("GameState autoload")
	
	if missing_deps.size() > 0:
		var error_msg = "Missing dependencies: " + ", ".join(missing_deps)
		_show_error(error_msg)
		campaign_error.emit(error_msg)

## Public Interface

func start_new_campaign(campaign_data: Dictionary) -> void:
	"""Start a new Five Parsecs campaign"""
	print("MainCampaignScene: Starting new campaign - %s" % campaign_data.get("name", "Unnamed"))
	
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
	"""Load an existing campaign from save data"""
	print("MainCampaignScene: Loading existing campaign")
	
	current_campaign = _restore_campaign_from_save(save_data)
	campaign_active = true
	
	# Restore campaign state
	_restore_campaign_state(save_data)
	
	# Show campaign interface
	_show_campaign_interface()
	
	campaign_started.emit(save_data)

func end_campaign(reason: String = "completed") -> void:
	"""End the current campaign"""
	print("MainCampaignScene: Ending campaign - %s" % reason)
	
	var final_results = _calculate_final_results()
	campaign_active = false
	
	# Save final campaign state
	_save_final_campaign_state()
	
	# Clean up campaign systems
	_cleanup_campaign_systems()
	
	campaign_ended.emit(final_results)

## Private Methods

func _create_campaign_resource(campaign_data: Dictionary) -> Resource:
	"""Create a new campaign resource from creation data"""
	# Future: Create proper Campaign resource class
	var campaign_resource = Resource.new()
	campaign_resource.set_meta("name", campaign_data.get("name", "New Campaign"))
	campaign_resource.set_meta("difficulty", campaign_data.get("difficulty", "Standard"))
	campaign_resource.set_meta("victory_condition", campaign_data.get("victory_condition", "Standard"))
	campaign_resource.set_meta("created_date", Time.get_datetime_string_from_system())
	
	return campaign_resource

func _restore_campaign_from_save(save_data: Dictionary) -> Resource:
	"""Restore campaign resource from save data"""
	# Future: Implement proper save/load system
	var campaign_resource = Resource.new()
	
	for key in save_data:
		campaign_resource.set_meta(key, save_data[key])
	
	return campaign_resource

func _initialize_campaign_systems(campaign_data: Dictionary) -> void:
	"""Initialize all campaign-related systems"""
	# Initialize game state
	if GameState:
		GameState.initialize_new_campaign(campaign_data)
	
	# Initialize campaign manager
	if CampaignManager:
		CampaignManager.start_new_campaign(campaign_data)
	
	# Initialize character system
	if CharacterManagerAutoload:
		CharacterManagerAutoload.initialize_for_campaign(campaign_data)

func _restore_campaign_state(save_data: Dictionary) -> void:
	"""Restore campaign state from save data"""
	if GameState:
		GameState.restore_from_save(save_data)
	
	if CampaignManager:
		CampaignManager.restore_from_save(save_data)

func _show_campaign_interface() -> void:
	"""Show the main campaign interface"""
	if campaign_turn_controller:
		campaign_turn_controller.show()
	
	if campaign_header:
		campaign_header.show()
		_update_campaign_header()
	
	if campaign_sidebar:
		campaign_sidebar.show()
		_update_campaign_sidebar()

func _update_campaign_header() -> void:
	"""Update campaign header with current information"""
	# Future: Update with actual campaign data
	print("MainCampaignScene: Updated campaign header")

func _update_campaign_sidebar() -> void:
	"""Update campaign sidebar with current status"""
	# Future: Update with actual campaign status
	print("MainCampaignScene: Updated campaign sidebar")

func _calculate_final_results() -> Dictionary:
	"""Calculate final campaign results"""
	return {
		"campaign_name": current_campaign.get_meta("name", "Unknown") if current_campaign else "Unknown",
		"turns_completed": GameState.get_campaign_turn() if GameState else 0,
		"victory_achieved": false,  # Future: Check actual victory conditions
		"final_crew_size": 4,  # Future: Get actual crew size
		"credits_earned": 1000,  # Future: Get actual credits
		"completion_date": Time.get_datetime_string_from_system()
	}

func _save_final_campaign_state() -> void:
	"""Save final campaign state for history/statistics"""
	if SaveManager:
		var final_state = {
			"campaign_data": current_campaign.get_meta_list() if current_campaign else {},
			"final_results": _calculate_final_results(),
			"game_state": GameState.serialize() if GameState else {}
		}
		SaveManager.save_campaign_completion(final_state)

func _cleanup_campaign_systems() -> void:
	"""Clean up campaign systems when ending"""
	current_campaign = null
	
	# Future: Clean up other systems as needed
	print("MainCampaignScene: Campaign systems cleaned up")

func _show_error(message: String) -> void:
	"""Display error message to user"""
	print("MainCampaignScene ERROR: %s" % message)
	
	if error_display:
		error_display.show_error(message)
		error_display.show()

## Signal Handlers

func _on_campaign_turn_started(turn_number: int) -> void:
	"""Handle campaign turn start"""
	print("MainCampaignScene: Campaign turn %d started" % turn_number)
	_update_campaign_header()

func _on_campaign_turn_completed(turn_number: int) -> void:
	"""Handle campaign turn completion"""
	print("MainCampaignScene: Campaign turn %d completed" % turn_number)
	_update_campaign_header()

func _on_phase_transition_started(from_phase: String, to_phase: String) -> void:
	"""Handle phase transition start"""
	print("MainCampaignScene: Phase transition %s -> %s" % [from_phase, to_phase])

func _on_phase_transition_completed(phase: String) -> void:
	"""Handle phase transition completion"""
	print("MainCampaignScene: Phase %s completed" % phase)
	_update_campaign_sidebar()

func _on_campaign_state_changed(state_data: Dictionary) -> void:
	"""Handle campaign state changes"""
	_update_campaign_header()
	_update_campaign_sidebar()

func _on_game_state_changed(state_data: Dictionary) -> void:
	"""Handle game state changes"""
	_update_campaign_header()

## Viewport and Input Handling

func _on_viewport_size_changed() -> void:
	"""Handle viewport size changes for responsive design"""
	_configure_responsive_layout()

func _input(event: InputEvent) -> void:
	"""Handle global input events"""
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				# Future: Show pause/exit menu
				print("MainCampaignScene: Escape pressed - pause menu")
			KEY_F1:
				# Future: Show help
				print("MainCampaignScene: F1 pressed - help")
			KEY_F5:
				# Quick save
				if SaveManager and campaign_active:
					SaveManager.quick_save()
					print("MainCampaignScene: Quick save performed")
