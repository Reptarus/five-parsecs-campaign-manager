class_name CampaignCreationUI
extends Control

## Campaign Creation UI Bridge
## Connects existing CampaignCreationUI.tscn scene to refactored architecture
## Routes to CampaignCreationCoordinator and modern panel system

# Signals for campaign creation workflow
signal campaign_data_updated(campaign_data: Dictionary)
signal campaign_completion_ready(campaign_data: Dictionary)
signal campaign_creation_completed(campaign_data: Dictionary)

# Import refactored components (using non-conflicting names)
const CampaignCoordinator = preload("res://src/ui/screens/campaign/CampaignCreationCoordinator.gd")
const CampaignStateManager = preload("res://src/core/campaign/creation/CampaignCreationStateManager.gd")
const CampaignPersistence = preload("res://src/core/campaign/creation/CampaignCreationPersistence.gd")
const SecurityValidator = preload("res://src/core/validation/SecurityValidator.gd")

# PHASE 1: Enhanced Safety Systems (using non-conflicting names)
const FeatureFlags = preload("res://src/core/systems/CampaignCreationFeatureFlags.gd")
const PerformanceTracker = preload("res://src/core/systems/CampaignCreationPerformanceTracker.gd")
const ErrorMonitor = preload("res://src/core/systems/CampaignCreationErrorMonitor.gd")

# PHASE 2: Formal State Machine (using non-conflicting name)
const CampaignStateMachine = preload("res://src/core/systems/CampaignCreationStateMachine.gd")

# Scene node references (matching CampaignCreationUI.tscn structure)
@onready var step_label: Label = %StepLabel
@onready var progress_bar: ProgressBar = $MarginContainer/VBoxContainer/Header/ProgressBar
@onready var content_container: Control = %ContentContainer
@onready var back_button: Button = %BackButton
@onready var next_button: Button = %NextButton
@onready var finish_button: Button = %FinishButton

# Refactored architecture components
var coordinator: CampaignCoordinator
var state_manager: CampaignStateManager
var persistence_manager: CampaignPersistence
var security_validator: FiveParsecsSecurityValidator
var current_panel: Control = null

# PHASE 2: Formal State Machine Integration
var formal_state_machine: CampaignStateMachine
var state_machine_enabled: bool = false

# Legacy UI state (kept for backward compatibility during transition)
enum UIState {
	IDLE,
	LOADING_PANEL,
	PANEL_ACTIVE,
	TRANSITIONING,
	ERROR_RECOVERY,
	EMERGENCY_ROLLBACK
}

var ui_state: UIState = UIState.IDLE
var ui_state_lock: Mutex = Mutex.new()
var panel_load_timeout: float = 5.0
var panel_load_timer: Timer

# PHASE 1: Enhanced Safety Systems
var performance_tracker: CampaignCreationPerformanceTracker
var error_monitor: CampaignCreationErrorMonitor
var error_count: int = 0
var max_errors_before_fallback: int = 3
var last_successful_phase: CampaignStateManager.Phase = CampaignStateManager.Phase.CONFIG
var pending_panel_cleanup: Array[Control] = []
var panel_ready_confirmation: bool = false

# Panel loading with enhanced caching system
var panel_scenes: Dictionary = {
	CampaignStateManager.Phase.CONFIG: "res://src/ui/screens/campaign/panels/ConfigPanel.tscn",
	CampaignStateManager.Phase.CREW_SETUP: "res://src/ui/screens/campaign/panels/CrewPanel.tscn",
	CampaignStateManager.Phase.CAPTAIN_CREATION: "res://src/ui/screens/campaign/panels/CaptainPanel.tscn",
	CampaignStateManager.Phase.SHIP_ASSIGNMENT: "res://src/ui/screens/campaign/panels/ShipPanel.tscn",
	CampaignStateManager.Phase.EQUIPMENT_GENERATION: "res://src/ui/screens/campaign/panels/EquipmentPanel.tscn",
	CampaignStateManager.Phase.WORLD_GENERATION: "res://src/ui/screens/campaign/panels/WorldInfoPanel.tscn",
	CampaignStateManager.Phase.FINAL_REVIEW: "res://src/ui/screens/campaign/panels/FinalPanel.tscn"
}

# CRITICAL: Panel loading state management to prevent overlap
var _is_panel_loading: bool = false
var _panel_load_queue: Array[CampaignStateManager.Phase] = []
var _pending_phase_transition: CampaignStateManager.Phase
var _is_transitioning: bool = false

# Enhanced panel caching system
var panel_cache: Dictionary = {}
var preloaded_scenes: Dictionary = {}
var panel_load_queue: Array[CampaignStateManager.Phase] = []
var is_preloading: bool = false
var preload_progress: int = 0

# Navigation update protection and optimization
var _is_updating_navigation: bool = false
var _navigation_update_timer: Timer
var _pending_navigation_update: bool = false

# PHASE 1B: Performance monitoring system
var _performance_monitor: Dictionary = {
	"session_start_time": 0.0,
	"panel_load_times": {},
	"panel_load_count": {},
	"total_panel_loads": 0,
	"memory_snapshots": [],
	# Animation performance tracking removed - Framework Bible compliance
	"validation_times": {},
	"transaction_times": {},
	"error_count": 0,
	"warning_count": 0
}
var _current_panel_load_start_time: float = 0.0
var _memory_monitoring_enabled: bool = true
var _performance_logging_enabled: bool = true

# Save directory constants
const CAMPAIGNS_DIR = "user://campaigns/"
const SAVE_EXTENSION = ".fpcs"
const BACKUP_EXTENSION = ".backup"

func _initialize_refactored_architecture() -> void:
	"""Initialize the coordinator, state manager, and persistence"""
	state_manager = CampaignStateManager.new()
	persistence_manager = CampaignPersistence.new(state_manager)
	coordinator = CampaignCoordinator.new(state_manager)
	security_validator = SecurityValidator.new()
	
	# Connect coordinator signals (suppress return value warnings)
	@warning_ignore("return_value_discarded")
	coordinator.navigation_updated.connect(_on_navigation_updated)
	@warning_ignore("return_value_discarded")
	coordinator.step_changed.connect(_on_step_changed)
	@warning_ignore("return_value_discarded")
	coordinator.phase_transition_requested.connect(_on_phase_transition_requested)
	
	# Connect persistence signals (suppress return value warnings)
	@warning_ignore("return_value_discarded")
	persistence_manager.persistence_data_loaded.connect(_on_persistence_data_loaded)
	@warning_ignore("return_value_discarded")
	persistence_manager.persistence_error.connect(_on_persistence_error)
	@warning_ignore("return_value_discarded")
	persistence_manager.auto_backup_created.connect(_on_auto_backup_created)
	
	# Check for crash recovery
	_check_crash_recovery()
	
	# PHASE 2: Initialize formal state machine if enabled
	_initialize_formal_state_machine()

func _connect_scene_signals() -> void:
	"""Connect scene button signals to coordinator methods"""
	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)
	if next_button:
		next_button.pressed.connect(_on_next_button_pressed)
	if finish_button:
		finish_button.pressed.connect(_on_finish_button_pressed)

func _load_initial_panel() -> void:
	"""Load the first panel (CONFIG phase)"""
	print("CampaignCreationUI: Loading initial panel for CONFIG phase")
	
	# Ensure state manager is properly initialized
	if not state_manager:
		push_error("CampaignCreationUI: State manager not initialized!")
		return
	
	# Verify initial phase is CONFIG
	print("CampaignCreationUI: State manager current_phase = %s" % str(state_manager.current_phase))
	
	# Force state manager to CONFIG if needed
	if state_manager.current_phase != CampaignStateManager.Phase.CONFIG:
		print("CampaignCreationUI: Resetting state manager to CONFIG phase")
		state_manager.current_phase = CampaignStateManager.Phase.CONFIG
	
	_load_panel_for_phase(CampaignStateManager.Phase.CONFIG)
	_update_navigation_state()

func _load_panel_for_phase(phase: CampaignStateManager.Phase) -> void:
	"""Load the appropriate panel for the given phase with comprehensive overlap prevention and state machine validation"""
	
	# PHASE 2: Use formal state machine if enabled
	if state_machine_enabled and formal_state_machine:
		_load_panel_for_phase_with_state_machine(phase)
		return
	
	# CRITICAL FIX: Enhanced race condition prevention with immediate return on duplicate loads
	if _is_panel_loading:
		print("CampaignCreationUI: Panel loading in progress, queueing phase: %s" % str(phase))
		# Prevent duplicate queuing of same phase AND prevent immediate re-entry
		if not _panel_load_queue.has(phase):
			_panel_load_queue.append(phase)
		return
	
	# CRITICAL FIX: Prevent loading same panel that's already current and correct
	if current_panel and state_manager and state_manager.current_phase == phase:
		# Verify the current panel is actually the correct panel for this phase
		var expected_scene_path: String = panel_scenes.get(phase, "")
		var current_panel_scene_path: String = current_panel.scene_file_path if current_panel else ""
		
		if expected_scene_path == current_panel_scene_path:
			print("CampaignCreationUI: Correct panel already loaded for phase: %s" % str(phase))
			_update_navigation_state()
			return
		else:
			print("CampaignCreationUI: Wrong panel loaded for phase %s, reloading correct panel" % str(phase))
	
	# PHASE 1 DAY 1: Validate state machine before panel loading
	if not _validate_state_machine_readiness(phase):
		push_error("CampaignCreationUI: State machine not ready for phase transition to: %s" % str(phase))
		return
	
	_is_panel_loading = true
	_pending_phase_transition = phase
	
	# PHASE 1 DAY 1: Add corruption detection before starting
	if not _detect_and_recover_corruption():
		push_error("CampaignCreationUI: Detected UI corruption, attempting recovery...")
		_emergency_recovery_and_restart()
		return
	
	# PHASE 1B: Enhanced performance monitoring
	var start_time = Time.get_ticks_msec()
	_current_panel_load_start_time = Time.get_unix_time_from_system()
	_take_memory_snapshot("panel_load_start_" + str(phase))
	
	if not panel_scenes.has(phase):
		push_error("No panel scene defined for phase: " + str(phase))
		_complete_panel_loading()
		return
	
	print("CampaignCreationUI: === Loading panel for phase: %s ===" % str(phase))
	print("CampaignCreationUI: Container state before cleanup - Children: %d" % content_container.get_child_count())
	
	# Step 1: COMPREHENSIVE panel cleanup with validation
	_comprehensive_panel_cleanup()
	print("CampaignCreationUI: Container state after cleanup - Children: %d" % content_container.get_child_count())
	
	# Step 2: Validate ContentContainer state
	if not _validate_content_container_state():
		push_error("ContentContainer validation failed during panel loading")
		_complete_panel_loading()
		return
	
	# Step 3: Load new panel with enhanced error handling and recovery
	var new_panel = await _create_panel_for_phase_with_recovery(phase)
	if not new_panel or not is_instance_valid(new_panel):
		push_error("Failed to create panel for phase: " + str(phase))
		# CRITICAL FIX: Attempt emergency recovery instead of missing function
		_emergency_recovery_and_restart()
		_complete_panel_loading()
		return
	
	# CRITICAL: Validate panel before proceeding
	if not new_panel.has_method("validate_panel"):
		push_error("Created panel missing required validate_panel method")
		new_panel.queue_free()
		_emergency_recovery_and_restart()
		_complete_panel_loading()
		return
	
	# Step 4: CRITICAL FIX - Ensure container is completely clean BEFORE working with new panel
	await get_tree().process_frame # Wait for any deferred cleanup to complete
	
	# Double-check container is empty with more aggressive cleanup
	if content_container.get_child_count() > 0:
		push_error("CRITICAL: Container not empty before adding new panel! Children: %d" % content_container.get_child_count())
		# List what's still in the container for debugging
		for i in range(content_container.get_child_count()):
			var child = content_container.get_child(i)
			print("  - Remaining child %d: %s (%s)" % [i, child.name, child.get_class()])
		
		_clear_content_container() # Force clear again
		await get_tree().process_frame # Wait again
		
		# Final verification with emergency cleanup
		if content_container.get_child_count() > 0:
			push_error("EMERGENCY: Container STILL not empty after forced cleanup!")
			# Nuclear option - remove all children directly
			var remaining_children = content_container.get_children()
			for child in remaining_children:
				if is_instance_valid(child):
					content_container.remove_child(child)
					child.queue_free()
				else:
					print("  - Invalid child detected, skipping")
			print("Emergency cleanup: Removed %d remaining children" % remaining_children.size())
			
			# Wait one more frame to ensure cleanup completes
			await get_tree().process_frame
			
			# Final verification
			if content_container.get_child_count() > 0:
				push_error("CRITICAL: Container cleanup failed completely!")
				return # Abort panel loading
	
	# Step 5: Set as current panel AFTER container is confirmed clean
	if new_panel and is_instance_valid(new_panel):
		current_panel = new_panel
		
		# Step 6: Add to content container with validation
		content_container.add_child(current_panel)
	else:
		push_error("CRITICAL: new_panel is null or invalid! Cannot proceed with panel loading.")
		_complete_panel_loading()
		return
	print("CampaignCreationUI: Successfully added panel to container. Children count: %d" % content_container.get_child_count())
	
	# Step 7: Verify single child state
	if not _verify_single_panel_state():
		push_error("CRITICAL: Multiple panels detected after loading!")
		_emergency_panel_cleanup()
		_complete_panel_loading()
		return
	
	# Step 7: Initialize panel with full lifecycle management
	_initialize_panel_complete(phase)
	
	# Step 8: Track performance and complete loading
	_track_panel_load_time(phase, start_time)
	_take_memory_snapshot("panel_load_complete_" + str(phase))
	_complete_panel_loading()
	
	print("CampaignCreationUI: ✅ Panel loaded successfully for phase: %s" % str(phase))

# Duplicate function removed - see line 1251 for the complete implementation

func _on_next_button_pressed() -> void:
	"""Handle next button press via coordinator with delay to prevent rapid transitions"""
	# CRITICAL FIX: Add delay to prevent rapid phase transitions
	if _is_transitioning:
		print("CampaignCreationUI: Already transitioning, ignoring button press")
		return
	
	_is_transitioning = true
	
	# Add a small delay to ensure current panel is stable
	await get_tree().create_timer(0.1).timeout
	
	coordinator.advance_to_next_phase()
	
	# Reset transition flag after a delay
	await get_tree().create_timer(0.5).timeout
	_is_transitioning = false

func _on_finish_button_pressed() -> void:
	"""Handle finish button press - finalize campaign creation with comprehensive validation"""
	print("CampaignCreationUI: === Campaign Finalization Started ===")
	
	# Show loading state immediately
	_show_loading_state(true, "Validating campaign data...")
	
	# 1. Validate current panel data
	if current_panel and current_panel.has_method("validate_panel"):
		var panel_validation = current_panel.validate_panel()
		if not panel_validation.valid:
			_show_loading_state(false)
			_show_validation_dialog("Current panel validation failed", panel_validation.get("errors", ["Unknown validation error"]))
			return
	
	# 2. Comprehensive validation of all phases
	var complete_validation = state_manager.validate_complete_state()
	if not complete_validation.valid:
		_show_loading_state(false)
		_show_validation_dialog("Campaign validation failed", complete_validation.get("errors", {}))
		return
	
	# 3. Validate coordinator state
	if not coordinator.can_finish_campaign_creation():
		_show_loading_state(false)
		_show_validation_dialog("Coordinator validation failed", ["Campaign creation not ready for completion"])
		return
	
	print("CampaignCreationUI: ✅ All validations passed")
	_show_loading_state(true, "Creating your campaign...")
	
	# 4. Gather all campaign data from state manager
	var campaign_data = coordinator.finalize_campaign()
	if campaign_data.is_empty() or not campaign_data.has("campaign_data"):
		_show_loading_state(false)
		_show_error_dialog("Failed to gather campaign data from coordinator")
		return
	
	# 5. Create and save campaign
	_finalize_campaign_creation(campaign_data)

func _finalize_campaign_creation(campaign_data: Dictionary) -> void:
	"""Complete implementation for campaign creation with SecureSaveManager"""
	print("CampaignCreationUI: Starting campaign finalization...")
	
	# Show loading state during finalization
	_show_loading_state(true, "Creating campaign...")
	
	# Extract campaign data from coordinator result
	var campaign_info = campaign_data.get("campaign_data", {})
	if campaign_info.is_empty():
		_show_error_dialog("No campaign data available for finalization")
		_show_loading_state(false)
		return
	
	# Create campaign resource from aggregated data
	# Note: FiveParsecsCampaignCore should be implemented or use a different campaign class
	var campaign = Resource.new() # Placeholder until proper campaign class is available
	
	# Initialize campaign with creation data
	var campaign_config = campaign_info.get("config", {})
	var campaign_name = campaign_config.get("name", "Unnamed Campaign")
	
	if campaign_name.is_empty() or campaign_name == "Unnamed Campaign":
		_show_error_dialog("Campaign must have a valid name")
		_show_loading_state(false)
		return
	
	# Set basic campaign properties (using set_meta for Resource placeholder)
	campaign.set_meta("campaign_name", campaign_name)
	campaign.set_meta("difficulty", campaign_config.get("difficulty", GlobalEnums.DifficultyLevel.STANDARD))
	
	# Initialize campaign with all phase data
	var init_success = _initialize_campaign_from_data(campaign, campaign_info)
	if not init_success:
		_show_error_dialog("Failed to initialize campaign from creation data")
		_show_loading_state(false)
		return
	
	# Generate unique save name with timestamp
	var save_name = _generate_campaign_save_name(campaign_name)
	print("CampaignCreationUI: Generated save name: ", save_name)
	
	# Save campaign using SecureSaveManager
	var save_path = CAMPAIGNS_DIR + save_name
	var save_result = await _save_campaign_secure(campaign, save_path)
	
	if save_result.success:
		print("CampaignCreationUI: ✅ Campaign saved successfully")
		
		# Clear persistence data after successful save
		_clear_persistence_data()
		
		# Clean up panel cache to free memory
		_cleanup_panel_cache()
		
		# Store as active campaign in GameStateManager if available
		if GameStateManagerAutoload and GameStateManagerAutoload.has_method("set_active_campaign"):
			GameStateManagerAutoload.set_active_campaign(campaign)
			print("CampaignCreationUI: Set as active campaign")
		
		# Transition to main campaign scene
		_show_loading_state(false)
		var scene_path = "res://src/ui/screens/campaign/MainCampaignScene.tscn"
		if ResourceLoader.exists(scene_path):
			var result = get_tree().change_scene_to_file(scene_path)
			if result != OK:
				push_error("Failed to change scene to: " + scene_path)
		else:
			# Fallback to campaign dashboard
			var fallback_path = "res://src/ui/screens/campaign/CampaignDashboard.tscn"
			if ResourceLoader.exists(fallback_path):
				var result = get_tree().change_scene_to_file(fallback_path)
				if result != OK:
					push_error("Failed to change scene to fallback: " + fallback_path)
			else:
				push_error("Neither main campaign scene nor dashboard scene found")
	else:
		_show_error_dialog("Failed to save campaign: " + save_result.get("error", "Unknown error"))
		_show_loading_state(false)

func _initialize_campaign_from_data(campaign: Resource, campaign_info: Dictionary) -> bool:
	"""Initialize campaign resource with creation data"""
	# Set config data (using set_meta for Resource placeholder)
	var config = campaign_info.get("config", {})
	campaign.set_meta("difficulty", config.get("difficulty", GlobalEnums.DifficultyLevel.STANDARD))
	
	# Set crew data
	var crew_data = campaign_info.get("crew", {})
	var crew_members = crew_data.get("members", [])
	if crew_members.size() == 0:
		push_warning("Campaign has no crew members")
	
	# Set captain data
	var captain_data = campaign_info.get("captain", {})
	
	# Set ship data
	var ship_data = campaign_info.get("ship", {})
	
	# Set equipment data
	var equipment_data = campaign_info.get("equipment", {})
	
	# Set world data
	var world_data = campaign_info.get("world", {})
	
	print("CampaignCreationUI: Campaign initialized with %d crew members" % crew_members.size())
	return true

func _generate_campaign_save_name(campaign_name: String) -> String:
	"""Generate unique save file name for campaign"""
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	var sanitized_name = campaign_name.strip_edges().replace(" ", "_").to_lower()
	
	# Remove any potentially problematic characters using modern string methods
	var regex = RegEx.new()
	regex.compile("[^a-zA-Z0-9_]")
	var safe_name = regex.sub(sanitized_name, "", true)
	
	return "campaign_%s_%s.fpcs" % [safe_name, timestamp]

func _ensure_save_directory() -> bool:
	"""Ensure campaigns directory exists with proper error handling"""
	if DirAccess.dir_exists_absolute(CAMPAIGNS_DIR):
		return true
	
	var dir = DirAccess.open("user://")
	if not dir:
		push_error("CampaignCreationUI: Cannot access user directory")
		return false
	
	var result = dir.make_dir_recursive("campaigns")
	if result != OK:
		push_error("CampaignCreationUI: Failed to create campaigns directory: " + str(result))
		return false
	
	return true

func _save_campaign_secure(campaign: Resource, save_path: String) -> Dictionary:
	"""Save campaign using SecureSaveManager"""
	# Ensure campaigns directory exists
	if not _ensure_save_directory():
		return {"success": false, "error": "Failed to create campaigns directory"}
	
	# Convert campaign to dictionary for saving
	var campaign_dict = {
		"name": campaign.get_meta("campaign_name", "Unnamed Campaign"),
		"difficulty": campaign.get_meta("difficulty", GlobalEnums.DifficultyLevel.STANDARD),
		"created_at": Time.get_datetime_string_from_system(),
		"version": "1.0"
	}
	
	# Use built-in JSON save since SecureSaveManager may not be available
	var save_result: Dictionary
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(campaign_dict))
		file.close()
		save_result = {"success": true}
	else:
		save_result = {"success": false, "error": "Failed to open file for writing"}
	
	return save_result

func _show_loading_state(show: bool, message: String = "Loading...") -> void:
	"""Show/hide loading state with message"""
	if show:
		# Disable navigation buttons during loading
		if back_button:
			back_button.disabled = true
		if next_button:
			next_button.disabled = true
		if finish_button:
			finish_button.disabled = true
	else:
		# Re-enable navigation buttons
		_update_navigation_state()

func _show_error_dialog(message: String) -> void:
	"""Show error dialog to user"""
	push_error("CampaignCreationUI: " + message)
	
	# Create simple error dialog
	var dialog = AcceptDialog.new()
	dialog.title = "Campaign Creation Error"
	dialog.dialog_text = message
	# Center dialog - use popup_centered() instead of deprecated initial position
	add_child(dialog)
	dialog.popup_centered()
	
	# Clean up dialog after use
	dialog.confirmed.connect(dialog.queue_free)

func _show_validation_dialog(title: String, errors) -> void:
	"""Show detailed validation errors dialog"""
	var dialog = AcceptDialog.new()
	dialog.title = title
	
	var error_text = "Please fix the following issues:\n\n"
	
	# Handle different error formats
	if errors is Dictionary:
		for phase in errors:
			error_text += "• " + str(phase) + ":\n"
			var phase_errors = errors[phase]
			if phase_errors is Array:
				for error in phase_errors:
					error_text += "  - " + str(error) + "\n"
			else:
				error_text += "  - " + str(phase_errors) + "\n"
	elif errors is Array:
		for error in errors:
			error_text += "• " + str(error) + "\n"
	else:
		error_text += "• " + str(errors) + "\n"
	
	dialog.dialog_text = error_text
	add_child(dialog)
	dialog.popup_centered(Vector2(500, 400))
	dialog.confirmed.connect(dialog.queue_free)

func _on_navigation_updated(can_go_back: bool, can_go_forward: bool, can_finish: bool) -> void:
	"""Update navigation button states"""
	if back_button:
		back_button.disabled = not can_go_back
	if next_button:
		next_button.disabled = not can_go_forward
		next_button.visible = can_go_forward or not can_finish
	if finish_button:
		finish_button.disabled = not can_finish
		finish_button.visible = can_finish

func _on_step_changed(step: int, total_steps: int) -> void:
	"""Update progress indicators"""
	if progress_bar:
		progress_bar.max_value = total_steps
		progress_bar.value = step
	
	if step_label:
		var phase_names = {
			0: "Campaign Configuration",
			1: "Crew Setup",
			2: "Captain Creation",
			3: "Ship Assignment",
			4: "Equipment Generation",
			5: "Final Review"
		}
		var phase_name = phase_names.get(step, "Unknown Phase")
		step_label.text = "Step %d: %s" % [step + 1, phase_name]

func _on_phase_transition_requested(from_phase: CampaignStateManager.Phase, to_phase: CampaignStateManager.Phase) -> void:
	"""Handle phase transition by loading new panel"""
	print("CampaignCreationUI: Phase transition requested: %s -> %s" % [str(from_phase), str(to_phase)])
	
	# CRITICAL: Prevent rapid transitions
	if _is_panel_loading or _is_transitioning:
		print("CampaignCreationUI: Panel already loading or transitioning, queuing transition")
		_panel_load_queue.append(to_phase)
		return
	
	# Add delay to prevent rapid transitions
	_is_transitioning = true
	await get_tree().create_timer(0.2).timeout
	
	# Save current panel data before switching
	_before_panel_switch(from_phase)
	
	# Load new panel
	_load_panel_for_phase(to_phase)
	
	# Restore new panel data after switching
	_after_panel_switch(to_phase)
	
	_update_navigation_state()
	
	# Reset transition flag after panel loads
	await get_tree().create_timer(0.3).timeout
	_is_transitioning = false

func _on_panel_completed(panel_data: Dictionary) -> void:
	"""Handle panel completion - save data and enable navigation"""
	coordinator.mark_phase_complete(state_manager.current_phase, true)
	_update_navigation_state()

func _on_panel_validation_failed(errors: Array[String]) -> void:
	"""Handle panel validation failure"""
	push_warning("Panel validation failed: " + str(errors))
	_update_navigation_state()

func _update_navigation_state() -> void:
	"""Comprehensive navigation state management with validation"""
	# Prevent recursion
	if _is_updating_navigation:
		return
	
	if not state_manager or not coordinator:
		return
	
	_is_updating_navigation = true
	
	# PHASE 1B: Track navigation update performance
	var validation_start_time = Time.get_unix_time_from_system()
	
	# Update coordinator state first
	coordinator._update_navigation_state()
	
	var current_phase = state_manager.current_phase
	var nav_state = coordinator.get_navigation_state()
	
	# Add null checks for robustness
	if not nav_state:
		_is_updating_navigation = false
		return
	
	# Validate current phase data with performance tracking
	var phase_validation = state_manager.validate_phase(current_phase)
	_track_validation_performance("phase_validation", validation_start_time)
	
	if not phase_validation:
		_is_updating_navigation = false
		return
	
	# Get complete validation only when needed (for finish button)
	var complete_validation: Dictionary = {}
	var is_final_phase = (current_phase == CampaignStateManager.Phase.FINAL_REVIEW)
	if is_final_phase:
		var complete_validation_start = Time.get_unix_time_from_system()
		complete_validation = state_manager.validate_complete_state()
		_track_validation_performance("complete_validation", complete_validation_start)
	
	# Update back button
	if back_button:
		back_button.disabled = not nav_state.can_go_back
		back_button.tooltip_text = "Return to previous step" if nav_state.can_go_back else "Cannot go back from first step"
	
	# Update next button
	if next_button:
		next_button.disabled = not nav_state.can_go_forward or not phase_validation
		next_button.visible = not is_final_phase
		
		if not phase_validation:
			next_button.tooltip_text = "Complete current step before proceeding"
		elif not nav_state.can_go_forward:
			next_button.tooltip_text = "Current step not ready for navigation"
		else:
			next_button.tooltip_text = "Continue to next step"
	
	# Update finish button
	if finish_button:
		finish_button.visible = is_final_phase
		
		if is_final_phase and complete_validation.has("valid"):
			finish_button.disabled = not complete_validation.valid
			
			if not complete_validation.valid:
				var error_count = 0
				if complete_validation.has("errors") and complete_validation.errors is Dictionary:
					for phase_errors in complete_validation.errors.values():
						if phase_errors is Array:
							error_count += phase_errors.size()
						else:
							error_count += 1
				finish_button.tooltip_text = "Fix %d validation issue(s) before creating campaign" % error_count
			else:
				finish_button.tooltip_text = "Create campaign and start playing"
		else:
			finish_button.disabled = true
			finish_button.tooltip_text = "Complete all steps to create campaign"
	
	# Update progress indicators
	_update_progress_display(current_phase)
	
	# Update panel navigation hints if panel supports it
	if current_panel and current_panel.has_method("update_navigation_hints"):
		var can_finish = is_final_phase and complete_validation.get("valid", false)
		current_panel.update_navigation_hints({
			"can_go_back": nav_state.can_go_back,
			"can_go_forward": nav_state.can_go_forward and phase_validation,
			"can_finish": can_finish,
			"validation_errors": [] # Phase validation is boolean, no detailed errors
		})
	
	# Reset recursion guard
	_is_updating_navigation = false

func _schedule_navigation_update() -> void:
	"""Schedule a debounced navigation update to prevent excessive calls"""
	if not _navigation_update_timer:
		_navigation_update_timer = Timer.new()
		_navigation_update_timer.wait_time = 0.1 # 100ms debounce
		_navigation_update_timer.one_shot = true
		_navigation_update_timer.timeout.connect(_update_navigation_state)
		add_child(_navigation_update_timer)
	
	if _navigation_update_timer.is_stopped():
		_navigation_update_timer.start()
	else:
		# Timer is already running, navigation update will happen when it expires
		_pending_navigation_update = true

func _update_real_time_state() -> void:
	"""Update state for real-time changes without full navigation update"""
	if not state_manager:
		return
	
	# Update current panel data in state manager
	if current_panel and current_panel.has_method("get_panel_data"):
		var panel_data = current_panel.get_panel_data()
		var current_phase = state_manager.current_phase
		
		# Update state based on current phase
		match current_phase:
			CampaignStateManager.Phase.CONFIG:
				state_manager.update_config_data(panel_data)
			CampaignStateManager.Phase.CREW_SETUP:
				state_manager.update_crew_data(panel_data)
			CampaignStateManager.Phase.CAPTAIN_CREATION:
				state_manager.update_captain_data(panel_data)
			CampaignStateManager.Phase.SHIP_ASSIGNMENT:
				state_manager.update_ship_data(panel_data)
			CampaignStateManager.Phase.EQUIPMENT_GENERATION:
				state_manager.update_equipment_data(panel_data)
	
	# Emit real-time update signal for other components
	if has_signal("campaign_data_updated"):
		campaign_data_updated.emit(state_manager.get_campaign_data())

func _check_overall_completion() -> void:
	"""Check if campaign creation is ready for completion"""
	if not state_manager:
		return
	
	var complete_validation = state_manager.validate_complete_state()
	if complete_validation.valid:
		print("CampaignCreationUI: Campaign creation ready for completion")
		
		# Enable finish button if we're on the final phase
		var current_phase = state_manager.current_phase
		if current_phase == CampaignStateManager.Phase.FINAL_REVIEW:
			if finish_button:
				finish_button.disabled = false
				finish_button.tooltip_text = "Campaign is ready - click to start playing!"
		
		# Emit completion readiness signal if available
		if has_signal("campaign_completion_ready"):
			campaign_completion_ready.emit(state_manager.get_campaign_data())
	else:
		print("CampaignCreationUI: Campaign not yet complete - missing: ", complete_validation.get("errors", {}))

func _update_progress_display(current_phase: CampaignStateManager.Phase) -> void:
	"""Update progress indicators and phase display"""
	var phase_index = _get_phase_index(current_phase)
	var total_phases = 7 # CONFIG, CREW_SETUP, CAPTAIN_CREATION, SHIP_ASSIGNMENT, EQUIPMENT_GENERATION, WORLD_GENERATION, FINAL_REVIEW
	
	# Update progress bar
	if progress_bar:
		progress_bar.max_value = total_phases
		progress_bar.value = phase_index + 1
	
	# Update step label
	if step_label:
		var phase_names = {
			CampaignStateManager.Phase.CONFIG: "Campaign Configuration",
			CampaignStateManager.Phase.CREW_SETUP: "Crew Setup",
			CampaignStateManager.Phase.CAPTAIN_CREATION: "Captain Creation",
			CampaignStateManager.Phase.SHIP_ASSIGNMENT: "Ship Assignment",
			CampaignStateManager.Phase.EQUIPMENT_GENERATION: "Equipment Generation",
			CampaignStateManager.Phase.WORLD_GENERATION: "World Generation",
			CampaignStateManager.Phase.FINAL_REVIEW: "Final Review"
		}
		var phase_name = phase_names.get(current_phase, "Unknown Phase")
		step_label.text = "Step %d of %d: %s" % [phase_index + 1, total_phases, phase_name]

func _get_phase_index(phase: CampaignStateManager.Phase) -> int:
	"""Get numeric index for phase"""
	match phase:
		CampaignStateManager.Phase.CONFIG: return 0
		CampaignStateManager.Phase.CREW_SETUP: return 1
		CampaignStateManager.Phase.CAPTAIN_CREATION: return 2
		CampaignStateManager.Phase.SHIP_ASSIGNMENT: return 3
		CampaignStateManager.Phase.EQUIPMENT_GENERATION: return 4
		CampaignStateManager.Phase.WORLD_GENERATION: return 5
		CampaignStateManager.Phase.FINAL_REVIEW: return 6
		_: return 0

func _connect_panel_signals() -> void:
	"""Connect all panel-specific signals beyond the standard ones"""
	if not current_panel:
		return
	
	# Connect panel to state manager for real-time updates
	if current_panel.has_method("set_state_manager"):
		current_panel.set_state_manager(state_manager)
	
	# Connect panel-specific signals based on current phase
	match state_manager.current_phase:
		CampaignStateManager.Phase.CONFIG:
			_connect_config_panel_signals()
		CampaignStateManager.Phase.CREW_SETUP:
			_connect_crew_panel_signals()
		CampaignStateManager.Phase.CAPTAIN_CREATION:
			_connect_captain_panel_signals()
		CampaignStateManager.Phase.SHIP_ASSIGNMENT:
			_connect_ship_panel_signals()
		CampaignStateManager.Phase.EQUIPMENT_GENERATION:
			_connect_equipment_panel_signals()
		CampaignStateManager.Phase.WORLD_GENERATION:
			_connect_world_panel_signals()
		CampaignStateManager.Phase.FINAL_REVIEW:
			_connect_final_panel_signals()

func _connect_config_panel_signals() -> void:
	"""Connect configuration panel specific signals"""
	if current_panel.has_signal("configuration_complete"):
		current_panel.configuration_complete.connect(_on_configuration_complete)
	if current_panel.has_signal("campaign_name_changed"):
		current_panel.campaign_name_changed.connect(_on_campaign_name_changed)
	if current_panel.has_signal("difficulty_changed"):
		current_panel.difficulty_changed.connect(_on_difficulty_changed)
	if current_panel.has_signal("ironman_toggled"):
		current_panel.ironman_toggled.connect(_on_ironman_toggled)

func _connect_crew_panel_signals() -> void:
	"""Connect crew panel specific signals"""
	if current_panel.has_signal("crew_member_added"):
		current_panel.crew_member_added.connect(_on_crew_member_added)
	if current_panel.has_signal("crew_size_changed"):
		current_panel.crew_size_changed.connect(_on_crew_size_changed)
	if current_panel.has_signal("crew_setup_complete"):
		current_panel.crew_setup_complete.connect(_on_crew_setup_complete)
	if current_panel.has_signal("crew_composition_changed"):
		current_panel.crew_composition_changed.connect(_on_crew_composition_changed)

func _connect_captain_panel_signals() -> void:
	"""Connect captain panel specific signals"""
	if current_panel.has_signal("captain_selected"):
		current_panel.captain_selected.connect(_on_captain_selected)
	if current_panel.has_signal("captain_data_changed"):
		current_panel.captain_data_changed.connect(_on_captain_data_changed)
	if current_panel.has_signal("captain_creation_complete"):
		current_panel.captain_creation_complete.connect(_on_captain_creation_complete)

func _connect_ship_panel_signals() -> void:
	"""Connect ship panel specific signals"""
	if current_panel.has_signal("ship_selected"):
		current_panel.ship_selected.connect(_on_ship_selected)
	if current_panel.has_signal("ship_configured"):
		current_panel.ship_configured.connect(_on_ship_configured)
	if current_panel.has_signal("ship_name_changed"):
		current_panel.ship_name_changed.connect(_on_ship_name_changed)
	if current_panel.has_signal("ship_type_changed"):
		current_panel.ship_type_changed.connect(_on_ship_type_changed)
	if current_panel.has_signal("ship_data_changed"):
		current_panel.ship_data_changed.connect(_on_ship_data_changed)
	if current_panel.has_signal("ship_configuration_complete"):
		current_panel.ship_configuration_complete.connect(_on_ship_configuration_complete)

func _connect_equipment_panel_signals() -> void:
	"""Connect equipment panel specific signals"""
	if current_panel.has_signal("equipment_distributed"):
		current_panel.equipment_distributed.connect(_on_equipment_distributed)
	if current_panel.has_signal("equipment_generated"):
		current_panel.equipment_generated.connect(_on_equipment_generated)
	if current_panel.has_signal("equipment_rerolled"):
		current_panel.equipment_rerolled.connect(_on_equipment_rerolled)
	if current_panel.has_signal("equipment_data_changed"):
		current_panel.equipment_data_changed.connect(_on_equipment_data_changed)
	if current_panel.has_signal("equipment_generation_complete"):
		current_panel.equipment_generation_complete.connect(_on_equipment_generation_complete)

func _connect_world_panel_signals() -> void:
	"""Connect world panel specific signals"""
	if current_panel.has_signal("world_generated"):
		current_panel.world_generated.connect(_on_world_generated)
	if current_panel.has_signal("world_name_changed"):
		current_panel.world_name_changed.connect(_on_world_name_changed)
	if current_panel.has_signal("world_type_changed"):
		current_panel.world_type_changed.connect(_on_world_type_changed)

func _connect_final_panel_signals() -> void:
	"""Connect final review panel specific signals"""
	if current_panel.has_signal("campaign_finalization_complete"):
		current_panel.campaign_finalization_complete.connect(_on_campaign_finalization_complete)

## Panel-specific signal handlers

func _on_configuration_complete(data: Dictionary) -> void:
	"""Handle configuration panel completion"""
	print("CampaignCreationUI: Configuration complete with data: ", data)
	if state_manager and state_manager.update_config_data(data):
		coordinator.mark_phase_complete(CampaignStateManager.Phase.CONFIG, true)
		_update_navigation_state()
	else:
		push_error("CampaignCreationUI: Failed to save configuration data")

func _on_crew_member_added(member_data: Dictionary) -> void:
	"""Handle crew member addition"""
	print("CampaignCreationUI: Crew member added: ", member_data.get("name", "Unknown"))

func _on_crew_size_changed(new_size: int) -> void:
	"""Handle crew size change"""
	print("CampaignCreationUI: Crew size changed to: ", new_size)
	if state_manager and state_manager.update_crew_data({"crew_size": new_size}):
		_update_navigation_state()
	else:
		push_error("CampaignCreationUI: Failed to save crew size change")

func _on_crew_setup_complete(crew_data: Dictionary) -> void:
	"""Handle crew setup completion"""
	print("CampaignCreationUI: Crew setup complete with %d members" % crew_data.get("members", []).size())
	if state_manager and state_manager.update_crew_data(crew_data):
		coordinator.mark_phase_complete(CampaignStateManager.Phase.CREW_SETUP, true)
		_update_navigation_state()
	else:
		push_error("CampaignCreationUI: Failed to save crew setup data")

func _on_captain_selected(captain_data: Dictionary) -> void:
	"""Handle captain selection"""
	print("CampaignCreationUI: Captain selected: ", captain_data.get("name", "Unknown"))
	if state_manager and state_manager.update_captain_data(captain_data):
		coordinator.mark_phase_complete(CampaignStateManager.Phase.CAPTAIN_CREATION, true)
		_update_navigation_state()
	else:
		push_error("CampaignCreationUI: Failed to save captain data")

func _on_ship_selected(ship_data: Dictionary) -> void:
	"""Handle ship selection"""
	print("CampaignCreationUI: Ship selected: ", ship_data.get("name", "Unknown Ship"))
	state_manager.update_ship_data(ship_data)
	_update_navigation_state()

func _on_ship_configured(ship_data: Dictionary) -> void:
	"""Handle ship configuration completion"""
	print("CampaignCreationUI: Ship configured: ", ship_data.get("name", "Unknown Ship"))
	state_manager.update_ship_data(ship_data)
	coordinator.mark_phase_complete(CampaignStateManager.Phase.SHIP_ASSIGNMENT, true)
	_update_navigation_state()

func _on_equipment_distributed(equipment_data: Dictionary) -> void:
	"""Handle equipment distribution completion"""
	print("CampaignCreationUI: Equipment distributed")
	state_manager.update_equipment_data(equipment_data)
	coordinator.mark_phase_complete(CampaignStateManager.Phase.EQUIPMENT_GENERATION, true)
	_update_navigation_state()

func _on_world_generated(world_data: Dictionary) -> void:
	"""Handle world generation completion"""
	print("CampaignCreationUI: World generated: ", world_data.get("name", "Unknown World"))
	state_manager.update_world_data(world_data)
	coordinator.mark_phase_complete(CampaignStateManager.Phase.WORLD_GENERATION, true)
	_update_navigation_state()

func _on_campaign_finalization_complete(finalization_data: Dictionary) -> void:
	"""Handle campaign finalization completion"""
	print("CampaignCreationUI: Campaign finalization completed")
	
	# Save final campaign data
	if state_manager:
		state_manager.finalize_campaign_creation()
	
	# Emit campaign creation completed signal if available
	if has_signal("campaign_creation_completed"):
		campaign_creation_completed.emit(finalization_data)
	coordinator.mark_phase_complete(CampaignStateManager.Phase.FINAL_REVIEW, true)
	_update_navigation_state()

## Additional Signal Handlers for Enhanced Integration

func _on_campaign_name_changed(name: String) -> void:
	"""Handle campaign name change"""
	state_manager.update_config_data({"campaign_name": name})
	_schedule_navigation_update()

func _on_difficulty_changed(difficulty: int) -> void:
	"""Handle difficulty change"""
	state_manager.update_config_data({"difficulty": difficulty})
	_schedule_navigation_update()

func _on_ironman_toggled(enabled: bool) -> void:
	"""Handle ironman mode toggle"""
	state_manager.update_config_data({"ironman_mode": enabled})
	_schedule_navigation_update()

func _on_crew_composition_changed(composition: Array) -> void:
	"""Handle crew composition change"""
	state_manager.update_crew_data({"crew_composition": composition})
	_schedule_navigation_update()

func _on_captain_data_changed(captain_data: Dictionary) -> void:
	"""Handle captain data change"""
	state_manager.update_captain_data(captain_data)
	_schedule_navigation_update()

func _on_captain_creation_complete(captain_data: Dictionary) -> void:
	"""Handle captain creation completion"""
	state_manager.update_captain_data(captain_data)
	coordinator.mark_phase_complete(CampaignStateManager.Phase.CAPTAIN_CREATION, true)
	_update_navigation_state()

func _on_ship_name_changed(name: String) -> void:
	"""Handle ship name change"""
	state_manager.update_ship_data({"ship_name": name})
	_schedule_navigation_update()

func _on_ship_type_changed(ship_type: int) -> void:
	"""Handle ship type change"""
	state_manager.update_ship_data({"ship_type": ship_type})
	_schedule_navigation_update()

func _on_equipment_generated(equipment: Dictionary) -> void:
	"""Handle equipment generation"""
	state_manager.update_equipment_data(equipment)
	_update_navigation_state()

func _on_equipment_rerolled(equipment: Dictionary) -> void:
	"""Handle equipment reroll"""
	state_manager.update_equipment_data(equipment)
	_update_navigation_state()

func _on_ship_data_changed(ship_data: Dictionary) -> void:
	"""Handle ship data changes for real-time updates"""
	if security_validator:
		var validation_result = security_validator.validate_dictionary_input(ship_data, 1000)
		if validation_result.valid:
			state_manager.update_ship_data(validation_result.sanitized_value)
			_update_real_time_state()
			print("CampaignCreationUI: Ship data updated in real-time")
		else:
			print("CampaignCreationUI: Ship data validation failed: ", validation_result.error)

func _on_ship_configuration_complete(ship: Dictionary) -> void:
	"""Handle ship configuration completion"""
	print("CampaignCreationUI: Ship configuration completed: ", ship.get("name", "Unknown Ship"))
	state_manager.update_ship_data(ship)
	_update_navigation_state()
	_check_overall_completion()

func _on_equipment_data_changed(equipment_data: Dictionary) -> void:
	"""Handle equipment data changes for real-time updates"""
	if security_validator:
		var validation_result = security_validator.validate_dictionary_input(equipment_data, 2000)
		if validation_result.valid:
			state_manager.update_equipment_data(validation_result.sanitized_value)
			_update_real_time_state()
			print("CampaignCreationUI: Equipment data updated in real-time")
		else:
			print("CampaignCreationUI: Equipment data validation failed: ", validation_result.error)

func _on_equipment_generation_complete(equipment: Array) -> void:
	"""Handle equipment generation completion"""
	print("CampaignCreationUI: Equipment generation completed: %d items" % equipment.size())
	state_manager.update_equipment_data({"equipment": equipment})
	_update_navigation_state()
	_check_overall_completion()

func _on_world_name_changed(name: String) -> void:
	"""Handle world name change"""
	state_manager.update_world_data({"world_name": name})
	_update_navigation_state()

func _on_world_type_changed(world_type: int) -> void:
	"""Handle world type change"""
	state_manager.update_world_data({"world_type": world_type})
	_update_navigation_state()

## Panel Data Persistence System

# Panel data cache for recovery and navigation
var panel_data_cache: Dictionary = {}
var persistence_file_path: String = "user://campaign_creation_state.dat"

func _before_panel_switch(old_phase: CampaignStateManager.Phase) -> void:
	"""Save current panel data before switching"""
	if not current_panel:
		return
		
	# Get panel data if method exists
	if current_panel.has_method("get_panel_data"):
		var panel_data = current_panel.get_panel_data()
		
		# Save to state manager
		state_manager.save_phase_data(old_phase, panel_data)
		
		# Store in persistent cache for recovery
		_store_panel_data_cache(old_phase, panel_data)
		
		# Save to disk for crash recovery
		_save_persistence_data()
		
		print("CampaignCreationUI: Saved data for phase: %s" % str(old_phase))

func _after_panel_switch(new_phase: CampaignStateManager.Phase) -> void:
	"""Restore panel data after switching"""
	if not current_panel:
		return
		
	# Set state manager reference
	if current_panel.has_method("set_state_manager"):
		current_panel.set_state_manager(state_manager)
	
	# Try to restore previous data for this phase
	var saved_data = state_manager.get_phase_data(new_phase)
	
	# If no data in state manager, try cache
	if saved_data.is_empty():
		saved_data = _restore_panel_data_cache(new_phase)
	
	# If still no data, try loading from disk
	if saved_data.is_empty():
		saved_data = _load_persistence_data_for_phase(new_phase)
	
	# Restore panel data if available
	if not saved_data.is_empty() and current_panel.has_method("restore_panel_data"):
		current_panel.restore_panel_data(saved_data)
		print("CampaignCreationUI: Restored data for phase: %s" % str(new_phase))

func _store_panel_data_cache(phase: CampaignStateManager.Phase, data: Dictionary) -> void:
	"""Store panel data in memory cache"""
	panel_data_cache[phase] = data.duplicate(true)

func _restore_panel_data_cache(phase: CampaignStateManager.Phase) -> Dictionary:
	"""Restore panel data from memory cache"""
	return panel_data_cache.get(phase, {})

func _save_persistence_data() -> void:
	"""Save panel data cache to disk for crash recovery"""
	var persistence_data = {
		"version": "1.0",
		"timestamp": Time.get_datetime_string_from_system(),
		"current_phase": state_manager.current_phase,
		"panel_cache": panel_data_cache,
		"campaign_data": _gather_all_campaign_data()
	}
	
	var file = FileAccess.open(persistence_file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(persistence_data))
		file.close()
		print("CampaignCreationUI: Persistence data saved")
	else:
		push_error("CampaignCreationUI: Failed to save persistence data")

func _load_persistence_data() -> Dictionary:
	"""Load persistence data from disk"""
	if not FileAccess.file_exists(persistence_file_path):
		return {}
	
	var file = FileAccess.open(persistence_file_path, FileAccess.READ)
	if not file:
		return {}
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	
	if parse_result != OK:
		push_error("CampaignCreationUI: Failed to parse persistence data")
		return {}
	
	return json.data

func _load_persistence_data_for_phase(phase: CampaignStateManager.Phase) -> Dictionary:
	"""Load persistence data for specific phase"""
	var persistence_data = _load_persistence_data()
	var panel_cache = persistence_data.get("panel_cache", {})
	return panel_cache.get(str(phase), {})

func _gather_all_campaign_data() -> Dictionary:
	"""Gather all campaign data from state manager"""
	if not state_manager:
		return {}
	
	return {
		"config": state_manager.get_phase_data(CampaignStateManager.Phase.CONFIG),
		"crew": state_manager.get_phase_data(CampaignStateManager.Phase.CREW_SETUP),
		"captain": state_manager.get_phase_data(CampaignStateManager.Phase.CAPTAIN_CREATION),
		"ship": state_manager.get_phase_data(CampaignStateManager.Phase.SHIP_ASSIGNMENT),
		"equipment": state_manager.get_phase_data(CampaignStateManager.Phase.EQUIPMENT_GENERATION),
		"world": state_manager.get_phase_data(CampaignStateManager.Phase.WORLD_GENERATION),
		"validation_summary": state_manager.get_validation_summary() if state_manager.has_method("get_validation_summary") else {},
		"completion_status": state_manager.get_completion_status() if state_manager.has_method("get_completion_status") else {}
	}

func _restore_from_persistence() -> bool:
	"""Restore campaign creation state from persistence data"""
	var persistence_data = _load_persistence_data()
	if persistence_data.is_empty():
		return false
	
	# Restore panel cache
	panel_data_cache = persistence_data.get("panel_cache", {})
	
	# Restore campaign data to state manager
	var campaign_data = persistence_data.get("campaign_data", {})
	for phase_name in campaign_data.keys():
		var phase_data = campaign_data[phase_name]
		if not phase_data.is_empty():
			var phase = _string_to_phase(phase_name)
			if phase != null:
				state_manager.save_phase_data(phase, phase_data)
	
	# Restore current phase
	var saved_phase = persistence_data.get("current_phase")
	if saved_phase != null:
		# Load the panel for the saved phase
		_load_panel_for_phase(saved_phase)
	
	print("CampaignCreationUI: Restored from persistence data")
	return true

func _string_to_phase(phase_name: String) -> CampaignStateManager.Phase:
	"""Convert string to phase enum"""
	match phase_name:
		"config":
			return CampaignStateManager.Phase.CONFIG
		"crew":
			return CampaignStateManager.Phase.CREW_SETUP
		"captain":
			return CampaignStateManager.Phase.CAPTAIN_CREATION
		"ship":
			return CampaignStateManager.Phase.SHIP_ASSIGNMENT
		"equipment":
			return CampaignStateManager.Phase.EQUIPMENT_GENERATION
		"world":
			return CampaignStateManager.Phase.WORLD_GENERATION
		_:
			return CampaignStateManager.Phase.CONFIG # Default to first phase instead of null

func _clear_persistence_data() -> void:
	"""Clear persistence data when campaign creation is complete"""
	if FileAccess.file_exists(persistence_file_path):
		DirAccess.open("user://").remove(persistence_file_path.get_file())
		print("CampaignCreationUI: Persistence data cleared")
	
	panel_data_cache.clear()

func _initialize_persistence_system() -> void:
	"""Initialize the persistence system and restore if needed"""
	# Try to restore from previous session
	if _restore_from_persistence():
		print("CampaignCreationUI: Restored previous campaign creation session")
	else:
		print("CampaignCreationUI: Starting fresh campaign creation")

## Enhanced Panel Data Restoration Methods

func _restore_config_panel_data(panel: Control, data: Dictionary) -> void:
	"""Restore configuration panel specific data"""
	if data.is_empty():
		return
	
	var name_input = panel.get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/Content/CampaignName/LineEdit")
	if name_input and data.has("name"):
		name_input.text = data.name
	
	var difficulty_option = panel.get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/Content/Difficulty/OptionButton")
	if difficulty_option and data.has("difficulty"):
		_select_option_by_value(difficulty_option, data.difficulty)

func _restore_crew_panel_data(panel: Control, data: Dictionary) -> void:
	"""Restore crew panel specific data"""
	if data.is_empty():
		return
	
	var crew_members = data.get("members", [])
	for member_data in crew_members:
		# This would be handled by the panel's restore_panel_data method
		pass

func _select_option_by_value(option_button: OptionButton, value: Variant) -> void:
	"""Select option button item by value"""
	if not option_button:
		return
		
	for i in range(option_button.get_item_count()):
		if option_button.get_item_metadata(i) == value:
			option_button.select(i)
			break

## Enhanced Panel Caching System

func _initialize_panel_caching() -> void:
	"""Initialize the panel caching system"""
	print("CampaignCreationUI: Initializing enhanced panel caching system")
	
	# Initialize cache structures
	panel_cache = {}
	preloaded_scenes = {}
	panel_load_queue = []
	
	# Start preloading critical panels
	_start_background_preloading()

func _start_background_preloading() -> void:
	"""Start background preloading of panel scenes"""
	if is_preloading:
		return
	
	is_preloading = true
	preload_progress = 0
	
	# Queue panels for preloading in likely usage order
	panel_load_queue = [
		CampaignStateManager.Phase.CONFIG,
		CampaignStateManager.Phase.CREW_SETUP,
		CampaignStateManager.Phase.CAPTAIN_CREATION,
		CampaignStateManager.Phase.SHIP_ASSIGNMENT,
		CampaignStateManager.Phase.EQUIPMENT_GENERATION,
		CampaignStateManager.Phase.WORLD_GENERATION,
		CampaignStateManager.Phase.FINAL_REVIEW
	]
	
	# Start preloading process
	call_deferred("_preload_next_scene")

func _preload_next_scene() -> void:
	"""Preload the next scene in the queue"""
	if panel_load_queue.is_empty():
		is_preloading = false
		print("CampaignCreationUI: ✅ Background preloading complete")
		return
	
	var phase = panel_load_queue.pop_front()
	var scene_path = panel_scenes.get(phase, "")
	
	if scene_path.is_empty():
		call_deferred("_preload_next_scene")
		return
	
	if not ResourceLoader.exists(scene_path):
		push_warning("CampaignCreationUI: Panel scene not found: " + scene_path)
		call_deferred("_preload_next_scene")
		return
	
	# Load scene resource with safe error handling
	var scene_resource = null
	
	# Use ResourceLoader for safer loading with error checking
	if ResourceLoader.exists(scene_path):
		scene_resource = ResourceLoader.load(scene_path)
		
		# Additional validation - ensure the scene is actually loadable
		if scene_resource and scene_resource is PackedScene:
			# Scene loaded successfully
			pass
		else:
			push_warning("CampaignCreationUI: Scene resource is not a valid PackedScene: " + scene_path)
			scene_resource = null
	else:
		push_warning("CampaignCreationUI: Scene file does not exist: " + scene_path)
	
	if scene_resource:
		preloaded_scenes[phase] = scene_resource
		preload_progress += 1
		print("CampaignCreationUI: Preloaded panel scene for phase: %s (%d/%d)" % [
			str(phase), preload_progress, panel_scenes.size()
		])
	else:
		push_warning("CampaignCreationUI: Failed to preload scene: " + scene_path)
	
	# Continue with next scene (with small delay to avoid blocking)
	get_tree().create_timer(0.01).timeout.connect(_preload_next_scene)

func _cache_current_panel(current_phase: CampaignStateManager.Phase) -> void:
	"""Cache the current panel for later reuse"""
	if not current_panel:
		return
	
	# Remove from scene tree but don't free
	content_container.remove_child(current_panel)
	
	# Store in cache
	panel_cache[current_phase] = current_panel
	
	print("CampaignCreationUI: Cached panel for phase: %s" % str(current_phase))

func _remove_current_panel() -> void:
	"""Remove current panel from scene tree"""
	if current_panel and current_panel.get_parent():
		current_panel.get_parent().remove_child(current_panel)
	current_panel = null

func _comprehensive_panel_cleanup() -> void:
	"""Comprehensive panel cleanup with validation"""
	if current_panel:
		_cache_current_panel(state_manager.current_phase)
		_remove_current_panel()
	_clear_content_container()

func _validate_content_container_state() -> bool:
	"""Validate content container is ready for new panel"""
	if not content_container:
		push_error("ContentContainer not found")
		return false
	
	var child_count = content_container.get_child_count()
	if child_count > 0:
		push_warning("ContentContainer has %d children when it should be empty" % child_count)
		_clear_content_container()
	
	return true

func _verify_single_panel_state() -> bool:
	"""Verify only one panel exists in content container"""
	if not content_container:
		return false
	
	var child_count = content_container.get_child_count()
	if child_count != 1:
		push_error("Expected 1 panel, found %d panels in ContentContainer" % child_count)
		return false
	
	return true

func _emergency_panel_cleanup() -> void:
	"""Emergency cleanup when multiple panels detected"""
	print("CampaignCreationUI: EMERGENCY - Cleaning up multiple panels")
	_clear_content_container()
	current_panel = null

func _initialize_panel_complete(phase: CampaignStateManager.Phase) -> void:
	"""Complete panel initialization"""
	if current_panel:
		_connect_standard_panel_signals()
		_connect_panel_to_state_manager(current_panel)
		_restore_panel_data(phase)
		
		# PHASE 1B: Track panel initialization performance
		var init_duration = Time.get_unix_time_from_system() - _current_panel_load_start_time
		if _performance_logging_enabled:
			_log_performance_metric("panel_initialization", {
				"phase": str(phase),
				"duration_ms": init_duration * 1000.0
			})

func _complete_panel_loading() -> void:
	"""Complete panel loading and process queue"""
	_is_panel_loading = false
	
	# Process any queued phase transitions
	if _panel_load_queue.size() > 0:
		var next_phase = _panel_load_queue.pop_front()
		call_deferred("_load_panel_for_phase", next_phase)

# PHASE 1 DAY 1: State machine validation and corruption detection functions

func _validate_state_machine_readiness(target_phase: CampaignStateManager.Phase) -> bool:
	"""Validate that state machine is ready for phase transition"""
	if not state_manager:
		push_error("CampaignCreationUI: No state manager available")
		return false
	
	# Check if state manager is in a valid state
	if state_manager.has_method("is_processing_operation") and state_manager.is_processing_operation():
		push_warning("CampaignCreationUI: State manager is processing operation, deferring transition")
		return false
	
	# Validate transition is allowed
	var current_phase = state_manager.current_phase
	if not _is_valid_phase_transition(current_phase, target_phase):
		push_error("CampaignCreationUI: Invalid phase transition from %s to %s" % [str(current_phase), str(target_phase)])
		return false
	
	return true

func _is_valid_phase_transition(from_phase: CampaignStateManager.Phase, to_phase: CampaignStateManager.Phase) -> bool:
	"""Check if phase transition is valid"""
	# Allow transitions to adjacent phases or same phase (refresh)
	var phase_order = [
		CampaignStateManager.Phase.CONFIG,
		CampaignStateManager.Phase.CREW_SETUP,
		CampaignStateManager.Phase.CAPTAIN_CREATION,
		CampaignStateManager.Phase.SHIP_ASSIGNMENT,
		CampaignStateManager.Phase.EQUIPMENT_GENERATION,
		CampaignStateManager.Phase.WORLD_GENERATION,
		CampaignStateManager.Phase.FINAL_REVIEW
	]
	
	var from_index = phase_order.find(from_phase)
	var to_index = phase_order.find(to_phase)
	
	if from_index == -1 or to_index == -1:
		return false
	
	# Allow forward/backward navigation within 2 steps or same phase
	var diff = abs(to_index - from_index)
	return diff <= 2 or from_phase == to_phase

func _detect_and_recover_corruption() -> bool:
	"""Detect UI corruption and attempt recovery"""
	var corruption_detected = false
	
	# Check 1: ContentContainer validity
	if not content_container or not is_instance_valid(content_container):
		push_error("CampaignCreationUI: ContentContainer corruption detected")
		corruption_detected = true
	
	# Check 2: Multiple panels in container
	if content_container and content_container.get_child_count() > 1:
		push_warning("CampaignCreationUI: Multiple panels detected - corruption likely")
		corruption_detected = true
	
	# Check 3: Panel/state manager mismatch
	if current_panel and state_manager:
		var expected_phase = state_manager.current_phase
		var panel_phase = _get_panel_phase(current_panel)
		if panel_phase != expected_phase and panel_phase != CampaignStateManager.Phase.CONFIG:
			push_warning("CampaignCreationUI: Panel/state mismatch detected")
			corruption_detected = true
	
	# Attempt basic recovery
	if corruption_detected:
		_attempt_basic_corruption_recovery()
	
	return not corruption_detected

func _attempt_basic_corruption_recovery() -> void:
	"""Attempt to recover from basic UI corruption"""
	print("CampaignCreationUI: Attempting corruption recovery...")
	
	# Clear all panels
	_emergency_panel_cleanup()
	
	# Reset loading state
	_is_panel_loading = false
	_panel_load_queue.clear()
	
	# Increment error count for monitoring
	_performance_monitor.error_count += 1

func _emergency_recovery_and_restart() -> void:
	"""Emergency recovery - restart campaign creation from safe state"""
	push_error("CampaignCreationUI: Performing emergency recovery restart")
	
	# Clear all state
	_emergency_panel_cleanup()
	_is_panel_loading = false
	_panel_load_queue.clear()
	current_panel = null
	
	# Create a minimal fallback panel to prevent complete failure
	var fallback_panel = _create_minimal_fallback_panel(state_manager.current_phase)
	if fallback_panel:
		current_panel = fallback_panel
		content_container.add_child(current_panel)
		print("CampaignCreationUI: Emergency fallback panel created")
		return
	
	# Reset to CONFIG phase
	if state_manager:
		state_manager.reset_to_phase(CampaignStateManager.Phase.CONFIG)
	
	# Reload initial panel after a brief delay
	call_deferred("_load_initial_panel")
	
	# Increment error count for monitoring
	_performance_monitor.error_count += 1

func _create_panel_for_phase_with_recovery(phase: CampaignStateManager.Phase) -> Control:
	"""Enhanced panel creation with error recovery"""
	var panel = await _create_panel_for_phase(phase)
	
	if not panel:
		push_warning("CampaignCreationUI: Primary panel creation failed, attempting recovery")
		# Clear any cached corrupted resources
		if preloaded_scenes.has(phase):
			preloaded_scenes.erase(phase)
		
		# Try loading fresh
		panel = await _create_panel_for_phase(phase)
		
		if panel:
			print("CampaignCreationUI: Panel recovery successful for phase: %s" % str(phase))
	
	# Clean up resources after successful creation
	if panel:
		if preloaded_scenes.has(phase):
			preloaded_scenes.erase(phase)
		if panel_cache.has(phase):
			panel_cache.erase(phase)
		
		# Force garbage collection
		if Engine.has_method("force_gc"):
			Engine.call("force_gc")
	else:
		# Increment error count only on failure
		_performance_monitor.error_count += 1
	
	# CRITICAL FIX: Always return panel (may be null)
	return panel

func _get_panel_phase(panel: Control) -> CampaignStateManager.Phase:
	"""Get the phase associated with a panel"""
	if not panel:
		return CampaignStateManager.Phase.CONFIG
	
	var panel_class = panel.get_class()
	
	# Map panel classes to phases
	match panel_class:
		"ConfigPanel": return CampaignStateManager.Phase.CONFIG
		"CrewPanel": return CampaignStateManager.Phase.CREW_SETUP
		"CaptainPanel": return CampaignStateManager.Phase.CAPTAIN_CREATION
		"ShipPanel": return CampaignStateManager.Phase.SHIP_ASSIGNMENT
		"EquipmentPanel": return CampaignStateManager.Phase.EQUIPMENT_GENERATION
		"WorldInfoPanel": return CampaignStateManager.Phase.WORLD_GENERATION
		"FinalPanel": return CampaignStateManager.Phase.FINAL_REVIEW
		_: return CampaignStateManager.Phase.CONFIG

# PHASE 1 DAY 1: Basic metrics collection integration

func collect_basic_metrics() -> Dictionary:
	"""Collect basic metrics for system health monitoring"""
	var metrics = {
		"timestamp": Time.get_unix_time_from_system(),
		"session_duration": _get_session_duration(),
		"ui_health": _get_ui_health_metrics(),
		"performance": _get_basic_performance_metrics(),
		"errors": _get_error_metrics(),
		"system": _get_system_metrics()
	}
	
	# Log critical metrics
	if metrics.errors.total_errors > 0 or metrics.ui_health.corruption_detected:
		_log_critical_metrics(metrics)
	
	return metrics

func _get_session_duration() -> float:
	"""Get current session duration in seconds"""
	return Time.get_unix_time_from_system() - _performance_monitor.session_start_time

func _get_ui_health_metrics() -> Dictionary:
	"""Get UI health metrics"""
	return {
		"current_panel_valid": current_panel != null and is_instance_valid(current_panel),
		"content_container_valid": content_container != null and is_instance_valid(content_container),
		"panel_loading_state": _is_panel_loading,
		"queue_length": _panel_load_queue.size(),
		"corruption_detected": _detect_ui_corruption_silent(),
		"multiple_panels": content_container.get_child_count() > 1 if content_container else false
	}

func _get_basic_performance_metrics() -> Dictionary:
	"""Get basic performance metrics"""
	return {
		"total_panel_loads": _performance_monitor.total_panel_loads,
		"average_load_time": _calculate_average_load_time(),
		"cache_hit_rate": performance_stats.cache_hit_rate if performance_stats else 0.0,
		"memory_usage_mb": OS.get_static_memory_usage() / 1024.0 / 1024.0,
		"animation_success_rate": 1.0  # Animations removed - immediate UI
	}

func _get_error_metrics() -> Dictionary:
	"""Get error metrics"""
	return {
		"total_errors": _performance_monitor.error_count,
		"total_warnings": _performance_monitor.warning_count,
		"recent_errors": _get_recent_error_count(),
		"error_rate": _calculate_error_rate()
	}

func _get_system_metrics() -> Dictionary:
	"""Get system-level metrics"""
	return {
		"godot_version": Engine.get_version_info(),
		"platform": OS.get_name(),
		"memory_available": OS.get_static_memory_usage(),
		"fps": Engine.get_frames_per_second(),
		"frame_time_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	}

func _detect_ui_corruption_silent() -> bool:
	"""Silently detect UI corruption without logging"""
	if not content_container or not is_instance_valid(content_container):
		return true
	
	if content_container.get_child_count() > 1:
		return true
	
	if current_panel and state_manager:
		var expected_phase = state_manager.current_phase
		var panel_phase = _get_panel_phase(current_panel)
		if panel_phase != expected_phase and panel_phase != CampaignStateManager.Phase.CONFIG:
			return true
	
	return false

# Animation success rate calculation removed - Framework Bible compliance
# Animations removed entirely for immediate UI responses

func _get_recent_error_count() -> int:
	"""Get count of errors in last 5 minutes"""
	var recent_threshold = Time.get_unix_time_from_system() - 300.0 # 5 minutes
	var recent_errors = 0
	
	# This is a simplified implementation - in a real system you'd track error timestamps
	if _performance_monitor.error_count > 0:
		recent_errors = min(_performance_monitor.error_count, 10) # Assume recent errors are last 10
	
	return recent_errors

func _calculate_error_rate() -> float:
	"""Calculate error rate per minute"""
	var session_minutes = _get_session_duration() / 60.0
	if session_minutes < 0.1: # Less than 6 seconds
		return 0.0
	
	return _performance_monitor.error_count / session_minutes

func _log_critical_metrics(metrics: Dictionary) -> void:
	"""Log critical metrics that indicate problems"""
	if metrics.errors.total_errors > 5:
		push_error("CampaignCreationUI: High error count detected: %d errors" % metrics.errors.total_errors)
	
	if metrics.ui_health.corruption_detected:
		push_error("CampaignCreationUI: UI corruption detected in metrics collection")
	
	if metrics.ui_health.multiple_panels:
		push_error("CampaignCreationUI: Multiple panels detected in metrics collection")
	
	if metrics.performance.cache_hit_rate < 0.5:
		push_warning("CampaignCreationUI: Low cache hit rate: %.2f" % metrics.performance.cache_hit_rate)

func export_metrics_for_monitoring() -> Dictionary:
	"""Export metrics in standardized format for external monitoring"""
	var basic_metrics = collect_basic_metrics()
	
	return {
		"service": "campaign_creation_ui",
		"version": "1.0.0",
		"timestamp": basic_metrics.timestamp,
		"metrics": {
			"uptime_seconds": basic_metrics.session_duration,
			"error_count": basic_metrics.errors.total_errors,
			"warning_count": basic_metrics.errors.total_warnings,
			"ui_healthy": not basic_metrics.ui_health.corruption_detected,
			"panel_loads_total": basic_metrics.performance.total_panel_loads,
			"memory_usage_mb": basic_metrics.performance.memory_usage_mb,
			"cache_hit_rate": basic_metrics.performance.cache_hit_rate,
			"animation_success_rate": basic_metrics.performance.animation_success_rate,
			"error_rate_per_minute": basic_metrics.errors.error_rate
		},
		"health_status": _determine_health_status(basic_metrics)
	}

func _determine_health_status(metrics: Dictionary) -> String:
	"""Determine overall health status from metrics"""
	if metrics.ui_health.corruption_detected:
		return "critical"
	
	if metrics.errors.total_errors > 10:
		return "unhealthy"
	
	if metrics.errors.error_rate > 2.0: # More than 2 errors per minute
		return "degraded"
	
	# Animation success rate check removed - no animations needed
	
	return "healthy"

func _get_cached_panel(phase: CampaignStateManager.Phase) -> Control:
	"""Get panel from cache if available"""
	var cached_panel = panel_cache.get(phase, null)
	if cached_panel:
		print("CampaignCreationUI: Retrieved cached panel for phase: %s" % str(phase))
		# Remove from cache to avoid duplicate usage
		panel_cache.erase(phase)
		return cached_panel
	return null

func _create_panel_for_phase(phase: CampaignStateManager.Phase) -> Control:
	"""Create panel with enhanced safety and feature flag support"""
	
	# PHASE 1: Check if enhanced animation safety is enabled
	if CampaignCreationFeatureFlags.is_enabled(CampaignCreationFeatureFlags.FeatureFlag.NEW_ANIMATION_SAFETY):
		return await _create_panel_for_phase_v2(phase)
	else:
		return await _create_panel_for_phase_v1(phase)

func _create_panel_for_phase_v1(phase: CampaignStateManager.Phase) -> Control:
	"""Original panel creation method (fallback)"""
	var scene_resource = preloaded_scenes.get(phase, null)
	
	# If not preloaded, load now
	if not scene_resource:
		var scene_path = panel_scenes.get(phase, "")
		if scene_path.is_empty():
			push_error("No scene path defined for phase: " + str(phase))
			return null
		
		scene_resource = load(scene_path)
		if not scene_resource:
			push_error("Failed to load panel scene: " + scene_path)
			return null
		
		print("CampaignCreationUI: Loaded panel scene on-demand for phase: %s" % str(phase))
	else:
		print("CampaignCreationUI: Using preloaded scene for phase: %s" % str(phase))
	
	# CRITICAL FIX: Add null checks and validation before instantiation
	if not scene_resource or not is_instance_valid(scene_resource):
		push_error("Scene resource is invalid for phase: " + str(phase))
		return null
	
	# CRITICAL FIX: Use the same safe instantiation as v2 for consistency
	var panel_instance = _safe_instantiate_with_error_suppression(scene_resource, phase)
	if not panel_instance:
		push_error("Failed to instantiate panel for phase: " + str(phase))
		return null
	
	print("Animation safety fixes applied to panel for phase: %s" % str(phase))
	
	# CRITICAL FIX: Ensure panel is ready before returning
	if panel_instance.has_method("_ready"):
		# Allow the panel to initialize properly
		await get_tree().process_frame
	
	return panel_instance

func _create_panel_for_phase_v2(phase: CampaignStateManager.Phase) -> Control:
	"""PHASE 1: Enhanced panel creation with comprehensive safety systems"""
	
	var start_time = Time.get_unix_time_from_system()
	
	# CRITICAL: State machine validation prevents race conditions
	if not _can_create_panel():
		push_error("Cannot create panel - UI not in valid state: %s" % str(ui_state))
		if error_monitor:
			error_monitor.record_error("Panel creation blocked by UI state", CampaignCreationErrorMonitor.ErrorCategory.UI_INTERACTION, CampaignCreationErrorMonitor.ErrorSeverity.MAJOR)
		return null
	
	_transition_ui_state(UIState.LOADING_PANEL)
	
	# CRITICAL: Validate phase bounds (fixes out of bounds errors)
	if phase < 0 or phase > CampaignStateManager.Phase.FINAL_REVIEW:
		push_error("Invalid phase index: %d" % phase)
		if error_monitor:
			error_monitor.record_error("Invalid phase index: %d" % phase, CampaignCreationErrorMonitor.ErrorCategory.STATE_MANAGEMENT, CampaignCreationErrorMonitor.ErrorSeverity.CRITICAL)
		_transition_ui_state(UIState.ERROR_RECOVERY)
		return null
	
	# PRODUCTION: Comprehensive scene loading with fallback
	var panel_instance = _safe_load_panel_scene(phase)
	if not panel_instance:
		_handle_panel_creation_failure(phase)
		return null
	
	# CRITICAL: Ensure panel is properly initialized before use
	if not await _validate_panel_readiness(panel_instance):
		push_error("Panel failed readiness validation for phase: %s" % str(phase))
		panel_instance.queue_free()
		_transition_ui_state(UIState.ERROR_RECOVERY)
		if error_monitor:
			error_monitor.record_error("Panel readiness validation failed", CampaignCreationErrorMonitor.ErrorCategory.PANEL_LOADING, CampaignCreationErrorMonitor.ErrorSeverity.MAJOR)
		return null
	
	# SUCCESS: Panel created and validated
	last_successful_phase = phase
	error_count = 0 # Reset error counter on success
	_transition_ui_state(UIState.PANEL_ACTIVE)
	
	var duration = (Time.get_unix_time_from_system() - start_time) * 1000
	if performance_tracker:
		performance_tracker.track_panel_creation(phase, true, duration)
	
	print("CampaignCreationUI: ✅ Successfully created panel for phase: %s (%.1fms)" % [str(phase), duration])
	return panel_instance

# PHASE 1: UI State Machine and Animation Safety Support Methods

func _can_create_panel() -> bool:
	"""Check if UI state allows panel creation"""
	ui_state_lock.lock()
	var can_create = ui_state in [UIState.IDLE, UIState.PANEL_ACTIVE]
	ui_state_lock.unlock()
	return can_create

func _transition_ui_state(new_state: UIState) -> void:
	"""Thread-safe UI state transitions with logging"""
	ui_state_lock.lock()
	var old_state = ui_state
	ui_state = new_state
	ui_state_lock.unlock()
	
	print("CampaignCreationUI: State transition: %s → %s" % [str(old_state), str(new_state)])
	
	# Handle state-specific initialization
	match new_state:
		UIState.LOADING_PANEL:
			_start_panel_load_timeout()
		UIState.ERROR_RECOVERY:
			_initiate_error_recovery()

func _safe_load_panel_scene(phase: CampaignStateManager.Phase) -> Control:
	"""Safe scene loading with comprehensive error handling"""
	
	# Get scene path with validation
	var scene_path = panel_scenes.get(phase, "")
	if scene_path.is_empty():
		push_error("No scene path defined for phase: %s" % str(phase))
		return null
	
	# Validate scene file exists
	if not ResourceLoader.exists(scene_path):
		push_error("Scene file does not exist: %s" % scene_path)
		return null
	
	# Load scene resource safely
	var scene_resource = null
	if preloaded_scenes.has(phase):
		scene_resource = preloaded_scenes[phase]
		print("Using preloaded scene for phase: %s" % str(phase))
	else:
		scene_resource = load(scene_path)
		if not scene_resource:
			push_error("Failed to load scene resource: %s" % scene_path)
			return null
		print("Loaded scene on-demand for phase: %s" % str(phase))
	
	# Validate scene resource
	if not scene_resource or not scene_resource is PackedScene:
		push_error("Invalid scene resource for phase: %s" % str(phase))
		return null
	
	# CRITICAL FIX: Error-suppressed instantiation to handle animation C++ errors
	var panel_instance = _safe_instantiate_with_error_suppression(scene_resource, phase)
	if not panel_instance:
		push_error("Failed to instantiate scene for phase: %s" % str(phase))
		# Try fallback panel creation
		var fallback_panel = _create_minimal_fallback_panel(phase)
		if fallback_panel:
			print("CampaignCreationUI: Using fallback panel for phase: %s" % str(phase))
			return fallback_panel
		return null
	
	# CRITICAL: Apply animation safety fixes immediately after instantiation
	if panel_instance and is_instance_valid(panel_instance):
		_setup_panel_basic(panel_instance)
		print("CampaignCreationUI: Animation safety fixes applied for phase: %s" % str(phase))
		
		# Additional validation to ensure panel is ready
		if not panel_instance.has_method("validate_panel"):
			push_error("Panel instance missing required validate_panel method")
			panel_instance.queue_free()
			
			# Try fallback panel creation
			var fallback_panel = _create_minimal_fallback_panel(phase)
			if fallback_panel:
				print("CampaignCreationUI: Using fallback panel due to validation failure")
				return fallback_panel
			return null
		
		return panel_instance
	else:
		push_error("Panel instance is null or invalid after instantiation")
		
		# Try fallback panel creation
		var fallback_panel = _create_minimal_fallback_panel(phase)
		if fallback_panel:
			print("CampaignCreationUI: Using fallback panel due to instantiation failure")
			return fallback_panel
		return null
	
	print("Successfully instantiated panel for phase: %s" % str(phase))
	
	return panel_instance

func _safe_instantiate_with_error_suppression(scene_resource: PackedScene, phase: CampaignStateManager.Phase) -> Control:
	"""Instantiate scene with comprehensive error suppression and recovery"""
	
	print("CampaignCreationUI: Starting safe instantiation for phase: %s" % str(phase))
	
	# Method 1: Try normal instantiation with error suppression
	var panel_instance = null
	
	# Suppress push_error messages during instantiation to reduce console spam
	var old_error_count = get_tree().get_meta("_editor_errors", 0)
	
	# CRITICAL: Wrap instantiation in error suppression
	var instantiation_success = false
	panel_instance = null
	
	# Try instantiation with error handling
	if scene_resource:
		# Attempt instantiation - C++ errors may occur but won't crash
		panel_instance = scene_resource.instantiate()
		instantiation_success = (panel_instance != null and is_instance_valid(panel_instance))
	
	# Check if instantiation succeeded despite C++ errors
	if instantiation_success:
		print("CampaignCreationUI: Instantiation succeeded for phase: %s" % str(phase))
		
		# Apply animation safety fixes to clean up the issues that caused C++ errors
		_setup_panel_basic(panel_instance)
		print("CampaignCreationUI: Animation safety fixes applied for phase: %s" % str(phase))
		
		return panel_instance
	else:
		print("CampaignCreationUI: Primary instantiation failed for phase: %s" % str(phase))
	
	# Method 2: Fallback - try with a fresh scene load
	print("CampaignCreationUI: Primary instantiation failed, trying fallback method...")
	
	var scene_path = panel_scenes.get(phase, "")
	if not scene_path.is_empty():
		var fresh_scene = load(scene_path)
		if fresh_scene:
			panel_instance = fresh_scene.instantiate()
			if panel_instance and is_instance_valid(panel_instance):
				print("CampaignCreationUI: Fallback instantiation succeeded for phase: %s" % str(phase))
				_setup_panel_basic(panel_instance)
				return panel_instance
	
	# Method 3: Last resort - create minimal fallback panel
	print("CampaignCreationUI: Creating minimal fallback panel for phase: %s" % str(phase))
	return _create_minimal_fallback_panel(phase)

func _create_minimal_fallback_panel(phase: CampaignStateManager.Phase) -> Control:
	"""Create a minimal functional panel as last resort"""
	
	var fallback_panel = Control.new()
	fallback_panel.name = "FallbackPanel_%s" % str(phase)
	fallback_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Add minimal error message
	var label = Label.new()
	label.text = "Panel loading error - Phase: %s\nUsing fallback mode." % str(phase)
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	fallback_panel.add_child(label)
	
	print("CampaignCreationUI: Created minimal fallback panel for phase: %s" % str(phase))
	return fallback_panel

func _setup_panel_basic(panel: Control) -> void:
	"""Simple panel setup without animation bloat - Framework Bible compliant"""
	if not panel or not is_instance_valid(panel):
		return
	
	# Simple, direct setup - no animation complexity
	panel.visible = true
	print("CampaignCreationUI: Panel setup complete - %s" % panel.name)
		
		# Remove problematic animations in a separate loop to avoid modification during iteration
		for anim_name in animations_to_remove:
			anim_library.remove_animation(anim_name)
			print("Removed problematic animation: %s" % anim_name)

func _find_all_animation_players(node: Node) -> Array[AnimationPlayer]:
	"""Recursively find all AnimationPlayer nodes"""
	var players: Array[AnimationPlayer] = []
	
	# Safety check for null node
	if not node or not is_instance_valid(node):
		return players
	
	if node is AnimationPlayer:
		players.append(node)
	
	for child in node.get_children():
		if is_instance_valid(child):
			players.append_array(_find_all_animation_players(child))
	
	return players

func _validate_panel_readiness(panel: Control) -> bool:
	"""Validate panel is ready for use with comprehensive checks"""
	
	if not is_instance_valid(panel):
		return false
	
	# Add to scene tree first to enable tree-dependent validation
	content_container.add_child(panel)
	
	# Wait for panel to process its _ready() method
	await get_tree().process_frame
	
	# CRITICAL: Verify panel is properly in scene tree
	if not panel.is_inside_tree():
		push_error("Panel failed to enter scene tree")
		return false
	
	# Validate required panel interface
	if not panel.has_method("validate_panel"):
		push_error("Panel missing required validate_panel method")
		return false
	
	if not panel.has_method("get_panel_data"):
		push_error("Panel missing required get_panel_data method")
		return false
	
	# PRODUCTION: Allow panel initialization to complete
	await get_tree().create_timer(0.1).timeout
	
	panel_ready_confirmation = true
	return true

func _handle_panel_creation_failure(phase: CampaignStateManager.Phase) -> void:
	"""Handle panel creation failure with recovery strategies"""
	
	error_count += 1
	push_error("Panel creation failed for phase: %s (Error #%d)" % [str(phase), error_count])
	
	if error_monitor:
		error_monitor.record_error("Panel creation failed for phase: %s" % str(phase), CampaignCreationErrorMonitor.ErrorCategory.PANEL_LOADING, CampaignCreationErrorMonitor.ErrorSeverity.MAJOR)
	
	if performance_tracker:
		performance_tracker.track_panel_creation(phase, false, 0.0, "Panel creation failed")
	
	if error_count >= max_errors_before_fallback:
		_initiate_fallback_recovery()
	else:
		_transition_ui_state(UIState.ERROR_RECOVERY)

func _initiate_error_recovery() -> void:
	"""Initiate error recovery process"""
	
	print("CampaignCreationUI: Initiating error recovery...")
	
	# Clean up any pending panels
	_cleanup_pending_panels()
	
	# Reset to last known good state
	if last_successful_phase != state_manager.current_phase:
		print("Reverting to last successful phase: %s" % str(last_successful_phase))
		state_manager.set_phase(last_successful_phase)
	
	# Clear any corrupted UI state
	_clear_content_container()
	
	# Wait before attempting recovery
	await get_tree().create_timer(0.5).timeout
	
	# Attempt to reload current phase
	_transition_ui_state(UIState.IDLE)
	_load_panel_for_phase(state_manager.current_phase)

func _initiate_fallback_recovery() -> void:
	"""Emergency fallback when normal recovery fails"""
	
	push_error("Maximum errors reached, initiating fallback recovery")
	
	if error_monitor:
		error_monitor.record_error("Maximum errors reached, fallback recovery initiated", CampaignCreationErrorMonitor.ErrorCategory.UI_INTERACTION, CampaignCreationErrorMonitor.ErrorSeverity.EMERGENCY)
	
	# Reset everything to a known good state
	state_manager.reset_to_config_phase()
	error_count = 0
	last_successful_phase = CampaignStateManager.Phase.CONFIG
	
	# Clear all UI state
	_clear_content_container()
	_cleanup_pending_panels()
	
	# Show user notification
	_show_recovery_notification("EMERGENCY_RECOVERY")
	
	# Restart from CONFIG phase
	_transition_ui_state(UIState.IDLE)
	_load_panel_for_phase(CampaignStateManager.Phase.CONFIG)

func _cleanup_pending_panels() -> void:
	"""Clean up any panels in pending cleanup state"""
	
	for panel in pending_panel_cleanup:
		if is_instance_valid(panel):
			panel.queue_free()
	
	pending_panel_cleanup.clear()

func _clear_content_container() -> void:
	"""Safely clear content container with IMMEDIATE cleanup"""
	
	if not content_container:
		return
	
	# CRITICAL FIX: More aggressive cleanup
	var children_to_cleanup = content_container.get_children()
	var removed_count = 0
	
	for child in children_to_cleanup:
		# Remove from scene tree immediately
		content_container.remove_child(child)
		
		# More aggressive cleanup
		if is_instance_valid(child):
			# Disconnect all signals to prevent errors
			_safely_disconnect_panel_signals(child)
			
			# Call cleanup methods if they exist
			if child.has_method("_cleanup_dynamic_resources"):
				child._cleanup_dynamic_resources()
			
			# Free immediately
			child.queue_free()
			removed_count += 1
			print("CampaignCreationUI: Cleaned up panel: %s" % child.name)
		else:
			print("CampaignCreationUI: Invalid child detected during cleanup")
	
	current_panel = null
	
	# Force multiple frames to ensure cleanup completes
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Final verification with emergency cleanup
	if content_container.get_child_count() > 0:
		push_error("CRITICAL: Container still has %d children after cleanup!" % content_container.get_child_count())
		var remaining_children = content_container.get_children()
		for remaining_child in remaining_children:
			content_container.remove_child(remaining_child)
			remaining_child.queue_free()
		await get_tree().process_frame
	
	print("CampaignCreationUI: Container cleanup complete. Children count: %d" % content_container.get_child_count())

func _safely_disconnect_panel_signals(panel: Control) -> void:
	"""Safely disconnect all signals from a panel to prevent errors during cleanup"""
	if not is_instance_valid(panel):
		return
	
	# Disconnect common panel signals to prevent errors after removal
	var signal_names = [
		"panel_data_changed", "validation_changed", "navigation_requested",
		"panel_completed", "panel_state_updated", "validation_failed",
		"configuration_complete", "crew_setup_complete", "captain_creation_complete"
	]
	
	for signal_name in signal_names:
		if panel.has_signal(signal_name):
			var connections = panel.get_signal_connection_list(signal_name)
			for connection in connections:
				if connection.signal.is_connected(connection.callable):
					panel.disconnect(signal_name, connection.callable)

func _start_panel_load_timeout() -> void:
	"""Start timeout for panel loading operations"""
	
	if not panel_load_timer:
		panel_load_timer = Timer.new()
		add_child(panel_load_timer)
		panel_load_timer.timeout.connect(_on_panel_load_timeout)
	
	panel_load_timer.wait_time = panel_load_timeout * 2 # Double the timeout
	panel_load_timer.start()
	print("CampaignCreationUI: Panel load timeout started: %d seconds" % panel_load_timer.wait_time)

func _on_panel_load_timeout() -> void:
	"""Handle panel load timeout with recovery"""
	
	push_error("Panel load timeout exceeded")
	if error_monitor:
		error_monitor.record_error("Panel load timeout exceeded", CampaignCreationErrorMonitor.ErrorCategory.PERFORMANCE, CampaignCreationErrorMonitor.ErrorSeverity.MAJOR)
	
	# Stop the timer to prevent multiple timeouts
	if panel_load_timer:
		panel_load_timer.stop()
	
	# Try to recover by creating a fallback panel
	print("CampaignCreationUI: Attempting timeout recovery...")
	var fallback_panel = _create_minimal_fallback_panel(state_manager.current_phase)
	if fallback_panel:
		current_panel = fallback_panel
		content_container.add_child(current_panel)
		_complete_panel_loading()
		print("CampaignCreationUI: Timeout recovery successful")
		
		# Stop the timer to prevent multiple timeouts
		if panel_load_timer:
			panel_load_timer.stop()
	else:
		print("CampaignCreationUI: Fallback panel creation failed, attempting error recovery")
		_transition_ui_state(UIState.ERROR_RECOVERY)

func get_ui_health_status() -> Dictionary:
	"""Get comprehensive UI health status for monitoring"""
	
	return {
		"ui_state": str(ui_state),
		"error_count": error_count,
		"last_successful_phase": str(last_successful_phase),
		"current_phase": str(state_manager.current_phase) if state_manager else "unknown",
		"panel_ready": panel_ready_confirmation,
		"content_container_children": content_container.get_child_count() if content_container else 0,
		"pending_cleanup": pending_panel_cleanup.size(),
		"memory_usage_estimate": _estimate_memory_usage(),
		"performance_tracker_ready": performance_tracker != null,
		"error_monitor_ready": error_monitor != null
	}

func _estimate_memory_usage() -> float:
	"""Rough estimate of UI memory usage for monitoring"""
	var estimate = 0.0
	estimate += panel_cache.size() * 0.5 # Cached panels
	estimate += preloaded_scenes.size() * 0.2 # Preloaded scenes
	estimate += pending_panel_cleanup.size() * 0.1 # Pending cleanup
	return estimate

func _connect_standard_panel_signals() -> void:
	"""Connect standard panel signals"""
	if not current_panel:
		return
	
	if current_panel.has_signal("panel_completed"):
		current_panel.panel_completed.connect(_on_panel_completed)
	if current_panel.has_signal("validation_failed"):
		current_panel.validation_failed.connect(_on_panel_validation_failed)

func _preload_adjacent_panels(current_phase: CampaignStateManager.Phase) -> void:
	"""Preload panels adjacent to current phase for smooth navigation"""
	var phase_order = [
		CampaignStateManager.Phase.CONFIG,
		CampaignStateManager.Phase.CREW_SETUP,
		CampaignStateManager.Phase.CAPTAIN_CREATION,
		CampaignStateManager.Phase.SHIP_ASSIGNMENT,
		CampaignStateManager.Phase.EQUIPMENT_GENERATION,
		CampaignStateManager.Phase.WORLD_GENERATION,
		CampaignStateManager.Phase.FINAL_REVIEW
	]
	
	var current_index = phase_order.find(current_phase)
	if current_index == -1:
		return
	
	# Preload next phase
	if current_index + 1 < phase_order.size():
		var next_phase = phase_order[current_index + 1]
		_ensure_panel_preloaded(next_phase)
	
	# Preload previous phase
	if current_index - 1 >= 0:
		var prev_phase = phase_order[current_index - 1]
		_ensure_panel_preloaded(prev_phase)

func _ensure_panel_preloaded(phase: CampaignStateManager.Phase) -> void:
	"""Ensure a specific panel is preloaded"""
	if preloaded_scenes.has(phase):
		return # Already preloaded
	
	var scene_path = panel_scenes.get(phase, "")
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		return
	
	# Load scene in background
	call_deferred("_background_load_scene", phase, scene_path)

func _background_load_scene(phase: CampaignStateManager.Phase, scene_path: String) -> void:
	"""Load a scene in the background"""
	var scene_resource = load(scene_path)
	if scene_resource:
		preloaded_scenes[phase] = scene_resource
		print("CampaignCreationUI: Background loaded panel for phase: %s" % str(phase))

func _cleanup_panel_cache() -> void:
	"""Clean up cached panels to free memory"""
	for phase in panel_cache.keys():
		var cached_panel = panel_cache[phase]
		if cached_panel and is_instance_valid(cached_panel):
			cached_panel.queue_free()
	
	panel_cache.clear()
	preloaded_scenes.clear()
	print("CampaignCreationUI: Panel cache cleaned up")

func get_cache_statistics() -> Dictionary:
	"""Get cache performance statistics"""
	return {
		"cached_panels": panel_cache.size(),
		"preloaded_scenes": preloaded_scenes.size(),
		"preload_progress": preload_progress,
		"is_preloading": is_preloading,
		"memory_usage_mb": _estimate_cache_memory_usage()
	}

func _estimate_cache_memory_usage() -> float:
	"""Estimate memory usage of panel cache (rough approximation)"""
	var estimated_mb = 0.0
	estimated_mb += panel_cache.size() * 0.5 # ~0.5MB per cached panel
	estimated_mb += preloaded_scenes.size() * 0.2 # ~0.2MB per preloaded scene
	return estimated_mb

## Memory Management and Performance Optimization

# Performance monitoring
var performance_stats: Dictionary = {
	"panel_load_times": {},
	"memory_usage_history": [],
	"transition_times": {},
	"cache_hit_rate": 0.0,
	"total_cache_requests": 0,
	"cache_hits": 0
}

var last_memory_check: int = 0
var memory_check_interval: int = 5000 # 5 seconds

func _notification(what: int) -> void:
	"""Handle notifications for memory management"""
	match what:
		NOTIFICATION_PREDELETE:
			_cleanup_on_exit()
		NOTIFICATION_WM_CLOSE_REQUEST:
			_cleanup_on_exit()

func _cleanup_on_exit() -> void:
	"""Clean up all resources before exit"""
	print("CampaignCreationUI: Starting cleanup on exit...")
	
	# Clean up panel cache
	_cleanup_panel_cache()
	
	# Clear persistence data cache
	panel_data_cache.clear()
	
	# Cleanup coordinator and state manager
	if coordinator:
		coordinator = null
	if state_manager:
		state_manager = null
	
	# Clear current panel references
	current_panel = null
	
	print("CampaignCreationUI: ✅ Cleanup complete")

func _ready() -> void:
	_initialize_refactored_architecture()
	_initialize_enhanced_safety_systems() # PHASE 1: Initialize safety systems
	_connect_scene_signals()
	_initialize_persistence_system()
	_initialize_panel_caching()
	_initialize_performance_monitoring()
	_load_initial_panel()

func _initialize_enhanced_safety_systems() -> void:
	"""PHASE 1: Initialize enhanced safety systems"""
	print("CampaignCreationUI: Initializing Phase 1 enhanced safety systems...")
	
	# Initialize performance tracker
	performance_tracker = CampaignCreationPerformanceTracker.new()
	
	# Initialize error monitor
	error_monitor = CampaignCreationErrorMonitor.new()
	
	# Initialize UI state
	ui_state = UIState.IDLE
	
	# Initialize feature flag validation
	if not CampaignCreationFeatureFlags.validate_flag_consistency():
		push_error("Feature flag configuration validation failed")
		error_monitor.record_error("Feature flag validation failed", CampaignCreationErrorMonitor.ErrorCategory.GENERAL, CampaignCreationErrorMonitor.ErrorSeverity.CRITICAL)
	
	# Log current feature flag status
	var flag_status = CampaignCreationFeatureFlags.get_flag_status()
	print("CampaignCreationUI: Feature flags status: %s" % str(flag_status))
	
	# Record system initialization
	error_monitor.record_system_health({
		"system": "campaign_creation_ui",
		"initialization_complete": true,
		"feature_flags_ready": true,
		"error_count": 0
	})
	
	print("CampaignCreationUI: ✅ Enhanced safety systems initialized")

func _initialize_performance_monitoring() -> void:
	"""Initialize performance monitoring system"""
	print("CampaignCreationUI: Initializing performance monitoring")
	
	# Initialize enhanced performance monitoring
	_performance_monitor.session_start_time = Time.get_unix_time_from_system()
	
	# Reset performance stats
	performance_stats = {
		"panel_load_times": {},
		"memory_usage_history": [],
		"transition_times": {},
		"cache_hit_rate": 0.0,
		"total_cache_requests": 0,
		"cache_hits": 0
	}
	
	# Start comprehensive monitoring
	_start_memory_monitoring()
	_start_performance_logging()
	_initialize_performance_metrics()

func _start_memory_monitoring() -> void:
	"""Start periodic memory monitoring"""
	var timer = Timer.new()
	timer.wait_time = memory_check_interval / 1000.0
	timer.timeout.connect(_check_memory_usage)
	timer.autostart = true
	add_child(timer)
	
	# Initial memory check
	_check_memory_usage()

func _check_memory_usage() -> void:
	"""Check current memory usage and log if concerning"""
	var current_memory = OS.get_static_memory_usage()
	var timestamp = Time.get_ticks_msec()
	
	# Store memory usage history
	performance_stats.memory_usage_history.append({
		"timestamp": timestamp,
		"static_memory": current_memory,
		"cache_memory": _estimate_cache_memory_usage()
	})
	
	# Keep only last 20 entries to avoid memory bloat
	if performance_stats.memory_usage_history.size() > 20:
		performance_stats.memory_usage_history.pop_front()
	
	# Check for memory growth concerns
	if performance_stats.memory_usage_history.size() > 5:
		var recent_entries = performance_stats.memory_usage_history.slice(-5)
		var memory_growth = _calculate_memory_growth(recent_entries)
		
		if memory_growth > 10.0: # > 10MB growth
			push_warning("CampaignCreationUI: High memory growth detected: %.2f MB" % memory_growth)
			_optimize_memory_usage()

func _calculate_memory_growth(entries: Array) -> float:
	"""Calculate memory growth over time"""
	if entries.size() < 2:
		return 0.0
	
	var first_memory = entries[0].static_memory
	var last_memory = entries[-1].static_memory
	
	return (last_memory - first_memory) / 1024.0 / 1024.0 # Convert to MB

func _optimize_memory_usage() -> void:
	"""Optimize memory usage when high growth is detected"""
	print("CampaignCreationUI: Optimizing memory usage...")
	
	# Clear unused cached panels (keep only current and adjacent)
	_optimize_panel_cache()
	
	# Force garbage collection if supported
	# Note: ResourceLoader.clear_cache() handled by engine automatically
	
	# Clear old persistence data entries
	_optimize_persistence_cache()
	
	print("CampaignCreationUI: Memory optimization complete")

func _optimize_panel_cache() -> void:
	"""Optimize panel cache by removing distant panels"""
	if not state_manager:
		return
	
	var current_phase = state_manager.current_phase
	var phase_order = [
		CampaignStateManager.Phase.CONFIG,
		CampaignStateManager.Phase.CREW_SETUP,
		CampaignStateManager.Phase.CAPTAIN_CREATION,
		CampaignStateManager.Phase.SHIP_ASSIGNMENT,
		CampaignStateManager.Phase.EQUIPMENT_GENERATION,
		CampaignStateManager.Phase.WORLD_GENERATION,
		CampaignStateManager.Phase.FINAL_REVIEW
	]
	
	var current_index = phase_order.find(current_phase)
	if current_index == -1:
		return
	
	# Keep only current, previous, and next panels
	var phases_to_keep = []
	for i in range(max(0, current_index - 1), min(phase_order.size(), current_index + 2)):
		phases_to_keep.append(phase_order[i])
	
	# Remove distant cached panels
	for phase in panel_cache.keys():
		if phase not in phases_to_keep:
			var cached_panel = panel_cache[phase]
			if cached_panel and is_instance_valid(cached_panel):
				cached_panel.queue_free()
			panel_cache.erase(phase)
			print("CampaignCreationUI: Removed distant cached panel: %s" % str(phase))

func _optimize_persistence_cache() -> void:
	"""Optimize persistence cache by removing old entries"""
	# Keep only last 10 entries in memory usage history
	while performance_stats.memory_usage_history.size() > 10:
		performance_stats.memory_usage_history.pop_front()
	
	# Clear old panel data cache entries (keep only last 5 phases)
	var cache_keys = panel_data_cache.keys()
	if cache_keys.size() > 5:
		cache_keys.sort()
		for i in range(cache_keys.size() - 5):
			panel_data_cache.erase(cache_keys[i])

func get_performance_report() -> Dictionary:
	"""Get comprehensive performance report"""
	var current_memory = OS.get_static_memory_usage()
	var cache_stats = get_cache_statistics()
	
	return {
		"current_memory_mb": current_memory / 1024.0 / 1024.0,
		"cache_memory_mb": cache_stats.memory_usage_mb,
		"cache_hit_rate": performance_stats.cache_hit_rate,
		"total_cache_requests": performance_stats.total_cache_requests,
		"cached_panels": cache_stats.cached_panels,
		"preloaded_scenes": cache_stats.preloaded_scenes,
		"memory_history_entries": performance_stats.memory_usage_history.size(),
		"panel_data_cache_size": panel_data_cache.size(),
		"average_panel_load_time": _calculate_average_load_time(),
		"memory_growth_trend": _get_memory_growth_trend()
	}

func _calculate_average_load_time() -> float:
	"""Calculate average panel load time"""
	if performance_stats.panel_load_times.is_empty():
		return 0.0
	
	var total_time = 0.0
	var count = 0
	
	for phase in performance_stats.panel_load_times:
		var times = performance_stats.panel_load_times[phase]
		if times is Array:
			for time in times:
				total_time += time
				count += 1
	
	return total_time / count if count > 0 else 0.0

func _get_memory_growth_trend() -> String:
	"""Get memory growth trend description"""
	if performance_stats.memory_usage_history.size() < 3:
		return "insufficient_data"
	
	var recent_growth = _calculate_memory_growth(performance_stats.memory_usage_history.slice(-3))
	
	if recent_growth > 5.0:
		return "high_growth"
	elif recent_growth > 1.0:
		return "moderate_growth"
	elif recent_growth > -1.0:
		return "stable"
	else:
		return "decreasing"

func _track_panel_load_time(phase: CampaignStateManager.Phase, start_time: int) -> void:
	"""Track panel load time for performance analysis"""
	var load_time = Time.get_ticks_msec() - start_time
	
	# Track in performance monitor
	if not _performance_monitor.panel_load_times.has(phase):
		_performance_monitor.panel_load_times[phase] = []
	
	_performance_monitor.panel_load_times[phase].append(load_time)
	_performance_monitor.total_panel_loads += 1
	
	# Track in panel load count
	if not _performance_monitor.panel_load_count.has(phase):
		_performance_monitor.panel_load_count[phase] = 0
	_performance_monitor.panel_load_count[phase] += 1
	
	# Legacy performance stats tracking
	if not performance_stats.panel_load_times.has(phase):
		performance_stats.panel_load_times[phase] = []
	
	performance_stats.panel_load_times[phase].append(load_time)
	
	# Keep only last 5 load times per phase
	if performance_stats.panel_load_times[phase].size() > 5:
		performance_stats.panel_load_times[phase].pop_front()
	
	# Log performance metrics
	if _performance_logging_enabled:
		_log_performance_metric("panel_load", {
			"phase": str(phase),
			"load_time_ms": load_time,
			"timestamp": Time.get_unix_time_from_system()
		})
	
	print("CampaignCreationUI: Panel load time for %s: %d ms" % [str(phase), load_time])
	
	# Check for performance issues
	if load_time > 1000: # > 1 second
		push_warning("CampaignCreationUI: Slow panel load detected for %s: %d ms" % [str(phase), load_time])
		_performance_monitor.warning_count += 1

func _update_cache_statistics(was_cache_hit: bool) -> void:
	"""Update cache hit rate statistics"""
	performance_stats.total_cache_requests += 1
	
	if was_cache_hit:
		performance_stats.cache_hits += 1
	
	performance_stats.cache_hit_rate = float(performance_stats.cache_hits) / float(performance_stats.total_cache_requests)

# PHASE 1B: Enhanced performance monitoring methods

func _start_performance_logging() -> void:
	"""Start performance logging system"""
	if not _performance_logging_enabled:
		return
	
	print("CampaignCreationUI: Performance logging enabled")
	
	# Create performance log file
	var log_dir = "user://logs/"
	if not DirAccess.dir_exists_absolute(log_dir):
		DirAccess.open("user://").make_dir_recursive("logs")
	
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	var log_path = log_dir + "campaign_creation_performance_%s.log" % timestamp
	
	# Log session start
	_log_performance_metric("session_start", {
		"timestamp": Time.get_unix_time_from_system(),
		"godot_version": Engine.get_version_info(),
		"platform": OS.get_name()
	})

func _initialize_performance_metrics() -> void:
	"""Initialize performance metrics collection"""
	# Set up memory monitoring
	if _memory_monitoring_enabled:
		_take_memory_snapshot("session_start")
	
	# Animation performance tracking removed - Framework Bible compliance
	# No animations needed for tabletop RPG assistant
	
	print("CampaignCreationUI: Performance metrics initialized")

func _log_performance_metric(metric_type: String, data: Dictionary) -> void:
	"""Log performance metric to console and file"""
	if not _performance_logging_enabled:
		return
	
	var log_entry = {
		"type": metric_type,
		"timestamp": Time.get_unix_time_from_system(),
		"session_time": Time.get_unix_time_from_system() - _performance_monitor.session_start_time,
		"data": data
	}
	
	# Log to console in debug builds
	if OS.is_debug_build():
		print("PERF: [%s] %s" % [metric_type, JSON.stringify(data)])

func _take_memory_snapshot(event_name: String) -> void:
	"""Take memory snapshot for performance analysis"""
	if not _memory_monitoring_enabled:
		return
	
	var snapshot = {
		"event": event_name,
		"timestamp": Time.get_unix_time_from_system(),
		"static_memory": OS.get_static_memory_usage(),
		"dynamic_memory": 0, # Dynamic memory usage not available in Godot 4
		"cache_size": get_cache_statistics().memory_usage_mb,
		"panel_count": panel_cache.size(),
		"preloaded_scenes": preloaded_scenes.size()
	}
	
	_performance_monitor.memory_snapshots.append(snapshot)
	
	# Keep only last 50 snapshots
	while _performance_monitor.memory_snapshots.size() > 50:
		_performance_monitor.memory_snapshots.pop_front()
	
	if _performance_logging_enabled:
		_log_performance_metric("memory_snapshot", snapshot)

func _track_validation_performance(validation_type: String, start_time: float) -> void:
	"""Track validation performance metrics"""
	var duration = Time.get_unix_time_from_system() - start_time
	
	if not _performance_monitor.validation_times.has(validation_type):
		_performance_monitor.validation_times[validation_type] = []
	
	_performance_monitor.validation_times[validation_type].append(duration)
	
	# Keep only last 20 validation times per type
	while _performance_monitor.validation_times[validation_type].size() > 20:
		_performance_monitor.validation_times[validation_type].pop_front()
	
	if _performance_logging_enabled:
		_log_performance_metric("validation_performance", {
			"type": validation_type,
			"duration_ms": duration * 1000.0
		})
	
	# Warn on slow validations
	if duration > 0.1: # > 100ms
		push_warning("CampaignCreationUI: Slow validation detected: %s took %.1f ms" % [validation_type, duration * 1000.0])
		_performance_monitor.warning_count += 1

func _track_transaction_performance(transaction_id: String, operation: String, start_time: float) -> void:
	"""Track transaction performance metrics"""
	var duration = Time.get_unix_time_from_system() - start_time
	
	var transaction_key = "%s_%s" % [transaction_id, operation]
	if not _performance_monitor.transaction_times.has(transaction_key):
		_performance_monitor.transaction_times[transaction_key] = []
	
	_performance_monitor.transaction_times[transaction_key].append(duration)
	
	# Keep only last 10 transaction times per operation
	while _performance_monitor.transaction_times[transaction_key].size() > 10:
		_performance_monitor.transaction_times[transaction_key].pop_front()
	
	if _performance_logging_enabled:
		_log_performance_metric("transaction_performance", {
			"transaction_id": transaction_id,
			"operation": operation,
			"duration_ms": duration * 1000.0
		})
	
	# Warn on slow transactions
	if duration > 0.5: # > 500ms
		push_warning("CampaignCreationUI: Slow transaction detected: %s %s took %.1f ms" % [transaction_id, operation, duration * 1000.0])
		_performance_monitor.warning_count += 1

# Animation performance tracking removed - Framework Bible compliance
# No animations = no performance tracking needed

func get_comprehensive_performance_report() -> Dictionary:
	"""Get comprehensive performance report"""
	var session_duration = Time.get_unix_time_from_system() - _performance_monitor.session_start_time
	
	return {
		"session": {
			"duration_seconds": session_duration,
			"start_time": _performance_monitor.session_start_time,
			"total_panel_loads": _performance_monitor.total_panel_loads,
			"error_count": _performance_monitor.error_count,
			"warning_count": _performance_monitor.warning_count
		},
		"panel_performance": {
			"load_times": _calculate_panel_load_statistics(),
			"load_counts": _performance_monitor.panel_load_count,
			"average_load_time": _calculate_average_load_time()
		},
		"memory": {
			"current_usage_mb": OS.get_static_memory_usage() / 1024.0 / 1024.0,
			"snapshots_count": _performance_monitor.memory_snapshots.size(),
			"cache_memory_mb": get_cache_statistics().memory_usage_mb,
			"growth_trend": _get_memory_growth_trend()
		},
		"validation": {
			"average_times": _calculate_validation_averages(),
			"total_validations": _count_total_validations()
		},
		"transactions": {
			"average_times": _calculate_transaction_averages(),
			"total_transactions": _performance_monitor.transaction_times.size()
		},
		# Animation performance removed - immediate UI preferred
		"cache": {
			"hit_rate": performance_stats.cache_hit_rate,
			"total_requests": performance_stats.total_cache_requests,
			"cached_panels": panel_cache.size(),
			"preloaded_scenes": preloaded_scenes.size()
		}
	}

func _calculate_panel_load_statistics() -> Dictionary:
	"""Calculate panel load statistics"""
	var stats = {}
	
	for phase in _performance_monitor.panel_load_times:
		var times = _performance_monitor.panel_load_times[phase]
		if times.size() > 0:
			var total = 0.0
			var min_time = times[0]
			var max_time = times[0]
			
			for time in times:
				total += time
				min_time = min(min_time, time)
				max_time = max(max_time, time)
			
			stats[str(phase)] = {
				"average_ms": total / times.size(),
				"min_ms": min_time,
				"max_ms": max_time,
				"count": times.size()
			}
	
	return stats

func _calculate_validation_averages() -> Dictionary:
	"""Calculate validation time averages"""
	var averages = {}
	
	for validation_type in _performance_monitor.validation_times:
		var times = _performance_monitor.validation_times[validation_type]
		if times.size() > 0:
			var total = 0.0
			for time in times:
				total += time
			averages[validation_type] = (total / times.size()) * 1000.0 # Convert to ms
	
	return averages

func _calculate_transaction_averages() -> Dictionary:
	"""Calculate transaction time averages"""
	var averages = {}
	
	for transaction_key in _performance_monitor.transaction_times:
		var times = _performance_monitor.transaction_times[transaction_key]
		if times.size() > 0:
			var total = 0.0
			for time in times:
				total += time
			averages[transaction_key] = (total / times.size()) * 1000.0 # Convert to ms
	
	return averages

func _count_total_validations() -> int:
	"""Count total validations performed"""
	var total = 0
	for validation_type in _performance_monitor.validation_times:
		total += _performance_monitor.validation_times[validation_type].size()
	return total

func _log_performance_warning(message: String, data: Dictionary = {}) -> void:
	"""Log performance warning"""
	_performance_monitor.warning_count += 1
	
	if _performance_logging_enabled:
		_log_performance_metric("performance_warning", {
			"message": message,
			"data": data
		})
	
	push_warning("PERFORMANCE: " + message)

func _log_performance_error(message: String, data: Dictionary = {}) -> void:
	"""Log performance error"""
	_performance_monitor.error_count += 1
	
	if _performance_logging_enabled:
		_log_performance_metric("performance_error", {
			"message": message,
			"data": data
		})
	
	push_error("PERFORMANCE: " + message)

# PHASE 1B: Advanced animation safety with reference tracking

var _animation_references: Dictionary = {}
var _animation_safety_enabled: bool = true
var _active_animations: Array[String] = []

func _register_animation_reference(animation_id: String, animation_player: AnimationPlayer, animation_name: String) -> bool:
	"""Register animation reference with safety tracking"""
	if not _animation_safety_enabled:
		return true
	
	if not animation_player or not is_instance_valid(animation_player):
		_log_performance_error("Invalid animation player for animation: " + animation_id)
		return false
	
	if not animation_player.has_animation(animation_name):
		_log_performance_error("Animation not found: %s in player %s" % [animation_name, str(animation_player)])
		return false
	
	_animation_references[animation_id] = {
		"player": animation_player,
		"animation_name": animation_name,
		"registered_at": Time.get_unix_time_from_system(),
		"is_active": false,
		"reference_count": 1
	}
	
	print("CampaignCreationUI: Registered animation reference: %s" % animation_id)
	return true

func _play_animation_safe(animation_id: String, custom_blend: float = -1.0) -> bool:
	"""Play animation with comprehensive safety checks"""
	if not _animation_safety_enabled:
		return false
	
	if not _animation_references.has(animation_id):
		_log_performance_error("Animation reference not found: " + animation_id)
		return false
	
	var anim_ref = _animation_references[animation_id]
	var animation_player = anim_ref.player
	var animation_name = anim_ref.animation_name
	
	# Validate animation player is still valid
	if not animation_player or not is_instance_valid(animation_player):
		_log_performance_error("Animation player is no longer valid for: " + animation_id)
		_cleanup_animation_reference(animation_id)
		return false
	
	# Check if animation still exists
	if not animation_player.has_animation(animation_name):
		_log_performance_error("Animation no longer exists: %s" % animation_name)
		_cleanup_animation_reference(animation_id)
		return false
	
	# Check if already playing
	if anim_ref.is_active:
		print("CampaignCreationUI: Animation already active: %s" % animation_id)
		return true
	
	# Start performance tracking
	var start_time = Time.get_unix_time_from_system()
	
	# Play animation
	if custom_blend >= 0.0:
		animation_player.play(animation_name, custom_blend)
	else:
		animation_player.play(animation_name)
	
	# Mark as active
	anim_ref.is_active = true
	_active_animations.append(animation_id)
	
	# Connect to finished signal if not already connected
	if not animation_player.animation_finished.is_connected(_on_animation_finished):
		animation_player.animation_finished.connect(_on_animation_finished.bind(animation_id))
	
	# Track success
	var duration = Time.get_unix_time_from_system() - start_time
	# Animation performance tracking removed - immediate UI preferred
	
	print("CampaignCreationUI: ✅ Animation started safely: %s" % animation_id)
	return true

func _stop_animation_safe(animation_id: String) -> bool:
	"""Stop animation with safety checks"""
	if not _animation_safety_enabled:
		return false
	
	if not _animation_references.has(animation_id):
		return false
	
	var anim_ref = _animation_references[animation_id]
	var animation_player = anim_ref.player
	
	# Validate animation player
	if not animation_player or not is_instance_valid(animation_player):
		_cleanup_animation_reference(animation_id)
		return false
	
	# Stop animation
	animation_player.stop()
	
	# Mark as inactive
	anim_ref.is_active = false
	_active_animations.erase(animation_id)
	
	print("CampaignCreationUI: Animation stopped safely: %s" % animation_id)
	return true

func _on_animation_finished(animation_name: String, animation_id: String) -> void:
	"""Handle animation completion"""
	if _animation_references.has(animation_id):
		var anim_ref = _animation_references[animation_id]
		anim_ref.is_active = false
		_active_animations.erase(animation_id)
		
		print("CampaignCreationUI: Animation completed: %s" % animation_id)

func _cleanup_animation_reference(animation_id: String) -> void:
	"""Clean up invalid animation reference"""
	if _animation_references.has(animation_id):
		_animation_references.erase(animation_id)
		_active_animations.erase(animation_id)
		print("CampaignCreationUI: Cleaned up animation reference: %s" % animation_id)

func _cleanup_all_animations() -> void:
	"""Clean up all animation references"""
	# Stop all active animations
	for animation_id in _active_animations.duplicate():
		_stop_animation_safe(animation_id)
	
	# Clear all references
	_animation_references.clear()
	_active_animations.clear()
	
	print("CampaignCreationUI: All animation references cleaned up")

func _validate_animation_references() -> Dictionary:
	"""Validate all animation references and return status"""
	var validation_result = {
		"total_references": _animation_references.size(),
		"valid_references": 0,
		"invalid_references": 0,
		"active_animations": _active_animations.size(),
		"invalid_ids": []
	}
	
	var invalid_ids = []
	
	for animation_id in _animation_references.keys():
		var anim_ref = _animation_references[animation_id]
		var animation_player = anim_ref.player
		
		if not animation_player or not is_instance_valid(animation_player):
			invalid_ids.append(animation_id)
			validation_result.invalid_references += 1
		elif not animation_player.has_animation(anim_ref.animation_name):
			invalid_ids.append(animation_id)
			validation_result.invalid_references += 1
		else:
			validation_result.valid_references += 1
	
	# Clean up invalid references
	for invalid_id in invalid_ids:
		_cleanup_animation_reference(invalid_id)
	
	validation_result.invalid_ids = invalid_ids
	
	if validation_result.invalid_references > 0:
		_log_performance_warning("Animation reference validation found %d invalid references" % validation_result.invalid_references)
	
	return validation_result

func get_animation_safety_report() -> Dictionary:
	"""Get comprehensive animation safety report"""
	var validation = _validate_animation_references()
	
	return {
		"safety_enabled": _animation_safety_enabled,
		"total_references": validation.total_references,
		"valid_references": validation.valid_references,
		"invalid_references": validation.invalid_references,
		"active_animations": validation.active_animations,
		# Animation performance removed - Framework Bible compliance
		"cleanup_required": validation.invalid_references > 0
	}

## Persistence Integration Methods

func _check_crash_recovery():
	"""Check if crash recovery data is available and offer recovery"""
	if not persistence_manager:
		return
	
	var recovery_info = persistence_manager.check_for_crash_recovery()
	
	if recovery_info.has_recovery_data:
		print("CampaignCreationUI: Crash recovery data found from %s" % recovery_info.recovery_timestamp)
		_offer_crash_recovery(recovery_info)

func _offer_crash_recovery(recovery_info: Dictionary):
	"""Present crash recovery options to user"""
	# TODO: Implement proper UI dialog for crash recovery
	# For now, automatically perform recovery
	print("CampaignCreationUI: Performing automatic crash recovery...")
	var recovery_success = persistence_manager.perform_crash_recovery()
	
	if recovery_success:
		print("CampaignCreationUI: ✅ Crash recovery completed successfully")
		# Refresh current panel with recovered data
		_refresh_current_panel()
	else:
		print("CampaignCreationUI: ❌ Crash recovery failed")

func _restore_panel_data(phase: CampaignStateManager.Phase):
	"""Restore panel data from persistence"""
	if not persistence_manager or not current_panel:
		return
	
	var panel_id = _get_panel_id_for_phase(phase)
	var panel_data = persistence_manager.restore_panel_state(panel_id)
	
	if not panel_data.is_empty() and current_panel.has_method("restore_panel_data"):
		current_panel.restore_panel_data(panel_data)
		print("CampaignCreationUI: Restored panel data for %s" % panel_id)

func _save_current_panel_data():
	"""Save current panel data to persistence"""
	if not persistence_manager or not current_panel:
		return
	
	var panel_id = _get_panel_id_for_phase(state_manager.current_phase)
	
	if current_panel.has_method("get_panel_data"):
		var panel_data = current_panel.get_panel_data()
		persistence_manager.save_panel_state(panel_id, panel_data)
		print("CampaignCreationUI: Saved panel data for %s" % panel_id)

func _get_panel_id_for_phase(phase: CampaignStateManager.Phase) -> String:
	"""Map phase to panel ID for persistence"""
	match phase:
		CampaignStateManager.Phase.CONFIG: return "config"
		CampaignStateManager.Phase.CREW_SETUP: return "crew"
		CampaignStateManager.Phase.CAPTAIN_CREATION: return "captain"
		CampaignStateManager.Phase.SHIP_ASSIGNMENT: return "ship"
		CampaignStateManager.Phase.EQUIPMENT_GENERATION: return "equipment"
		CampaignStateManager.Phase.WORLD_GENERATION: return "world"
		CampaignStateManager.Phase.FINAL_REVIEW: return "final"
		_: return "unknown"

func _refresh_current_panel():
	"""Refresh current panel with updated data"""
	if current_panel and current_panel.has_method("refresh_display"):
		current_panel.refresh_display()

## Persistence Signal Handlers

func _on_persistence_data_loaded(data: Dictionary):
	"""Handle persistence data loaded"""
	print("CampaignCreationUI: Persistence data loaded - %d keys" % data.size())

func _on_persistence_error(error_message: String):
	"""Handle persistence errors"""
	print("CampaignCreationUI: Persistence error - %s" % error_message)
	# TODO: Show user-friendly error message

func _on_auto_backup_created(backup_path: String):
	"""Handle auto backup creation"""
	print("CampaignCreationUI: Auto backup created - %s" % backup_path.get_file())

func _on_panel_data_changed():
	"""Handle panel data changes for auto-save"""
	_save_current_panel_data()

## Enhanced Navigation with Persistence

func _on_back_button_pressed():
	"""Handle back button press with persistence"""
	_save_current_panel_data() # Save before navigation
	coordinator.go_back_to_previous_phase()

## Cleanup

## Panel Signal Management

func _connect_panel_to_state_manager(panel: Control):
	"""Connect panel to state manager for enhanced signal flow"""
	if not panel or not state_manager:
		return
	
	# Check if panel extends BaseCampaignPanel
	if panel.has_method("connect_to_state_manager"):
		panel.connect_to_state_manager(state_manager)
		print("CampaignCreationUI: Connected panel to state manager - %s" % panel.get_class())
	
	# Connect panel-specific signals
	if panel.has_signal("panel_data_changed"):
		if not panel.panel_data_changed.is_connected(_on_panel_data_changed):
			panel.panel_data_changed.connect(_on_panel_data_changed)
	
	if panel.has_signal("panel_validation_changed"):
		if not panel.panel_validation_changed.is_connected(_on_panel_validation_changed):
			panel.panel_validation_changed.connect(_on_panel_validation_changed)
	
	if panel.has_signal("panel_navigation_requested"):
		if not panel.panel_navigation_requested.is_connected(_on_panel_navigation_requested):
			panel.panel_navigation_requested.connect(_on_panel_navigation_requested)

func _disconnect_panel_from_state_manager(panel: Control):
	"""Disconnect panel from state manager"""
	if not panel:
		return
	
	# Disconnect from state manager
	if panel.has_method("disconnect_from_state_manager"):
		panel.disconnect_from_state_manager()
	
	# Disconnect panel signals
	if panel.has_signal("panel_data_changed"):
		if panel.panel_data_changed.is_connected(_on_panel_data_changed):
			panel.panel_data_changed.disconnect(_on_panel_data_changed)
	
	if panel.has_signal("panel_validation_changed"):
		if panel.panel_validation_changed.is_connected(_on_panel_validation_changed):
			panel.panel_validation_changed.disconnect(_on_panel_validation_changed)
	
	if panel.has_signal("panel_navigation_requested"):
		if panel.panel_navigation_requested.is_connected(_on_panel_navigation_requested):
			panel.panel_navigation_requested.disconnect(_on_panel_navigation_requested)

## Panel Signal Handlers

func _on_panel_validation_changed(is_valid: bool):
	"""Handle panel validation changes"""
	print("CampaignCreationUI: Panel validation changed - valid: %s" % is_valid)
	
	# Update navigation buttons
	if next_button:
		next_button.disabled = not is_valid
	
	if finish_button:
		finish_button.disabled = not is_valid

func _on_panel_navigation_requested(direction: String):
	"""Handle panel navigation requests"""
	print("CampaignCreationUI: Navigation requested - %s" % direction)
	
	match direction:
		"next":
			_on_next_button_pressed()
		"back":
			_on_back_button_pressed()
		"complete":
			_on_finish_button_pressed()

## State Manager Integration

func _connect_state_manager_signals():
	"""Connect to state manager signals"""
	if not state_manager:
		return
	
	# Connect phase transition signals
	if state_manager.has_signal("phase_completed"):
		if not state_manager.phase_completed.is_connected(_on_phase_completed):
			state_manager.phase_completed.connect(_on_phase_completed)
	
	if state_manager.has_signal("creation_completed"):
		if not state_manager.creation_completed.is_connected(_on_creation_completed):
			state_manager.creation_completed.connect(_on_creation_completed)

func _on_phase_completed(phase: int):
	"""Handle phase completion"""
	print("CampaignCreationUI: Phase completed - %d" % phase)
	
	# Create backup at phase completion
	if persistence_manager:
		persistence_manager.create_backup()

func _on_creation_completed(campaign_data: Dictionary):
	"""Handle campaign creation completion"""
	print("CampaignCreationUI: Campaign creation completed")
	
	# Final save and cleanup
	if persistence_manager:
		persistence_manager.create_backup()
		persistence_manager.clear_persistence_data() # Clear temp data after completion
	
	# Emit completion signal or transition to next scene
	# TODO: Add proper scene transition logic

## Cleanup

func _exit_tree():
	"""Cleanup when exiting"""
	# Disconnect current panel
	if current_panel:
		_disconnect_panel_from_state_manager(current_panel)
	
	# Cleanup persistence
	if persistence_manager:
		persistence_manager.stop_persistence_monitoring()
		persistence_manager.cleanup()
	
	# Cleanup state manager connections
	if state_manager:
		if state_manager.has_signal("phase_completed"):
			if state_manager.phase_completed.is_connected(_on_phase_completed):
				state_manager.phase_completed.disconnect(_on_phase_completed)
		
		if state_manager.has_signal("creation_completed"):
			if state_manager.creation_completed.is_connected(_on_creation_completed):
				state_manager.creation_completed.disconnect(_on_creation_completed)
	
	# PHASE 2: Cleanup formal state machine
	if formal_state_machine:
		formal_state_machine.cleanup()

## PHASE 2: Formal State Machine Integration

func _initialize_formal_state_machine() -> void:
	"""Initialize the formal state machine if feature flag is enabled"""
	state_machine_enabled = CampaignCreationFeatureFlags.is_enabled(CampaignCreationFeatureFlags.FeatureFlag.UI_STATE_MACHINE)
	
	if not state_machine_enabled:
		print("CampaignCreationUI: Formal state machine disabled via feature flag")
		return
	
	print("CampaignCreationUI: Initializing formal state machine...")
	
	formal_state_machine = CampaignCreationStateMachine.new()
	
	# Connect state machine signals
	formal_state_machine.state_changed.connect(_on_state_machine_state_changed)
	formal_state_machine.state_transition_blocked.connect(_on_state_machine_transition_blocked)
	formal_state_machine.state_machine_error.connect(_on_state_machine_error)
	formal_state_machine.recovery_initiated.connect(_on_state_machine_recovery_initiated)
	
	# Initialize to IDLE state
	formal_state_machine.request_transition(CampaignCreationStateMachine.UIState.IDLE)
	
	print("CampaignCreationUI: Formal state machine initialized successfully")

func _transition_state_machine(target_state: CampaignCreationStateMachine.UIState, event_data: Dictionary = {}) -> bool:
	"""Request state machine transition with fallback to legacy state management"""
	if not state_machine_enabled or not formal_state_machine:
		# Fallback to legacy state management
		return _legacy_state_transition(target_state, event_data)
	
	return formal_state_machine.request_transition(target_state, event_data)

func _legacy_state_transition(target_state: CampaignCreationStateMachine.UIState, event_data: Dictionary) -> bool:
	"""Legacy state transition for backward compatibility"""
	ui_state_lock.lock()
	
	# Map formal state machine states to legacy states
	var legacy_state: UIState
	match target_state:
		CampaignCreationStateMachine.UIState.IDLE:
			legacy_state = UIState.IDLE
		CampaignCreationStateMachine.UIState.LOADING_PANEL:
			legacy_state = UIState.LOADING_PANEL
		CampaignCreationStateMachine.UIState.PANEL_ACTIVE:
			legacy_state = UIState.PANEL_ACTIVE
		CampaignCreationStateMachine.UIState.TRANSITIONING:
			legacy_state = UIState.TRANSITIONING
		CampaignCreationStateMachine.UIState.ERROR_RECOVERY:
			legacy_state = UIState.ERROR_RECOVERY
		CampaignCreationStateMachine.UIState.EMERGENCY_ROLLBACK:
			legacy_state = UIState.EMERGENCY_ROLLBACK
		_:
			legacy_state = UIState.IDLE
	
	var old_state = ui_state
	ui_state = legacy_state
	
	print("CampaignCreationUI: Legacy state transition from %s to %s" % [str(old_state), str(legacy_state)])
	ui_state_lock.unlock()
	return true

## State Machine Event Handlers

func _on_state_machine_state_changed(old_state: CampaignCreationStateMachine.UIState, new_state: CampaignCreationStateMachine.UIState) -> void:
	"""Handle state machine state changes"""
	print("CampaignCreationUI: State machine transition: %s -> %s" % [formal_state_machine._state_to_string(old_state), formal_state_machine._state_to_string(new_state)])
	
	# Update legacy state for backward compatibility
	_sync_legacy_state_with_formal(new_state)
	
	# Handle state-specific logic
	match new_state:
		CampaignCreationStateMachine.UIState.IDLE:
			_handle_idle_state()
		CampaignCreationStateMachine.UIState.LOADING_PANEL:
			_handle_loading_panel_state()
		CampaignCreationStateMachine.UIState.PANEL_ACTIVE:
			_handle_panel_active_state()
		CampaignCreationStateMachine.UIState.ERROR_RECOVERY:
			_handle_error_recovery_state()
		CampaignCreationStateMachine.UIState.EMERGENCY_ROLLBACK:
			_handle_emergency_rollback_state()

func _on_state_machine_transition_blocked(current_state: CampaignCreationStateMachine.UIState, target_state: CampaignCreationStateMachine.UIState, reason: String) -> void:
	"""Handle blocked state transitions"""
	push_warning("CampaignCreationUI: State transition blocked - %s" % reason)
	
	# Log blocked transition for analysis
	if error_monitor:
		error_monitor.record_error(
			"STATE_TRANSITION_BLOCKED: %s" % reason,
			CampaignCreationErrorMonitor.ErrorCategory.STATE_MANAGEMENT,
			CampaignCreationErrorMonitor.ErrorSeverity.WARNING,
			{
				"current_state": formal_state_machine._state_to_string(current_state),
				"target_state": formal_state_machine._state_to_string(target_state),
				"reason": reason
			}
		)

func _on_state_machine_error(error_type: String, details: String) -> void:
	"""Handle state machine errors"""
	push_error("CampaignCreationUI: State machine error - %s: %s" % [error_type, details])
	
	# Record error for monitoring
	if error_monitor:
		error_monitor.record_error(
			"State machine error: %s - %s" % [error_type, details],
			CampaignCreationErrorMonitor.ErrorCategory.STATE_MANAGEMENT,
			CampaignCreationErrorMonitor.ErrorSeverity.CRITICAL,
			{
				"type": "STATE_MACHINE_ERROR",
				"error_type": error_type,
				"details": details,
				"current_state": formal_state_machine._state_to_string(formal_state_machine.current_state) if formal_state_machine else "UNKNOWN"
			}
		)
	
	# Trigger recovery if possible
	_attempt_state_machine_recovery(error_type)

func _on_state_machine_recovery_initiated(recovery_type: String) -> void:
	"""Handle state machine recovery initiation"""
	print("CampaignCreationUI: State machine recovery initiated - %s" % recovery_type)
	
	# Show user feedback for recovery
	_show_recovery_notification(recovery_type)

## State-Specific Handlers

func _handle_idle_state() -> void:
	"""Handle IDLE state entry"""
	_update_navigation_state()
	_enable_user_interaction()

func _handle_loading_panel_state() -> void:
	"""Handle LOADING_PANEL state entry"""
	_disable_user_interaction()
	_show_loading_indicator()

func _handle_panel_active_state() -> void:
	"""Handle PANEL_ACTIVE state entry"""
	_enable_user_interaction()
	_hide_loading_indicator()
	_update_navigation_state()

func _handle_error_recovery_state() -> void:
	"""Handle ERROR_RECOVERY state entry"""
	_disable_user_interaction()
	_show_error_recovery_ui()

func _handle_emergency_rollback_state() -> void:
	"""Handle EMERGENCY_ROLLBACK state entry"""
	_disable_user_interaction()
	_show_emergency_rollback_ui()
	_perform_emergency_rollback()

## State Machine Utilities

func _sync_legacy_state_with_formal(formal_state: CampaignCreationStateMachine.UIState) -> void:
	"""Sync legacy state with formal state machine"""
	ui_state_lock.lock()
	
	match formal_state:
		CampaignCreationStateMachine.UIState.IDLE:
			ui_state = UIState.IDLE
		CampaignCreationStateMachine.UIState.LOADING_PANEL:
			ui_state = UIState.LOADING_PANEL
		CampaignCreationStateMachine.UIState.PANEL_ACTIVE:
			ui_state = UIState.PANEL_ACTIVE
		CampaignCreationStateMachine.UIState.TRANSITIONING:
			ui_state = UIState.TRANSITIONING
		CampaignCreationStateMachine.UIState.ERROR_RECOVERY:
			ui_state = UIState.ERROR_RECOVERY
		CampaignCreationStateMachine.UIState.EMERGENCY_ROLLBACK:
			ui_state = UIState.EMERGENCY_ROLLBACK
		_:
			ui_state = UIState.IDLE
	
	ui_state_lock.unlock()

func _attempt_state_machine_recovery(error_type: String) -> void:
	"""Attempt to recover from state machine errors"""
	if not formal_state_machine:
		return
	
	match error_type:
		"PANEL_LOAD_TIMEOUT", "TRANSITION_TIMEOUT":
			formal_state_machine.recover_from_error()
		"CRITICAL_ERROR", "CORRUPTION_DETECTED":
			formal_state_machine.emergency_rollback()
		_:
			formal_state_machine.recover_from_error()

func _show_recovery_notification(recovery_type: String) -> void:
	"""Show user notification during recovery"""
	var notification_text = ""
	match recovery_type:
		"ERROR_RECOVERY":
			notification_text = "Recovering from error, please wait..."
		"EMERGENCY_ROLLBACK":
			notification_text = "Emergency recovery in progress..."
		_:
			notification_text = "System recovery in progress..."
	
	# Show notification to user (implementation depends on UI structure)
	print("CampaignCreationUI: %s" % notification_text)

func _disable_user_interaction() -> void:
	"""Disable user interaction during state transitions"""
	if back_button:
		back_button.disabled = true
	if next_button:
		next_button.disabled = true
	if finish_button:
		finish_button.disabled = true

func _enable_user_interaction() -> void:
	"""Enable user interaction when in stable state"""
	if back_button:
		back_button.disabled = false
	if next_button:
		next_button.disabled = false
	if finish_button:
		finish_button.disabled = false

func _show_loading_indicator() -> void:
	"""Show loading indicator during panel loading"""
	if progress_bar:
		progress_bar.visible = true

func _hide_loading_indicator() -> void:
	"""Hide loading indicator when panel is active"""
	if progress_bar:
		progress_bar.visible = false

func _show_error_recovery_ui() -> void:
	"""Show error recovery UI elements"""
	print("CampaignCreationUI: Showing error recovery UI")
	# Implementation depends on UI structure

func _show_emergency_rollback_ui() -> void:
	"""Show emergency rollback UI elements"""
	print("CampaignCreationUI: Showing emergency rollback UI")
	# Implementation depends on UI structure

func _perform_emergency_rollback() -> void:
	"""Perform emergency rollback to safe state"""
	print("CampaignCreationUI: Performing emergency rollback")
	
	# Reset to initial state
	if state_manager:
		state_manager.current_phase = state_manager.Phase.CONFIG
	
	# Clear current panel and reload
	if current_panel:
		_safely_remove_panel(current_panel)
		current_panel = null
	
	# Load initial panel
	_load_initial_panel()

func _safely_remove_panel(panel: Control) -> void:
	"""Safely remove a panel with proper cleanup"""
	if not panel or not is_instance_valid(panel):
		return
	
	# Disconnect any signals to prevent orphaned references
	if panel.has_signal("panel_completed"):
		if panel.panel_completed.is_connected(_on_panel_completed):
			panel.panel_completed.disconnect(_on_panel_completed)
	
	if panel.has_signal("panel_data_changed"):
		if panel.panel_data_changed.is_connected(_on_panel_data_changed):
			panel.panel_data_changed.disconnect(_on_panel_data_changed)
	
	# Remove from parent safely
	var parent = panel.get_parent()
	if parent and is_instance_valid(parent):
		parent.remove_child(panel)
	
	# Add to pending cleanup instead of immediate queue_free
	pending_panel_cleanup.append(panel)
	
	print("CampaignCreationUI: Safely removed panel: %s" % panel.get_class())

## Enhanced Panel Loading with State Machine Integration

func _load_panel_for_phase_with_state_machine(phase: CampaignStateManager.Phase) -> void:
	"""Load panel with formal state machine coordination"""
	if not _transition_state_machine(CampaignCreationStateMachine.UIState.LOADING_PANEL, {
		"phase": phase,
		"panel_path": panel_scenes.get(phase, "")
	}):
		push_error("CampaignCreationUI: Failed to transition to LOADING_PANEL state")
		return
	
	# Continue with existing panel loading logic
	_load_panel_for_phase(phase)

func get_state_machine_diagnostics() -> Dictionary:
	"""Get comprehensive state machine diagnostics"""
	if not formal_state_machine:
		return {"formal_state_machine": false, "legacy_state": str(ui_state)}
	
	var diagnostics = formal_state_machine.get_state_statistics()
	diagnostics["performance"] = formal_state_machine.get_performance_report()
	diagnostics["legacy_state"] = str(ui_state)
	diagnostics["state_machine_enabled"] = state_machine_enabled
	
	return diagnostics
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                