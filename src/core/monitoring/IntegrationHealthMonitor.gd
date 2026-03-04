class_name IntegrationHealthMonitor
extends Node

## Real-time Integration Health Monitoring System
## Monitors UI-backend integration health, performance, and system availability
## Provides automated degradation detection and recovery suggestions

# Handle missing preload files gracefully
const ValidationErrorBoundary = preload("res://src/core/validation/ValidationErrorBoundary.gd")

## Health status levels
enum HealthStatus {
	EXCELLENT, # All systems operational, performance optimal
	GOOD, # All systems operational, minor performance issues
	DEGRADED, # Some systems unavailable, fallbacks in use
	CRITICAL, # Major systems unavailable, limited functionality
	OFFLINE # Core systems unavailable, system unusable
}

## Monitoring data structure
class SystemHealthData:
	var system_name: String = ""
	var is_available: bool = false
	var last_check_time: int = 0
	var response_time_ms: int = 0
	var error_count: int = 0
	var success_count: int = 0
	var last_error: String = ""
	var health_status: HealthStatus = HealthStatus.OFFLINE
	var performance_history: Array[int] = [] # Last 10 response times
	
	func _init(p_system_name: String) -> void:
		system_name = p_system_name
		last_check_time = Time.get_ticks_msec()
	
	func get_success_rate() -> float:
		var total = success_count + error_count
		if total == 0:
			return 0.0
		return float(success_count) / float(total)
	
	func get_average_response_time() -> float:
		if performance_history.is_empty():
			return 0.0
		var sum = 0
		for time in performance_history:
			sum += time
		return float(sum) / float(performance_history.size())

## System health signals
signal system_health_changed(system_name: String, new_status: HealthStatus, old_status: HealthStatus)
signal overall_health_changed(new_status: HealthStatus, old_status: HealthStatus)
signal system_degradation_detected(system_name: String, issue: String)
signal system_recovery_detected(system_name: String)
signal performance_warning(system_name: String, response_time_ms: int, threshold_ms: int)

## Monitoring configuration
var monitoring_enabled: bool = true
var check_interval_ms: int = 30000 # 30 seconds
var performance_threshold_ms: int = 100
var degradation_threshold: float = 0.7 # Success rate below this triggers degradation
var max_performance_history: int = 10

## System health tracking
var system_health: Dictionary = {} # String -> SystemHealthData
var overall_health_status: HealthStatus = HealthStatus.OFFLINE
var monitoring_timer: Timer
var is_monitoring: bool = false

## Backend systems to monitor
var monitored_systems: Array[String] = [
	"SimpleCharacterCreator",
	"StartingEquipmentGenerator",
	"ContactManager",
	"PlanetDataManager",
	"RivalBattleGenerator",
	"PatronJobGenerator"
]

func _ready() -> void:
	_initialize_monitoring()

func _initialize_monitoring() -> void:
	## Initialize the monitoring system
	
	# Initialize health data for each system
	for system_name in monitored_systems:
		system_health[system_name] = SystemHealthData.new(system_name)
	
	# Setup monitoring timer
	monitoring_timer = Timer.new()
	monitoring_timer.wait_time = float(check_interval_ms) / 1000.0
	monitoring_timer.timeout.connect(_perform_health_check)
	monitoring_timer.autostart = true
	add_child(monitoring_timer)
	
	# Perform initial health check
	call_deferred("_perform_initial_health_check")
	
	pass

func _perform_initial_health_check() -> void:
	## Perform initial health check on startup
	_perform_health_check()
	is_monitoring = true

func _perform_health_check() -> void:
	## Perform comprehensive health check of all monitored systems
	if not monitoring_enabled:
		return
	
	var start_time = Time.get_ticks_msec()
	
	# Check backend system availability
	var health_results = ValidationErrorBoundary.validate_integration_health(monitored_systems)
	
	# Update system health data
	for result in health_results:
		var system_name = result.context.get("system_name", "Unknown")
		if system_health.has(system_name):
			_update_system_health(system_name, result)
	
	# Update overall health status
	_update_overall_health()
	
	var end_time = Time.get_ticks_msec()
	var duration = end_time - start_time

func _update_system_health(system_name: String, result: ValidationErrorBoundary.ValidationErrorResult) -> void:
	## Update health data for a specific system
	var health_data = system_health[system_name] as SystemHealthData
	var old_status = health_data.health_status
	
	health_data.last_check_time = Time.get_ticks_msec()
	health_data.response_time_ms = result.performance_data.get("duration_ms", 0)
	
	# Update performance history
	health_data.performance_history.append(health_data.response_time_ms)
	if health_data.performance_history.size() > max_performance_history:
		health_data.performance_history.pop_front()
	
	# Update success/error counts
	if result.success:
		health_data.success_count += 1
		health_data.is_available = true
		
		# Determine health status based on performance
		if health_data.response_time_ms <= performance_threshold_ms:
			health_data.health_status = HealthStatus.EXCELLENT
		else:
			health_data.health_status = HealthStatus.GOOD
			if health_data.response_time_ms > performance_threshold_ms * 2:
				performance_warning.emit(system_name, health_data.response_time_ms, performance_threshold_ms)
		
		# Check for recovery
		if old_status == HealthStatus.OFFLINE or old_status == HealthStatus.CRITICAL:
			system_recovery_detected.emit(system_name)
	else:
		health_data.error_count += 1
		health_data.last_error = result.error_message
		health_data.is_available = false
		
		# Determine degraded status based on success rate
		var success_rate = health_data.get_success_rate()
		if success_rate < degradation_threshold:
			health_data.health_status = HealthStatus.CRITICAL
		else:
			health_data.health_status = HealthStatus.DEGRADED
		
		# Check for degradation
		if old_status == HealthStatus.EXCELLENT or old_status == HealthStatus.GOOD:
			system_degradation_detected.emit(system_name, result.error_message)
	
	# Emit status change signal if needed
	if health_data.health_status != old_status:
		system_health_changed.emit(system_name, health_data.health_status, old_status)

func _update_overall_health() -> void:
	## Calculate and update overall system health
	var old_overall_status = overall_health_status
	
	var excellent_count = 0
	var good_count = 0
	var degraded_count = 0
	var critical_count = 0
	var offline_count = 0
	
	for system_name in system_health.keys():
		var health_data = system_health[system_name] as SystemHealthData
		match health_data.health_status:
			HealthStatus.EXCELLENT:
				excellent_count += 1
			HealthStatus.GOOD:
				good_count += 1
			HealthStatus.DEGRADED:
				degraded_count += 1
			HealthStatus.CRITICAL:
				critical_count += 1
			HealthStatus.OFFLINE:
				offline_count += 1
	
	var total_systems = monitored_systems.size()
	var operational_systems = excellent_count + good_count
	
	# Determine overall status
	if offline_count == total_systems:
		overall_health_status = HealthStatus.OFFLINE
	elif critical_count > 0 or offline_count > total_systems / 2:
		overall_health_status = HealthStatus.CRITICAL
	elif degraded_count > 0 or operational_systems < total_systems * 0.8:
		overall_health_status = HealthStatus.DEGRADED
	elif good_count > excellent_count:
		overall_health_status = HealthStatus.GOOD
	else:
		overall_health_status = HealthStatus.EXCELLENT
	
	# Emit overall status change if needed
	if overall_health_status != old_overall_status:
		overall_health_changed.emit(overall_health_status, old_overall_status)
		pass

## Public API for health monitoring

func get_system_health(system_name: String) -> SystemHealthData:
	## Get health data for a specific system
	return system_health.get(system_name, null)

func get_overall_health_status() -> HealthStatus:
	## Get current overall health status
	return overall_health_status

func get_health_summary() -> Dictionary:
	## Get comprehensive health summary
	var summary = {
		"overall_status": HealthStatus.keys()[overall_health_status],
		"total_systems": monitored_systems.size(),
		"operational_systems": 0,
		"degraded_systems": 0,
		"offline_systems": 0,
		"average_response_time": 0.0,
		"systems": {}
	}
	
	var total_response_time = 0.0
	var response_count = 0
	
	for system_name in system_health.keys():
		var health_data = system_health[system_name] as SystemHealthData
		
		# Count system statuses
		match health_data.health_status:
			HealthStatus.EXCELLENT, HealthStatus.GOOD:
				summary.operational_systems += 1
			HealthStatus.DEGRADED, HealthStatus.CRITICAL:
				summary.degraded_systems += 1
			HealthStatus.OFFLINE:
				summary.offline_systems += 1
		
		# Calculate average response time
		var avg_response = health_data.get_average_response_time()
		if avg_response > 0:
			total_response_time += avg_response
			response_count += 1
		
		# Add system details
		summary.systems[system_name] = {
			"status": HealthStatus.keys()[health_data.health_status],
			"is_available": health_data.is_available,
			"success_rate": health_data.get_success_rate(),
			"average_response_time": avg_response,
			"last_error": health_data.last_error
		}
	
	if response_count > 0:
		summary.average_response_time = total_response_time / response_count
	
	return summary

func force_health_check() -> void:
	## Force an immediate health check
	_perform_health_check()

func set_monitoring_enabled(enabled: bool) -> void:
	## Enable or disable health monitoring
	monitoring_enabled = enabled
	if monitoring_timer:
		monitoring_timer.paused = not enabled
	pass

func set_check_interval(interval_ms: int) -> void:
	## Set the health check interval
	check_interval_ms = interval_ms
	if monitoring_timer:
		monitoring_timer.wait_time = float(interval_ms) / 1000.0

func get_performance_report() -> String:
	## Generate a detailed performance report
	var report = "# Integration Health Monitor Report\n\n"
	report += "**Overall Status**: %s\n\n" % HealthStatus.keys()[overall_health_status]
	
	var summary = get_health_summary()
	report += "## Summary\n"
	report += "- Total Systems: %d\n" % summary.total_systems
	report += "- Operational: %d\n" % summary.operational_systems
	report += "- Degraded: %d\n" % summary.degraded_systems
	report += "- Offline: %d\n" % summary.offline_systems
	report += "- Average Response Time: %.1fms\n\n" % summary.average_response_time
	
	report += "## System Details\n"
	for system_name in system_health.keys():
		var health_data = system_health[system_name] as SystemHealthData
		report += "### %s\n" % system_name
		report += "- Status: %s\n" % HealthStatus.keys()[health_data.health_status]
		report += "- Available: %s\n" % ("Yes" if health_data.is_available else "No")
		report += "- Success Rate: %.1f%%\n" % (health_data.get_success_rate() * 100)
		report += "- Average Response: %.1fms\n" % health_data.get_average_response_time()
		
		if not health_data.last_error.is_empty():
			report += "- Last Error: %s\n" % health_data.last_error
		
		report += "\n"
	
	return report

func _notification(what: int) -> void:
	## Handle cleanup on node removal
	if what == NOTIFICATION_PREDELETE:
		if monitoring_timer:
			monitoring_timer.stop()
		is_monitoring = false