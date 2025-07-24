@tool
extends Control
class_name DataVisualization

## Data Visualization Components - Visual charts and graphs for campaign data analysis
## Follows dice system visual feedback patterns and 60 FPS performance requirements
## Provides comprehensive data visualization for campaign insights

# Universal Safety patterns
const BaseInformationCard = preload("res://src/base/ui/BaseInformationCard.gd")
const EnhancedCampaignSignals = preload("res://src/core/signals/EnhancedCampaignSignals.gd")
const LogbookDataManager = preload("res://src/core/logbook/LogbookDataManager.gd")

# Visualization components
@onready var chart_container: Control = %ChartContainer
@onready var performance_container: Control = %PerformanceContainer
@onready var trend_container: Control = %TrendContainer
@onready var summary_container: Control = %SummaryContainer

# Data management
var logbook_data_manager: LogbookDataManager
var chart_data: Dictionary = {}
var performance_data: Dictionary = {}
var trend_data: Dictionary = {}
var animation_tween: Tween

# Signal connections
var enhanced_signals: EnhancedCampaignSignals

func _ready() -> void:
	_setup_data_visualization()
	_connect_enhanced_signals()
	_apply_responsive_layout()

func _setup_data_visualization() -> void:
	# Initialize data visualization components
	logbook_data_manager = LogbookDataManager.new()
	animation_tween = create_tween()
	
	# Setup visualization containers
	_setup_chart_components()
	_setup_performance_components()
	_setup_trend_components()

func _connect_enhanced_signals() -> void:
	# Connect to enhanced campaign signals
	enhanced_signals = EnhancedCampaignSignals.new()
	
	# Connect visualization-related signals
	enhanced_signals.connect_signal_safely("data_visualization_requested", self, "_on_visualization_requested")
	enhanced_signals.connect_signal_safely("performance_metric_recorded", self, "_on_performance_metric_recorded")
	enhanced_signals.connect_signal_safely("pattern_discovered", self, "_on_pattern_discovered")

func _apply_responsive_layout() -> void:
	# Apply responsive design patterns
	var viewport_size = get_viewport().get_visible_rect().size
	if viewport_size.x < viewport_size.y:
		_apply_portrait_layout()
	else:
		_apply_landscape_layout()

func _apply_portrait_layout() -> void:
	# Mobile-first compact layout
	if chart_container:
		chart_container.custom_minimum_size.y = 200
		chart_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	if performance_container:
		performance_container.custom_minimum_size.y = 150
		performance_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _apply_landscape_layout() -> void:
	# Desktop detailed layout
	if chart_container:
		chart_container.custom_minimum_size.y = 300
		chart_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	if performance_container:
		performance_container.custom_minimum_size.y = 250
		performance_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

## Main visualization functions
func display_credit_history(credit_data: Array) -> void:
	# Display credit tracking over time with line chart
	var chart = _create_line_chart()
	chart.add_data_series("Credits", credit_data, BaseInformationCard.SUCCESS_COLOR)
	chart.animate_appearance() # 60 FPS animation like dice system
	
	# Store chart data
	chart_data["credit_history"] = chart

func display_mission_analytics(mission_data: Array) -> void:
	# Display mission success rate by type with bar chart
	var success_rates = _calculate_success_rates(mission_data)
	var bar_chart = _create_bar_chart()
	bar_chart.display_with_color_coding(success_rates) # Use dice system colors
	
	# Store chart data
	chart_data["mission_analytics"] = bar_chart

func display_crew_analytics(crew_performance: Dictionary) -> void:
	# Show crew member performance over time with visual indicators
	for crew_member in crew_performance:
		var performance_card = _create_performance_card(crew_member)
		performance_container.add_child(performance_card)

func display_trend_analysis(trend_data: Dictionary) -> void:
	# Display trend analysis with trend indicators
	var trend_chart = _create_trend_chart()
	trend_chart.display_trends(trend_data)
	trend_chart.animate_appearance()
	
	# Store trend data
	trend_data = trend_data

func display_summary_statistics(summary_data: Dictionary) -> void:
	# Display summary statistics with visual indicators
	var summary_card = _create_summary_card(summary_data)
	summary_container.add_child(summary_card)

## Chart creation functions
func _create_line_chart() -> Control:
	# Create line chart component
	var line_chart = Control.new()
	line_chart.name = "LineChart"
	
	# Setup line chart properties
	line_chart.custom_minimum_size = Vector2(300, 200)
	
	# Add chart functionality
	line_chart.set_script(load("res://src/ui/components/logbook/LineChart.gd"))
	
	return line_chart

func _create_bar_chart() -> Control:
	# Create bar chart component
	var bar_chart = Control.new()
	bar_chart.name = "BarChart"
	
	# Setup bar chart properties
	bar_chart.custom_minimum_size = Vector2(300, 200)
	
	# Add chart functionality
	bar_chart.set_script(load("res://src/ui/components/logbook/BarChart.gd"))
	
	return bar_chart

func _create_trend_chart() -> Control:
	# Create trend chart component
	var trend_chart = Control.new()
	trend_chart.name = "TrendChart"
	
	# Setup trend chart properties
	trend_chart.custom_minimum_size = Vector2(300, 200)
	
	# Add chart functionality
	trend_chart.set_script(load("res://src/ui/components/logbook/TrendChart.gd"))
	
	return trend_chart

func _create_performance_card(crew_member: Dictionary) -> Control:
	# Create performance card following dice system design
	var performance_card = BaseInformationCard.new()
	
	# Setup with safety validation
	performance_card.setup_with_safety_validation(crew_member)
	
	# Apply visual styling
	_apply_performance_styling(performance_card, crew_member)
	
	# Set context information
	_set_performance_context(performance_card, crew_member)
	
	return performance_card

func _create_summary_card(summary_data: Dictionary) -> Control:
	# Create summary card following dice system design
	var summary_card = BaseInformationCard.new()
	
	# Setup with safety validation
	summary_card.setup_with_safety_validation(summary_data)
	
	# Apply visual styling
	_apply_summary_styling(summary_card, summary_data)
	
	# Set context information
	_set_summary_context(summary_card, summary_data)
	
	return summary_card

## Styling functions
func _apply_performance_styling(performance_card: Control, crew_member: Dictionary) -> void:
	# Apply color coding based on performance (dice system colors)
	var performance_rating = crew_member.get("performance_rating", 0.0)
	var health_ratio = crew_member.get("health_ratio", 1.0)
	
	if performance_rating >= 0.8 and health_ratio >= 0.8:
		performance_card.add_theme_color_override("font_color", BaseInformationCard.SUCCESS_COLOR)
	elif performance_rating >= 0.6 and health_ratio >= 0.6:
		performance_card.add_theme_color_override("font_color", BaseInformationCard.INFO_COLOR)
	elif performance_rating >= 0.4 and health_ratio >= 0.4:
		performance_card.add_theme_color_override("font_color", BaseInformationCard.WARNING_COLOR)
	else:
		performance_card.add_theme_color_override("font_color", BaseInformationCard.DANGER_COLOR)

func _apply_summary_styling(summary_card: Control, summary_data: Dictionary) -> void:
	# Apply color coding based on summary metrics (dice system colors)
	var overall_rating = summary_data.get("overall_rating", 0.0)
	
	if overall_rating >= 0.8:
		summary_card.add_theme_color_override("font_color", BaseInformationCard.SUCCESS_COLOR)
	elif overall_rating >= 0.6:
		summary_card.add_theme_color_override("font_color", BaseInformationCard.INFO_COLOR)
	elif overall_rating >= 0.4:
		summary_card.add_theme_color_override("font_color", BaseInformationCard.WARNING_COLOR)
	else:
		summary_card.add_theme_color_override("font_color", BaseInformationCard.DANGER_COLOR)

func _set_performance_context(performance_card: Control, crew_member: Dictionary) -> void:
	# Set contextual information for performance card
	var crew_name = crew_member.get("name", "Unknown")
	var performance_rating = crew_member.get("performance_rating", 0.0)
	var health_ratio = crew_member.get("health_ratio", 1.0)
	
	performance_card.set_context_label("Crew: %s | Performance: %.1f%% | Health: %.1f%%" % [
		crew_name,
		performance_rating * 100,
		health_ratio * 100
	])

func _set_summary_context(summary_card: Control, summary_data: Dictionary) -> void:
	# Set contextual information for summary card
	var total_missions = summary_data.get("total_missions", 0)
	var success_rate = summary_data.get("success_rate", 0.0)
	var overall_rating = summary_data.get("overall_rating", 0.0)
	
	summary_card.set_context_label("Summary: %d Missions | %.1f%% Success | %.1f%% Overall" % [
		total_missions,
		success_rate * 100,
		overall_rating * 100
	])

## Data processing functions
func _calculate_success_rates(mission_data: Array) -> Dictionary:
	# Calculate success rates by mission type
	var success_rates: Dictionary = {}
	var mission_type_counts: Dictionary = {}
	var mission_type_successes: Dictionary = {}
	
	for mission in mission_data:
		var mission_type = mission.get("mission_type", "unknown")
		
		if not mission_type_counts.has(mission_type):
			mission_type_counts[mission_type] = 0
			mission_type_successes[mission_type] = 0
		
		mission_type_counts[mission_type] += 1
		
		if mission.get("outcome") == "success":
			mission_type_successes[mission_type] += 1
	
	# Calculate success rates
	for mission_type in mission_type_counts.keys():
		var total = mission_type_counts[mission_type]
		var successes = mission_type_successes[mission_type]
		success_rates[mission_type] = float(successes) / float(total) if total > 0 else 0.0
	
	return success_rates

## Animation functions
func animate_chart_appearance(chart: Control) -> void:
	# Animate chart appearance with 60 FPS performance
	if not animation_tween:
		return
	
	# Start with zero scale
	chart.scale = Vector2.ZERO
	
	# Animate to full scale
	animation_tween.tween_property(chart, "scale", Vector2.ONE, 0.3)
	animation_tween.tween_callback(chart.animate_data_points)

func animate_data_points(chart: Control) -> void:
	# Animate data points appearing
	if not animation_tween:
		return
	
	# Animate each data point with staggered timing
	var data_points = chart.get_data_points()
	for i in range(data_points.size()):
		var point = data_points[i]
		animation_tween.tween_property(point, "modulate:a", 1.0, 0.1).set_delay(i * 0.05)

## Setup functions
func _setup_chart_components() -> void:
	# Setup chart container components
	if chart_container:
		_setup_chart_buttons()

func _setup_chart_buttons() -> void:
	# Setup chart type selection buttons
	var chart_types = ["line", "bar", "pie", "trend"]
	
	for chart_type in chart_types:
		var chart_button = Button.new()
		chart_button.text = chart_type.capitalize()
		chart_button.custom_minimum_size = Vector2(60, 44) # Touch-friendly
		chart_button.pressed.connect(_on_chart_button_pressed.bind(chart_type))
		chart_container.add_child(chart_button)

func _setup_performance_components() -> void:
	# Setup performance visualization components
	if performance_container:
		_setup_performance_metrics()

func _setup_performance_metrics() -> void:
	# Setup performance metric displays
	pass

func _setup_trend_components() -> void:
	# Setup trend analysis components
	if trend_container:
		_setup_trend_indicators()

func _setup_trend_indicators() -> void:
	# Setup trend indicator displays
	pass

## Signal handlers
func _on_visualization_requested(chart_type: String, data: Variant) -> void:
	# Handle visualization requests
	match chart_type:
		"credit_history":
			if data is Array:
				display_credit_history(data)
		"mission_analytics":
			if data is Array:
				display_mission_analytics(data)
		"crew_analytics":
			if data is Dictionary:
				display_crew_analytics(data)
		"trend_analysis":
			if data is Dictionary:
				display_trend_analysis(data)
		"summary_statistics":
			if data is Dictionary:
				display_summary_statistics(data)

func _on_performance_metric_recorded(metric: String, value: float) -> void:
	# Handle performance metric recording
	_update_performance_display(metric, value)

func _on_pattern_discovered(pattern_type: String, confidence: float) -> void:
	# Handle pattern discovery for visualization
	_highlight_pattern_in_charts(pattern_type, confidence)

func _on_chart_button_pressed(chart_type: String) -> void:
	# Handle chart type selection
	_switch_chart_type(chart_type)

## Helper functions
func _update_performance_display(metric: String, value: float) -> void:
	# Update performance display with new metric
	if performance_container:
		var metric_label = Label.new()
		metric_label.text = "%s: %.2f" % [metric, value]
		metric_label.add_theme_color_override("font_color", BaseInformationCard.INFO_COLOR)
		performance_container.add_child(metric_label)

func _highlight_pattern_in_charts(pattern_type: String, confidence: float) -> void:
	# Highlight discovered patterns in charts
	for chart in chart_data.values():
		if chart.has_method("highlight_pattern"):
			chart.highlight_pattern(pattern_type, confidence)

func _switch_chart_type(chart_type: String) -> void:
	# Switch to different chart type
	match chart_type:
		"line":
			_display_line_chart()
		"bar":
			_display_bar_chart()
		"pie":
			_display_pie_chart()
		"trend":
			_display_trend_chart()

func _display_line_chart() -> void:
	# Display line chart
	pass

func _display_bar_chart() -> void:
	# Display bar chart
	pass

func _display_pie_chart() -> void:
	# Display pie chart
	pass

func _display_trend_chart() -> void:
	# Display trend chart
	pass

## Public API for external access
func get_chart_data() -> Dictionary:
	return chart_data

func get_performance_data() -> Dictionary:
	return performance_data

func get_trend_data() -> Dictionary:
	return trend_data

func refresh_visualizations() -> void:
	# Refresh all visualizations
	for chart in chart_data.values():
		if chart.has_method("refresh"):
			chart.refresh()
	
	# Update performance displays
	_update_performance_displays()
	
	# Update trend displays
	_update_trend_displays()

func _update_performance_displays() -> void:
	# Update performance displays
	pass

func _update_trend_displays() -> void:
	# Update trend displays
	pass