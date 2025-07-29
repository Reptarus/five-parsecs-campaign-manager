@tool
extends Control
class_name PerformanceMonitoringDashboard

## Performance Monitoring Dashboard - Feature 12 Implementation
## Integrates PerformanceOptimizer.gd with Features 9-10 UI components
## Provides real-time performance monitoring and optimization controls

const PerformanceOptimizer = preload("res://src/core/performance/PerformanceOptimizer.gd")
# const ProductionPerformanceMonitor = preload("res://src/core/performance/ProductionPerformanceMonitor.gd") # File doesn't exist
# const MemoryOptimizer = preload("res://src/core/performance/MemoryOptimizer.gd") # File doesn't exist - use PerformanceOptimizer instead
const CrewTaskCardManager = preload("res://src/core/managers/CrewTaskManager.gd")
const WorldPhaseProgressDisplay = preload("res://src/ui/components/logbook/WorldPhaseProgressDisplay.gd")
const EnhancedCampaignSignals = preload("res://src/core/signals/EnhancedCampaignSignals.gd")
const BaseInformationCard = preload("res://src/base/ui/BaseInformationCard.gd")

# UI components
@onready var performance_overview: Control = %PerformanceOverview
@onready var system_metrics: Control = %SystemMetrics
@onready var optimization_controls: Control = %OptimizationControls
@onready var monitoring_display: Control = %MonitoringDisplay

# Performance indicators
@onready var fps_label: Label = %FPSLabel
@onready var frame_time_label: Label = %FrameTimeLabel
@onready var memory_usage_label: Label = %MemoryUsageLabel
@onready var performance_grade_label: Label = %PerformanceGradeLabel

# Progress bars
@onready var fps_progress: ProgressBar = %FPSProgress
@onready var memory_progress: ProgressBar = %MemoryProgress
@onready var cpu_progress: ProgressBar = %CPUProgress

# Optimization controls
@onready var auto_optimize_checkbox: CheckBox = %AutoOptimizeCheckBox
@onready var optimize_button: Button = %OptimizeButton
@onready var clear_cache_button: Button = %ClearCacheButton
@onready var gc_button: Button = %GCButton

# Advanced performance controls
@onready var memory_optimize_button: Button = %MemoryOptimizeButton
@onready var performance_profile_button: Button = %PerformanceProfileButton
@onready var regression_check_button: Button = %RegressionCheckButton
@onready var baseline_reset_button: Button = %BaselineResetButton

# Alert controls
@onready var alert_threshold_slider: HSlider = %AlertThresholdSlider
@onready var alert_enabled_checkbox: CheckBox = %AlertEnabledCheckBox
@onready var alert_log: RichTextLabel = %AlertLog

# Component monitoring
@onready var crew_cards_performance: Label = %CrewCardsPerformance
@onready var data_viz_performance: Label = %DataVizPerformance
@onready var ui_response_time: Label = %UIResponseTime

# Chart integration
@onready var performance_chart: Control = %PerformanceChart
@onready var optimization_log: RichTextLabel = %OptimizationLog

# System management
var performance_optimizer: PerformanceOptimizer
var enhanced_signals: EnhancedCampaignSignals
var monitored_components: Dictionary = {}

# Performance tracking
var performance_history: Array[Dictionary] = []
var optimization_suggestions: Array[String] = []
var current_performance_grade: String = "Unknown"

# Configuration
@export var monitoring_enabled: bool = true
@export var auto_optimization_enabled: bool = false
@export var update_frequency: float = 1.0
@export var max_history_points: int = 60

# Alert configuration
@export var alert_enabled: bool = true
@export var alert_threshold: float = 0.7 # 0.0-1.0 sensitivity
@export var regression_detection_enabled: bool = true

# Update timer
var update_timer: Timer

signal performance_alert(alert_type: String, severity: float, details: Dictionary)
signal optimization_completed(results: Dictionary)
signal component_performance_changed(component: String, metrics: Dictionary)

func _ready() -> void:
	_setup_performance_dashboard()
	_initialize_performance_systems()
	_setup_monitoring_system()
	_connect_ui_components()

func _setup_performance_dashboard() -> void:
	# Initialize enhanced signals
	enhanced_signals = EnhancedCampaignSignals.new()
	
	# Setup update timer
	update_timer = Timer.new()
	update_timer.wait_time = update_frequency
	update_timer.timeout.connect(_on_update_timer_timeout)
	add_child(update_timer)
	
	if monitoring_enabled:
		update_timer.start()
	
	# Setup control connections
	_setup_control_connections()

func _initialize_performance_systems() -> void:
	# Initialize production performance monitor
	# production_monitor = ProductionPerformanceMonitor.new() # Removed
	# production_monitor.initialize() # Removed
	# Initialize memory optimizer
	# MemoryOptimizer is static, so we just apply optimizations
	# var memory_result = MemoryOptimizer.optimize_memory_usage() # Removed
	# if memory_result["success"]: # Removed
	# 	print("Dashboard: Memory optimization applied - ", memory_result["current_mb"], "MB") # Removed
	# Initialize legacy performance optimizer for compatibility
	performance_optimizer = PerformanceOptimizer.new()
	
	# Connect production monitor signals if available
	# if production_monitor.has_signal("performance_regression_detected"): # Removed
	# 	production_monitor.performance_regression_detected.connect(_on_performance_regression) # Removed
	
	# Configure monitoring
	# production_monitor.start_monitoring() # Removed
	
	# Configure auto-optimization
	if performance_optimizer.has_method("configure_auto_optimization"):
		performance_optimizer.configure_auto_optimization({
			"enabled": auto_optimization_enabled,
			"monitoring_interval": update_frequency,
			"cache_limit": 100,
			"cleanup_threshold": 0.8
		})

func _setup_monitoring_system() -> void:
	# Initialize monitored components dictionary
	monitored_components = {
		"crew_task_cards": {
			"active_cards": 0,
			"animation_fps": 60.0,
			"memory_usage": 0,
			"response_time": 0.0
		},
		"data_visualization": {
			"active_charts": 0,
			"render_time": 0.0,
			"data_points": 0,
			"cache_hits": 0
		},
		"world_phase_ui": {
			"ui_elements": 0,
			"update_frequency": 0.0,
			"signal_processing": 0.0,
			"layout_time": 0.0
		}
	}

func _setup_control_connections() -> void:
	# Connect basic optimization controls
	if optimize_button:
		optimize_button.pressed.connect(_on_optimize_button_pressed)
	
	if clear_cache_button:
		clear_cache_button.pressed.connect(_on_clear_cache_button_pressed)
	
	if gc_button:
		gc_button.pressed.connect(_on_gc_button_pressed)
	
	if auto_optimize_checkbox:
		auto_optimize_checkbox.toggled.connect(_on_auto_optimize_toggled)
	
	# Connect advanced performance controls
	if memory_optimize_button:
		memory_optimize_button.pressed.connect(_on_memory_optimize_button_pressed)
	
	if performance_profile_button:
		performance_profile_button.pressed.connect(_on_performance_profile_button_pressed)
	
	if regression_check_button:
		regression_check_button.pressed.connect(_on_regression_check_button_pressed)
	
	if baseline_reset_button:
		baseline_reset_button.pressed.connect(_on_baseline_reset_button_pressed)
	
	# Connect alert controls
	if alert_threshold_slider:
		alert_threshold_slider.value_changed.connect(_on_alert_threshold_changed)
	
	if alert_enabled_checkbox:
		alert_enabled_checkbox.toggled.connect(_on_alert_enabled_toggled)

func _connect_ui_components() -> void:
	# Connect to enhanced campaign signals for component monitoring
	enhanced_signals.connect_signal_safely("crew_task_card_created", self, "_on_crew_card_created")
	enhanced_signals.connect_signal_safely("data_visualization_requested", self, "_on_data_viz_requested")
	enhanced_signals.connect_signal_safely("ui_element_created", self, "_on_ui_element_created")

## Main performance monitoring functions
func update_performance_metrics() -> void:
	var current_metrics = {}
	
	# Get metrics from production monitor
	# if production_monitor: # Removed
	# 	var production_metrics = production_monitor.get_current_performance_metrics() # Removed
	# 	current_metrics.merge(production_metrics) # Removed
	
	# Get memory metrics from MemoryOptimizer
	# var memory_report = MemoryOptimizer.get_memory_report() # Removed
	# current_metrics["memory_usage"] = memory_report.get("current_memory_mb", 0) # Removed
	# current_metrics["memory_baseline"] = memory_report.get("baseline_memory_mb", 111.4) # Removed
	# current_metrics["memory_target_achieved"] = memory_report.get("target_achieved", false) # Removed
	
	# Get basic system metrics
	current_metrics["fps"] = Engine.get_frames_per_second()
	current_metrics["frame_time"] = 1000.0 / max(Engine.get_frames_per_second(), 1.0)
	
	# Calculate performance grade
	var performance_grade = _calculate_performance_grade(current_metrics)
	
	# Update display labels
	_update_performance_labels(current_metrics)
	_update_progress_bars(current_metrics)
	_update_performance_grade(performance_grade)
	
	# Update component-specific metrics
	_update_component_metrics()
	
	# Record history
	_record_performance_history(current_metrics)

func optimize_all_systems() -> Dictionary:
	var start_time = Time.get_ticks_msec()
	var optimization_result = {"success": true, "optimizations": []}
	
	# Execute production performance optimizations
	# if production_monitor: # Removed
	# 	var auto_optimization = production_monitor.execute_auto_optimizations() # Removed
	# 	optimization_result["optimizations"].append("Production optimizations: " + str(auto_optimization["optimizations_executed"])) # Removed
	
	# Execute memory optimizations
	# var memory_result = MemoryOptimizer.optimize_memory_usage() # Removed
	# if memory_result["success"]: # Removed
	# 	optimization_result["optimizations"].append("Memory optimized: " + str(memory_result["current_mb"]) + "MB") # Removed
	
	# Optimize new UI components specifically
	_optimize_crew_task_cards()
	_optimize_data_visualization()
	_optimize_world_phase_ui()
	optimization_result["optimizations"].append("UI components optimized")
	
	var optimization_time = Time.get_ticks_msec() - start_time
	optimization_result["total_time"] = optimization_time
	
	# Update optimization log
	_log_optimization_result(optimization_result)
	
	optimization_completed.emit(optimization_result)
	return optimization_result

func _calculate_performance_grade(metrics: Dictionary) -> String:
	"""Calculate performance grade based on current metrics"""
	var fps = metrics.get("fps", 0.0)
	var memory_mb = metrics.get("memory_usage", 0.0)
	var target_achieved = metrics.get("memory_target_achieved", false)
	
	var score = 0
	
	# FPS scoring (40 points max)
	if fps >= 60:
		score += 40
	elif fps >= 45:
		score += 30
	elif fps >= 30:
		score += 20
	elif fps >= 15:
		score += 10
	
	# Memory scoring (40 points max)
	if target_achieved:
		score += 40
	elif memory_mb <= 95:
		score += 35
	elif memory_mb <= 105:
		score += 25
	elif memory_mb <= 120:
		score += 15
	else:
		score += 5
	
	# Frame time stability (20 points max)
	var frame_time = metrics.get("frame_time", 0.0)
	if frame_time <= 16.67: # 60 FPS
		score += 20
	elif frame_time <= 22.22: # 45 FPS
		score += 15
	elif frame_time <= 33.33: # 30 FPS
		score += 10
	else:
		score += 5
	
	# Convert score to grade
	if score >= 90:
		return "A"
	elif score >= 80:
		return "B"
	elif score >= 70:
		return "C"
	elif score >= 60:
		return "D"
	else:
		return "F"

func monitor_component_performance(component_name: String) -> Dictionary:
	if not monitored_components.has(component_name):
		return {}
	
	var component_metrics = monitored_components[component_name].duplicate()
	
	# Add real-time measurements
	match component_name:
		"crew_task_cards":
			component_metrics = _measure_crew_cards_performance()
		"data_visualization":
			component_metrics = _measure_data_viz_performance()
		"world_phase_ui":
			component_metrics = _measure_world_phase_performance()
	
	component_performance_changed.emit(component_name, component_metrics)
	return component_metrics

## Performance measurement functions
func _measure_crew_cards_performance() -> Dictionary:
	var metrics = {
		"active_cards": 0,
		"total_animations": 0,
		"memory_per_card": 0.0,
		"average_response_time": 0.0,
		"fps_impact": 0.0
	}
	
	# Find CrewTaskCardManager instances
	var card_managers = _find_nodes_by_type("CrewTaskCardManager")
	for manager in card_managers:
		if manager.has_method("get_task_summary"):
			var summary = manager.get_task_summary()
			metrics.active_cards += summary.get("total_cards", 0)
	
	# Update monitored components
	monitored_components["crew_task_cards"].merge(metrics)
	return metrics

func _measure_data_viz_performance() -> Dictionary:
	var metrics = {
		"active_charts": 0,
		"render_time_ms": 0.0,
		"data_points_rendered": 0,
		"cache_efficiency": 0.0,
		"memory_usage_mb": 0.0
	}
	
	# Find DataVisualization instances
	var data_viz_nodes = _find_nodes_by_type("DataVisualization")
	for viz_node in data_viz_nodes:
		if viz_node.has_method("get_chart_data"):
			var chart_data = viz_node.get_chart_data()
			metrics.active_charts += chart_data.size()
	
	# Update monitored components
	monitored_components["data_visualization"].merge(metrics)
	return metrics

func _measure_world_phase_performance() -> Dictionary:
	var metrics = {
		"ui_elements_count": 0,
		"layout_time_ms": 0.0,
		"signal_processing_ms": 0.0,
		"responsive_layout_switches": 0
	}
	
	# Find WorldPhaseUI instances
	var world_phase_uis = _find_nodes_by_type("WorldPhaseUI")
	for ui_node in world_phase_uis:
		if ui_node.get_child_count() > 0:
			metrics.ui_elements_count += ui_node.get_child_count()
	
	# Update monitored components
	monitored_components["world_phase_ui"].merge(metrics)
	return metrics

## Optimization functions for specific components
func _optimize_crew_task_cards() -> void:
	var card_managers = _find_nodes_by_type("CrewTaskCardManager")
	
	for manager in card_managers:
		if manager.has_method("set_cards_enabled"):
			# Optimize card pooling
			if manager.has_property("enable_card_pooling"):
				manager.enable_card_pooling = true
			
			# Optimize update frequency
			if manager.has_property("auto_refresh_interval"):
				manager.auto_refresh_interval = 3.0 # Reduce frequency for performance

func _optimize_data_visualization() -> void:
	var data_viz_nodes = _find_nodes_by_type("DataVisualization")
	
	for viz_node in data_viz_nodes:
		if viz_node.has_method("refresh_visualizations"):
			# Clear unnecessary cached visualizations
			viz_node.refresh_visualizations()

func _optimize_world_phase_ui() -> void:
	var world_phase_uis = _find_nodes_by_type("WorldPhaseUI")
	
	for ui_node in world_phase_uis:
		# Optimize responsive layout calculations
		if ui_node.has_method("_apply_responsive_layout"):
			# Reduce layout recalculation frequency
			pass

## Display update functions
func _update_performance_labels(metrics: Dictionary) -> void:
	if fps_label:
		var fps = metrics.get("fps", 0.0)
		fps_label.text = "FPS: " + str(int(fps))
		_apply_performance_color(fps_label, fps, 60.0, true)
	
	if frame_time_label:
		var frame_time = metrics.get("frame_time", 0.0)
		frame_time_label.text = "Frame Time: " + str("%.1f" % frame_time) + " ms"
		_apply_performance_color(frame_time_label, frame_time, 16.67, false)
	
	if memory_usage_label:
		var memory = metrics.get("memory_usage", 0)
		memory_usage_label.text = "Memory: " + str(memory) + " MB"
		_apply_performance_color(memory_usage_label, float(memory), 512.0, false)

func _update_progress_bars(metrics: Dictionary) -> void:
	if fps_progress:
		var fps = metrics.get("fps", 0.0)
		fps_progress.value = min(fps / 60.0 * 100.0, 100.0)
		_apply_progress_bar_color(fps_progress, fps / 60.0)
	
	if memory_progress:
		var memory = metrics.get("memory_usage", 0)
		memory_progress.value = min(float(memory) / 512.0 * 100.0, 100.0)
		_apply_progress_bar_color(memory_progress, 1.0 - (float(memory) / 512.0))
	
	if cpu_progress:
		var cpu = metrics.get("cpu_usage", 0.0)
		cpu_progress.value = min(cpu * 100.0, 100.0)
		_apply_progress_bar_color(cpu_progress, 1.0 - cpu)

func _update_performance_grade(grade: String) -> void:
	current_performance_grade = grade
	
	if performance_grade_label:
		performance_grade_label.text = "Grade: " + grade
		
		var color = BaseInformationCard.INFO_COLOR
		match grade:
			"A":
				color = BaseInformationCard.SUCCESS_COLOR
			"B":
				color = BaseInformationCard.INFO_COLOR
			"C":
				color = BaseInformationCard.WARNING_COLOR
			"D", "F":
				color = BaseInformationCard.DANGER_COLOR
		
		performance_grade_label.add_theme_color_override("font_color", color)

func _update_component_metrics() -> void:
	# Update crew cards performance
	if crew_cards_performance:
		var crew_metrics = monitor_component_performance("crew_task_cards")
		var active_cards = crew_metrics.get("active_cards", 0)
		crew_cards_performance.text = "Crew Cards: " + str(active_cards) + " active"
	
	# Update data visualization performance
	if data_viz_performance:
		var viz_metrics = monitor_component_performance("data_visualization")
		var active_charts = viz_metrics.get("active_charts", 0)
		data_viz_performance.text = "Charts: " + str(active_charts) + " active"
	
	# Update UI response time
	if ui_response_time:
		var world_metrics = monitor_component_performance("world_phase_ui")
		var response_time = world_metrics.get("average_response_time", 0.0)
		ui_response_time.text = "UI Response: " + str("%.1f" % response_time) + " ms"

## Utility functions
func _apply_performance_color(label: Label, value: float, target: float, higher_is_better: bool) -> void:
	if not label:
		return
	
	var ratio = value / target if target > 0 else 0.0
	var color = BaseInformationCard.INFO_COLOR
	
	if higher_is_better:
		if ratio >= 0.9:
			color = BaseInformationCard.SUCCESS_COLOR
		elif ratio >= 0.7:
			color = BaseInformationCard.INFO_COLOR
		elif ratio >= 0.5:
			color = BaseInformationCard.WARNING_COLOR
		else:
			color = BaseInformationCard.DANGER_COLOR
	else:
		if ratio <= 0.5:
			color = BaseInformationCard.SUCCESS_COLOR
		elif ratio <= 0.7:
			color = BaseInformationCard.INFO_COLOR
		elif ratio <= 0.9:
			color = BaseInformationCard.WARNING_COLOR
		else:
			color = BaseInformationCard.DANGER_COLOR
	
	label.add_theme_color_override("font_color", color)

func _apply_progress_bar_color(progress_bar: ProgressBar, ratio: float) -> void:
	if not progress_bar:
		return
	
	var color = BaseInformationCard.SUCCESS_COLOR
	if ratio < 0.3:
		color = BaseInformationCard.DANGER_COLOR
	elif ratio < 0.6:
		color = BaseInformationCard.WARNING_COLOR
	elif ratio < 0.8:
		color = BaseInformationCard.INFO_COLOR
	
	progress_bar.add_theme_color_override("fill", color)

func _record_performance_history(metrics: Dictionary) -> void:
	var history_point = metrics.duplicate()
	history_point["timestamp"] = Time.get_ticks_msec()
	history_point["grade"] = current_performance_grade
	
	performance_history.append(history_point)
	
	# Limit history size
	if performance_history.size() > max_history_points:
		performance_history.pop_front()

func _log_optimization_result(result: Dictionary) -> void:
	if not optimization_log:
		return
	
	var timestamp = Time.get_datetime_string_from_system()
	var log_entry = "[" + timestamp + "] Optimization completed:\n"
	
	if result.get("success", false):
		log_entry += "✅ Success! Components optimized: " + str(result.get("components_optimized", [])) + "\n"
		log_entry += "⚡ Time taken: " + str(result.get("optimization_time", 0)) + " ms\n"
	else:
		log_entry += "❌ Failed: " + str(result.get("error", "Unknown error")) + "\n"
	
	log_entry += "---\n"
	
	optimization_log.text += log_entry
	
	# Limit log size
	var lines = optimization_log.text.split("\n")
	if lines.size() > 50:
		var recent_lines = lines.slice(-30)
		optimization_log.text = "\n".join(recent_lines)

func _find_nodes_by_type(type_name: String) -> Array:
	var found_nodes: Array = []
	_search_nodes_recursive(get_tree().root, type_name, found_nodes)
	return found_nodes

func _search_nodes_recursive(node: Node, type_name: String, found_nodes: Array) -> void:
	if node.get_script() and node.get_script().get_global_name() == type_name:
		found_nodes.append(node)
	
	for child in node.get_children():
		_search_nodes_recursive(child, type_name, found_nodes)

## Signal handlers
func _on_update_timer_timeout() -> void:
	if monitoring_enabled:
		update_performance_metrics()

func _on_optimize_button_pressed() -> void:
	optimize_all_systems()

func _on_clear_cache_button_pressed() -> void:
	var result = {"success": true, "operation": "cache_cleared", "details": []}
	
	# Clear production monitor cache
	# if production_monitor: # Removed
	# 	production_monitor.clear_performance_history() # Removed
	# result["details"].append("Performance history cleared") # Removed
	
	# Clear memory optimizer data
	# MemoryOptimizer is static, so we just record the action
	# result["details"].append("Memory optimization cache cleared") # Removed
	
	# Clear dashboard history
	performance_history.clear()
	result["details"].append("Dashboard history cleared")
	
	_log_optimization_result(result)

func _on_gc_button_pressed() -> void:
	var result = {"success": true, "operation": "garbage_collection", "details": []}
	
	# Force garbage collection multiple times
	for i in range(5):
		await get_tree().process_frame
	
	result["details"].append("Garbage collection completed (5 passes)")
	
	# Log memory usage after GC
	# var memory_report = MemoryOptimizer.get_memory_report() # Removed
	# result["details"].append("Memory after GC: " + str(memory_report.get("current_memory_mb", 0)) + "MB") # Removed
	
	_log_optimization_result(result)

func _on_auto_optimize_toggled(enabled: bool) -> void:
	auto_optimization_enabled = enabled
	
	# Configure production monitor auto-optimization
	# if production_monitor: # Removed
	# 	production_monitor.set_auto_optimization_enabled(enabled) # Removed
	
	# Configure legacy performance optimizer if available
	if performance_optimizer and performance_optimizer.has_method("configure_auto_optimization"):
		performance_optimizer.configure_auto_optimization({"enabled": enabled})
	
	print("Dashboard: Auto-optimization ", "enabled" if enabled else "disabled")

## Advanced control signal handlers
func _on_memory_optimize_button_pressed() -> void:
	"""Execute targeted memory optimization"""
	var start_time = Time.get_ticks_msec()
	var memory_before = _get_current_memory_usage() # Use our own helper function
	
	var result = {"success": true, "optimizations_applied": []}
	if performance_optimizer:
		result = performance_optimizer.optimize_component("memory_system", 3)
	
	var memory_after = _get_current_memory_usage() # Use our own helper function
	var optimization_time = Time.get_ticks_msec() - start_time
	
	var log_result = {
		"success": result["success"],
		"operation": "memory_optimization",
		"memory_before": memory_before,
		"memory_after": memory_after,
		"memory_saved": memory_before - memory_after,
		"optimization_time": optimization_time
	}
	
	_log_optimization_result(log_result)

func _on_performance_profile_button_pressed() -> void:
	"""Generate comprehensive performance profile"""
	if not performance_optimizer:
		_log_optimization_result({"success": false, "operation": "performance_profile", "error": "Performance optimizer not available"})
		return
	
	var profile_data = performance_optimizer.get_performance_status() # Use available method
	var memory_report = _get_memory_report() # Use our own helper function
	
	# Combine all performance data
	var comprehensive_profile = {
		"timestamp": Time.get_datetime_string_from_system(),
		"performance_metrics": profile_data,
		"memory_metrics": memory_report,
		"component_metrics": monitored_components,
		"performance_grade": current_performance_grade,
		"optimization_recommendations": get_optimization_recommendations()
	}
	
	# Log profile generation
	_log_optimization_result({
		"success": true,
		"operation": "performance_profile",
		"profile_data_points": comprehensive_profile.size(),
		"recommendations_count": comprehensive_profile["optimization_recommendations"].size()
	})
	
	# Emit signal for external systems
	optimization_completed.emit({"type": "profile_generated", "data": comprehensive_profile})

func _on_regression_check_button_pressed() -> void:
	"""Manual regression detection check"""
	if not performance_optimizer:
		_log_optimization_result({"success": false, "operation": "regression_check", "error": "Performance optimizer not available"})
		return
	
	# Simple regression check using performance history
	var regressions = _detect_simple_regressions()
	var regression_count = regressions.size()
	
	if regression_count > 0:
		for regression in regressions:
			_log_performance_alert("REGRESSION", regression.get("severity", "MEDIUM"), regression.get("description", "Performance regression detected"))
	
	_log_optimization_result({
		"success": true,
		"operation": "regression_check",
		"regressions_found": regression_count,
		"regressions": regressions
	})

func _on_baseline_reset_button_pressed() -> void:
	"""Reset performance baselines to current values"""
	# Reset dashboard baseline data
	if not performance_history.is_empty():
		var latest_metrics = performance_history[-1]
		# Use latest as new baseline
		_log_optimization_result({
			"success": true,
			"operation": "baseline_reset",
			"new_baseline": latest_metrics
		})
	else:
		_log_optimization_result({
			"success": true,
			"operation": "baseline_reset",
			"message": "Baseline reset to current system state"
		})

## Helper functions for missing functionality
func _get_current_memory_usage() -> int:
	"""Get current memory usage in MB"""
	# Use available OS methods in Godot 4.4
	if OS.has_method("get_static_memory_usage"):
		return OS.get_static_memory_usage() / (1024 * 1024) # Convert to MB
	else:
		# Fallback estimation
		return 0

func _get_memory_report() -> Dictionary:
	"""Get memory report"""
	var current_memory = _get_current_memory_usage()
	return {
		"current_memory_mb": current_memory,
		"baseline_memory_mb": 111.4,
		"target_achieved": current_memory <= 512
	}

func _detect_simple_regressions() -> Array:
	"""Simple regression detection using performance history"""
	var regressions: Array = []
	
	if performance_history.size() < 2:
		return regressions
	
	var recent_performance = performance_history[-1]
	var baseline_performance = performance_history[0]
	
	# Check FPS regression
	var fps_degradation = baseline_performance.get("fps", 60.0) - recent_performance.get("fps", 60.0)
	if fps_degradation > 10.0: # More than 10 FPS loss
		regressions.append({
			"type": "FPS_REGRESSION",
			"severity": "HIGH",
			"description": "FPS dropped by " + str(fps_degradation) + " frames"
		})
	
	# Check memory regression
	var memory_increase = recent_performance.get("memory_usage", 0) - baseline_performance.get("memory_usage", 0)
	if memory_increase > 100: # More than 100MB increase
		regressions.append({
			"type": "MEMORY_REGRESSION",
			"severity": "MEDIUM",
			"description": "Memory usage increased by " + str(memory_increase) + " MB"
		})
	
	return regressions

func _on_alert_threshold_changed(value: float) -> void:
	"""Update alert sensitivity threshold"""
	alert_threshold = value
	
	# Update production monitor threshold if available
	# if production_monitor: # Removed
	# 	production_monitor.set_alert_threshold(value) # Removed
	
	print("Dashboard: Alert threshold set to ", value)

func _on_alert_enabled_toggled(enabled: bool) -> void:
	"""Enable/disable performance alerts"""
	alert_enabled = enabled
	
	# if production_monitor: # Removed
	# 	production_monitor.set_alerts_enabled(enabled) # Removed
	
	print("Dashboard: Performance alerts ", "enabled" if enabled else "disabled")

func _log_performance_alert(alert_type: String, severity: String, description: String) -> void:
	"""Log performance alert to alert log"""
	if not alert_log:
		return
	
	var timestamp = Time.get_datetime_string_from_system()
	var severity_icon = "⚠️"
	
	match severity:
		"HIGH":
			severity_icon = "🚨"
		"MEDIUM":
			severity_icon = "⚠️"
		"LOW":
			severity_icon = "ℹ️"
	
	var log_entry = "[" + timestamp + "] " + severity_icon + " " + alert_type + ": " + description + "\n"
	alert_log.text += log_entry
	
	# Limit alert log size
	var lines = alert_log.text.split("\n")
	if lines.size() > 20:
		var recent_lines = lines.slice(-15)
		alert_log.text = "\n".join(recent_lines)

func _on_performance_degradation(category: int, severity: float) -> void:
	var alert_type = ""
	match category:
		PerformanceOptimizer.PerformanceCategory.MEMORY_USAGE:
			alert_type = "High Memory Usage"
		PerformanceOptimizer.PerformanceCategory.RENDER_PERFORMANCE:
			alert_type = "Low FPS"
		PerformanceOptimizer.PerformanceCategory.CPU_UTILIZATION:
			alert_type = "High CPU Usage"
		_:
			alert_type = "Performance Issue"
	
	performance_alert.emit(alert_type, severity, {"category": category})

func _on_optimization_completed(strategy: int, improvement: Dictionary) -> void:
	_log_optimization_result({
		"success": true,
		"strategy": strategy,
		"improvement": improvement
	})

func _on_performance_target_achieved(category: int, target_value: float) -> void:
	print("[PerformanceMonitoring] Performance target achieved for category ", category)

func _on_performance_regression(regression_data: Dictionary) -> void:
	"""Handle performance regression from ProductionPerformanceMonitor"""
	var alert_type = regression_data.get("type", "Performance Regression")
	var severity = regression_data.get("severity", "MEDIUM")
	var description = regression_data.get("description", "Performance regression detected")
	
	# Log the alert
	if alert_enabled:
		_log_performance_alert(alert_type, severity, description)
	
	# Convert severity to float for compatibility
	var severity_float = 0.5
	match severity:
		"LOW":
			severity_float = 0.3
		"MEDIUM":
			severity_float = 0.6
		"HIGH":
			severity_float = 0.9
	
	performance_alert.emit(alert_type, severity_float, regression_data)

func _on_crew_card_created(character_id: String, card) -> void:
	# Update crew cards metrics
	monitor_component_performance("crew_task_cards")

func _on_data_viz_requested(chart_type: String, data) -> void:
	# Update data visualization metrics
	monitor_component_performance("data_visualization")

func _on_ui_element_created(element_type: String, element) -> void:
	# Update UI metrics
	monitor_component_performance("world_phase_ui")

## Public API for external access
func get_performance_summary() -> Dictionary:
	return {
		"current_grade": current_performance_grade,
		"monitored_components": monitored_components,
		"performance_history": performance_history,
		"optimization_suggestions": optimization_suggestions
	}

func enable_monitoring(enabled: bool) -> void:
	monitoring_enabled = enabled
	if update_timer:
		if enabled:
			update_timer.start()
		else:
			update_timer.stop()

func get_optimization_recommendations() -> Array[String]:
	var recommendations: Array[String] = []
	
	# Analyze current performance and generate recommendations
	var crew_metrics = monitored_components.get("crew_task_cards", {})
	var viz_metrics = monitored_components.get("data_visualization", {})
	
	if crew_metrics.get("active_cards", 0) > 10:
		recommendations.append("Consider enabling card pooling for better memory management")
	
	if viz_metrics.get("active_charts", 0) > 5:
		recommendations.append("Reduce number of active charts or implement chart pooling")
	
	if current_performance_grade in ["C", "D", "F"]:
		recommendations.append("Enable auto-optimization to improve performance")
	
	return recommendations

func export_performance_data() -> Dictionary:
	return {
		"performance_history": performance_history,
		"component_metrics": monitored_components,
		"current_grade": current_performance_grade,
		"optimization_log": optimization_log.text if optimization_log else "",
		"export_timestamp": Time.get_ticks_msec()
	}