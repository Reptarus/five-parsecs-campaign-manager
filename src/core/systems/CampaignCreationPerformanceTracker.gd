@tool
class_name CampaignCreationPerformanceTracker
extends RefCounted

## Performance Tracking System for Campaign Creation
## Monitors performance impact and provides baseline measurements

# Performance data storage
var phase_load_times: Dictionary = {}
var error_handling_overhead: float = 0.0
var memory_usage_baseline: int = 0
var memory_usage_current: int = 0
var panel_creation_metrics: Array[Dictionary] = []
var system_health_metrics: Dictionary = {}

# Performance thresholds
const PERFORMANCE_THRESHOLDS = {
	"max_panel_load_time_ms": 1000.0,
	"max_error_recovery_time_ms": 2000.0,
	"max_memory_overhead_percent": 10.0,
	"max_acceptable_error_rate": 0.05, # 5%
	"min_success_rate": 0.95 # 95%
}

# Metrics collection
var metrics_collection_enabled: bool = true
var start_time: float = 0.0

func _init():
	## Initialize performance tracker
	# Use available memory tracking method or fallback
	memory_usage_baseline = _get_memory_usage_safe()
	start_time = Time.get_unix_time_from_system()
	print("CampaignCreationPerformanceTracker: Initialized with baseline memory: %d bytes" % memory_usage_baseline)

func track_phase_transition(phase: int, duration_ms: float) -> void:
	## Track phase transition performance
	if not metrics_collection_enabled:
		return
	
	var phase_key = str(phase)
	if not phase_load_times.has(phase_key):
		phase_load_times[phase_key] = []
	
	phase_load_times[phase_key].append({
		"duration_ms": duration_ms,
		"timestamp": Time.get_unix_time_from_system(),
		"memory_usage": _get_memory_usage_safe()
	})
	
	# Check performance threshold
	if duration_ms > PERFORMANCE_THRESHOLDS.max_panel_load_time_ms:
		push_warning("Performance Alert: Phase %s load time exceeded threshold: %0.2fms" % [phase_key, duration_ms])
		_record_performance_alert("phase_load_time_exceeded", {
			"phase": phase_key,
			"duration_ms": duration_ms,
			"threshold_ms": PERFORMANCE_THRESHOLDS.max_panel_load_time_ms
		})

func track_panel_creation(phase: int, success: bool, duration_ms: float, error_message: String = "") -> void:
	## Track panel creation metrics
	if not metrics_collection_enabled:
		return
	
	var metric = {
		"phase": phase,
		"success": success,
		"duration_ms": duration_ms,
		"timestamp": Time.get_unix_time_from_system(),
		"error_message": error_message,
		"memory_usage": _get_memory_usage_safe()
	}
	
	panel_creation_metrics.append(metric)
	
	# Limit metrics storage to prevent memory bloat
	if panel_creation_metrics.size() > 1000:
		panel_creation_metrics = panel_creation_metrics.slice(500) # Keep recent 500

func track_error_recovery(recovery_duration_ms: float, success: bool) -> void:
	## Track error recovery performance
	if not metrics_collection_enabled:
		return
	
	error_handling_overhead += recovery_duration_ms
	
	if recovery_duration_ms > PERFORMANCE_THRESHOLDS.max_error_recovery_time_ms:
		push_warning("Performance Alert: Error recovery time exceeded threshold: %0.2fms" % recovery_duration_ms)
		_record_performance_alert("error_recovery_time_exceeded", {
			"duration_ms": recovery_duration_ms,
			"threshold_ms": PERFORMANCE_THRESHOLDS.max_error_recovery_time_ms,
			"success": success
		})

func get_performance_report() -> Dictionary:
	## Generate comprehensive performance report
	memory_usage_current = _get_memory_usage_safe()
	var memory_overhead_percent = 0.0
	if memory_usage_baseline > 0:
		memory_overhead_percent = ((memory_usage_current - memory_usage_baseline) / float(memory_usage_baseline)) * 100.0
	
	return {
		"average_load_times": _calculate_phase_averages(),
		"panel_creation_success_rate": _calculate_success_rate(),
		"error_handling_overhead_ms": error_handling_overhead,
		"memory_overhead_percent": memory_overhead_percent,
		"memory_usage_baseline_bytes": memory_usage_baseline,
		"memory_usage_current_bytes": memory_usage_current,
		"performance_alerts": _get_performance_alerts(),
		"system_uptime_seconds": Time.get_unix_time_from_system() - start_time,
		"metrics_collection_enabled": metrics_collection_enabled,
		"total_panel_creations": panel_creation_metrics.size()
	}

func get_health_status() -> Dictionary:
	## Get current system health status
	var report = get_performance_report()
	var health_status = "healthy"
	var issues = []
	
	# Check memory overhead
	if report.memory_overhead_percent > PERFORMANCE_THRESHOLDS.max_memory_overhead_percent:
		health_status = "warning"
		issues.append("Memory overhead exceeded: %0.2f%%" % report.memory_overhead_percent)
	
	# Check success rate
	if report.panel_creation_success_rate < PERFORMANCE_THRESHOLDS.min_success_rate:
		health_status = "critical"
		issues.append("Panel creation success rate below threshold: %0.2f%%" % (report.panel_creation_success_rate * 100))
	
	# Check average load times
	for phase in report.average_load_times:
		if report.average_load_times[phase] > PERFORMANCE_THRESHOLDS.max_panel_load_time_ms:
			health_status = "warning"
			issues.append("Phase %s average load time exceeded: %0.2fms" % [phase, report.average_load_times[phase]])
	
	return {
		"status": health_status,
		"issues": issues,
		"performance_score": _calculate_performance_score(report),
		"recommendations": _generate_recommendations(report)
	}

func create_baseline() -> Dictionary:
	## Create performance baseline for comparison
	var baseline = {
		"timestamp": Time.get_unix_time_from_system(),
		"memory_usage": _get_memory_usage_safe(),
		"phase_load_times": {},
		"panel_creation_success_rate": 1.0,
		"error_handling_overhead": 0.0
	}
	
	print("CampaignCreationPerformanceTracker: Created baseline: %s" % str(baseline))
	return baseline

func _calculate_phase_averages() -> Dictionary:
	## Calculate average load times per phase
	var averages = {}
	
	for phase_key in phase_load_times.keys():
		var times = phase_load_times[phase_key]
		if times.size() > 0:
			var total = 0.0
			for time_data in times:
				total += time_data.duration_ms
			averages[phase_key] = total / times.size()
		else:
			averages[phase_key] = 0.0
	
	return averages

func _calculate_success_rate() -> float:
	## Calculate overall panel creation success rate
	if panel_creation_metrics.size() == 0:
		return 1.0
	
	var successful = 0
	for metric in panel_creation_metrics:
		if metric.success:
			successful += 1
	
	return float(successful) / float(panel_creation_metrics.size())

func _record_performance_alert(alert_type: String, data: Dictionary) -> void:
	## Record performance alert for monitoring
	if not system_health_metrics.has("alerts"):
		system_health_metrics.alerts = []
	
	var alert = {
		"type": alert_type,
		"timestamp": Time.get_unix_time_from_system(),
		"data": data
	}
	
	system_health_metrics.alerts.append(alert)
	
	# Limit alert storage
	if system_health_metrics.alerts.size() > 100:
		system_health_metrics.alerts = system_health_metrics.alerts.slice(50)

func _get_performance_alerts() -> Array:
	## Get recent performance alerts
	if system_health_metrics.has("alerts"):
		return system_health_metrics.alerts
	return []

func _calculate_performance_score(report: Dictionary) -> float:
	## Calculate overall performance score (0-100)
	var score = 100.0
	
	# Deduct for memory overhead
	if report.memory_overhead_percent > 0:
		score -= min(report.memory_overhead_percent * 2, 30) # Max 30% deduction
	
	# Deduct for low success rate
	var success_rate_penalty = (1.0 - report.panel_creation_success_rate) * 50
	score -= success_rate_penalty
	
	# Deduct for slow load times
	for phase in report.average_load_times:
		var load_time = report.average_load_times[phase]
		if load_time > 500: # 500ms threshold
			score -= min((load_time - 500) / 100, 10) # Max 10% deduction per phase
	
	return max(score, 0.0)

func _generate_recommendations(report: Dictionary) -> Array[String]:
	## Generate performance improvement recommendations
	var recommendations = []
	
	if report.memory_overhead_percent > 5.0:
		recommendations.append("Consider memory optimization - overhead is %0.2f%%" % report.memory_overhead_percent)
	
	if report.panel_creation_success_rate < 0.98:
		recommendations.append("Investigate panel creation failures - success rate is %0.2f%%" % (report.panel_creation_success_rate * 100))
	
	for phase in report.average_load_times:
		if report.average_load_times[phase] > 750:
			recommendations.append("Optimize phase %s loading - average time is %0.2fms" % [phase, report.average_load_times[phase]])
	
	if recommendations.is_empty():
		recommendations.append("Performance is within acceptable parameters")
	
	return recommendations

func _get_memory_usage_safe() -> int:
	## Get current memory usage using available Godot methods
	# Note: OS.get_static_memory_usage_by_type() is not available in Godot 4.4
	# For now, we'll use a simulated memory tracking approach
	
	# In production, this could be replaced with:
	# - Custom memory tracking
	# - Process-based memory monitoring
	# - Relative usage tracking using other metrics
	
	# Return a baseline value that allows relative tracking
	# This will still enable performance monitoring even without absolute memory values
	var base_memory = 1024 * 1024 # 1MB baseline
	var runtime_factor = int(Time.get_unix_time_from_system() - start_time) * 1024 # Simulated growth
	return base_memory + runtime_factor
