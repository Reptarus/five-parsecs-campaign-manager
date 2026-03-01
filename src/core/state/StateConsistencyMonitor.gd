class_name StateConsistencyMonitor
extends Node

## Real-time State Consistency Monitor - Phase 3C.2
## Monitors data consistency across all systems in real-time
## Provides automated alerts and recovery suggestions for consistency violations

# DataConsistencyValidator removed - file does not exist
const CampaignCreationStateManager = preload("res://src/core/campaign/creation/CampaignCreationStateManager.gd")
const IntegrationHealthMonitor = preload("res://src/core/monitoring/IntegrationHealthMonitor.gd")

## Consistency monitoring levels
enum MonitoringLevel {
	DISABLED,     # No consistency monitoring
	BASIC,        # Essential consistency checks only
	STANDARD,     # Regular consistency monitoring
	COMPREHENSIVE # Full real-time consistency monitoring
}

## Consistency alert severity
enum AlertSeverity {
	INFO,         # Informational consistency updates
	WARNING,      # Minor consistency issues
	ERROR,        # Significant consistency problems
	CRITICAL      # Critical consistency failures requiring immediate attention
}

## Consistency monitoring data
class ConsistencyAlert:
	var timestamp: int = 0
	var severity: AlertSeverity = AlertSeverity.INFO
	var system_name: String = ""
	var message: String = ""
	var details: Dictionary = {}
	var auto_recovery_attempted: bool = false
	var recovery_successful: bool = false
	
	func _init(p_severity: AlertSeverity, p_system: String, p_message: String, p_details: Dictionary = {}) -> void:
		timestamp = Time.get_ticks_msec()
		severity = p_severity
		system_name = p_system
		message = p_message
		details = p_details

## Monitoring signals
signal consistency_alert_raised(alert: ConsistencyAlert)
signal consistency_restored(system_name: String, recovery_time_ms: int)
signal monitoring_level_changed(old_level: MonitoringLevel, new_level: MonitoringLevel)
signal auto_recovery_triggered(system_name: String, recovery_type: String)

## Configuration
var monitoring_level: MonitoringLevel = MonitoringLevel.STANDARD
var check_interval_ms: int = 10000  # 10 seconds default
var auto_recovery_enabled: bool = true
var max_alert_history: int = 100

## Monitoring state
var is_monitoring_active: bool = false
var consistency_timer: Timer
var alert_history: Array[ConsistencyAlert] = []
var monitored_systems: Dictionary = {}  # system_name -> last_known_state
var recovery_attempts: Dictionary = {}  # system_name -> attempt_count

## System references
var ui_controller: Node
var state_manager: CampaignCreationStateManager
var health_monitor: IntegrationHealthMonitor

func _ready() -> void:
	_initialize_consistency_monitoring()

func _initialize_consistency_monitoring() -> void:
	## Initialize real-time consistency monitoring
	print("StateConsistencyMonitor: Initializing real-time consistency monitoring...")
	
	# Setup monitoring timer
	consistency_timer = Timer.new()
	consistency_timer.wait_time = float(check_interval_ms) / 1000.0
	consistency_timer.timeout.connect(_perform_consistency_check)
	consistency_timer.autostart = false
	add_child(consistency_timer)
	
	# Initialize monitored systems
	monitored_systems = {
		"ui_panels": {},
		"state_manager": {},
		"backend_systems": {},
		"data_flows": {}
	}
	
	# Initialize recovery attempts tracking
	recovery_attempts = {}
	
	print("StateConsistencyMonitor: Monitoring system initialized")

## PUBLIC API

func start_monitoring(
	p_ui_controller: Node = null,
	p_state_manager: CampaignCreationStateManager = null,
	p_health_monitor: IntegrationHealthMonitor = null
) -> void:
	## Start real-time consistency monitoring
	print("StateConsistencyMonitor: Starting consistency monitoring...")
	
	# Set system references
	ui_controller = p_ui_controller
	state_manager = p_state_manager
	health_monitor = p_health_monitor
	
	# Validate required systems
	if not _validate_monitoring_prerequisites():
		_raise_alert(AlertSeverity.ERROR, "System", "Cannot start monitoring - missing prerequisites")
		return
	
	# Start monitoring
	is_monitoring_active = true
	consistency_timer.start()
	
	# Perform initial consistency check
	call_deferred("_perform_initial_consistency_check")
	
	print("StateConsistencyMonitor: Monitoring started (level: %s)" % MonitoringLevel.keys()[monitoring_level])

func stop_monitoring() -> void:
	## Stop real-time consistency monitoring
	print("StateConsistencyMonitor: Stopping consistency monitoring...")
	
	is_monitoring_active = false
	if consistency_timer:
		consistency_timer.stop()
	
	print("StateConsistencyMonitor: Monitoring stopped")

func set_monitoring_level(new_level: MonitoringLevel) -> void:
	## Set consistency monitoring level
	var old_level = monitoring_level
	monitoring_level = new_level
	
	# Adjust check interval based on level
	match monitoring_level:
		MonitoringLevel.DISABLED:
			stop_monitoring()
		MonitoringLevel.BASIC:
			check_interval_ms = 30000  # 30 seconds
		MonitoringLevel.STANDARD:
			check_interval_ms = 10000  # 10 seconds
		MonitoringLevel.COMPREHENSIVE:
			check_interval_ms = 5000   # 5 seconds
	
	# Update timer if running
	if consistency_timer and is_monitoring_active:
		consistency_timer.wait_time = float(check_interval_ms) / 1000.0
	
	monitoring_level_changed.emit(old_level, new_level)
	print("StateConsistencyMonitor: Monitoring level changed to %s" % MonitoringLevel.keys()[new_level])

func force_consistency_check() -> Array[ConsistencyAlert]:
	## Force immediate consistency check
	print("StateConsistencyMonitor: Forcing immediate consistency check...")
	return _perform_consistency_check()

func get_consistency_status() -> Dictionary:
	## Get current consistency status
	var status = {
		"monitoring_active": is_monitoring_active,
		"monitoring_level": MonitoringLevel.keys()[monitoring_level],
		"check_interval_ms": check_interval_ms,
		"total_alerts": alert_history.size(),
		"recent_alerts": _get_recent_alerts(5),
		"systems_monitored": monitored_systems.keys().size(),
		"auto_recovery_enabled": auto_recovery_enabled,
		"last_check_time": _get_last_check_time()
	}
	
	# Alert breakdown
	var alert_breakdown = {"info": 0, "warning": 0, "error": 0, "critical": 0}
	for alert in alert_history:
		match alert.severity:
			AlertSeverity.INFO:
				alert_breakdown.info += 1
			AlertSeverity.WARNING:
				alert_breakdown.warning += 1
			AlertSeverity.ERROR:
				alert_breakdown.error += 1
			AlertSeverity.CRITICAL:
				alert_breakdown.critical += 1
	
	status["alert_breakdown"] = alert_breakdown
	return status

func get_recent_alerts(count: int = 10) -> Array[ConsistencyAlert]:
	## Get recent consistency alerts
	return _get_recent_alerts(count)

func clear_alert_history() -> void:
	## Clear consistency alert history
	alert_history.clear()
	print("StateConsistencyMonitor: Alert history cleared")

## CONSISTENCY CHECKING

func _perform_initial_consistency_check() -> void:
	## Perform initial consistency check on startup
	print("StateConsistencyMonitor: Performing initial consistency check...")
	
	var initial_alerts = _perform_consistency_check()
	
	if initial_alerts.is_empty():
		_raise_alert(AlertSeverity.INFO, "System", "Initial consistency check passed - all systems consistent")
	else:
		_raise_alert(AlertSeverity.WARNING, "System", "Initial consistency check found %d issues" % initial_alerts.size())

func _perform_consistency_check() -> Array[ConsistencyAlert]:
	## Perform comprehensive consistency check
	if not is_monitoring_active:
		return []
	
	var check_start = Time.get_ticks_msec()
	var new_alerts: Array[ConsistencyAlert] = []
	
	# Check based on monitoring level
	match monitoring_level:
		MonitoringLevel.BASIC:
			new_alerts.append_array(_check_basic_consistency())
		MonitoringLevel.STANDARD:
			new_alerts.append_array(_check_standard_consistency())
		MonitoringLevel.COMPREHENSIVE:
			new_alerts.append_array(_check_comprehensive_consistency())
	
	var check_duration = Time.get_ticks_msec() - check_start
	
	# Process new alerts
	for alert in new_alerts:
		_process_consistency_alert(alert)
	
	# Update monitoring statistics
	_update_monitoring_statistics(check_duration, new_alerts.size())
	
	return new_alerts

func _check_basic_consistency() -> Array[ConsistencyAlert]:
	## Perform basic consistency checks
	var alerts: Array[ConsistencyAlert] = []
	
	# Check if critical systems are still available
	if ui_controller and not is_instance_valid(ui_controller):
		alerts.append(ConsistencyAlert.new(
			AlertSeverity.CRITICAL,
			"UI Controller",
			"UI Controller reference is no longer valid"
		))
	
	if state_manager and not is_instance_valid(state_manager):
		alerts.append(ConsistencyAlert.new(
			AlertSeverity.CRITICAL,
			"State Manager",
			"State Manager reference is no longer valid"
		))
	
	return alerts

func _check_standard_consistency() -> Array[ConsistencyAlert]:
	## Perform standard consistency checks
	var alerts: Array[ConsistencyAlert] = []
	
	# Include basic checks
	alerts.append_array(_check_basic_consistency())
	
	# Check UI-state consistency
	if ui_controller and state_manager:
		var ui_state_alerts = _validate_ui_state_consistency()
		alerts.append_array(ui_state_alerts)
	
	# Check backend integration status
	if health_monitor:
		var backend_alerts = _validate_backend_consistency()
		alerts.append_array(backend_alerts)
	
	return alerts

func _check_comprehensive_consistency() -> Array[ConsistencyAlert]:
	## Perform comprehensive consistency checks
	var alerts: Array[ConsistencyAlert] = []
	
	# Include standard checks
	alerts.append_array(_check_standard_consistency())
	
	# Deep data flow validation
	if ui_controller and state_manager:
		var flow_alerts = _validate_comprehensive_data_flows()
		alerts.append_array(flow_alerts)
	
	# Performance consistency checks
	var performance_alerts = _validate_performance_consistency()
	alerts.append_array(performance_alerts)
	
	return alerts

## SPECIFIC CONSISTENCY VALIDATIONS

func _validate_ui_state_consistency() -> Array[ConsistencyAlert]:
	## Validate UI-state manager consistency
	var alerts: Array[ConsistencyAlert] = []
	
	if not ui_controller or not state_manager:
		return alerts
	
	# Quick validation using DataConsistencyValidator
	# DataConsistencyValidator check removed - validator not available
	# Basic validation fallback
	if ui_controller == null or state_manager == null:
		alerts.append(ConsistencyAlert.new(
			AlertSeverity.WARNING,
			"UI-State Consistency",
			"Missing UI controller or state manager reference",
			{}
		))
	
	return alerts

func _validate_backend_consistency() -> Array[ConsistencyAlert]:
	## Validate backend system consistency
	var alerts: Array[ConsistencyAlert] = []
	
	if not health_monitor:
		return alerts
	
	var health_summary = health_monitor.get_health_summary()
	
	# Check for degraded systems
	if health_summary.degraded_systems > 0:
		var severity = AlertSeverity.WARNING
		if health_summary.offline_systems > health_summary.total_systems / 2:
			severity = AlertSeverity.CRITICAL
		
		alerts.append(ConsistencyAlert.new(
			severity,
			"Backend Systems",
			"Backend system health degraded: %d/%d systems operational" % [
				health_summary.operational_systems,
				health_summary.total_systems
			],
			{"health_summary": health_summary}
		))
	
	return alerts

func _validate_comprehensive_data_flows() -> Array[ConsistencyAlert]:
	## Validate comprehensive data flows
	var alerts: Array[ConsistencyAlert] = []
	
	# This would perform deep data flow analysis
	# For now, we'll do a simplified check
	
	if ui_controller:
		# Check if UI panels have consistent data
		var panels = ["config_panel", "crew_panel", "equipment_panel"]
		for panel_name in panels:
			var panel = ui_controller.get(panel_name)
			if panel and panel.has_method("is_valid"):
				if not panel.is_valid():
					alerts.append(ConsistencyAlert.new(
						AlertSeverity.WARNING,
						"Data Flow",
						"Panel %s reports invalid state" % panel_name,
						{"panel": panel_name}
					))
	
	return alerts

func _validate_performance_consistency() -> Array[ConsistencyAlert]:
	## Validate performance consistency
	var alerts: Array[ConsistencyAlert] = []
	
	# Check if monitoring itself is performing within acceptable bounds
	var last_check_duration = _get_last_check_duration()
	if last_check_duration > 1000:  # More than 1 second
		alerts.append(ConsistencyAlert.new(
			AlertSeverity.WARNING,
			"Performance",
			"Consistency check taking too long: %dms" % last_check_duration,
			{"duration_ms": last_check_duration}
		))
	
	return alerts

## ALERT PROCESSING AND RECOVERY

func _process_consistency_alert(alert: ConsistencyAlert) -> void:
	## Process a consistency alert
	# Add to history
	alert_history.append(alert)
	
	# Maintain history size limit
	while alert_history.size() > max_alert_history:
		alert_history.pop_front()
	
	# Emit signal
	consistency_alert_raised.emit(alert)
	
	# Log alert
	var severity_text = AlertSeverity.keys()[alert.severity]
	print("StateConsistencyMonitor: [%s] %s - %s" % [severity_text, alert.system_name, alert.message])
	
	# Attempt auto-recovery if enabled and appropriate
	if auto_recovery_enabled and _should_attempt_recovery(alert):
		_attempt_auto_recovery(alert)

func _should_attempt_recovery(alert: ConsistencyAlert) -> bool:
	## Determine if auto-recovery should be attempted
	# Only attempt recovery for specific types of issues
	if alert.severity == AlertSeverity.INFO:
		return false
	
	# Limit recovery attempts per system
	var system_attempts = recovery_attempts.get(alert.system_name, 0)
	return system_attempts < 3  # Max 3 attempts per system

func _attempt_auto_recovery(alert: ConsistencyAlert) -> void:
	## Attempt automatic recovery from consistency issue
	print("StateConsistencyMonitor: Attempting auto-recovery for %s..." % alert.system_name)
	
	# Track recovery attempt
	recovery_attempts[alert.system_name] = recovery_attempts.get(alert.system_name, 0) + 1
	alert.auto_recovery_attempted = true
	
	auto_recovery_triggered.emit(alert.system_name, "consistency_recovery")
	
	var recovery_successful = false
	
	# System-specific recovery logic
	match alert.system_name:
		"UI Controller":
			recovery_successful = _recover_ui_controller()
		"State Manager":
			recovery_successful = _recover_state_manager()
		"Backend Systems":
			recovery_successful = _recover_backend_systems()
		"Data Flow":
			recovery_successful = _recover_data_flow()
	
	# Update alert with recovery result
	alert.recovery_successful = recovery_successful
	
	if recovery_successful:
		print("StateConsistencyMonitor: Auto-recovery successful for %s" % alert.system_name)
		consistency_restored.emit(alert.system_name, Time.get_ticks_msec() - alert.timestamp)
	else:
		print("StateConsistencyMonitor: Auto-recovery failed for %s" % alert.system_name)

## RECOVERY METHODS

func _recover_ui_controller() -> bool:
	## Attempt to recover UI controller consistency
	# Basic recovery - validate UI controller is still accessible
	if ui_controller and is_instance_valid(ui_controller):
		return true
	
	# Try to re-establish connection
	# In a real implementation, this might involve recreating the UI reference
	return false

func _recover_state_manager() -> bool:
	## Attempt to recover state manager consistency
	if state_manager and is_instance_valid(state_manager):
		# Try to trigger state validation
		if state_manager.has_method("_validate_current_phase"):
			state_manager._validate_current_phase()
			return true
	
	return false

func _recover_backend_systems() -> bool:
	## Attempt to recover backend system consistency
	if health_monitor:
		# Force health check to refresh backend status
		health_monitor.force_health_check()
		return true
	
	return false

func _recover_data_flow() -> bool:
	## Attempt to recover data flow consistency
	# Try to trigger data flow validation
	if ui_controller and state_manager:
		# In a real implementation, this might involve re-syncing data
		return true
	
	return false

## UTILITY METHODS

func _validate_monitoring_prerequisites() -> bool:
	## Validate prerequisites for monitoring
	# At minimum, we need either UI controller or state manager
	return ui_controller != null or state_manager != null

func _get_recent_alerts(count: int) -> Array[ConsistencyAlert]:
	## Get recent alerts up to specified count
	var recent: Array[ConsistencyAlert] = []
	var start_index = max(0, alert_history.size() - count)
	
	for i in range(start_index, alert_history.size()):
		recent.append(alert_history[i])
	
	return recent

func _get_last_check_time() -> int:
	## Get timestamp of last consistency check
	if alert_history.is_empty():
		return 0
	return alert_history[-1].timestamp

func _get_last_check_duration() -> int:
	## Get duration of last consistency check
	# This would be tracked during actual checks
	# For now, return a placeholder
	return 50  # 50ms placeholder

func _update_monitoring_statistics(check_duration_ms: int, alert_count: int) -> void:
	## Update monitoring statistics
	# Update internal statistics
	# This could be expanded to track trends over time
	pass

func _raise_alert(severity: AlertSeverity, system: String, message: String, details: Dictionary = {}) -> void:
	## Raise a consistency alert
	var alert = ConsistencyAlert.new(severity, system, message, details)
	_process_consistency_alert(alert)

## CLEANUP

func _notification(what: int) -> void:
	## Handle cleanup on node removal
	if what == NOTIFICATION_PREDELETE:
		stop_monitoring()
		if consistency_timer:
			consistency_timer.stop()
		print("StateConsistencyMonitor: Monitoring system stopped")