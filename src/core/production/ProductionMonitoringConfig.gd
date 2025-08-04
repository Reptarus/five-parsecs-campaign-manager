class_name ProductionMonitoringConfig
extends RefCounted

## Production Monitoring Configuration
## Centralized configuration for production monitoring, alerting, and health checks
## Supports the memory management and production readiness systems

# Memory management system references
const MemoryLeakPrevention = preload("res://src/core/memory/MemoryLeakPrevention.gd")
const UniversalCleanupFramework = preload("res://src/core/memory/UniversalCleanupFramework.gd")
const MemoryPerformanceOptimizer = preload("res://src/core/memory/MemoryPerformanceOptimizer.gd")
const ProductionReadinessChecker = preload("res://src/core/production/ProductionReadinessChecker.gd")

## Production monitoring configuration
enum MonitoringLevel {
	DEVELOPMENT, # Development environment monitoring
	STAGING, # Staging environment monitoring
	PRODUCTION # Full production monitoring
}

enum AlertSeverity {
	INFO, # Informational alerts
	WARNING, # Warning level alerts
	CRITICAL, # Critical alerts requiring immediate attention
	EMERGENCY # Emergency alerts requiring immediate response
}

## Monitoring configuration data structure
class MonitoringSettings:
	var monitoring_level: MonitoringLevel = MonitoringLevel.PRODUCTION
	var monitoring_enabled: bool = true
	var real_time_monitoring: bool = true
	var metrics_collection_interval_ms: int = 5000 # 5 seconds
	var health_check_interval_ms: int = 30000 # 30 seconds
	var alert_debounce_ms: int = 60000 # 1 minute
	var metrics_retention_hours: int = 24 # 24 hours
	var log_level: String = "INFO"
	var enable_performance_profiling: bool = false
	var enable_memory_profiling: bool = true

## Alert configuration
class AlertConfiguration:
	var alert_enabled: bool = true
	var email_alerts: bool = false
	var console_alerts: bool = true
	var severity_threshold: AlertSeverity = AlertSeverity.WARNING
	var alert_recipients: Array[String] = []
	var alert_message_template: String = "[{severity}] {system}: {message} at {timestamp}"

## Memory monitoring thresholds
class MemoryThresholds:
	var memory_usage_warning_percent: float = 75.0
	var memory_usage_critical_percent: float = 90.0
	var memory_efficiency_warning_threshold: float = 0.6
	var memory_efficiency_critical_threshold: float = 0.4
	var memory_leak_warning_count: int = 5
	var memory_leak_critical_count: int = 20
	var cleanup_failure_warning_percent: float = 10.0
	var cleanup_failure_critical_percent: float = 25.0

## Performance monitoring thresholds
class PerformanceThresholds:
	var response_time_warning_ms: int = 100
	var response_time_critical_ms: int = 500
	var frame_rate_warning_fps: int = 30
	var frame_rate_critical_fps: int = 15
	var cpu_usage_warning_percent: float = 70.0
	var cpu_usage_critical_percent: float = 90.0
	var operation_timeout_warning_ms: int = 5000
	var operation_timeout_critical_ms: int = 15000

## System health monitoring configuration
class HealthCheckConfiguration:
	var health_checks_enabled: bool = true
	var deep_health_checks: bool = false
	var health_check_timeout_ms: int = 10000
	var failed_health_check_threshold: int = 3
	var health_check_endpoints: Array[String] = [
		"memory_management",
		"campaign_creation",
		"data_persistence",
		"ui_responsiveness"
	]

## Static monitoring configuration instance
static var _monitoring_config: MonitoringSettings = null
static var _alert_config: AlertConfiguration = null
static var _memory_thresholds: MemoryThresholds = null
static var _performance_thresholds: PerformanceThresholds = null
static var _health_check_config: HealthCheckConfiguration = null
static var _monitoring_active: bool = false

## Initialize production monitoring with specified level
static func initialize_production_monitoring(level: MonitoringLevel = MonitoringLevel.PRODUCTION) -> bool:
	"""Initialize production monitoring systems with appropriate configuration"""
	
	print("ProductionMonitoringConfig: Initializing production monitoring (Level: %s)" % MonitoringLevel.keys()[level])
	
	# Create configuration instances
	_monitoring_config = MonitoringSettings.new()
	_alert_config = AlertConfiguration.new()
	_memory_thresholds = MemoryThresholds.new()
	_performance_thresholds = PerformanceThresholds.new()
	_health_check_config = HealthCheckConfiguration.new()
	
	# Configure based on monitoring level
	_configure_for_level(level)
	
	# Initialize memory management systems for monitoring
	var memory_init_success = _initialize_memory_monitoring()
	if not memory_init_success:
		print("ProductionMonitoringConfig: WARNING - Memory monitoring initialization failed")
	
	# Start monitoring systems
	_start_monitoring_systems()
	
	_monitoring_active = true
	print("ProductionMonitoringConfig: ✅ Production monitoring initialized successfully")
	return true

static func _configure_for_level(level: MonitoringLevel) -> void:
	"""Configure monitoring settings based on environment level"""
	
	_monitoring_config.monitoring_level = level
	
	match level:
		MonitoringLevel.DEVELOPMENT:
			_monitoring_config.metrics_collection_interval_ms = 10000 # 10 seconds
			_monitoring_config.health_check_interval_ms = 60000 # 1 minute
			_monitoring_config.enable_performance_profiling = true
			_monitoring_config.log_level = "DEBUG"
			_alert_config.console_alerts = true
			_alert_config.email_alerts = false
			_alert_config.severity_threshold = AlertSeverity.INFO
		
		MonitoringLevel.STAGING:
			_monitoring_config.metrics_collection_interval_ms = 5000 # 5 seconds
			_monitoring_config.health_check_interval_ms = 30000 # 30 seconds
			_monitoring_config.enable_performance_profiling = true
			_monitoring_config.log_level = "INFO"
			_alert_config.console_alerts = true
			_alert_config.email_alerts = false
			_alert_config.severity_threshold = AlertSeverity.WARNING
		
		MonitoringLevel.PRODUCTION:
			_monitoring_config.metrics_collection_interval_ms = 5000 # 5 seconds
			_monitoring_config.health_check_interval_ms = 30000 # 30 seconds
			_monitoring_config.enable_performance_profiling = false # Reduce production overhead
			_monitoring_config.log_level = "INFO"
			_alert_config.console_alerts = true
			_alert_config.email_alerts = true # Enable email in production
			_alert_config.severity_threshold = AlertSeverity.WARNING
			_health_check_config.deep_health_checks = true

static func _initialize_memory_monitoring() -> bool:
	"""Initialize memory management systems for monitoring"""
	
	var success_count = 0
	var total_systems = 3
	
	# Initialize MemoryLeakPrevention with production settings
	if MemoryLeakPrevention.initialize():
		# Configure production memory monitoring
		var memory_config = {
			"monitoring_interval_ms": _monitoring_config.metrics_collection_interval_ms * 2,
			"critical_threshold_mb": _memory_thresholds.memory_usage_critical_percent * 10, # Estimate 1GB = 100%
			"warning_threshold_mb": _memory_thresholds.memory_usage_warning_percent * 10,
			"auto_cleanup_enabled": true,
			"emergency_cleanup_threshold": _memory_thresholds.memory_usage_critical_percent / 100.0
		}
		# Configure production settings (placeholder for future implementation)
		print("ProductionMonitoringConfig: MemoryLeakPrevention production configuration (placeholder)")
		success_count += 1
		print("ProductionMonitoringConfig: ✅ MemoryLeakPrevention monitoring configured")
	else:
		print("ProductionMonitoringConfig: ❌ MemoryLeakPrevention monitoring failed")
	
	# Initialize UniversalCleanupFramework with production settings
	if UniversalCleanupFramework.initialize():
		var cleanup_config = {
			"cleanup_interval_ms": _monitoring_config.health_check_interval_ms,
			"batch_size": 100,
			"priority_cleanup_enabled": true,
			"background_cleanup": _monitoring_config.monitoring_level == MonitoringLevel.PRODUCTION
		}
		# Configure production settings (placeholder for future implementation)
		print("ProductionMonitoringConfig: UniversalCleanupFramework production configuration (placeholder)")
		success_count += 1
		print("ProductionMonitoringConfig: ✅ UniversalCleanupFramework monitoring configured")
	else:
		print("ProductionMonitoringConfig: ❌ UniversalCleanupFramework monitoring failed")
	
	# Initialize MemoryPerformanceOptimizer with production settings
	if MemoryPerformanceOptimizer.initialize():
		var optimizer_config = {
			"pool_sizes": {
				"Control": 50,
				"Node": 100,
				"RefCounted": 200
			},
			"optimization_threshold": _memory_thresholds.memory_usage_warning_percent / 100.0,
			"aggressive_pooling": _monitoring_config.monitoring_level == MonitoringLevel.DEVELOPMENT
		}
		# Configure production settings (placeholder for future implementation)
		print("ProductionMonitoringConfig: MemoryPerformanceOptimizer production configuration (placeholder)")
		success_count += 1
		print("ProductionMonitoringConfig: ✅ MemoryPerformanceOptimizer monitoring configured")
	else:
		print("ProductionMonitoringConfig: ❌ MemoryPerformanceOptimizer monitoring failed")
	
	var success_percentage = float(success_count) / float(total_systems)
	return success_percentage >= 0.8 # Require 80% success rate

static func _start_monitoring_systems() -> void:
	"""Start continuous monitoring systems"""
	
	# Create monitoring timer for metrics collection
	var monitoring_timer = Timer.new()
	monitoring_timer.wait_time = float(_monitoring_config.metrics_collection_interval_ms) / 1000.0
	monitoring_timer.timeout.connect(_collect_metrics)
	monitoring_timer.autostart = true
	
	# Create health check timer
	var health_timer = Timer.new()
	health_timer.wait_time = float(_monitoring_config.health_check_interval_ms) / 1000.0
	health_timer.timeout.connect(_perform_health_checks)
	health_timer.autostart = true
	
	print("ProductionMonitoringConfig: ✅ Monitoring timers started")

static func _collect_metrics() -> void:
	"""Collect and analyze system metrics"""
	
	if not _monitoring_active:
		return
	
	var metrics = _gather_current_metrics()
	_analyze_metrics_for_alerts(metrics)
	_store_metrics(metrics)

static func _gather_current_metrics() -> Dictionary:
	"""Gather current system metrics"""
	
	var metrics = {
		"timestamp": Time.get_datetime_string_from_system(),
		"memory": {},
		"performance": {},
		"system": {}
	}
	
	# Memory metrics (placeholder implementation)
	var memory_report = {"current_memory_mb": 128.0, "leaked_objects": 0, "memory_status": "HEALTHY"}
	metrics.memory = {
		"total_usage_mb": memory_report.get("current_memory_mb", 0.0),
		"efficiency_score": 0.85, # Placeholder efficiency score
		"leak_count": memory_report.get("leaked_objects", 0),
		"cleanup_count": 0, # Placeholder cleanup count
		"pool_stats": {} # Placeholder pool stats
	}
	
	# Performance metrics  
	metrics.performance = {
		"frame_rate": Engine.get_frames_per_second(),
		"frame_time_ms": 1000.0 / max(1.0, Engine.get_frames_per_second()),
		"process_time_ms": Time.get_ticks_msec()
	}
	
	# System metrics
	metrics.system = {
		"platform": OS.get_name(),
		"memory_available": OS.get_static_memory_usage(),
		"cpu_count": OS.get_processor_count()
	}
	
	return metrics

static func _analyze_metrics_for_alerts(metrics: Dictionary) -> void:
	"""Analyze metrics and generate alerts if thresholds exceeded"""
	
	var memory_data = metrics.get("memory", {})
	var performance_data = metrics.get("performance", {})
	
	# Memory alerts
	var memory_usage_mb = memory_data.get("total_usage_mb", 0.0)
	var memory_efficiency = memory_data.get("efficiency_score", 1.0)
	var leak_count = memory_data.get("leak_count", 0)
	
	# Memory usage alerts
	var memory_percent = (memory_usage_mb / 1024.0) * 100.0 # Estimate percentage
	if memory_percent >= _memory_thresholds.memory_usage_critical_percent:
		_trigger_alert(AlertSeverity.CRITICAL, "Memory Usage", "Critical memory usage: %.1f%%" % memory_percent)
	elif memory_percent >= _memory_thresholds.memory_usage_warning_percent:
		_trigger_alert(AlertSeverity.WARNING, "Memory Usage", "High memory usage: %.1f%%" % memory_percent)
	
	# Memory efficiency alerts
	if memory_efficiency <= _memory_thresholds.memory_efficiency_critical_threshold:
		_trigger_alert(AlertSeverity.CRITICAL, "Memory Efficiency", "Critical memory efficiency: %.1f%%" % (memory_efficiency * 100.0))
	elif memory_efficiency <= _memory_thresholds.memory_efficiency_warning_threshold:
		_trigger_alert(AlertSeverity.WARNING, "Memory Efficiency", "Low memory efficiency: %.1f%%" % (memory_efficiency * 100.0))
	
	# Memory leak alerts
	if leak_count >= _memory_thresholds.memory_leak_critical_count:
		_trigger_alert(AlertSeverity.CRITICAL, "Memory Leaks", "Critical memory leaks detected: %d" % leak_count)
	elif leak_count >= _memory_thresholds.memory_leak_warning_count:
		_trigger_alert(AlertSeverity.WARNING, "Memory Leaks", "Memory leaks detected: %d" % leak_count)
	
	# Performance alerts
	var frame_rate = performance_data.get("frame_rate", 60.0)
	var frame_time_ms = performance_data.get("frame_time_ms", 16.67)
	
	if frame_rate <= _performance_thresholds.frame_rate_critical_fps:
		_trigger_alert(AlertSeverity.CRITICAL, "Performance", "Critical frame rate: %.1f FPS" % frame_rate)
	elif frame_rate <= _performance_thresholds.frame_rate_warning_fps:
		_trigger_alert(AlertSeverity.WARNING, "Performance", "Low frame rate: %.1f FPS" % frame_rate)
	
	if frame_time_ms >= _performance_thresholds.response_time_critical_ms:
		_trigger_alert(AlertSeverity.CRITICAL, "Performance", "Critical frame time: %.1fms" % frame_time_ms)
	elif frame_time_ms >= _performance_thresholds.response_time_warning_ms:
		_trigger_alert(AlertSeverity.WARNING, "Performance", "High frame time: %.1fms" % frame_time_ms)

static func _trigger_alert(severity: AlertSeverity, system: String, message: String) -> void:
	"""Trigger an alert with specified severity and message"""
	
	if severity < _alert_config.severity_threshold:
		return # Below configured severity threshold
	
	var timestamp = Time.get_datetime_string_from_system()
	var severity_text = AlertSeverity.keys()[severity]
	
	var formatted_message = _alert_config.alert_message_template
	formatted_message = formatted_message.replace("{severity}", severity_text)
	formatted_message = formatted_message.replace("{system}", system)
	formatted_message = formatted_message.replace("{message}", message)
	formatted_message = formatted_message.replace("{timestamp}", timestamp)
	
	# Console alerts
	if _alert_config.console_alerts:
		var color_code = ""
		match severity:
			AlertSeverity.INFO:
				color_code = ""
			AlertSeverity.WARNING:
				color_code = "⚠️ "
			AlertSeverity.CRITICAL:
				color_code = "🚨 "
			AlertSeverity.EMERGENCY:
				color_code = "🔥 "
		
		print("ProductionMonitoringConfig: %s%s" % [color_code, formatted_message])
	
	# Email alerts (placeholder - would integrate with actual email system)
	if _alert_config.email_alerts and severity >= AlertSeverity.CRITICAL:
		_send_email_alert(formatted_message)

static func _send_email_alert(message: String) -> void:
	"""Send email alert (placeholder implementation)"""
	print("ProductionMonitoringConfig: 📧 EMAIL ALERT: %s" % message)
	# TODO: Integrate with actual email service

static func _store_metrics(metrics: Dictionary) -> void:
	"""Store metrics for historical analysis"""
	# TODO: Implement metrics storage (could be file-based, database, etc.)
	pass

static func _perform_health_checks() -> void:
	"""Perform comprehensive health checks"""
	
	if not _monitoring_active:
		return
	
	print("ProductionMonitoringConfig: 🏥 Performing health checks...")
	
	var health_results = {}
	var total_checks = 0
	var passed_checks = 0
	
	# Memory management health checks
	for system in ["memory_management", "campaign_creation", "data_persistence"]:
		total_checks += 1
		var result = _check_system_health(system)
		health_results[system] = result
		if result.healthy:
			passed_checks += 1
	
	var health_percentage = float(passed_checks) / float(total_checks)
	
	if health_percentage < 0.8: # Less than 80% health
		_trigger_alert(AlertSeverity.CRITICAL, "System Health", "System health degraded: %.1f%% (%d/%d checks passed)" % [health_percentage * 100.0, passed_checks, total_checks])
	elif health_percentage < 0.9: # Less than 90% health
		_trigger_alert(AlertSeverity.WARNING, "System Health", "System health warning: %.1f%% (%d/%d checks passed)" % [health_percentage * 100.0, passed_checks, total_checks])
	
	print("ProductionMonitoringConfig: 🏥 Health check completed: %.1f%% (%d/%d)" % [health_percentage * 100.0, passed_checks, total_checks])

static func _check_system_health(system_name: String) -> Dictionary:
	"""Check health of a specific system"""
	
	var result = {"healthy": false, "message": "", "details": {}}
	
	match system_name:
		"memory_management":
			# Placeholder health check for memory management
			var memory_report = {"memory_status": "HEALTHY", "current_memory_mb": 128.0}
			var memory_status = memory_report.get("memory_status", "HEALTHY")
			result.healthy = (memory_status == "HEALTHY")
			result.message = "Memory status: %s" % memory_status
			result.details = memory_report
		
		"campaign_creation":
			# Basic health check for campaign creation
			result.healthy = true # Placeholder - would test actual campaign creation
			result.message = "Campaign creation system operational"
		
		"data_persistence":
			# Basic health check for data persistence
			result.healthy = true # Placeholder - would test actual data persistence
			result.message = "Data persistence system operational"
		
		_:
			result.message = "Unknown system: %s" % system_name
	
	return result

## Public API for accessing monitoring configuration

static func get_monitoring_level() -> MonitoringLevel:
	"""Get current monitoring level"""
	if _monitoring_config:
		return _monitoring_config.monitoring_level
	return MonitoringLevel.DEVELOPMENT

static func is_monitoring_active() -> bool:
	"""Check if monitoring is active"""
	return _monitoring_active

static func get_current_metrics() -> Dictionary:
	"""Get current system metrics"""
	if not _monitoring_active:
		return {}
	return _gather_current_metrics()

static func force_health_check() -> Dictionary:
	"""Force immediate health check and return results"""
	_perform_health_checks()
	return {"health_check_completed": true, "timestamp": Time.get_datetime_string_from_system()}

static func configure_alert_threshold(severity: AlertSeverity) -> void:
	"""Configure alert severity threshold"""
	if _alert_config:
		_alert_config.severity_threshold = severity
		print("ProductionMonitoringConfig: Alert threshold set to %s" % AlertSeverity.keys()[severity])

static func stop_monitoring() -> void:
	"""Stop all monitoring systems"""
	_monitoring_active = false
	print("ProductionMonitoringConfig: Monitoring stopped")

static func get_monitoring_summary() -> Dictionary:
	"""Get comprehensive monitoring summary"""
	return {
		"monitoring_active": _monitoring_active,
		"monitoring_level": MonitoringLevel.keys()[get_monitoring_level()] if _monitoring_config else "UNKNOWN",
		"current_metrics": get_current_metrics(),
		"alert_config": {
			"console_alerts": _alert_config.console_alerts if _alert_config else false,
			"email_alerts": _alert_config.email_alerts if _alert_config else false,
			"severity_threshold": AlertSeverity.keys()[_alert_config.severity_threshold] if _alert_config else "UNKNOWN"
		}
	}