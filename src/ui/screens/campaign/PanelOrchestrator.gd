class_name PanelOrchestrator
extends RefCounted

## PanelOrchestrator - Dedicated panel management for campaign creation workflow
## Extracts panel loading, navigation, and UI orchestration from CampaignCreationCoordinator
## Implements Orchestrator Pattern to handle complex panel lifecycle and transitions

# Required imports
const CampaignCreationStateManager := preload("res://src/core/campaign/creation/CampaignCreationStateManager.gd")

# Signals for panel lifecycle
signal panel_loading_started(panel_name: String)
signal panel_loaded(panel_instance: Control, panel_name: String)
signal panel_loading_failed(panel_name: String, error: String)
signal panel_transition_started(from_panel: String, to_panel: String)
signal panel_transition_completed(new_panel: String)

# Navigation state signals
signal navigation_state_changed(can_go_back: bool, can_go_forward: bool, can_finish: bool)
signal panel_validation_changed(panel_name: String, is_valid: bool)

# Panel configuration - centralized panel scene mapping
var panel_scenes: Dictionary = {
	CampaignCreationStateManager.Phase.CONFIG: "res://src/ui/screens/campaign/panels/ExpandedConfigPanel.tscn",
	CampaignCreationStateManager.Phase.CAPTAIN_CREATION: "res://src/ui/screens/campaign/panels/CaptainPanel.tscn",
	CampaignCreationStateManager.Phase.CREW_SETUP: "res://src/ui/screens/campaign/panels/CrewPanel.tscn",
	CampaignCreationStateManager.Phase.SHIP_ASSIGNMENT: "res://src/ui/screens/campaign/panels/ShipPanel.tscn",
	CampaignCreationStateManager.Phase.EQUIPMENT_GENERATION: "res://src/ui/screens/campaign/panels/EquipmentPanel.tscn",
	CampaignCreationStateManager.Phase.WORLD_GENERATION: "res://src/ui/screens/campaign/panels/WorldInfoPanel.tscn",
	CampaignCreationStateManager.Phase.FINAL_REVIEW: "res://src/ui/screens/campaign/panels/FinalPanel.tscn"
}

# Panel state management
var current_panel: Control = null
var current_panel_name: String = ""
var panel_container: Control = null
var panel_signal_connections: Array[Dictionary] = []

# Panel loading and lifecycle
var panel_load_timeout: float = 5.0
var panel_loading_in_progress: bool = false
var pending_panel_cleanup: Array[Control] = []

# Navigation state
var navigation_enabled: bool = true
var phase_completion_status: Dictionary = {}

# Panel validation state
var panel_validation_states: Dictionary = {}

func _init(container: Control) -> void:
	"""Initialize panel orchestrator with container reference"""
	panel_container = container
	_initialize_validation_states()
	print("PanelOrchestrator: Initialized with container")

func _initialize_validation_states() -> void:
	"""Initialize panel validation tracking"""
	for phase in CampaignCreationStateManager.Phase.values():
		panel_validation_states[phase] = false

## Core Panel Management

func load_panel_for_phase(phase: CampaignCreationStateManager.Phase) -> bool:
	"""Load and display panel for specified phase"""
	if panel_loading_in_progress:
		print("PanelOrchestrator: Panel loading already in progress")
		return false
	
	var panel_name = _get_panel_name_for_phase(phase)
	
	if not panel_scenes.has(phase):
		var error = "No panel scene configured for phase: %s" % panel_name
		print("PanelOrchestrator ERROR: %s" % error)
		panel_loading_failed.emit(panel_name, error)
		return false
	
	print("PanelOrchestrator: Loading panel for phase: %s" % panel_name)
	panel_loading_started.emit(panel_name)
	panel_loading_in_progress = true
	
	# Clean up previous panel
	_cleanup_current_panel()
	
	# Load new panel
	var scene_path = panel_scenes[phase]
	var success = _load_panel_scene(scene_path, panel_name, phase)
	
	panel_loading_in_progress = false
	
	if success:
		panel_transition_completed.emit(panel_name)
		print("PanelOrchestrator: Panel loaded successfully: %s" % panel_name)
	
	return success

func _load_panel_scene(scene_path: String, panel_name: String, phase: CampaignCreationStateManager.Phase) -> bool:
	"""Load panel scene and set up connections"""
	if not ResourceLoader.exists(scene_path):
		var error = "Panel scene not found: %s" % scene_path
		print("PanelOrchestrator ERROR: %s" % error)
		panel_loading_failed.emit(panel_name, error)
		return false
	
	var panel_scene = load(scene_path)
	if not panel_scene:
		var error = "Failed to load panel scene: %s" % scene_path
		print("PanelOrchestrator ERROR: %s" % error)
		panel_loading_failed.emit(panel_name, error)
		return false
	
	var panel_instance = panel_scene.instantiate()
	if not panel_instance:
		var error = "Failed to instantiate panel: %s" % panel_name
		print("PanelOrchestrator ERROR: %s" % error)
		panel_loading_failed.emit(panel_name, error)
		return false
	
	# Add to container
	if panel_container:
		panel_container.add_child(panel_instance)
		current_panel = panel_instance
		current_panel_name = panel_name
		
		# Connect panel signals
		_connect_panel_signals(panel_instance, panel_name, phase)
		
		panel_loaded.emit(panel_instance, panel_name)
		print("PanelOrchestrator: Panel instance created and connected: %s" % panel_name)
		return true
	else:
		print("PanelOrchestrator ERROR: No panel container available")
		panel_instance.queue_free()
		return false

func _connect_panel_signals(panel_instance: Control, panel_name: String, phase: CampaignCreationStateManager.Phase) -> void:
	"""Connect panel-specific signals with proper cleanup tracking"""
	_disconnect_panel_signals()  # Clean up previous connections
	
	# Connect common panel signals
	if panel_instance.has_signal("panel_data_updated"):
		var connection = panel_instance.panel_data_updated.connect(_on_panel_data_updated.bind(panel_name, phase))
		panel_signal_connections.append({
			"signal_name": "panel_data_updated",
			"source": panel_instance,
			"connection": connection
		})
	
	if panel_instance.has_signal("validation_changed"):
		var connection = panel_instance.validation_changed.connect(_on_panel_validation_changed.bind(panel_name, phase))
		panel_signal_connections.append({
			"signal_name": "validation_changed",
			"source": panel_instance,
			"connection": connection
		})
	
	if panel_instance.has_signal("next_panel_requested"):
		var connection = panel_instance.next_panel_requested.connect(_on_next_panel_requested.bind(panel_name))
		panel_signal_connections.append({
			"signal_name": "next_panel_requested",
			"source": panel_instance,
			"connection": connection
		})
	
	if panel_instance.has_signal("previous_panel_requested"):
		var connection = panel_instance.previous_panel_requested.connect(_on_previous_panel_requested.bind(panel_name))
		panel_signal_connections.append({
			"signal_name": "previous_panel_requested",
			"source": panel_instance,
			"connection": connection
		})
	
	print("PanelOrchestrator: Connected %d signals for panel: %s" % [panel_signal_connections.size(), panel_name])

func _disconnect_panel_signals() -> void:
	"""Clean up all panel signal connections"""
	for connection_data in panel_signal_connections:
		var source = connection_data.get("source")
		var signal_name = connection_data.get("signal_name", "")
		
		if is_instance_valid(source) and source.has_signal(signal_name):
			if source.is_connected(signal_name, connection_data.get("connection")):
				source.disconnect(signal_name, connection_data.get("connection"))
	
	panel_signal_connections.clear()
	print("PanelOrchestrator: Disconnected panel signals")

func _cleanup_current_panel() -> void:
	"""Clean up current panel and connections"""
	if current_panel and is_instance_valid(current_panel):
		_disconnect_panel_signals()
		
		# Schedule for cleanup to avoid issues during transitions
		pending_panel_cleanup.append(current_panel)
		current_panel.queue_free()
		
		print("PanelOrchestrator: Scheduled cleanup for panel: %s" % current_panel_name)
	
	current_panel = null
	current_panel_name = ""

## Navigation Management

func update_navigation_state(can_go_back: bool, can_go_forward: bool, can_finish: bool) -> void:
	"""Update navigation state and emit signal"""
	if navigation_enabled:
		navigation_state_changed.emit(can_go_back, can_go_forward, can_finish)
		print("PanelOrchestrator: Navigation state updated - Back: %s, Forward: %s, Finish: %s" % [can_go_back, can_go_forward, can_finish])

func set_navigation_enabled(enabled: bool) -> void:
	"""Enable or disable navigation"""
	navigation_enabled = enabled
	print("PanelOrchestrator: Navigation %s" % ("enabled" if enabled else "disabled"))

func transition_to_panel(from_phase: CampaignCreationStateManager.Phase, to_phase: CampaignCreationStateManager.Phase) -> bool:
	"""Handle panel transition between phases"""
	var from_name = _get_panel_name_for_phase(from_phase)
	var to_name = _get_panel_name_for_phase(to_phase)
	
	print("PanelOrchestrator: Transitioning from %s to %s" % [from_name, to_name])
	panel_transition_started.emit(from_name, to_name)
	
	return load_panel_for_phase(to_phase)

## Panel Data and Validation Management

func update_panel_validation(panel_name: String, phase: CampaignCreationStateManager.Phase, is_valid: bool) -> void:
	"""Update panel validation state"""
	panel_validation_states[phase] = is_valid
	panel_validation_changed.emit(panel_name, is_valid)
	print("PanelOrchestrator: Panel validation updated - %s: %s" % [panel_name, is_valid])

func get_panel_validation_state(phase: CampaignCreationStateManager.Phase) -> bool:
	"""Get validation state for panel"""
	return panel_validation_states.get(phase, false)

func get_all_panel_validation_states() -> Dictionary:
	"""Get all panel validation states"""
	return panel_validation_states.duplicate()

## Panel Information and Utilities

func get_current_panel() -> Control:
	"""Get currently displayed panel"""
	return current_panel

func get_current_panel_name() -> String:
	"""Get current panel name"""
	return current_panel_name

func get_panel_scene_path(phase: CampaignCreationStateManager.Phase) -> String:
	"""Get scene path for phase"""
	return panel_scenes.get(phase, "")

func _get_panel_name_for_phase(phase: CampaignCreationStateManager.Phase) -> String:
	"""Get human-readable panel name for phase"""
	match phase:
		CampaignCreationStateManager.Phase.CONFIG:
			return "Configuration"
		CampaignCreationStateManager.Phase.CAPTAIN_CREATION:
			return "Captain Creation"
		CampaignCreationStateManager.Phase.CREW_SETUP:
			return "Crew Setup"
		CampaignCreationStateManager.Phase.SHIP_ASSIGNMENT:
			return "Ship Assignment"
		CampaignCreationStateManager.Phase.EQUIPMENT_GENERATION:
			return "Equipment Generation"
		CampaignCreationStateManager.Phase.WORLD_GENERATION:
			return "World Generation"
		CampaignCreationStateManager.Phase.FINAL_REVIEW:
			return "Final Review"
		_:
			return "Unknown Panel"

## Signal Handlers

func _on_panel_data_updated(panel_name: String, phase: CampaignCreationStateManager.Phase, data: Dictionary) -> void:
	"""Handle panel data updates"""
	print("PanelOrchestrator: Panel data updated - %s: %d keys" % [panel_name, data.keys().size()])
	# This can be connected to external systems that need panel data

func _on_panel_validation_changed(panel_name: String, phase: CampaignCreationStateManager.Phase, is_valid: bool) -> void:
	"""Handle panel validation changes"""
	update_panel_validation(panel_name, phase, is_valid)

func _on_next_panel_requested(from_panel_name: String) -> void:
	"""Handle next panel navigation request"""
	print("PanelOrchestrator: Next panel requested from: %s" % from_panel_name)
	# This should be connected to navigation system

func _on_previous_panel_requested(from_panel_name: String) -> void:
	"""Handle previous panel navigation request"""
	print("PanelOrchestrator: Previous panel requested from: %s" % from_panel_name)
	# This should be connected to navigation system

## Cleanup and Maintenance

func cleanup() -> void:
	"""Clean up orchestrator resources"""
	_cleanup_current_panel()
	
	# Clean up any pending panels
	for pending_panel in pending_panel_cleanup:
		if is_instance_valid(pending_panel):
			pending_panel.queue_free()
	pending_panel_cleanup.clear()
	
	panel_container = null
	print("PanelOrchestrator: Cleanup completed")

## Debug and Monitoring

func get_orchestrator_state() -> Dictionary:
	"""Get current orchestrator state for debugging"""
	return {
		"current_panel_name": current_panel_name,
		"panel_loading_in_progress": panel_loading_in_progress,
		"navigation_enabled": navigation_enabled,
		"active_signal_connections": panel_signal_connections.size(),
		"pending_cleanup_count": pending_panel_cleanup.size(),
		"panel_validation_states": panel_validation_states.duplicate(),
		"available_panels": panel_scenes.keys()
	}

func print_orchestrator_debug() -> void:
	"""Print debug information"""
	var state = get_orchestrator_state()
	print("=== PanelOrchestrator Debug State ===")
	for key in state.keys():
		print("  %s: %s" % [key, state[key]])
	print("=====================================")