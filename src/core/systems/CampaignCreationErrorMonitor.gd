@tool
extends RefCounted
class_name CampaignCreationErrorMonitor

## Production Error Monitoring System for Campaign Creation
## Provides comprehensive error tracking, alerting, and health monitoring

# Error tracking data
var error_log: Array[Dictionary] = []
var warning_log: Array[Dictionary] = []
var performance_alerts: Array[Dictionary] = []
var system_health_history: Array[Dictionary] = []

# Error categorization
enum ErrorSeverity {
	INFO,
	WARNING, 
	MAJOR,
	CRITICAL,
	EMERGENCY
}

enum ErrorCategory {
	ANIMATION_SYSTEM,
	PANEL_LOADING,
	STATE_MANAGEMENT,
	VALIDATION,
	PERFORMANCE,
	UI_INTERACTION,
	MEMORY,
	GENERAL
}

# Monitoring configuration
const MONITORING_CONFIG = {
	"max_log_entries": 1000,
	"alert_thresholds": {
		"critical_errors_per_minute": 5,
		"total_errors_per_hour": 50,
		"memory_increase_percent": 15.0,
		"performance_degradation_percent": 25.0
	},
	"retention_hours": 24,
	"health_check_interval_seconds": 30
}

# Real-time monitoring state
var monitoring_enabled: bool = true
var alert_callbacks: Array[Callable] = []
var health_check_timer: Timer
var current_session_start: float
var last_health_check: float

func _init():
	## Initialize error monitoring system
	current_session_start = Time.get_unix_time_from_system()
	last_health_check = current_session_start
	

func record_error(message: String, category: ErrorCategory = ErrorCategory.GENERAL, severity: ErrorSeverity = ErrorSeverity.MAJOR, context: Dictionary = {}) -> void:
	## Record an error with full context and categorization
	if not monitoring_enabled:
		return
	
	var error_entry = {
		"message": message,
		"category": str(category),
		"severity": str(severity),
		"timestamp": Time.get_unix_time_from_system(),
		"context": context,
		"session_time": Time.get_unix_time_from_system() - current_session_start,
		"stack_trace": _get_simple_stack_trace()
	}
	
	# Add to appropriate log
	if severity in [ErrorSeverity.CRITICAL, ErrorSeverity.EMERGENCY, ErrorSeverity.MAJOR]:
		error_log.append(error_entry)
	else:
		warning_log.append(error_entry)
	
	# Trigger alerts for critical errors
	if severity >= ErrorSeverity.CRITICAL:
		_trigger_critical_error_alert(error_entry)
	
	# Check alert thresholds
	_check_alert_thresholds()
	
	# Cleanup old entries
	_cleanup_old_entries()
	
	push_warning("CampaignCreationErrorMonitor: [%s] %s - %s" % [str(severity), str(category), message])

func record_performance_alert(alert_type: String, data: Dictionary, severity: ErrorSeverity = ErrorSeverity.WARNING) -> void:
	## Record performance-related alert
	if not monitoring_enabled:
		return
	
	var alert_entry = {
		"type": alert_type,
		"severity": str(severity),
		"timestamp": Time.get_unix_time_from_system(),
		"data": data,
		"session_time": Time.get_unix_time_from_system() - current_session_start
	}
	
	performance_alerts.append(alert_entry)
	
	# Also record as error if severe enough
	if severity >= ErrorSeverity.MAJOR:
		record_error("Performance alert: %s" % alert_type, ErrorCategory.PERFORMANCE, severity, data)
	
	_cleanup_old_entries()

func record_system_health(health_data: Dictionary) -> void:
	## Record system health snapshot
	if not monitoring_enabled:
		return
	
	var health_entry = health_data.duplicate()
	health_entry.timestamp = Time.get_unix_time_from_system()
	health_entry.session_time = Time.get_unix_time_from_system() - current_session_start
	
	system_health_history.append(health_entry)
	last_health_check = Time.get_unix_time_from_system()
	
	# Analyze health trends
	_analyze_health_trends()
	
	_cleanup_old_entries()

func get_error_summary() -> Dictionary:
	## Get comprehensive error summary
	var now = Time.get_unix_time_from_system()
	var last_hour = now - 3600
	var last_minute = now - 60
	
	# Count errors by time period
	var errors_last_hour = 0
	var errors_last_minute = 0
	var critical_errors_total = 0
	
	for error in error_log:
		if error.timestamp > last_hour:
			errors_last_hour += 1
		if error.timestamp > last_minute:
			errors_last_minute += 1
		if error.severity in ["CRITICAL", "EMERGENCY"]:
			critical_errors_total += 1
	
	# Count by category
	var errors_by_category = {}
	for error in error_log:
		var category = error.category
		if not errors_by_category.has(category):
			errors_by_category[category] = 0
		errors_by_category[category] += 1
	
	return {
		"total_errors": error_log.size(),
		"total_warnings": warning_log.size(),
		"critical_errors": critical_errors_total,
		"errors_last_hour": errors_last_hour,
		"errors_last_minute": errors_last_minute,
		"errors_by_category": errors_by_category,
		"performance_alerts": performance_alerts.size(),
		"session_duration_minutes": (now - current_session_start) / 60.0,
		"monitoring_enabled": monitoring_enabled,
		"last_health_check_seconds_ago": now - last_health_check
	}

func get_health_status() -> Dictionary:
	## Get current system health assessment
	var summary = get_error_summary()
	var status = "healthy"
	var issues = []
	var recommendations = []
	
	# Analyze error rates
	if summary.errors_last_minute > MONITORING_CONFIG.alert_thresholds.critical_errors_per_minute:
		status = "critical"
		issues.append("Critical error rate exceeded: %d errors/minute" % summary.errors_last_minute)
		recommendations.append("Immediate investigation required - system may be unstable")
	elif summary.errors_last_hour > MONITORING_CONFIG.alert_thresholds.total_errors_per_hour:
		status = "warning"
		issues.append("High error rate: %d errors/hour" % summary.errors_last_hour)
		recommendations.append("Monitor system closely and investigate error patterns")
	
	# Analyze critical errors
	if summary.critical_errors > 0:
		if summary.critical_errors > 5:
			status = "critical"
		elif status == "healthy":
			status = "warning"
		issues.append("%d critical errors detected" % summary.critical_errors)
		recommendations.append("Review critical errors and implement fixes")
	
	# Analyze performance alerts
	if summary.performance_alerts > 10:
		if status == "healthy":
			status = "warning"
		issues.append("Multiple performance alerts: %d" % summary.performance_alerts)
		recommendations.append("Performance optimization may be needed")
	
	# Analyze health check freshness
	if summary.last_health_check_seconds_ago > 300:  # 5 minutes
		if status == "healthy":
			status = "warning"
		issues.append("Health checks are stale (last check %d seconds ago)" % summary.last_health_check_seconds_ago)
		recommendations.append("Verify monitoring system is functioning correctly")
	
	return {
		"status": status,
		"issues": issues,
		"recommendations": recommendations,
		"error_summary": summary,
		"uptime_minutes": summary.session_duration_minutes,
		"health_score": _calculate_health_score(summary)
	}

func get_recent_errors(count: int = 20) -> Array[Dictionary]:
	## Get most recent errors
	var all_errors = []
	all_errors.append_array(error_log)
	all_errors.append_array(warning_log)
	
	# Sort by timestamp (most recent first)
	all_errors.sort_custom(func(a, b): return a.timestamp > b.timestamp)
	
	return all_errors.slice(0, min(count, all_errors.size()))

func get_error_trends() -> Dictionary:
	## Analyze error trends over time
	var now = Time.get_unix_time_from_system()
	var trends = {
		"hourly_error_count": [],
		"category_trends": {},
		"severity_trends": {},
		"trend_direction": "stable"
	}
	
	# Analyze hourly error counts for last 6 hours
	for i in range(6):
		var hour_start = now - (i + 1) * 3600
		var hour_end = now - i * 3600
		var count = 0
		
		for error in error_log:
			if error.timestamp >= hour_start and error.timestamp < hour_end:
				count += 1
		
		trends.hourly_error_count.append(count)
	
	# Determine trend direction
	if trends.hourly_error_count.size() >= 3:
		var recent_avg = (trends.hourly_error_count[0] + trends.hourly_error_count[1]) / 2.0
		var older_avg = (trends.hourly_error_count[2] + trends.hourly_error_count[3]) / 2.0
		
		if recent_avg > older_avg * 1.5:
			trends.trend_direction = "increasing"
		elif recent_avg < older_avg * 0.67:
			trends.trend_direction = "decreasing"
	
	return trends

func add_alert_callback(callback: Callable) -> void:
	## Add callback for critical error alerts
	alert_callbacks.append(callback)

func remove_alert_callback(callback: Callable) -> void:
	## Remove alert callback
	alert_callbacks.erase(callback)

func enable_monitoring() -> void:
	## Enable error monitoring
	monitoring_enabled = true

func disable_monitoring() -> void:
	## Disable error monitoring
	monitoring_enabled = false

func clear_logs() -> void:
	## Clear all error logs (use with caution)
	error_log.clear()
	warning_log.clear()
	performance_alerts.clear()
	system_health_history.clear()

func export_error_report() -> String:
	## Export comprehensive error report for analysis
	var report = {
		"export_timestamp": Time.get_unix_time_from_system(),
		"session_start": current_session_start,
		"monitoring_config": MONITORING_CONFIG,
		"error_summary": get_error_summary(),
		"health_status": get_health_status(),
		"recent_errors": get_recent_errors(50),
		"error_trends": get_error_trends(),
		"performance_alerts": performance_alerts,
		"system_health_history": system_health_history.slice(max(0, system_health_history.size() - 20))
	}
	
	return JSON.stringify(report, "\t")

func _trigger_critical_error_alert(error_entry: Dictionary) -> void:
	## Trigger alerts for critical errors
	for callback in alert_callbacks:
		if callback.is_valid():
			callback.call(error_entry)

func _check_alert_thresholds() -> void:
	## Check if error rates exceed alert thresholds
	var summary = get_error_summary()
	
	# Check critical errors per minute
	if summary.errors_last_minute > MONITORING_CONFIG.alert_thresholds.critical_errors_per_minute:
		record_performance_alert("critical_error_rate_exceeded", {
			"errors_per_minute": summary.errors_last_minute,
			"threshold": MONITORING_CONFIG.alert_thresholds.critical_errors_per_minute
		}, ErrorSeverity.CRITICAL)
	
	# Check total errors per hour
	if summary.errors_last_hour > MONITORING_CONFIG.alert_thresholds.total_errors_per_hour:
		record_performance_alert("hourly_error_rate_exceeded", {
			"errors_per_hour": summary.errors_last_hour,
			"threshold": MONITORING_CONFIG.alert_thresholds.total_errors_per_hour
		}, ErrorSeverity.MAJOR)

func _analyze_health_trends() -> void:
	## Analyze health trends and generate alerts if needed
	if system_health_history.size() < 3:
		return
	
	# Get recent health data
	var recent_entries = system_health_history.slice(max(0, system_health_history.size() - 3))
	
	# Check for degrading trends (simplified analysis)
	var error_counts = []
	for entry in recent_entries:
		if entry.has("error_count"):
			error_counts.append(entry.error_count)
	
	if error_counts.size() >= 3:
		var is_trending_up = error_counts[2] > error_counts[1] and error_counts[1] > error_counts[0]
		if is_trending_up and error_counts[2] > error_counts[0] * 2:
			record_performance_alert("error_trend_increasing", {
				"trend_data": error_counts,
				"increase_factor": float(error_counts[2]) / float(max(error_counts[0], 1))
			}, ErrorSeverity.WARNING)

func _cleanup_old_entries() -> void:
	## Clean up old log entries to prevent memory bloat
	var cutoff_time = Time.get_unix_time_from_system() - (MONITORING_CONFIG.retention_hours * 3600)
	
	# Clean error log
	error_log = error_log.filter(func(entry): return entry.timestamp > cutoff_time)
	
	# Clean warning log
	warning_log = warning_log.filter(func(entry): return entry.timestamp > cutoff_time)
	
	# Clean performance alerts
	performance_alerts = performance_alerts.filter(func(entry): return entry.timestamp > cutoff_time)
	
	# Clean health history
	system_health_history = system_health_history.filter(func(entry): return entry.timestamp > cutoff_time)
	
	# Enforce max entry limits
	if error_log.size() > MONITORING_CONFIG.max_log_entries:
		error_log = error_log.slice(error_log.size() - MONITORING_CONFIG.max_log_entries)
	
	if warning_log.size() > MONITORING_CONFIG.max_log_entries:
		warning_log = warning_log.slice(warning_log.size() - MONITORING_CONFIG.max_log_entries)

func _get_simple_stack_trace() -> String:
	## Get simplified stack trace for error context
	# In a real implementation, this would capture the actual stack trace
	# For now, return a simple identifier
	return "CampaignCreation::%s" % Time.get_datetime_string_from_system()

func _calculate_health_score(summary: Dictionary) -> float:
	## Calculate overall system health score (0-100)
	var score = 100.0
	
	# Deduct for errors
	score -= min(summary.critical_errors * 20, 60)  # Max 60% deduction for critical errors
	score -= min(summary.errors_last_hour * 0.5, 20)  # Max 20% deduction for hourly errors
	score -= min(summary.performance_alerts * 2, 15)  # Max 15% deduction for performance alerts
	
	# Bonus for stable operation
	if summary.session_duration_minutes > 60 and summary.total_errors == 0:
		score += 5  # Bonus for stable long-running session
	
	return max(score, 0.0)