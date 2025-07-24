@tool
extends Control
class_name CampaignManagementHub

## Campaign Management Hub - Final integration hub combining all enhanced dashboard and smart logbook features
## Follows proven integration patterns from successful existing systems
## Provides unified interface for campaign management with all enhanced features

# Universal Safety patterns
const BaseInformationCard = preload("res://src/base/ui/BaseInformationCard.gd")
const EnhancedCampaignSignals = preload("res://src/core/signals/EnhancedCampaignSignals.gd")
const FPCM_CampaignResponsiveLayout = preload("res://src/ui/components/base/CampaignResponsiveLayout.gd")
const EnhancedCampaignDashboard = preload("res://src/ui/screens/campaign/EnhancedCampaignDashboard.gd")
const SmartLogbook = preload("res://src/ui/components/logbook/SmartLogbook.gd")
const PredictiveAnalysis = preload("res://src/core/logbook/PredictiveAnalysis.gd")
const DataVisualization = preload("res://src/ui/components/logbook/DataVisualization.gd")

# Enhanced UI components
@onready var dashboard_container: Control = %DashboardContainer
@onready var logbook_container: Control = %LogbookContainer
@onready var visualization_container: Control = %VisualizationContainer
@onready var navigation_panel: Control = %NavigationPanel
@onready var status_bar: Control = %StatusBar

# Integration components
var enhanced_dashboard: EnhancedCampaignDashboard
var smart_logbook: SmartLogbook
var predictive_analysis: PredictiveAnalysis
var data_visualization: DataVisualization

# State management
var current_view: String = "dashboard"
var campaign_data: Dictionary = {}
var analysis_results: Dictionary = {}

# Signal connections
var enhanced_signals: EnhancedCampaignSignals

func _ready() -> void:
	_setup_campaign_management_hub()
	_connect_enhanced_signals()
	_apply_responsive_layout()
	_initialize_components()

func _setup_campaign_management_hub() -> void:
	# Initialize campaign management hub components
	enhanced_signals = EnhancedCampaignSignals.new()
	
	# Setup navigation
	_setup_navigation_system()
	_setup_status_bar()
	
	# Initialize analysis system
	predictive_analysis = PredictiveAnalysis.new()

func _connect_enhanced_signals() -> void:
	# Connect to enhanced campaign signals
	enhanced_signals.connect_signal_safely("dashboard_updated", self, "_on_dashboard_updated")
	enhanced_signals.connect_signal_safely("logbook_updated", self, "_on_logbook_updated")
	enhanced_signals.connect_signal_safely("visualization_requested", self, "_on_visualization_requested")
	enhanced_signals.connect_signal_safely("analysis_completed", self, "_on_analysis_completed")

func _apply_responsive_layout() -> void:
	# Apply responsive design patterns
	var viewport_size = get_viewport().get_visible_rect().size
	if viewport_size.x < viewport_size.y:
		_apply_portrait_layout()
	else:
		_apply_landscape_layout()

func _apply_portrait_layout() -> void:
	# Mobile-first compact layout
	if navigation_panel:
		navigation_panel.custom_minimum_size.y = 60
		navigation_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	if dashboard_container:
		dashboard_container.custom_minimum_size.y = 400
		dashboard_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	if logbook_container:
		logbook_container.custom_minimum_size.y = 300
		logbook_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _apply_landscape_layout() -> void:
	# Desktop detailed layout
	if navigation_panel:
		navigation_panel.custom_minimum_size.y = 50
		navigation_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	if dashboard_container:
		dashboard_container.custom_minimum_size.y = 500
		dashboard_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	if logbook_container:
		logbook_container.custom_minimum_size.y = 400
		logbook_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _initialize_components() -> void:
	# Initialize all enhanced components
	_initialize_enhanced_dashboard()
	_initialize_smart_logbook()
	_initialize_data_visualization()

func _initialize_enhanced_dashboard() -> void:
	# Initialize enhanced dashboard
	enhanced_dashboard = EnhancedCampaignDashboard.new()
	if dashboard_container:
		dashboard_container.add_child(enhanced_dashboard)
		enhanced_dashboard.setup_with_campaign_data(campaign_data)

func _initialize_smart_logbook() -> void:
	# Initialize smart logbook
	smart_logbook = SmartLogbook.new()
	if logbook_container:
		logbook_container.add_child(smart_logbook)
		smart_logbook.update_logbook_display()

func _initialize_data_visualization() -> void:
	# Initialize data visualization
	data_visualization = DataVisualization.new()
	if visualization_container:
		visualization_container.add_child(data_visualization)

## Main integration functions
func update_campaign_data(new_data: Dictionary) -> void:
	# Update campaign data across all components
	campaign_data = new_data
	
	# Update dashboard
	if enhanced_dashboard:
		enhanced_dashboard.update_campaign_display(campaign_data)
	
	# Update logbook
	if smart_logbook:
		smart_logbook.refresh_display()
	
	# Update visualizations
	if data_visualization:
		_generate_visualizations()
	
	# Run predictive analysis
	_run_predictive_analysis()

func switch_view(view_name: String) -> void:
	# Switch between different views
	current_view = view_name
	
	match view_name:
		"dashboard":
			_show_dashboard_view()
		"logbook":
			_show_logbook_view()
		"visualization":
			_show_visualization_view()
		"analysis":
			_show_analysis_view()
	
	# Update navigation state
	_update_navigation_state(view_name)
	
	# Emit view change signal
	enhanced_signals.emit_safe_signal("view_changed", [view_name])

func _show_dashboard_view() -> void:
	# Show enhanced dashboard view
	if dashboard_container:
		dashboard_container.visible = true
	if logbook_container:
		logbook_container.visible = false
	if visualization_container:
		visualization_container.visible = false

func _show_logbook_view() -> void:
	# Show smart logbook view
	if dashboard_container:
		dashboard_container.visible = false
	if logbook_container:
		logbook_container.visible = true
	if visualization_container:
		visualization_container.visible = false

func _show_visualization_view() -> void:
	# Show data visualization view
	if dashboard_container:
		dashboard_container.visible = false
	if logbook_container:
		logbook_container.visible = false
	if visualization_container:
		visualization_container.visible = true

func _show_analysis_view() -> void:
	# Show predictive analysis view
	if dashboard_container:
		dashboard_container.visible = false
	if logbook_container:
		logbook_container.visible = false
	if visualization_container:
		visualization_container.visible = true

## Analysis and prediction functions
func _run_predictive_analysis() -> void:
	# Run predictive analysis on current campaign data
	if not predictive_analysis:
		return
	
	# Analyze different aspects
	var trade_opportunities = predictive_analysis.analyze_trade_opportunities(campaign_data.get("current_world", ""))
	var patron_suggestions = predictive_analysis.suggest_patron_contacts(campaign_data.get("current_world", ""))
	var mission_risks = predictive_analysis.assess_mission_risks("general", campaign_data.get("crew_data", []))
	var crew_development = predictive_analysis.predict_crew_development_needs(campaign_data.get("crew_data", []))
	var ship_maintenance = predictive_analysis.predict_ship_maintenance_needs(campaign_data.get("ship_data", {}))
	var exploration_targets = predictive_analysis.suggest_world_exploration_targets(campaign_data.get("explored_worlds", []))
	
	# Store analysis results
	analysis_results = {
		"trade_opportunities": trade_opportunities,
		"patron_suggestions": patron_suggestions,
		"mission_risks": mission_risks,
		"crew_development": crew_development,
		"ship_maintenance": ship_maintenance,
		"exploration_targets": exploration_targets
	}
	
	# Update UI with analysis results
	_update_analysis_display()

func _update_analysis_display() -> void:
	# Update analysis display with results
	if enhanced_dashboard:
		enhanced_dashboard.update_analysis_results(analysis_results)
	
	# Emit analysis completed signal
	enhanced_signals.emit_safe_signal("analysis_completed", [analysis_results])

func _generate_visualizations() -> void:
	# Generate visualizations for current data
	if not data_visualization:
		return
	
	# Generate different chart types
	var credit_data = _extract_credit_history()
	var mission_data = _extract_mission_data()
	var crew_performance = _extract_crew_performance()
	var trend_data = _extract_trend_data()
	var summary_data = _extract_summary_data()
	
	# Display visualizations
	data_visualization.display_credit_history(credit_data)
	data_visualization.display_mission_analytics(mission_data)
	data_visualization.display_crew_analytics(crew_performance)
	data_visualization.display_trend_analysis(trend_data)
	data_visualization.display_summary_statistics(summary_data)

## Data extraction functions
func _extract_credit_history() -> Array:
	# Extract credit history for visualization
	var credit_history: Array = []
	var economic_data = campaign_data.get("economic_data", {})
	
	for timestamp in economic_data.keys():
		var entry = economic_data[timestamp]
		credit_history.append({
			"timestamp": timestamp,
			"credits": entry.get("credits", 0),
			"debt": entry.get("debt", 0)
		})
	
	return credit_history

func _extract_mission_data() -> Array:
	# Extract mission data for visualization
	var mission_data: Array = []
	var missions = campaign_data.get("mission_history", [])
	
	for mission in missions:
		mission_data.append({
			"mission_id": mission.get("mission_id", ""),
			"mission_type": mission.get("mission_type", ""),
			"outcome": mission.get("outcome", ""),
			"credits_earned": mission.get("credits_earned", 0)
		})
	
	return mission_data

func _extract_crew_performance() -> Dictionary:
	# Extract crew performance data for visualization
	var crew_performance: Dictionary = {}
	var crew_data = campaign_data.get("crew_data", [])
	
	for crew_member in crew_data:
		var crew_id = crew_member.get("id", "")
		crew_performance[crew_id] = {
			"name": crew_member.get("name", ""),
			"performance_rating": crew_member.get("performance_rating", 0.0),
			"health_ratio": crew_member.get("health_ratio", 1.0),
			"missions_completed": crew_member.get("missions_completed", 0)
		}
	
	return crew_performance

func _extract_trend_data() -> Dictionary:
	# Extract trend data for visualization
	var trend_data: Dictionary = {}
	
	# Calculate various trends
	trend_data["mission_success_rate"] = _calculate_success_rate()
	trend_data["economic_trend"] = _calculate_economic_trend()
	trend_data["crew_performance_trend"] = _calculate_crew_trend()
	
	return trend_data

func _extract_summary_data() -> Dictionary:
	# Extract summary data for visualization
	var summary_data: Dictionary = {}
	
	summary_data["total_missions"] = campaign_data.get("mission_history", []).size()
	summary_data["success_rate"] = _calculate_success_rate()
	summary_data["overall_rating"] = _calculate_overall_rating()
	summary_data["total_credits"] = campaign_data.get("total_credits", 0)
	summary_data["total_debt"] = campaign_data.get("total_debt", 0)
	
	return summary_data

## Calculation functions
func _calculate_success_rate() -> float:
	# Calculate overall mission success rate
	var missions = campaign_data.get("mission_history", [])
	var successful_missions = 0
	
	for mission in missions:
		if mission.get("outcome") == "success":
			successful_missions += 1
	
	return float(successful_missions) / float(missions.size()) if missions.size() > 0 else 0.0

func _calculate_economic_trend() -> String:
	# Calculate economic trend
	var economic_data = campaign_data.get("economic_data", {})
	var entries = economic_data.values()
	
	if entries.size() < 2:
		return "stable"
	
	var first_entry = entries[0]
	var last_entry = entries[-1]
	var credit_change = last_entry.get("credits", 0) - first_entry.get("credits", 0)
	
	if credit_change > 1000:
		return "improving"
	elif credit_change < -1000:
		return "declining"
	else:
		return "stable"

func _calculate_crew_trend() -> String:
	# Calculate crew performance trend
	var crew_data = campaign_data.get("crew_data", [])
	var total_performance = 0.0
	
	for crew_member in crew_data:
		total_performance += crew_member.get("performance_rating", 0.0)
	
	var avg_performance = total_performance / crew_data.size() if crew_data.size() > 0 else 0.0
	
	if avg_performance > 0.7:
		return "improving"
	elif avg_performance < 0.4:
		return "declining"
	else:
		return "stable"

func _calculate_overall_rating() -> float:
	# Calculate overall campaign rating
	var success_rate = _calculate_success_rate()
	var economic_health = _calculate_economic_health()
	var crew_health = _calculate_crew_health()
	
	return (success_rate + economic_health + crew_health) / 3.0

func _calculate_economic_health() -> float:
	# Calculate economic health score
	var total_credits = campaign_data.get("total_credits", 0)
	var total_debt = campaign_data.get("total_debt", 0)
	
	if total_debt == 0:
		return 1.0
	
	var debt_ratio = float(total_debt) / float(total_credits + total_debt)
	return 1.0 - debt_ratio

func _calculate_crew_health() -> float:
	# Calculate crew health score
	var crew_data = campaign_data.get("crew_data", [])
	var total_health = 0.0
	
	for crew_member in crew_data:
		total_health += crew_member.get("health_ratio", 1.0)
	
	return total_health / crew_data.size() if crew_data.size() > 0 else 1.0

## Navigation functions
func _setup_navigation_system() -> void:
	# Setup navigation system
	if navigation_panel:
		_setup_navigation_buttons()

func _setup_navigation_buttons() -> void:
	# Setup navigation buttons following touch-friendly patterns
	var view_types = ["dashboard", "logbook", "visualization", "analysis"]
	
	for view_type in view_types:
		var nav_button = Button.new()
		nav_button.text = view_type.capitalize()
		nav_button.custom_minimum_size = Vector2(80, 44) # Touch-friendly
		nav_button.pressed.connect(_on_navigation_button_pressed.bind(view_type))
		navigation_panel.add_child(nav_button)

func _on_navigation_button_pressed(view_type: String) -> void:
	# Handle navigation button presses
	switch_view(view_type)

func _update_navigation_state(active_view: String) -> void:
	# Update navigation button states
	if not navigation_panel:
		return
	
	for child in navigation_panel.get_children():
		if child is Button:
			var button = child as Button
			if button.text.to_lower() == active_view:
				button.add_theme_color_override("font_color", BaseInformationCard.SUCCESS_COLOR)
			else:
				button.add_theme_color_override("font_color", BaseInformationCard.NEUTRAL_COLOR)

## Status bar functions
func _setup_status_bar() -> void:
	# Setup status bar
	if status_bar:
		_setup_status_indicators()

func _setup_status_indicators() -> void:
	# Setup status indicators
	pass

func update_status_bar(status_message: String, status_type: String = "info") -> void:
	# Update status bar with message
	if status_bar:
		var status_label = Label.new()
		status_label.text = status_message
		
		# Apply color coding based on status type
		match status_type:
			"success":
				status_label.add_theme_color_override("font_color", BaseInformationCard.SUCCESS_COLOR)
			"warning":
				status_label.add_theme_color_override("font_color", BaseInformationCard.WARNING_COLOR)
			"error":
				status_label.add_theme_color_override("font_color", BaseInformationCard.DANGER_COLOR)
			_:
				status_label.add_theme_color_override("font_color", BaseInformationCard.INFO_COLOR)
		
		status_bar.add_child(status_label)

## Signal handlers
func _on_dashboard_updated(dashboard_data: Dictionary) -> void:
	# Handle dashboard updates
	update_campaign_data(dashboard_data)

func _on_logbook_updated(logbook_data: Dictionary) -> void:
	# Handle logbook updates
	update_campaign_data(logbook_data)

func _on_visualization_requested(chart_type: String, data: Variant) -> void:
	# Handle visualization requests
	if data_visualization:
		data_visualization._on_visualization_requested(chart_type, data)

func _on_analysis_completed(analysis_data: Dictionary) -> void:
	# Handle analysis completion
	analysis_results = analysis_data
	update_status_bar("Analysis completed", "success")

## Public API for external access
func get_current_view() -> String:
	return current_view

func get_campaign_data() -> Dictionary:
	return campaign_data

func get_analysis_results() -> Dictionary:
	return analysis_results

func refresh_all_components() -> void:
	# Refresh all components
	if enhanced_dashboard:
		enhanced_dashboard.refresh_display()
	
	if smart_logbook:
		smart_logbook.refresh_display()
	
	if data_visualization:
		data_visualization.refresh_visualizations()
	
	# Run new analysis
	_run_predictive_analysis()