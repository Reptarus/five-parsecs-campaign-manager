class_name CampaignWorkflowOrchestrator
extends Control

## Production-Ready Campaign Creation Orchestrator
## Senior Dev Implementation: Lightweight scene coordination with bulletproof error handling
## Replaces monolithic CampaignCreationUI with composition pattern

# Import production classes
const CampaignFactory = preload("res://src/core/workflow/CampaignFactory.gd")
# ProductionSaveManager removed - file does not exist

# UI Components
@onready var loading_screen: ColorRect = $LoadingScreen
@onready var loading_label: Label = $LoadingScreen/CenterContainer/VBox/LoadingLabel
@onready var progress_bar: ProgressBar = $LoadingScreen/CenterContainer/VBox/ProgressBar
@onready var status_label: Label = $LoadingScreen/CenterContainer/VBox/StatusLabel
@onready var return_button: Button = $LoadingScreen/CenterContainer/VBox/ButtonContainer/ReturnButton
@onready var error_panel: Panel = $ErrorPanel
@onready var error_message: Label = $ErrorPanel/ErrorVBox/ErrorMessage
@onready var retry_button: Button = $ErrorPanel/ErrorVBox/ErrorButtons/RetryButton
@onready var main_menu_button: Button = $ErrorPanel/ErrorVBox/ErrorButtons/MainMenuButton

# Workflow state machine - explicit states prevent undefined behavior
enum WorkflowState {
	UNINITIALIZED,
	CONFIG_PHASE,
	CREW_PHASE,
	CHARACTER_PHASE,
	SHIP_PHASE,
	FINALIZING,
	COMPLETED,
	ERROR_STATE
}

# Production-grade error handling
enum WorkflowError {
	SCENE_LOAD_FAILED,
	DATA_VALIDATION_FAILED,
	SYSTEM_INITIALIZATION_FAILED,
	USER_CANCELLED,
	UNKNOWN_ERROR
}

# Workflow configuration - makes system behavior predictable
var workflow_scenes: Dictionary = {
	WorkflowState.CONFIG_PHASE: "res://src/ui/screens/campaign/panels/ExpandedConfigPanel.tscn",
	# WorkflowState.CREW_PHASE: DEPRECATED - CrewPanel (Step 3) handles crew creation in CampaignCreationUI wizard
	WorkflowState.CHARACTER_PHASE: "res://src/ui/screens/character/SimpleCharacterCreator.tscn",
	WorkflowState.SHIP_PHASE: "res://src/ui/screens/ships/ShipManager.tscn"
}

# State management - single source of truth
var current_state: WorkflowState = WorkflowState.UNINITIALIZED
var campaign_data: Dictionary = {}
var workflow_context: Dictionary = {}
var error_recovery_attempts: int = 0
const MAX_RECOVERY_ATTEMPTS: int = 3

# Production monitoring
signal workflow_step_completed(step: WorkflowState, data: Dictionary)
signal workflow_error(error: WorkflowError, details: String)
signal workflow_completed(campaign: Dictionary)

# Performance tracking
var step_start_time: float
var total_workflow_time: float

func _ready() -> void:
	## Initialize workflow orchestrator with comprehensive error handling
	_setup_ui_components()
	_initialize_workflow_system()

func _setup_ui_components() -> void:
	## Setup UI components and event handlers
	if error_panel:
		error_panel.hide()
	
	if return_button:
		return_button.pressed.connect(_return_to_main_menu)
		return_button.hide()
	
	if retry_button:
		retry_button.pressed.connect(_retry_workflow)
	
	if main_menu_button:
		main_menu_button.pressed.connect(_return_to_main_menu)
	
	if progress_bar:
		progress_bar.value = 0.0

func _initialize_workflow_system() -> void:
	## Production initialization with validation and fallback handling
	print("CampaignWorkflowOrchestrator: Initializing production workflow system...")
	_update_status("Initializing workflow system...")
	
	# Validate required scenes exist
	_update_status("Validating scene availability...")
	var validation_result = _validate_scene_availability()
	if not validation_result.success:
		_handle_initialization_error(validation_result.error_message)
		return
	
	# Initialize workflow context manager
	_update_status("Connecting to workflow context manager...")
	if not _initialize_context_manager():
		_handle_initialization_error("Failed to initialize workflow context")
		return
	
	# Setup production monitoring
	_update_status("Setting up workflow monitoring...")
	_setup_workflow_monitoring()
	
	# Start workflow
	_update_status("Starting campaign workflow...")
	current_state = WorkflowState.CONFIG_PHASE
	_start_workflow_step(current_state)
	
	print("CampaignWorkflowOrchestrator: ✅ Production workflow system initialized successfully")

func _validate_scene_availability() -> Dictionary:
	## Validate all required scenes are available before starting workflow
	var missing_scenes: Array[String] = []
	
	for state in workflow_scenes:
		var scene_path = workflow_scenes[state]
		if not FileAccess.file_exists(scene_path):
			missing_scenes.append(scene_path)
	
	if missing_scenes.is_empty():
		return {"success": true}
	else:
		return {
			"success": false,
			"error_message": "Missing required scenes: " + str(missing_scenes)
		}

func _initialize_context_manager() -> bool:
	## Initialize workflow context for data passing between scenes
	var context_manager = get_node_or_null("/root/WorkflowContextManager")
	if not context_manager:
		print("CampaignWorkflowOrchestrator: WorkflowContextManager not found in autoload")
		return false
	
	print("CampaignWorkflowOrchestrator: WorkflowContextManager found and available")
	return true

func _setup_workflow_monitoring() -> void:
	## Setup production monitoring and analytics
	workflow_step_completed.connect(_on_workflow_step_completed)
	workflow_error.connect(_on_workflow_error)
	workflow_completed.connect(_on_workflow_completed)
	
	total_workflow_time = Time.get_ticks_msec()

func _start_workflow_step(step: WorkflowState) -> void:
	## Start a workflow step with comprehensive error handling
	print("CampaignWorkflowOrchestrator: Starting workflow step: %s" % _get_state_name(step))
	
	step_start_time = Time.get_ticks_msec()
	current_state = step
	
	# Prepare context for the scene
	var context = {
		"workflow_step": step,
		"campaign_data": campaign_data.duplicate(),
		"completion_callback": _create_completion_callback(step),
		"error_callback": _create_error_callback(step)
	}
	
	# Pass context to context manager
	var context_manager = get_node("/root/WorkflowContextManager")
	context_manager.set_context(context)
	
	# Transition to scene
	var scene_path = workflow_scenes.get(step, "")
	if scene_path.is_empty():
		_handle_workflow_error(WorkflowError.SCENE_LOAD_FAILED, "No scene configured for step: " + _get_state_name(step))
		return
	
	_transition_to_scene(scene_path)

func _transition_to_scene(scene_path: String) -> void:
	## Production-safe scene transition with error handling
	if not FileAccess.file_exists(scene_path):
		_handle_workflow_error(WorkflowError.SCENE_LOAD_FAILED, "Scene file not found: " + scene_path)
		return
	
	# Log transition for debugging
	print("CampaignWorkflowOrchestrator: Transitioning to scene: %s" % scene_path)

	# Perform scene transition using standardized navigation
	GameStateManager.navigate_to_scene_path(scene_path)

func _create_completion_callback(step: WorkflowState) -> Callable:
	## Create completion callback for current workflow step
	match step:
		WorkflowState.CONFIG_PHASE:
			return _on_config_step_completed
		WorkflowState.CREW_PHASE:
			return _on_crew_step_completed
		WorkflowState.CHARACTER_PHASE:
			return _on_character_step_completed
		WorkflowState.SHIP_PHASE:
			return _on_ship_step_completed
		_:
			return _on_generic_step_completed

func _create_error_callback(step: WorkflowState) -> Callable:
	## Create error callback for current workflow step
	return func(error_details: String): _handle_step_error(step, error_details)

# Step completion handlers
func _on_config_step_completed(config_data: Dictionary) -> void:
	## Handle configuration step completion
	campaign_data["config"] = config_data
	_complete_workflow_step(WorkflowState.CONFIG_PHASE, config_data)
	_start_workflow_step(WorkflowState.CREW_PHASE)

func _on_crew_step_completed(crew_data: Dictionary) -> void:
	## Handle crew creation step completion
	campaign_data["crew"] = crew_data
	_complete_workflow_step(WorkflowState.CREW_PHASE, crew_data)
	_start_workflow_step(WorkflowState.CHARACTER_PHASE)

func _on_character_step_completed(character_data: Dictionary) -> void:
	## Handle character customization step completion
	campaign_data["characters"] = character_data
	_complete_workflow_step(WorkflowState.CHARACTER_PHASE, character_data)
	_start_workflow_step(WorkflowState.SHIP_PHASE)

func _on_ship_step_completed(ship_data: Dictionary) -> void:
	## Handle ship assignment step completion
	campaign_data["ship"] = ship_data
	_complete_workflow_step(WorkflowState.SHIP_PHASE, ship_data)
	_finalize_campaign()

func _on_generic_step_completed(step_data: Dictionary) -> void:
	## Generic step completion handler
	print("CampaignWorkflowOrchestrator: Generic step completed with data: %s" % step_data.keys())

func _complete_workflow_step(step: WorkflowState, data: Dictionary) -> void:
	## Mark workflow step as completed and emit monitoring signal
	var step_duration = Time.get_ticks_msec() - step_start_time
	print("CampaignWorkflowOrchestrator: ✅ Step %s completed in %d ms" % [_get_state_name(step), step_duration])
	
	workflow_step_completed.emit(step, data)

func _finalize_campaign() -> void:
	## Finalize campaign creation and transition to dashboard
	print("CampaignWorkflowOrchestrator: Finalizing campaign creation...")
	current_state = WorkflowState.FINALIZING
	
	# Validate complete campaign data
	var validation_result = _validate_complete_campaign()
	if not validation_result.success:
		_handle_workflow_error(WorkflowError.DATA_VALIDATION_FAILED, validation_result.error_message)
		return
	
	# Create final campaign using factory pattern
	var final_campaign = _create_final_campaign()
	if final_campaign.is_empty():
		_handle_workflow_error(WorkflowError.UNKNOWN_ERROR, "Failed to create final campaign")
		return
	
	# Save campaign
	var save_result = _save_campaign(final_campaign)
	if not save_result.success:
		_handle_workflow_error(WorkflowError.UNKNOWN_ERROR, "Failed to save campaign: " + save_result.error_message)
		return
	
	# Mark workflow as completed
	current_state = WorkflowState.COMPLETED
	total_workflow_time = Time.get_ticks_msec() - total_workflow_time
	
	print("CampaignWorkflowOrchestrator: ✅ Campaign creation completed in %d ms" % total_workflow_time)
	workflow_completed.emit(final_campaign)
	
	# Transition to campaign dashboard
	_transition_to_dashboard(final_campaign)

func _validate_complete_campaign() -> Dictionary:
	## Validate that all required campaign data is present
	var errors: Array[String] = []

	# Validate config
	if not campaign_data.has("config") or campaign_data["config"].is_empty():
		errors.append("Campaign configuration is missing")

	# Validate crew
	if not campaign_data.has("crew") or campaign_data["crew"].is_empty():
		errors.append("Crew data is missing")
	
	# Validate characters (optional but recommended)
	if not campaign_data.has("characters"):
		print("CampaignWorkflowOrchestrator: Warning - No character customizations provided")
	
	# Validate ship (optional)
	if not campaign_data.has("ship"):
		print("CampaignWorkflowOrchestrator: Warning - No ship assignment provided")
	
	if errors.is_empty():
		return {"success": true}
	else:
		return {
			"success": false,
			"error_message": "Campaign validation failed: " + ", ".join(errors)
		}

func _create_final_campaign() -> Dictionary:
	## Create final campaign using production CampaignFactory
	print("CampaignWorkflowOrchestrator: Creating final campaign using CampaignFactory...")
	
	# Use production factory to create validated campaign
	var creation_result = CampaignFactory.create_campaign(campaign_data)
	
	if creation_result.success:
		print("CampaignWorkflowOrchestrator: ✅ Campaign created successfully with ID: %s" % creation_result.campaign_id)
		return creation_result.campaign
	else:
		print("CampaignWorkflowOrchestrator: ❌ CampaignFactory failed: %s" % creation_result.error_message)
		return {}

func _save_campaign(campaign: Dictionary) -> Dictionary:
	## Save campaign using SaveManager
	print("CampaignWorkflowOrchestrator: Saving campaign using SaveManager...")

	# Use save manager for secure, atomic save operations
	var save_manager = get_node_or_null("/root/SaveManager")
	if not save_manager:
		push_error("CampaignWorkflowOrchestrator: SaveManager not found")
		return {"success": false, "error": "SaveManager not available"}

	var save_name = campaign.get("crew_name", "campaign") + "_" + str(Time.get_unix_time_from_system())
	var save_success = save_manager.save_game(campaign, save_name)

	if save_success:
		var file_path = "user://saves/" + save_name + ".save"
		print("CampaignWorkflowOrchestrator: ✅ Campaign saved successfully to: %s" % file_path)
		return {
			"success": true,
			"file_path": file_path
		}
	else:
		print("CampaignWorkflowOrchestrator: ❌ Save failed")
		return {
			"success": false,
			"error_message": "Save operation failed"
		}

func _transition_to_dashboard(campaign: Dictionary) -> void:
	## Transition to campaign dashboard with campaign data
	var dashboard_path = "res://src/ui/screens/campaign/CampaignDashboard.tscn"
	
	# Prepare context for dashboard
	var context = {
		"campaign": campaign,
		"source": "workflow_orchestrator"
	}
	
	var context_manager = get_node("/root/WorkflowContextManager")
	context_manager.set_context(context)
	
	# Transition to dashboard using standardized navigation
	GameStateManager.navigate_to_scene_path(dashboard_path)

# Error handling system
func _handle_workflow_error(error: WorkflowError, details: String) -> void:
	## Handle workflow errors with recovery options
	print("CampaignWorkflowOrchestrator: ❌ Workflow error: %s - %s" % [error, details])
	
	current_state = WorkflowState.ERROR_STATE
	workflow_error.emit(error, details)
	
	# Attempt recovery if possible
	if error_recovery_attempts < MAX_RECOVERY_ATTEMPTS:
		_attempt_error_recovery(error, details)
	else:
		_handle_unrecoverable_error(details)

func _handle_step_error(step: WorkflowState, error_details: String) -> void:
	## Handle errors from individual workflow steps
	_handle_workflow_error(WorkflowError.UNKNOWN_ERROR, "Step %s failed: %s" % [_get_state_name(step), error_details])

func _handle_initialization_error(error_message: String) -> void:
	## Handle initialization errors
	current_state = WorkflowState.ERROR_STATE
	_handle_workflow_error(WorkflowError.SYSTEM_INITIALIZATION_FAILED, error_message)

# UI Helper Methods
func _update_status(message: String) -> void:
	## Update status display in UI
	if status_label:
		status_label.text = message
	print("CampaignWorkflowOrchestrator: " + message)

func _update_progress(value: float) -> void:
	## Update progress bar
	if progress_bar:
		progress_bar.value = value

func _show_error_ui(title: String, message: String) -> void:
	## Show error UI panel
	if error_panel and error_message:
		error_message.text = message
		error_panel.show()
		
	if loading_screen:
		loading_screen.hide()

func _hide_error_ui() -> void:
	## Hide error UI panel
	if error_panel:
		error_panel.hide()
		
	if loading_screen:
		loading_screen.show()

func _return_to_main_menu() -> void:
	## Return to main menu
	print("CampaignWorkflowOrchestrator: Returning to main menu")
	GameStateManager.navigate_to_screen("main_menu")

func _retry_workflow() -> void:
	## Retry workflow initialization
	print("CampaignWorkflowOrchestrator: Retrying workflow initialization")
	_hide_error_ui()
	error_recovery_attempts = 0
	current_state = WorkflowState.UNINITIALIZED
	_initialize_workflow_system()

func _attempt_error_recovery(error: WorkflowError, details: String) -> void:
	## Attempt to recover from workflow errors
	error_recovery_attempts += 1
	print("CampaignWorkflowOrchestrator: Attempting error recovery (attempt %d/%d)" % [error_recovery_attempts, MAX_RECOVERY_ATTEMPTS])
	
	match error:
		WorkflowError.SCENE_LOAD_FAILED:
			_show_error_ui("Scene Load Error", "Failed to load required scene. Please check your installation.")
		WorkflowError.DATA_VALIDATION_FAILED:
			_show_error_ui("Data Validation Error", details)
		WorkflowError.SYSTEM_INITIALIZATION_FAILED:
			_show_error_ui("System Initialization Failed", details)
		_:
			_show_error_ui("Workflow Error", details)

func _handle_unrecoverable_error(details: String) -> void:
	## Handle errors that cannot be recovered from
	_show_error_ui("Critical Error", "Campaign creation has encountered an unrecoverable error: " + details)

# Legacy dialog method removed - using UI panel instead

func _restart_current_step() -> void:
	## Restart the current workflow step
	if current_state != WorkflowState.ERROR_STATE:
		_start_workflow_step(current_state)

# Monitoring and debugging
func _on_workflow_step_completed(step: WorkflowState, data: Dictionary) -> void:
	## Handle workflow step completion for monitoring
	print("CampaignWorkflowOrchestrator: 📊 Step completed - %s (Data keys: %s)" % [_get_state_name(step), data.keys()])

func _on_workflow_error(error: WorkflowError, details: String) -> void:
	## Handle workflow errors for monitoring
	print("CampaignWorkflowOrchestrator: 🚨 Error - %s: %s" % [error, details])

func _on_workflow_completed(campaign: Dictionary) -> void:
	## Handle workflow completion for monitoring
	print("CampaignWorkflowOrchestrator: 🎉 Workflow completed - Campaign: %s" % campaign.get("config", {}).get("campaign_name", "Unknown"))

func _get_state_name(state: WorkflowState) -> String:
	## Get human-readable state name for debugging
	match state:
		WorkflowState.UNINITIALIZED: return "UNINITIALIZED"
		WorkflowState.CONFIG_PHASE: return "CONFIG_PHASE"
		WorkflowState.CREW_PHASE: return "CREW_PHASE"
		WorkflowState.CHARACTER_PHASE: return "CHARACTER_PHASE"
		WorkflowState.SHIP_PHASE: return "SHIP_PHASE"
		WorkflowState.FINALIZING: return "FINALIZING"
		WorkflowState.COMPLETED: return "COMPLETED"
		WorkflowState.ERROR_STATE: return "ERROR_STATE"
		_: return "UNKNOWN_STATE"

# Debug API for development
func get_workflow_debug_info() -> Dictionary:
	## Get comprehensive workflow debug information
	return {
		"current_state": _get_state_name(current_state),
		"campaign_data_keys": campaign_data.keys(),
		"error_recovery_attempts": error_recovery_attempts,
		"total_workflow_time": total_workflow_time,
		"available_scenes": workflow_scenes,
		"context_manager_available": get_node_or_null("/root/WorkflowContextManager") != null
	}
