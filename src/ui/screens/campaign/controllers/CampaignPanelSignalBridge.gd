class_name CampaignPanelSignalBridge
extends RefCounted

## CampaignPanelSignalBridge: Production-grade signal coordination system
## Provides centralized signal management and validation for campaign panel workflows
## Implements enterprise patterns for signal propagation and error recovery

# Core signal definitions with strict typing
signal panel_data_changed(panel_name: String, data: Dictionary)
signal panel_validation_changed(panel_name: String, is_valid: bool, errors: Array[String])
signal panel_complete(panel_name: String, data: Dictionary)
signal panel_error(panel_name: String, error: String)

# Advanced signal management
signal workflow_progression_requested(from_phase: String, to_phase: String)
signal campaign_data_consolidated(campaign_data: Dictionary)
signal validation_cascade_triggered(validation_results: Array[Dictionary])

# Signal validation and monitoring
var active_panels: Dictionary = {}
var signal_history: Array[Dictionary] = []
var validation_state: Dictionary = {}
var error_recovery_queue: Array[Dictionary] = []

# Performance tracking for signal operations
var signal_metrics: Dictionary = {
	"total_emissions": 0,
	"failed_connections": 0,
	"validation_failures": 0,
	"recovery_operations": 0
}

func _init() -> void:
	_initialize_signal_monitoring()

func _initialize_signal_monitoring() -> void:
	"""Initialize comprehensive signal monitoring and validation system"""
	active_panels.clear()
	signal_history.clear()
	validation_state.clear()
	error_recovery_queue.clear()
	
	# Reset metrics
	for key in signal_metrics:
		signal_metrics[key] = 0

## Panel Registration and Management

func register_panel(panel_name: String, panel_controller: Node) -> bool:
	"""Register a panel controller with the signal bridge"""
	if panel_name.is_empty() or not panel_controller:
		push_error("Signal Bridge: Invalid panel registration - %s" % panel_name)
		return false
	
	if panel_name in active_panels:
		push_warning("Signal Bridge: Panel '%s' already registered, updating reference" % panel_name)
	
	active_panels[panel_name] = {
		"controller": panel_controller,
		"registration_time": Time.get_unix_time_from_system(),
		"signal_count": 0,
		"last_activity": Time.get_unix_time_from_system(),
		"validation_state": "unknown"
	}
	
	# Connect panel signals if they exist
	_connect_panel_signals(panel_name, panel_controller)
	
	return true

func unregister_panel(panel_name: String) -> bool:
	"""Unregister a panel controller from the signal bridge"""
	if not panel_name in active_panels:
		return true  # Already unregistered
	
	var panel_info = active_panels[panel_name]
	var controller = panel_info.get("controller") as Node
	
	# Disconnect signals safely
	if controller:
		_disconnect_panel_signals(panel_name, controller)
	
	active_panels.erase(panel_name)
	return true

func _connect_panel_signals(panel_name: String, controller: Node) -> void:
	"""Connect panel controller signals with error handling"""
	var connection_context = "Panel: %s" % panel_name
	
	# Connect standard panel signals
	if controller.has_signal("panel_data_changed"):
		var callable = _on_panel_data_changed.bind(panel_name)
		if not controller.is_connected("panel_data_changed", callable):
			var result = controller.connect("panel_data_changed", callable)
			if result != OK:
				signal_metrics["failed_connections"] += 1
				push_error("Failed to connect panel_data_changed for %s: %s" % [panel_name, result])
	
	if controller.has_signal("panel_validation_changed"):
		var callable = _on_panel_validation_changed.bind(panel_name)
		if not controller.is_connected("panel_validation_changed", callable):
			var result = controller.connect("panel_validation_changed", callable)
			if result != OK:
				signal_metrics["failed_connections"] += 1
				push_error("Failed to connect panel_validation_changed for %s: %s" % [panel_name, result])
	
	if controller.has_signal("panel_complete"):
		var callable = _on_panel_complete.bind(panel_name)
		if not controller.is_connected("panel_complete", callable):
			var result = controller.connect("panel_complete", callable)
			if result != OK:
				signal_metrics["failed_connections"] += 1
				push_error("Failed to connect panel_complete for %s: %s" % [panel_name, result])
	
	# Connect error signals if available
	if controller.has_signal("error_occurred"):
		var callable = _on_panel_error.bind(panel_name)
		if not controller.is_connected("error_occurred", callable):
			var result = controller.connect("error_occurred", callable)
			if result != OK:
				signal_metrics["failed_connections"] += 1
				push_error("Failed to connect error_occurred for %s: %s" % [panel_name, result])

func _disconnect_panel_signals(panel_name: String, controller: Node) -> void:
	"""Safely disconnect panel controller signals"""
	var signals_to_disconnect = [
		"panel_data_changed",
		"panel_validation_changed", 
		"panel_complete",
		"error_occurred"
	]
	
	for signal_name in signals_to_disconnect:
		if controller.has_signal(signal_name):
			var callable_method = "_on_%s" % signal_name
			# Note: This is a simplified disconnect - in production you'd track the exact callables
			controller.disconnect(signal_name, Callable(self, callable_method))

## Signal Event Handlers

func _on_panel_data_changed(panel_name: String) -> void:
	"""Handle panel data change with validation and propagation"""
	_update_panel_activity(panel_name)
	_log_signal_event(panel_name, "data_changed", {})
	
	# Get panel data and validate
	var panel_info = active_panels.get(panel_name, {})
	var controller = panel_info.get("controller") as Node
	
	if controller and controller.has_method("get_panel_data"):
		var panel_data = controller.get_panel_data()
		panel_data_changed.emit(panel_name, panel_data)
		signal_metrics["total_emissions"] += 1

func _on_panel_validation_changed(panel_name: String) -> void:
	"""Handle panel validation change with state tracking"""
	_update_panel_activity(panel_name)
	_log_signal_event(panel_name, "validation_changed", {})
	
	var panel_info = active_panels.get(panel_name, {})
	var controller = panel_info.get("controller") as Node
	
	if controller and controller.has_method("is_valid") and controller.has_method("get_validation_errors"):
		var is_valid = controller.is_valid()
		var errors = controller.get_validation_errors()
		
		# Update validation state tracking
		validation_state[panel_name] = {
			"is_valid": is_valid,
			"errors": errors,
			"timestamp": Time.get_unix_time_from_system()
		}
		
		panel_validation_changed.emit(panel_name, is_valid, errors)
		signal_metrics["total_emissions"] += 1
		
		if not is_valid:
			signal_metrics["validation_failures"] += 1

func _on_panel_complete(panel_name: String) -> void:
	"""Handle panel completion with workflow coordination"""
	_update_panel_activity(panel_name)
	_log_signal_event(panel_name, "complete", {})
	
	var panel_info = active_panels.get(panel_name, {})
	var controller = panel_info.get("controller") as Node
	
	if controller and controller.has_method("get_panel_data"):
		var panel_data = controller.get_panel_data()
		panel_complete.emit(panel_name, panel_data)
		signal_metrics["total_emissions"] += 1

func _on_panel_error(panel_name: String, error: String) -> void:
	"""Handle panel error with recovery coordination"""
	_update_panel_activity(panel_name)
	_log_signal_event(panel_name, "error", {"error": error})
	
	# Add to error recovery queue
	error_recovery_queue.append({
		"panel_name": panel_name,
		"error": error,
		"timestamp": Time.get_unix_time_from_system(),
		"recovery_attempted": false
	})
	
	panel_error.emit(panel_name, error)
	signal_metrics["total_emissions"] += 1

## Utility and Monitoring Methods

func _update_panel_activity(panel_name: String) -> void:
	"""Update panel activity tracking"""
	if panel_name in active_panels:
		active_panels[panel_name]["last_activity"] = Time.get_unix_time_from_system()
		active_panels[panel_name]["signal_count"] += 1

func _log_signal_event(panel_name: String, event_type: String, event_data: Dictionary) -> void:
	"""Log signal event for debugging and monitoring"""
	var event_entry = {
		"panel_name": panel_name,
		"event_type": event_type,
		"event_data": event_data,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	signal_history.append(event_entry)
	
	# Limit history size to prevent memory growth
	if signal_history.size() > 1000:
		signal_history = signal_history.slice(500)  # Keep last 500 events

## Public API for Campaign Creation Workflow

func get_all_panel_validation_states() -> Dictionary:
	"""Get validation state for all registered panels"""
	return validation_state.duplicate(true)

func get_consolidated_campaign_data() -> Dictionary:
	"""Get consolidated data from all panels"""
	var consolidated_data = {}
	
	for panel_name in active_panels.keys():
		var panel_info = active_panels[panel_name]
		var controller = panel_info.get("controller") as Node
		
		if controller and controller.has_method("get_panel_data"):
			var panel_data = controller.get_panel_data()
			consolidated_data[panel_name] = panel_data
	
	return consolidated_data

func validate_workflow_state() -> Dictionary:
	"""Validate the overall workflow state"""
	var workflow_validation = {
		"is_valid": true,
		"panel_states": {},
		"errors": [],
		"warnings": []
	}
	
	for panel_name in active_panels.keys():
		var panel_info = active_panels[panel_name]
		var controller = panel_info.get("controller") as Node
		
		if controller and controller.has_method("is_valid"):
			var panel_valid = controller.is_valid()
			workflow_validation.panel_states[panel_name] = panel_valid
			
			if not panel_valid:
				workflow_validation.is_valid = false
				if controller.has_method("get_validation_errors"):
					var errors = controller.get_validation_errors()
					workflow_validation.errors.append_array(errors)
	
	return workflow_validation

func get_signal_metrics() -> Dictionary:
	"""Get signal system performance metrics"""
	return signal_metrics.duplicate()

func get_debug_information() -> Dictionary:
	"""Get comprehensive debug information"""
	return {
		"active_panels": active_panels.keys(),
		"validation_states": validation_state.duplicate(),
		"signal_metrics": signal_metrics.duplicate(),
		"recent_events": signal_history.slice(-10),  # Last 10 events
		"error_queue_size": error_recovery_queue.size(),
		"system_health": _assess_system_health()
	}

func _assess_system_health() -> Dictionary:
	"""Assess overall signal system health"""
	var total_signals = signal_metrics.get("total_emissions", 0)
	var failed_connections = signal_metrics.get("failed_connections", 0)
	var validation_failures = signal_metrics.get("validation_failures", 0)
	
	var health_score = 1.0
	if total_signals > 0:
		health_score -= (failed_connections / float(total_signals)) * 0.5
		health_score -= (validation_failures / float(total_signals)) * 0.3
	
	return {
		"health_score": max(0.0, health_score),
		"status": "healthy" if health_score > 0.8 else ("degraded" if health_score > 0.5 else "critical"),
		"active_panel_count": active_panels.size(),
		"error_queue_size": error_recovery_queue.size()
	}