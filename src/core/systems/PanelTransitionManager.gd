@tool
class_name PanelTransitionManager
extends RefCounted

## Thread-Safe Panel Transition Manager
## Prevents race conditions during panel transitions
## Ensures data integrity during phase switching

# Thread safety and state management
var _transition_mutex: Mutex
var _transition_in_progress: bool = false
var _pending_transitions: Array[Dictionary] = []
var _current_transition_id: String = ""

# Panel state preservation
var _saved_panel_states: Dictionary = {}
var _transition_history: Array[Dictionary] = []

func _init():
	_transition_mutex = Mutex.new()
	print("PanelTransitionManager: Initialized with thread safety")

## Safely switch to a new phase with state preservation
func safe_switch_to_phase(ui: Control, phase: int, coordinator = null) -> bool:
	## Thread-safe phase switching with state preservation
	
	if not ui:
		push_error("PanelTransitionManager: Invalid UI reference")
		return false
	
	var transition_id = _generate_transition_id()
	
	# Check if transition is safe to proceed
	_transition_mutex.lock()
	
	if _transition_in_progress:
		# Queue transition for later
		print("PanelTransitionManager: Transition in progress, queuing phase %d" % phase)
		_pending_transitions.append({
			"phase": phase,
			"ui": ui,
			"coordinator": coordinator,
			"transition_id": transition_id,
			"timestamp": Time.get_ticks_msec()
		})
		_transition_mutex.unlock()
		
		# Wait for current transition to complete, then retry
		await _wait_for_transition_completion()
		return await safe_switch_to_phase(ui, phase, coordinator)
	
	# Mark transition as in progress
	_transition_in_progress = true
	_current_transition_id = transition_id
	_transition_mutex.unlock()
	
	print("PanelTransitionManager: Starting transition %s to phase %d" % [transition_id, phase])
	
	var success = false
	
	# Perform safe transition with error handling
	success = await _perform_safe_transition(ui, phase, coordinator)
	if not success:
		push_error("PanelTransitionManager: Transition failed")
	
	# Mark transition as complete
	_transition_mutex.lock()
	_transition_in_progress = false
	_current_transition_id = ""
	_transition_mutex.unlock()
	
	# Process any pending transitions
	if _pending_transitions.size() > 0:
		call_deferred("_process_pending_transitions")
	
	return success

func _perform_safe_transition(ui: Control, phase: int, coordinator) -> bool:
	## Perform the actual transition with safety checks
	
	# Step 1: Save current panel state
	var current_panel = ui.get("current_panel")
	if current_panel and is_instance_valid(current_panel):
		_save_panel_state(current_panel, ui.get("state_manager").get("current_phase"))
	
	# Step 2: Validate transition
	if not _validate_transition(ui, phase):
		push_error("PanelTransitionManager: Transition validation failed")
		return false
	
	# Step 3: Clear current panel safely
	if current_panel:
		await _safe_panel_cleanup(current_panel)
	
	# Step 4: Load new panel
	var new_panel = await _load_panel_for_phase(ui, phase)
	if not new_panel:
		push_error("PanelTransitionManager: Failed to load panel for phase %d" % phase)
		return false
	
	# Step 5: Update UI state
	_update_ui_state(ui, phase, new_panel)
	
	# Step 6: Connect signals and restore state
	if coordinator:
		_connect_panel_to_coordinator(new_panel, coordinator)
	
	_restore_panel_state(new_panel, phase)
	
	# Step 7: Record transition
	_record_transition(phase, new_panel.get_class() if new_panel else "Unknown")
	
	print("PanelTransitionManager: Transition to phase %d completed successfully" % phase)
	return true

func _save_panel_state(panel: Control, phase: int) -> void:
	## Save panel state before transition
	if not panel or not panel.has_method("get_panel_data"):
		return
	
	# Get panel data with error handling
	var panel_data = panel.get_panel_data()
	if panel_data != null:
		_saved_panel_states[phase] = {
			"data": panel_data,
			"timestamp": Time.get_ticks_msec(),
			"panel_class": panel.get_class()
		}
		print("PanelTransitionManager: Saved state for phase %d" % phase)
	else:
		push_warning("PanelTransitionManager: Failed to save state for phase %d" % phase)

func _validate_transition(ui: Control, target_phase: int) -> bool:
	## Validate that transition is safe to proceed
	if not ui:
		return false
	
	var state_manager = ui.get("state_manager")
	if not state_manager:
		push_warning("PanelTransitionManager: No state manager available")
		return true # Allow transition to proceed
	
	var current_phase = state_manager.get("current_phase", 0)
	
	# Validate phase order (allow backward transitions)
	if target_phase < 0:
		push_error("PanelTransitionManager: Invalid phase %d" % target_phase)
		return false
	
	# Additional validation can be added here
	return true

func _safe_panel_cleanup(panel: Control) -> void:
	## Safely cleanup current panel
	if not panel or not is_instance_valid(panel):
		return
	
	# Disconnect signals if possible
	var coordinator = _find_coordinator()
	if coordinator:
		SignalConnectionManager.disconnect_panel_signals_safely(panel, coordinator)
	
	# Call cleanup method if available
	if panel.has_method("cleanup_panel"):
		# Call cleanup with basic error handling
		panel.cleanup_panel()
		# Note: GDScript doesn't have try/except, relying on panel's internal error handling
	
	# Remove from parent and queue for deletion
	if panel.get_parent():
		panel.get_parent().remove_child(panel)
	
	panel.queue_free()
	
	# Wait a frame to ensure cleanup
	await Engine.get_main_loop().process_frame

func _load_panel_for_phase(ui: Control, phase: int) -> Control:
	## Load panel for the specified phase
	var panel_scenes = ui.get("panel_scenes")
	if not panel_scenes or not panel_scenes.has(phase):
		push_error("PanelTransitionManager: No scene configured for phase %d" % phase)
		return null
	
	var scene_path = panel_scenes[phase]
	if not ResourceLoader.exists(scene_path):
		push_error("PanelTransitionManager: Scene not found: %s" % scene_path)
		return null
	
	var scene = load(scene_path)
	if not scene:
		push_error("PanelTransitionManager: Failed to load scene: %s" % scene_path)
		return null
	
	var panel = scene.instantiate()
	if not panel:
		push_error("PanelTransitionManager: Failed to instantiate panel")
		return null
	
	return panel

func _update_ui_state(ui: Control, phase: int, new_panel: Control) -> void:
	## Update UI state with new panel
	# Add panel to UI
	var content_container = ui.get("content_container")
	if content_container and new_panel:
		content_container.add_child(new_panel)
		ui.set("current_panel", new_panel)
	
	# Update state manager if available
	var state_manager = ui.get("state_manager")
	if state_manager and state_manager.has_method("set_current_phase"):
		state_manager.set_current_phase(phase)

func _connect_panel_to_coordinator(panel: Control, coordinator) -> void:
	## Connect panel signals to coordinator
	if panel and coordinator:
		SignalConnectionManager.connect_panel_signals_safely(panel, coordinator)
		SignalConnectionManager.connect_state_update_methods(panel, coordinator)

func _restore_panel_state(panel: Control, phase: int) -> void:
	## Restore saved panel state if available
	if not _saved_panel_states.has(phase):
		return
	
	if not panel or not panel.has_method("set_panel_data"):
		return
	
	# Restore panel data with error checking
	var saved_state = _saved_panel_states[phase]
	if saved_state and saved_state.has("data"):
		panel.set_panel_data(saved_state.data)
		print("PanelTransitionManager: Restored state for phase %d" % phase)
	else:
		push_warning("PanelTransitionManager: Failed to restore state for phase %d" % phase)

func _record_transition(phase: int, panel_class: String) -> void:
	## Record transition in history for debugging
	_transition_history.append({
		"phase": phase,
		"panel_class": panel_class,
		"timestamp": Time.get_ticks_msec(),
		"transition_id": _current_transition_id
	})
	
	# Keep history manageable
	if _transition_history.size() > 50:
		_transition_history = _transition_history.slice(-25)

func _find_coordinator():
	## Find the campaign coordinator
	# This would need to be implemented based on your specific architecture
	# Could be a singleton, passed as parameter, or found through scene tree
	var main_loop = Engine.get_main_loop()
	if main_loop and main_loop is SceneTree:
		var root = main_loop.root
		return root.find_child("CampaignCreationCoordinator", true, false)
	return null

func _generate_transition_id() -> String:
	## Generate unique transition ID
	return "trans_%d_%d" % [Time.get_ticks_msec(), randi()]

func _wait_for_transition_completion() -> void:
	## Wait for current transition to complete
	var timeout = 100 # 10 seconds in 100ms intervals
	var checks = 0
	
	while _transition_in_progress and checks < timeout:
		await Engine.get_main_loop().process_frame
		await Engine.get_main_loop().create_timer(0.1).timeout
		checks += 1
	
	if checks >= timeout:
		push_warning("PanelTransitionManager: Timeout waiting for transition completion")

func _process_pending_transitions() -> void:
	## Process any pending transitions
	if _pending_transitions.size() == 0:
		return
	
	var next_transition = _pending_transitions.pop_front()
	
	if is_instance_valid(next_transition.ui):
		print("PanelTransitionManager: Processing pending transition to phase %d" % next_transition.phase)
		await safe_switch_to_phase(next_transition.ui, next_transition.phase, next_transition.coordinator)
	else:
		print("PanelTransitionManager: Skipping invalid pending transition")

## Get current transition status
func get_transition_status() -> Dictionary:
	return {
		"in_progress": _transition_in_progress,
		"current_id": _current_transition_id,
		"pending_count": _pending_transitions.size(),
		"history_count": _transition_history.size(),
		"saved_states_count": _saved_panel_states.size()
	}

## Clear all saved states (for cleanup)
func clear_saved_states() -> void:
	_saved_panel_states.clear()
	print("PanelTransitionManager: Cleared all saved states")

## Get transition history for debugging
func get_transition_history() -> Array[Dictionary]:
	return _transition_history.duplicate()