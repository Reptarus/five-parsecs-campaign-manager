@tool
extends Control
class_name WorldPhaseProgressDisplay

## World Phase Progress Display - Feature 10 Implementation
## Connects DataVisualization.gd backend with visual UI components
## Provides contextual information and real-time data updates for campaign progress

const DataVisualization = preload("res://src/ui/components/logbook/DataVisualization.gd")
const EnhancedCampaignSignals = preload("res://src/core/signals/EnhancedCampaignSignals.gd")
const BaseInformationCard = preload("res://src/base/ui/BaseInformationCard.gd")

# UI components
@onready var data_visualization: DataVisualization = %DataVisualization
@onready var progress_overview: Control = %ProgressOverview
@onready var chart_display: Control = %ChartDisplay
@onready var context_panel: Control = %ContextPanel
@onready var real_time_feed: Control = %RealTimeFeed

# Progress indicators
@onready var campaign_progress_bar: ProgressBar = %CampaignProgressBar
@onready var crew_efficiency_bar: ProgressBar = %CrewEfficiencyBar
@onready var resource_utilization_bar: ProgressBar = %ResourceUtilizationBar

# Context labels
@onready var current_phase_label: Label = %CurrentPhaseLabel
@onready var phase_duration_label: Label = %PhaseDurationLabel
@onready var next_milestone_label: Label = %NextMilestoneLabel
@onready var efficiency_rating_label: Label = %EfficiencyRatingLabel

# Real-time updates
@onready var recent_events_list: ItemList = %RecentEventsList
@onready var active_tasks_label: Label = %ActiveTasksLabel
@onready var credits_label: Label = %CreditsLabel
@onready var crew_status_label: Label = %CrewStatusLabel

# Chart selection
@onready var chart_type_selector: OptionButton = %ChartTypeSelector
@onready var time_range_selector: OptionButton = %TimeRangeSelector

# Data management
var campaign_data: Dictionary = {}
var historical_data: Array[Dictionary] = []
var real_time_metrics: Dictionary = {}
var update_timer: Timer
var enhanced_signals: EnhancedCampaignSignals

# Configuration
@export var update_interval: float = 2.0
@export var max_recent_events: int = 10
@export var enable_auto_refresh: bool = true
@export var show_predictions: bool = true

# Chart types
enum ChartType {
	CAMPAIGN_PROGRESS,
	CREW_EFFICIENCY,
	RESOURCE_TRENDS,
	MISSION_SUCCESS_RATE,
	CREDIT_HISTORY,
	PHASE_COMPARISON
}

signal chart_type_changed(chart_type: ChartType)
signal data_updated(metrics: Dictionary)
signal milestone_reached(milestone: Dictionary)
signal efficiency_alert(alert_type: String, data: Dictionary)

func _ready() -> void:
	_setup_progress_display()
	_setup_real_time_updates()
	_connect_enhanced_signals()

func _setup_progress_display() -> void:
	# Initialize data visualization component
	if data_visualization:
		data_visualization._setup_data_visualization()
	
	# Setup chart type selector
	if chart_type_selector:
		_populate_chart_selector()
		chart_type_selector.item_selected.connect(_on_chart_type_selected)
	
	# Setup time range selector
	if time_range_selector:
		_populate_time_range_selector()
		time_range_selector.item_selected.connect(_on_time_range_selected)
	
	# Initialize with default view
	_display_default_charts()

func _setup_real_time_updates() -> void:
	if enable_auto_refresh:
		update_timer = Timer.new()
		update_timer.wait_time = update_interval
		update_timer.timeout.connect(_on_update_timer_timeout)
		add_child(update_timer)
		update_timer.start()

func _connect_enhanced_signals() -> void:
	enhanced_signals = EnhancedCampaignSignals.new()
	
	# Connect to campaign progress signals
	enhanced_signals.connect_signal_safely("world_phase_progress_updated", self, "_on_phase_progress_updated")
	enhanced_signals.connect_signal_safely("crew_task_completed", self, "_on_crew_task_completed")
	enhanced_signals.connect_signal_safely("mission_completed", self, "_on_mission_completed")
	enhanced_signals.connect_signal_safely("credits_updated", self, "_on_credits_updated")
	enhanced_signals.connect_signal_safely("milestone_achieved", self, "_on_milestone_achieved")

## Main API functions
func update_campaign_data(new_data: Dictionary) -> void:
	campaign_data = new_data.duplicate(true)
	_refresh_all_displays()

func update_real_time_metrics(metrics: Dictionary) -> void:
	real_time_metrics = metrics.duplicate(true)
	_update_real_time_displays()
	data_updated.emit(metrics)

func add_historical_data_point(data: Dictionary) -> void:
	historical_data.append(data.duplicate(true))
	
	# Limit historical data size for performance
	if historical_data.size() > 100:
		historical_data.pop_front()
	
	# Update trend charts if data visualization is available
	# Note: _update_trend_charts() function not implemented yet

func display_chart_type(chart_type: ChartType) -> void:
	if not data_visualization:
		return
	
	match chart_type:
		ChartType.CAMPAIGN_PROGRESS:
			_display_campaign_progress_chart()
		ChartType.CREW_EFFICIENCY:
			_display_crew_efficiency_chart()
		ChartType.RESOURCE_TRENDS:
			_display_resource_trends_chart()
		ChartType.MISSION_SUCCESS_RATE:
			_display_mission_success_chart()
		ChartType.CREDIT_HISTORY:
			_display_credit_history_chart()
		ChartType.PHASE_COMPARISON:
			_display_phase_comparison_chart()

func get_current_efficiency_rating() -> String:
	var efficiency = real_time_metrics.get("crew_efficiency", 0.0)
	
	if efficiency >= 0.9:
		return "Excellent"
	elif efficiency >= 0.8:
		return "Very Good"
	elif efficiency >= 0.7:
		return "Good"
	elif efficiency >= 0.6:
		return "Average"
	elif efficiency >= 0.5:
		return "Below Average"
	else:
		return "Poor"

## Display update functions
func _refresh_all_displays() -> void:
	_update_progress_bars()
	_update_context_labels()
	_update_current_chart()
	_update_real_time_displays()

func _update_progress_bars() -> void:
	if not campaign_data.has("progress"):
		return
	
	var progress_data = campaign_data.get("progress", {})
	
	# Campaign progress
	if campaign_progress_bar:
		var campaign_progress = progress_data.get("campaign_completion", 0.0)
		campaign_progress_bar.value = campaign_progress * 100.0
		_apply_progress_bar_color(campaign_progress_bar, campaign_progress)
	
	# Crew efficiency
	if crew_efficiency_bar:
		var crew_efficiency = real_time_metrics.get("crew_efficiency", 0.0)
		crew_efficiency_bar.value = crew_efficiency * 100.0
		_apply_progress_bar_color(crew_efficiency_bar, crew_efficiency)
	
	# Resource utilization
	if resource_utilization_bar:
		var resource_utilization = real_time_metrics.get("resource_utilization", 0.0)
		resource_utilization_bar.value = resource_utilization * 100.0
		_apply_progress_bar_color(resource_utilization_bar, resource_utilization)

func _update_context_labels() -> void:
	# Current phase
	if current_phase_label:
		var current_phase = campaign_data.get("current_phase", "Unknown")
		current_phase_label.text = "Phase: " + current_phase
	
	# Phase duration
	if phase_duration_label:
		var duration = campaign_data.get("phase_duration", 0)
		phase_duration_label.text = "Duration: " + str(duration) + " turns"
	
	# Next milestone
	if next_milestone_label:
		var next_milestone = campaign_data.get("next_milestone", "None")
		next_milestone_label.text = "Next: " + next_milestone
	
	# Efficiency rating
	if efficiency_rating_label:
		var rating = get_current_efficiency_rating()
		efficiency_rating_label.text = "Efficiency: " + rating
		_apply_efficiency_color(efficiency_rating_label, rating)

func _update_real_time_displays() -> void:
	# Active tasks
	if active_tasks_label:
		var active_tasks = real_time_metrics.get("active_tasks", 0)
		active_tasks_label.text = "Active Tasks: " + str(active_tasks)
	
	# Credits
	if credits_label:
		var credits = real_time_metrics.get("credits", 0)
		credits_label.text = "Credits: " + str(credits)
	
	# Crew status
	if crew_status_label:
		var crew_health = real_time_metrics.get("crew_health_percentage", 100.0)
		crew_status_label.text = "Crew Health: " + str(int(crew_health)) + "%"
		_apply_health_color(crew_status_label, crew_health)

func _update_recent_events() -> void:
	if not recent_events_list:
		return
	
	recent_events_list.clear()
	
	var recent_events = real_time_metrics.get("recent_events", [])
	for event in recent_events:
		var event_text = str(event.get("description", "Unknown event"))
		recent_events_list.add_item(event_text)

## Chart display functions
func _display_campaign_progress_chart() -> void:
	if not data_visualization:
		return
	
	var progress_data = _generate_campaign_progress_data()
	data_visualization.display_trend_analysis(progress_data)

func _display_crew_efficiency_chart() -> void:
	if not data_visualization:
		return
	
	var efficiency_data = _generate_crew_efficiency_data()
	data_visualization.display_crew_analytics(efficiency_data)

func _display_resource_trends_chart() -> void:
	if not data_visualization:
		return
	
	var resource_data = _generate_resource_trends_data()
	data_visualization.display_trend_analysis(resource_data)

func _display_mission_success_chart() -> void:
	if not data_visualization:
		return
	
	var mission_data = _generate_mission_success_data()
	data_visualization.display_mission_analytics(mission_data)

func _display_credit_history_chart() -> void:
	if not data_visualization:
		return
	
	var credit_data = _generate_credit_history_data()
	data_visualization.display_credit_history(credit_data)

func _display_phase_comparison_chart() -> void:
	if not data_visualization:
		return
	
	var comparison_data = _generate_phase_comparison_data()
	data_visualization.display_summary_statistics(comparison_data)

## Data generation functions
func _generate_campaign_progress_data() -> Dictionary:
	var progress_points: Array[float] = []
	
	# Extract progress from historical data
	for data_point in historical_data:
		var progress = data_point.get("campaign_progress", 0.0)
		progress_points.append(progress)
	
	return {
		"campaign_progress": progress_points,
		"trend": "increasing" if progress_points.size() > 1 and progress_points[-1] > progress_points[0] else "stable"
	}

func _generate_crew_efficiency_data() -> Dictionary:
	var crew_data = {}
	
	# Generate data for each crew member
	var crew_members = campaign_data.get("crew_members", [])
	for crew_member in crew_members:
		crew_data[crew_member.get("name", "Unknown")] = {
			"performance_rating": crew_member.get("efficiency", 0.5),
			"health_ratio": crew_member.get("health_percentage", 100.0) / 100.0,
			"tasks_completed": crew_member.get("tasks_completed", 0)
		}
	
	return crew_data

func _generate_resource_trends_data() -> Dictionary:
	var trends = {}
	
	# Extract resource trends from historical data
	var credit_trend: Array[float] = []
	var equipment_trend: Array[float] = []
	
	for data_point in historical_data:
		credit_trend.append(data_point.get("credits", 0.0))
		equipment_trend.append(data_point.get("equipment_count", 0.0))
	
	trends["credits"] = credit_trend
	trends["equipment"] = equipment_trend
	
	return trends

func _generate_mission_success_data() -> Array:
	var mission_data: Array = []
	
	# Extract mission data from historical records
	for data_point in historical_data:
		var missions = data_point.get("missions", [])
		mission_data.append_array(missions)
	
	return mission_data

func _generate_credit_history_data() -> Array:
	var credit_history: Array = []
	
	for data_point in historical_data:
		credit_history.append(data_point.get("credits", 0))
	
	return credit_history

func _generate_phase_comparison_data() -> Dictionary:
	return {
		"total_missions": historical_data.size(),
		"success_rate": _calculate_overall_success_rate(),
		"overall_rating": _calculate_overall_rating(),
		"efficiency_trend": _calculate_efficiency_trend()
	}

## Utility functions
func _calculate_overall_success_rate() -> float:
	var total_missions = 0
	var successful_missions = 0
	
	for data_point in historical_data:
		var missions = data_point.get("missions", [])
		for mission in missions:
			total_missions += 1
			if mission.get("outcome") == "success":
				successful_missions += 1
	
	return float(successful_missions) / max(float(total_missions), 1.0)

func _calculate_overall_rating() -> float:
	if historical_data.is_empty():
		return 0.0
	
	var total_rating = 0.0
	for data_point in historical_data:
		total_rating += data_point.get("efficiency_rating", 0.0)
	
	return total_rating / float(historical_data.size())

func _calculate_efficiency_trend() -> String:
	if historical_data.size() < 2:
		return "stable"
	
	var early_efficiency = historical_data[0].get("crew_efficiency", 0.0)
	var recent_efficiency = historical_data[-1].get("crew_efficiency", 0.0)
	
	if recent_efficiency > early_efficiency * 1.1:
		return "improving"
	elif recent_efficiency < early_efficiency * 0.9:
		return "declining"
	else:
		return "stable"

func _apply_progress_bar_color(progress_bar: ProgressBar, value: float) -> void:
	if not progress_bar:
		return
	
	var color = BaseInformationCard.SUCCESS_COLOR
	if value < 0.3:
		color = BaseInformationCard.DANGER_COLOR
	elif value < 0.6:
		color = BaseInformationCard.WARNING_COLOR
	elif value < 0.8:
		color = BaseInformationCard.INFO_COLOR
	
	progress_bar.add_theme_color_override("fill", color)

func _apply_efficiency_color(label: Label, rating: String) -> void:
	if not label:
		return
	
	var color = BaseInformationCard.INFO_COLOR
	match rating:
		"Excellent", "Very Good":
			color = BaseInformationCard.SUCCESS_COLOR
		"Good", "Average":
			color = BaseInformationCard.INFO_COLOR
		"Below Average", "Poor":
			color = BaseInformationCard.WARNING_COLOR
	
	label.add_theme_color_override("font_color", color)

func _apply_health_color(label: Label, health: float) -> void:
	if not label:
		return
	
	var color = BaseInformationCard.SUCCESS_COLOR
	if health < 30.0:
		color = BaseInformationCard.DANGER_COLOR
	elif health < 60.0:
		color = BaseInformationCard.WARNING_COLOR
	elif health < 80.0:
		color = BaseInformationCard.INFO_COLOR
	
	label.add_theme_color_override("font_color", color)

func _populate_chart_selector() -> void:
	if not chart_type_selector:
		return
	
	chart_type_selector.clear()
	chart_type_selector.add_item("Campaign Progress")
	chart_type_selector.add_item("Crew Efficiency")
	chart_type_selector.add_item("Resource Trends")
	chart_type_selector.add_item("Mission Success Rate")
	chart_type_selector.add_item("Credit History")
	chart_type_selector.add_item("Phase Comparison")

func _populate_time_range_selector() -> void:
	if not time_range_selector:
		return
	
	time_range_selector.clear()
	time_range_selector.add_item("Last 10 Turns")
	time_range_selector.add_item("Last 25 Turns")
	time_range_selector.add_item("Last 50 Turns")
	time_range_selector.add_item("All Time")

func _display_default_charts() -> void:
	display_chart_type(ChartType.CAMPAIGN_PROGRESS)

func _update_current_chart() -> void:
	if chart_type_selector:
		var selected_index = chart_type_selector.selected
		display_chart_type(selected_index as ChartType)

## Signal handlers
func _on_chart_type_selected(index: int) -> void:
	display_chart_type(index as ChartType)
	chart_type_changed.emit(index as ChartType)

func _on_time_range_selected(index: int) -> void:
	# Update data filtering based on time range
	_update_current_chart()

func _on_update_timer_timeout() -> void:
	if enable_auto_refresh:
		_refresh_all_displays()
		_update_recent_events()

func _on_phase_progress_updated(progress: float) -> void:
	real_time_metrics["campaign_progress"] = progress
	_update_progress_bars()

func _on_crew_task_completed(crew_member: Dictionary, task: int, success: bool) -> void:
	var event = {
		"type": "crew_task",
		"description": crew_member.get("name", "Unknown") + " completed a task",
		"success": success,
		"timestamp": Time.get_ticks_msec()
	}
	
	var recent_events = real_time_metrics.get("recent_events", [])
	recent_events.append(event)
	
	# Limit recent events
	if recent_events.size() > max_recent_events:
		recent_events.pop_front()
	
	real_time_metrics["recent_events"] = recent_events
	_update_recent_events()

func _on_mission_completed(mission: Dictionary, success: bool) -> void:
	var event = {
		"type": "mission",
		"description": "Mission completed: " + mission.get("name", "Unknown"),
		"success": success,
		"timestamp": Time.get_ticks_msec()
	}
	
	var recent_events = real_time_metrics.get("recent_events", [])
	recent_events.append(event)
	real_time_metrics["recent_events"] = recent_events
	_update_recent_events()

func _on_credits_updated(new_credits: int) -> void:
	real_time_metrics["credits"] = new_credits
	_update_real_time_displays()

func _on_milestone_achieved(milestone: Dictionary) -> void:
	milestone_reached.emit(milestone)
	
	var event = {
		"type": "milestone",
		"description": "Milestone achieved: " + milestone.get("name", "Unknown"),
		"timestamp": Time.get_ticks_msec()
	}
	
	var recent_events = real_time_metrics.get("recent_events", [])
	recent_events.append(event)
	real_time_metrics["recent_events"] = recent_events
	_update_recent_events()

## Public API for external access
func get_current_metrics() -> Dictionary:
	return real_time_metrics

func get_historical_data() -> Array[Dictionary]:
	return historical_data

func set_auto_refresh(enabled: bool) -> void:
	enable_auto_refresh = enabled
	if update_timer:
		if enabled:
			update_timer.start()
		else:
			update_timer.stop()

func export_chart_data() -> Dictionary:
	return {
		"campaign_data": campaign_data,
		"historical_data": historical_data,
		"real_time_metrics": real_time_metrics,
		"timestamp": Time.get_ticks_msec()
	}