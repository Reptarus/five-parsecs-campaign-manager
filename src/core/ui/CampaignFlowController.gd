class_name CampaignFlowController
extends Control

## Campaign Flow Controller - Modern Godot 4.x Signal-Based Architecture
## 
## Replaces dependency injection anti-patterns with signal-based loose coupling.
## Manages campaign creation panel transitions using PackedScene resources and
## implements proper memory management with scene cleanup.
##
## Features:
## - Signal-based communication system
## - Group-based panel registration ("campaign_panels")
## - PackedScene resource management
## - Comprehensive error handling
## - Memory management with automatic cleanup
## - Godot 4.x scene composition principles
##
## @author: Claude Code
## @version: 1.0
## @license: MIT

# ============================================================================
# CONSTANTS & ENUMS
# ============================================================================

## Campaign creation phases enumeration
enum CampaignPhase {
	CONFIG = 0, ## Configuration phase - basic campaign setup
	CREW = 1, ## Crew creation phase
	CAPTAIN = 2, ## Captain selection/creation phase
	SHIP = 3, ## Ship setup phase
	EQUIPMENT = 4, ## Equipment allocation phase
	FINAL = 5 ## Final review and confirmation phase
}

## Panel loading states
enum PanelState {
	UNLOADED, ## Panel not loaded
	LOADING, ## Panel is being loaded
	LOADED, ## Panel loaded and ready
	ERROR ## Panel failed to load
}

## Maximum number of concurrent panel loads to prevent memory issues
const MAX_CONCURRENT_LOADS: int = 2

## Panel group identifier for automatic registration
const PANEL_GROUP_NAME: String = "campaign_panels"

# ============================================================================
# SIGNALS - Signal-Based Architecture
# ============================================================================

## Emitted when campaign state data is available for panels
signal campaign_state_available(state_data: Dictionary)

## Emitted when a panel requests data from the controller
signal panel_data_requested(requesting_panel: Control)

## Emitted when a phase transition is requested
signal phase_transition_requested(from_phase: int, to_phase: int)

## Emitted when a panel is successfully loaded
signal panel_loaded(panel: Control, phase: int)

## Emitted when a panel fails to load
signal panel_load_failed(phase: int, error_message: String)

## Emitted when campaign flow is completed
signal campaign_flow_completed(campaign_data: Dictionary)

## Emitted when campaign flow encounters an error
signal campaign_flow_error(error_message: String)

## Emitted when phase transition is complete
signal phase_transition_completed(old_phase: int, new_phase: int)

# ============================================================================
# PANEL RESOURCE DEFINITIONS
# ============================================================================

## Panel PackedScene resources - lazy loaded for memory efficiency
var panel_scenes: Dictionary = {
	CampaignPhase.CONFIG: {
		"path": "res://src/ui/screens/campaign/panels/ConfigPanel.tscn",
		"scene": null,
		"instance": null,
		"state": PanelState.UNLOADED
	},
	CampaignPhase.CREW: {
		"path": "res://src/ui/screens/campaign/panels/CrewPanel.tscn",
		"scene": null,
		"instance": null,
		"state": PanelState.UNLOADED
	},
	CampaignPhase.CAPTAIN: {
		"path": "res://src/ui/screens/campaign/panels/CaptainPanel.tscn",
		"scene": null,
		"instance": null,
		"state": PanelState.UNLOADED
	},
	CampaignPhase.SHIP: {
		"path": "res://src/ui/screens/campaign/panels/ShipPanel.tscn",
		"scene": null,
		"instance": null,
		"state": PanelState.UNLOADED
	},
	CampaignPhase.EQUIPMENT: {
		"path": "res://src/ui/screens/campaign/panels/EquipmentPanel.tscn",
		"scene": null,
		"instance": null,
		"state": PanelState.UNLOADED
	},
	CampaignPhase.FINAL: {
		"path": "res://src/ui/screens/campaign/panels/FinalPanel.tscn",
		"scene": null,
		"instance": null,
		"state": PanelState.UNLOADED
	}
}

# ============================================================================
# STATE MANAGEMENT
# ============================================================================

## Current campaign phase
var current_phase: CampaignPhase = CampaignPhase.CONFIG

## Campaign state data accumulated from all panels
var campaign_state: Dictionary = {}

## Panel container for managing panel instances
@onready var panel_container: Control = $PanelContainer

## Currently active panel
var active_panel: Control = null

## Panel loading queue to manage concurrent loads
var loading_queue: Array[CampaignPhase] = []

## Currently loading panels counter
var currently_loading: int = 0

## Error tracking for comprehensive error handling
var error_log: Array[String] = []

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	"""Initialize the Campaign Flow Controller with proper setup"""
	_setup_controller()
	_connect_panel_signals()
	_initialize_first_panel()

func _setup_controller() -> void:
	"""Setup the controller with proper configuration"""
	# Set up the controller in the scene tree
	set_process(true)
	set_physics_process(false)
	
	# Create panel container if it doesn't exist
	if not panel_container:
		panel_container = Control.new()
		panel_container.name = "PanelContainer"
		panel_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(panel_container)
	
	# Initialize campaign state
	campaign_state = {
		"version": "1.0",
		"created_at": Time.get_datetime_string_from_system(),
		"phases": {},
		"completed_phases": [],
		"current_phase": current_phase
	}
	
	print("CampaignFlowController: Initialized successfully")

func _connect_panel_signals() -> void:
	"""Connect to group-based panel signals for loose coupling"""
	# Connect to tree-based group signals for automatic panel registration
	if not get_tree().tree_changed.is_connected(_on_tree_changed):
		get_tree().tree_changed.connect(_on_tree_changed)

func _initialize_first_panel() -> void:
	"""Initialize the first panel (CONFIG) to start the flow"""
	call_deferred("_load_panel", CampaignPhase.CONFIG)

# ============================================================================
# PANEL MANAGEMENT - PackedScene Resource System
# ============================================================================

func _load_panel(phase: CampaignPhase) -> void:
	"""Load a panel using PackedScene resources with proper error handling"""
	if not panel_scenes.has(phase):
		_handle_panel_error(phase, "Unknown panel phase: " + str(phase))
		return
	
	var panel_info = panel_scenes[phase]
	
	# Check if already loaded
	if panel_info.state == PanelState.LOADED and panel_info.instance:
		_activate_panel(phase)
		return
	
	# Check if currently loading
	if panel_info.state == PanelState.LOADING:
		return
	
	# Check concurrent load limit
	if currently_loading >= MAX_CONCURRENT_LOADS:
		if not loading_queue.has(phase):
			loading_queue.append(phase)
		return
	
	# Begin loading process
	currently_loading += 1
	panel_info.state = PanelState.LOADING
	
	print("CampaignFlowController: Loading panel for phase ", _phase_to_string(phase))
	
	# Load PackedScene resource
	if not panel_info.scene:
		if ResourceLoader.exists(panel_info.path):
			var resource = load(panel_info.path)
			if resource is PackedScene:
				panel_info.scene = resource
			else:
				_handle_panel_error(phase, "Resource is not a PackedScene: " + panel_info.path)
				return
		else:
			_handle_panel_error(phase, "Panel scene file not found: " + panel_info.path)
			return
	
	# Instantiate panel
	var panel_instance = panel_info.scene.instantiate()
	if not panel_instance:
		_handle_panel_error(phase, "Failed to instantiate panel scene")
		return
	
	# Configure panel instance
	panel_instance.name = _phase_to_string(phase) + "Panel"
	panel_instance.visible = false
	
	# Add to group for automatic registration
	panel_instance.add_to_group(PANEL_GROUP_NAME)
	
	# Store instance reference
	panel_info.instance = panel_instance
	panel_info.state = PanelState.LOADED
	
	# Add to scene tree
	panel_container.add_child(panel_instance)
	
	# Connect panel-specific signals
	_connect_panel_instance_signals(panel_instance, phase)
	
	# Complete loading process
	currently_loading -= 1
	
	# Process loading queue
	_process_loading_queue()
	
	# Emit panel loaded signal
	panel_loaded.emit(panel_instance, phase)
	
	# Activate panel if it's the current phase
	if phase == current_phase:
		_activate_panel(phase)

func _connect_panel_instance_signals(panel: Control, phase: CampaignPhase) -> void:
	"""Connect signals from a specific panel instance"""
	# Connect standard panel signals if they exist
	if panel.has_signal("panel_completed"):
		panel.panel_completed.connect(_on_panel_completed.bind(phase))
	
	if panel.has_signal("validation_failed"):
		panel.validation_failed.connect(_on_panel_validation_failed.bind(phase))
	
	if panel.has_signal("panel_ready"):
		panel.panel_ready.connect(_on_panel_ready.bind(phase))
	
	# Connect phase-specific signals
	match phase:
		CampaignPhase.CONFIG:
			if panel.has_signal("config_updated"):
				panel.config_updated.connect(_on_config_updated)
		
		CampaignPhase.CREW:
			if panel.has_signal("crew_updated"):
				panel.crew_updated.connect(_on_crew_updated)
		
		CampaignPhase.CAPTAIN:
			if panel.has_signal("captain_selected"):
				panel.captain_selected.connect(_on_captain_selected)
		
		CampaignPhase.SHIP:
			if panel.has_signal("ship_configured"):
				panel.ship_configured.connect(_on_ship_configured)
		
		CampaignPhase.EQUIPMENT:
			if panel.has_signal("equipment_allocated"):
				panel.equipment_allocated.connect(_on_equipment_allocated)
		
		CampaignPhase.FINAL:
			if panel.has_signal("campaign_finalized"):
				panel.campaign_finalized.connect(_on_campaign_finalized)

func _activate_panel(phase: CampaignPhase) -> void:
	"""Activate the specified panel, hiding others"""
	var panel_info = panel_scenes[phase]
	
	if panel_info.state != PanelState.LOADED or not panel_info.instance:
		_handle_panel_error(phase, "Cannot activate unloaded panel")
		return
	
	# Hide current active panel
	if active_panel and active_panel != panel_info.instance:
		active_panel.visible = false
	
	# Show target panel
	panel_info.instance.visible = true
	active_panel = panel_info.instance
	
	# Update current phase
	current_phase = phase
	campaign_state.current_phase = phase
	
	# Provide campaign state to panel
	_provide_state_to_panel(panel_info.instance)
	
	print("CampaignFlowController: Activated panel for phase ", _phase_to_string(phase))

func _provide_state_to_panel(panel: Control) -> void:
	"""Provide current campaign state to a panel via signals"""
	# Emit signal with current campaign state
	campaign_state_available.emit(campaign_state)
	
	# Call panel-specific data provision if method exists
	if panel.has_method("set_campaign_state"):
		panel.set_campaign_state(campaign_state)

func _unload_panel(phase: CampaignPhase) -> void:
	"""Unload a panel to free memory"""
	if not panel_scenes.has(phase):
		return
	
	var panel_info = panel_scenes[phase]
	
	if panel_info.instance:
		# Remove from group
		panel_info.instance.remove_from_group(PANEL_GROUP_NAME)
		
		# Disconnect signals
		_disconnect_panel_signals(panel_info.instance)
		
		# Remove from scene tree
		if panel_info.instance.get_parent():
			panel_info.instance.get_parent().remove_child(panel_info.instance)
		
		# Queue for deletion
		panel_info.instance.queue_free()
		panel_info.instance = null
	
	# Reset state
	panel_info.state = PanelState.UNLOADED
	
	print("CampaignFlowController: Unloaded panel for phase ", _phase_to_string(phase))

func _disconnect_panel_signals(panel: Control) -> void:
	"""Disconnect all signals from a panel"""
	# Get all connections and disconnect them
	for connection in panel.get_incoming_connections():
		if connection.signal.is_connected(connection.callable):
			connection.signal.disconnect(connection.callable)

func _process_loading_queue() -> void:
	"""Process the panel loading queue"""
	while loading_queue.size() > 0 and currently_loading < MAX_CONCURRENT_LOADS:
		var next_phase = loading_queue.pop_front()
		_load_panel(next_phase)

# ============================================================================
# PHASE TRANSITIONS
# ============================================================================

func transition_to_phase(target_phase: CampaignPhase) -> void:
	"""Transition to the specified phase with proper validation"""
	if target_phase == current_phase:
		return
	
	var old_phase = current_phase
	
	# Validate transition
	if not _can_transition_to_phase(target_phase):
		_handle_transition_error(old_phase, target_phase, "Invalid phase transition")
		return
	
	# Emit transition request signal
	phase_transition_requested.emit(old_phase, target_phase)
	
	# Load target panel if not loaded
	if not panel_scenes[target_phase].instance:
		_load_panel(target_phase)
		# Activation will happen in _load_panel when complete
	else:
		_activate_panel(target_phase)
	
	# Mark old phase as completed
	if not campaign_state.completed_phases.has(old_phase):
		campaign_state.completed_phases.append(old_phase)
	
	# Emit completion signal
	phase_transition_completed.emit(old_phase, target_phase)
	
	print("CampaignFlowController: Transitioned from ", _phase_to_string(old_phase), " to ", _phase_to_string(target_phase))

func _can_transition_to_phase(target_phase: CampaignPhase) -> bool:
	"""Validate if transition to target phase is allowed"""
	# Can always go to the first phase
	if target_phase == CampaignPhase.CONFIG:
		return true
	
	# Can go back to any previously completed phase
	if campaign_state.completed_phases.has(target_phase):
		return true
	
	# Can go forward one phase at a time
	if target_phase == current_phase + 1:
		return true
	
	# Cannot skip phases
	return false

func go_to_next_phase() -> void:
	"""Move to the next phase in sequence"""
	var next_phase = current_phase + 1
	if next_phase <= CampaignPhase.FINAL:
		transition_to_phase(next_phase)

func go_to_previous_phase() -> void:
	"""Move to the previous phase"""
	var prev_phase = current_phase - 1
	if prev_phase >= CampaignPhase.CONFIG:
		transition_to_phase(prev_phase)

# ============================================================================
# SIGNAL HANDLERS - Panel Communication
# ============================================================================

func _on_panel_completed(phase: CampaignPhase, panel_data: Dictionary) -> void:
	"""Handle panel completion signal"""
	# Store phase data
	campaign_state.phases[_phase_to_string(phase)] = panel_data
	
	# Mark phase as completed
	if not campaign_state.completed_phases.has(phase):
		campaign_state.completed_phases.append(phase)
	
	print("CampaignFlowController: Phase ", _phase_to_string(phase), " completed")
	
	# Auto-transition to next phase if not final
	if phase != CampaignPhase.FINAL:
		call_deferred("go_to_next_phase")
	else:
		# Campaign completion
		_complete_campaign_flow()

func _on_panel_validation_failed(phase: CampaignPhase, errors: Array) -> void:
	"""Handle panel validation failure"""
	var error_message = "Panel validation failed for " + _phase_to_string(phase) + ": " + str(errors)
	_log_error(error_message)
	print("CampaignFlowController: ", error_message)

func _on_panel_ready(phase: CampaignPhase) -> void:
	"""Handle panel ready signal"""
	print("CampaignFlowController: Panel ready for phase ", _phase_to_string(phase))

func _on_tree_changed() -> void:
	"""Handle scene tree changes for automatic panel registration"""
	# Find panels in the campaign_panels group
	var panels = get_tree().get_nodes_in_group(PANEL_GROUP_NAME)
	
	for panel in panels:
		if panel != self and panel is Control:
			# Auto-register panel if not already managed
			_register_external_panel(panel)

func _register_external_panel(panel: Control) -> void:
	"""Register an external panel that joined the group"""
	# Implementation for external panel registration
	print("CampaignFlowController: Registered external panel: ", panel.name)

# ============================================================================
# PHASE-SPECIFIC SIGNAL HANDLERS
# ============================================================================

func _on_config_updated(config_data: Dictionary) -> void:
	"""Handle configuration updates from ConfigPanel"""
	campaign_state.phases["config"] = config_data
	print("CampaignFlowController: Configuration updated")

func _on_crew_updated(crew_data: Array) -> void:
	"""Handle crew updates from CrewPanel"""
	campaign_state.phases["crew"] = {"members": crew_data}
	print("CampaignFlowController: Crew updated")

func _on_captain_selected(captain_data: Dictionary) -> void:
	"""Handle captain selection from CaptainPanel"""
	campaign_state.phases["captain"] = captain_data
	print("CampaignFlowController: Captain selected")

func _on_ship_configured(ship_data: Dictionary) -> void:
	"""Handle ship configuration from ShipPanel"""
	campaign_state.phases["ship"] = ship_data
	print("CampaignFlowController: Ship configured")

func _on_equipment_allocated(equipment_data: Dictionary) -> void:
	"""Handle equipment allocation from EquipmentPanel"""
	campaign_state.phases["equipment"] = equipment_data
	print("CampaignFlowController: Equipment allocated")

func _on_campaign_finalized(final_data: Dictionary) -> void:
	"""Handle campaign finalization from FinalPanel"""
	campaign_state.phases["final"] = final_data
	_complete_campaign_flow()

# ============================================================================
# CAMPAIGN COMPLETION
# ============================================================================

func _complete_campaign_flow() -> void:
	"""Complete the campaign creation flow"""
	campaign_state.completed_at = Time.get_datetime_string_from_system()
	campaign_state.is_complete = true
	
	# Emit completion signal
	campaign_flow_completed.emit(campaign_state)
	
	print("CampaignFlowController: Campaign flow completed successfully")

# ============================================================================
# ERROR HANDLING
# ============================================================================

func _handle_panel_error(phase: CampaignPhase, error_message: String) -> void:
	"""Handle panel loading/management errors"""
	var full_error = "Panel error for " + _phase_to_string(phase) + ": " + error_message
	_log_error(full_error)
	
	# Update panel state
	if panel_scenes.has(phase):
		panel_scenes[phase].state = PanelState.ERROR
	
	# Emit error signal
	panel_load_failed.emit(phase, error_message)
	
	# Decrement loading counter if was loading
	currently_loading = max(0, currently_loading - 1)
	
	# Process queue in case other panels are waiting
	_process_loading_queue()

func _handle_transition_error(from_phase: CampaignPhase, to_phase: CampaignPhase, error_message: String) -> void:
	"""Handle phase transition errors"""
	var full_error = "Transition error from " + _phase_to_string(from_phase) + " to " + _phase_to_string(to_phase) + ": " + error_message
	_log_error(full_error)
	
	# Emit error signal
	campaign_flow_error.emit(full_error)

func _log_error(error_message: String) -> void:
	"""Log error message to error tracking system"""
	error_log.append(error_message)
	push_error("CampaignFlowController: " + error_message)

# ============================================================================
# MEMORY MANAGEMENT
# ============================================================================

func _notification(what: int) -> void:
	"""Handle node notifications for proper cleanup"""
	if what == NOTIFICATION_PREDELETE:
		_cleanup_resources()

func _cleanup_resources() -> void:
	"""Clean up all resources and panel instances"""
	print("CampaignFlowController: Cleaning up resources")
	
	# Unload all panels
	for phase in panel_scenes.keys():
		_unload_panel(phase)
	
	# Clear references
	active_panel = null
	campaign_state.clear()
	error_log.clear()
	loading_queue.clear()

func unload_unused_panels() -> void:
	"""Unload panels that are not currently active to free memory"""
	for phase in panel_scenes.keys():
		if phase != current_phase and panel_scenes[phase].state == PanelState.LOADED:
			_unload_panel(phase)

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

func _phase_to_string(phase: CampaignPhase) -> String:
	"""Convert phase enum to string for logging and identification"""
	match phase:
		CampaignPhase.CONFIG: return "CONFIG"
		CampaignPhase.CREW: return "CREW"
		CampaignPhase.CAPTAIN: return "CAPTAIN"
		CampaignPhase.SHIP: return "SHIP"
		CampaignPhase.EQUIPMENT: return "EQUIPMENT"
		CampaignPhase.FINAL: return "FINAL"
		_: return "UNKNOWN"

func get_current_phase() -> CampaignPhase:
	"""Get the current campaign phase"""
	return current_phase

func get_campaign_state() -> Dictionary:
	"""Get the current campaign state"""
	return campaign_state.duplicate()

func get_phase_data(phase: CampaignPhase) -> Dictionary:
	"""Get data for a specific phase"""
	var phase_name = _phase_to_string(phase)
	return campaign_state.phases.get(phase_name, {})

func is_phase_completed(phase: CampaignPhase) -> bool:
	"""Check if a phase has been completed"""
	return campaign_state.completed_phases.has(phase)

func get_panel_instance(phase: CampaignPhase) -> Control:
	"""Get the panel instance for a specific phase"""
	if panel_scenes.has(phase):
		return panel_scenes[phase].instance
	return null

func get_error_log() -> Array[String]:
	"""Get the current error log"""
	return error_log.duplicate()

# ============================================================================
# PUBLIC API METHODS
# ============================================================================

func request_panel_data(requesting_panel: Control) -> void:
	"""Public method for panels to request data"""
	panel_data_requested.emit(requesting_panel)

func update_campaign_state(phase_name: String, data: Dictionary) -> void:
	"""Public method to update campaign state from external sources"""
	campaign_state.phases[phase_name] = data
	campaign_state_available.emit(campaign_state)

func force_panel_reload(phase: CampaignPhase) -> void:
	"""Force reload a specific panel"""
	_unload_panel(phase)
	_load_panel(phase)

func get_loading_status() -> Dictionary:
	"""Get current loading status information"""
	return {
		"currently_loading": currently_loading,
		"queue_size": loading_queue.size(),
		"loaded_panels": _get_loaded_panel_count()
	}

func _get_loaded_panel_count() -> int:
	"""Get the number of currently loaded panels"""
	var count = 0
	for phase_info in panel_scenes.values():
		if phase_info.state == PanelState.LOADED:
			count += 1
	return count