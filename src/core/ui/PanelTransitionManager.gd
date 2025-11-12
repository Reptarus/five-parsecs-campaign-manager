extends RefCounted

## Panel Transition Manager - Prevents race conditions during panel transitions
## Manages safe panel switching with proper cleanup and loading states

# Transition state tracking
var _transition_in_progress: bool = false
var _current_panel: Control = null
var _pending_panel_data: Dictionary = {}

# Transition signals
signal transition_started(from_panel: String, to_panel: String)
signal transition_completed(panel: String)
signal transition_failed(error: String)

func _init() -> void:
	print("PanelTransitionManager: Initialized")

func get_transition_status() -> Dictionary:
	"""Get current transition status"""
	return {
		"in_progress": _transition_in_progress,
		"current_panel": _current_panel.name if _current_panel else null,
		"has_pending_data": not _pending_panel_data.is_empty()
	}

func is_transition_in_progress() -> bool:
	"""Check if transition is currently in progress"""
	return _transition_in_progress

func start_transition(from_panel: String, to_panel: String) -> bool:
	"""Start panel transition with race condition protection"""
	if _transition_in_progress:
		push_warning("PanelTransitionManager: Transition already in progress, ignoring request")
		return false
	
	_transition_in_progress = true
	transition_started.emit(from_panel, to_panel)
	print("PanelTransitionManager: Starting transition from %s to %s" % [from_panel, to_panel])
	
	return true

func complete_transition(panel: String) -> void:
	"""Complete panel transition"""
	_transition_in_progress = false
	transition_completed.emit(panel)
	print("PanelTransitionManager: Completed transition to %s" % panel)

func fail_transition(error: String) -> void:
	"""Handle transition failure"""
	_transition_in_progress = false
	transition_failed.emit(error)
	push_error("PanelTransitionManager: Transition failed - %s" % error)

func set_current_panel(panel: Control) -> void:
	"""Set current active panel"""
	_current_panel = panel

func get_current_panel() -> Control:
	"""Get current active panel"""
	return _current_panel

func store_pending_data(data: Dictionary) -> void:
	"""Store data during transition"""
	_pending_panel_data = data

func get_pending_data() -> Dictionary:
	"""Retrieve pending data"""
	return _pending_panel_data

func clear_pending_data() -> void:
	"""Clear pending transition data"""
	_pending_panel_data.clear()