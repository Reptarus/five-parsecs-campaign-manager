@tool
extends Control
class_name EnhancedCampaignDashboard

## Enhanced Campaign Dashboard - Integrates all new panels with enhanced functionality
## Enhances existing CampaignDashboard.gd with new panels following Digital Dice System visual patterns
## Provides comprehensive campaign management with responsive design

# Universal Safety patterns
const BaseInformationCard = preload("res://src/base/ui/BaseInformationCard.gd")
const EnhancedCampaignSignals = preload("res://src/core/signals/EnhancedCampaignSignals.gd")
const FPCM_CampaignResponsiveLayout = preload("res://src/ui/components/base/CampaignResponsiveLayout.gd")

# Enhanced panel classes
const EnhancedCrewPanel = preload("res://src/ui/screens/campaign/panels/EnhancedCrewPanel.gd")
const EnhancedShipPanel = preload("res://src/ui/screens/campaign/panels/EnhancedShipPanel.gd")
const QuestTrackerWidget = preload("res://src/ui/components/enhanced/QuestTrackerWidget.gd")
const WorldInfoPanel = preload("res://src/ui/screens/campaign/panels/WorldInfoPanel.gd")

# Enhanced panel references
@onready var enhanced_crew_panel: EnhancedCrewPanel = %EnhancedCrewPanel
@onready var enhanced_ship_panel: EnhancedShipPanel = %EnhancedShipPanel
@onready var quest_tracker: QuestTrackerWidget = %QuestTrackerWidget
@onready var world_info_panel: WorldInfoPanel = %WorldInfoPanel
@onready var campaign_summary: Label = %CampaignSummary
@onready var quick_actions_panel: Control = %QuickActionsPanel
@onready var performance_overview: Control = %PerformanceOverview

# Data management
var campaign_data: Dictionary = {}
var crew_data: Array[Dictionary] = []
var ship_data: Dictionary = {}
var quest_data: Array[Dictionary] = []
var world_data: Dictionary = {}

# Signal connections
var enhanced_signals: EnhancedCampaignSignals

func _ready() -> void:
	_setup_enhanced_dashboard()
	_connect_enhanced_signals()
	_apply_responsive_layout()

func _setup_enhanced_dashboard() -> void:
	# Initialize enhanced dashboard components
	_setup_enhanced_panels()
	_setup_quick_actions()
	_setup_performance_tracking()

func _connect_enhanced_signals() -> void:
	# Connect to enhanced campaign signals
	enhanced_signals = EnhancedCampaignSignals.new()
	
	# Connect dashboard-related signals
	enhanced_signals.connect_signal_safely("dashboard_panel_changed", self, "_on_dashboard_panel_changed")
	enhanced_signals.connect_signal_safely("quick_action_requested", self, "_on_quick_action_requested")
	enhanced_signals.connect_signal_safely("campaign_data_updated", self, "_on_campaign_data_updated")

func _apply_responsive_layout() -> void:
	# Apply responsive design patterns
	var viewport_size = get_viewport().get_visible_rect().size
	if viewport_size.x < viewport_size.y:
		_apply_portrait_layout()
	else:
		_apply_landscape_layout()

func _apply_portrait_layout() -> void:
	# Mobile-first compact layout
	_setup_mobile_layout()
	_optimize_for_touch_navigation()

func _apply_landscape_layout() -> void:
	# Desktop detailed layout
	_setup_desktop_layout()
	_optimize_for_mouse_navigation()

func _setup_mobile_layout() -> void:
	# Mobile: Stack panels vertically with compact spacing
	if enhanced_crew_panel:
		enhanced_crew_panel.custom_minimum_size.y = 200
	
	if enhanced_ship_panel:
		enhanced_ship_panel.custom_minimum_size.y = 150
	
	if quest_tracker:
		quest_tracker.custom_minimum_size.y = 150
	
	if world_info_panel:
		world_info_panel.custom_minimum_size.y = 200

func _setup_desktop_layout() -> void:
	# Desktop: Side-by-side panels with detailed information
	if enhanced_crew_panel:
		enhanced_crew_panel.custom_minimum_size.y = 300
	
	if enhanced_ship_panel:
		enhanced_ship_panel.custom_minimum_size.y = 250
	
	if quest_tracker:
		quest_tracker.custom_minimum_size.y = 250
	
	if world_info_panel:
		world_info_panel.custom_minimum_size.y = 300

func _optimize_for_touch_navigation() -> void:
	# Ensure minimum 44px touch targets
	var touch_target_size = Vector2(44, 44)
	
	# Apply touch-friendly sizing to interactive elements
	_setup_touch_targets(touch_target_size)

func _optimize_for_mouse_navigation() -> void:
	# Optimize for mouse interaction
	var mouse_target_size = Vector2(32, 32)
	
	# Apply mouse-friendly sizing to interactive elements
	_setup_mouse_targets(mouse_target_size)

func _setup_touch_targets(minimum_size: Vector2) -> void:
	# Setup touch-friendly target sizes for mobile
	pass

func _setup_mouse_targets(minimum_size: Vector2) -> void:
	# Setup mouse-friendly target sizes for desktop
	pass

## Main dashboard update function
func update_dashboard(campaign_data: Dictionary) -> void:
	self.campaign_data = campaign_data
	
	# Update all enhanced panels
	_update_enhanced_panels()
	
	# Update summary and performance data
	_update_campaign_summary()
	_update_performance_overview()

func _update_enhanced_panels() -> void:
	# Update crew panel
	if enhanced_crew_panel and campaign_data.has("crew"):
		enhanced_crew_panel.update_crew_display(campaign_data.get("crew", []))
	
	# Update ship panel
	if enhanced_ship_panel and campaign_data.has("ship"):
		enhanced_ship_panel.display_ship_status(campaign_data.get("ship", {}))
	
	# Update quest tracker
	if quest_tracker and campaign_data.has("quests"):
		quest_tracker.update_quest_display(campaign_data.get("quests", []))
	
	# Update world info panel
	if world_info_panel and campaign_data.has("current_world"):
		world_info_panel.update_world_display(campaign_data.get("current_world", "Unknown"))

func _update_campaign_summary() -> void:
	if not campaign_summary:
		return
	
	var crew_count = campaign_data.get("crew", []).size()
	var ship_hull = campaign_data.get("ship", {}).get("hull_current", 0)
	var ship_max_hull = campaign_data.get("ship", {}).get("hull_max", 100)
	var active_quests = campaign_data.get("quests", []).size()
	var current_world = campaign_data.get("current_world", "Unknown")
	
	# Update summary with contextual information
	campaign_summary.text = "Campaign: %d Crew | %d%% Hull | %d Quests | World: %s" % [
		crew_count,
		(ship_hull * 100) / ship_max_hull if ship_max_hull > 0 else 0,
		active_quests,
		current_world
	]

func _update_performance_overview() -> void:
	if not performance_overview:
		return
	
	# Update performance visualization
	var performance_data = _calculate_campaign_performance()
	performance_overview.update_performance_display(performance_data)

func _calculate_campaign_performance() -> Dictionary:
	var performance = {
		"crew_health": 0.0,
		"ship_condition": 0.0,
		"quest_progress": 0.0,
		"overall_rating": 0.0
	}
	
	# Calculate crew health average
	var crew_data = campaign_data.get("crew", [])
	var total_health = 0.0
	for crew_member in crew_data:
		total_health += crew_member.get("health_ratio", 1.0)
	performance.crew_health = total_health / crew_data.size() if crew_data.size() > 0 else 0.0
	
	# Calculate ship condition
	var ship_data = campaign_data.get("ship", {})
	var hull_current = ship_data.get("hull_current", 0)
	var hull_max = ship_data.get("hull_max", 100)
	performance.ship_condition = float(hull_current) / float(hull_max) if hull_max > 0 else 0.0
	
	# Calculate quest progress
	var quest_data = campaign_data.get("quests", [])
	var total_progress = 0.0
	for quest in quest_data:
		var progress = quest.get("progress", 0)
		var total_steps = quest.get("total_steps", 1)
		total_progress += float(progress) / float(total_steps) if total_steps > 0 else 0.0
	performance.quest_progress = total_progress / quest_data.size() if quest_data.size() > 0 else 0.0
	
	# Calculate overall rating
	performance.overall_rating = (
		performance.crew_health * 0.3 +
		performance.ship_condition * 0.3 +
		performance.quest_progress * 0.4
	)
	
	return performance

## Enhanced panel setup functions
func _setup_enhanced_panels() -> void:
	# Replace basic panels with enhanced versions
	_replace_crew_panel()
	_replace_ship_panel()
	_add_quest_tracker()
	_add_world_info_panel()

func _replace_crew_panel() -> void:
	# Replace basic crew panel with enhanced version
	if enhanced_crew_panel:
		enhanced_crew_panel.setup_with_safety_validation()

func _replace_ship_panel() -> void:
	# Replace basic ship panel with enhanced version
	if enhanced_ship_panel:
		enhanced_ship_panel.setup_with_safety_validation()

func _add_quest_tracker() -> void:
	# Add quest tracker widget
	if quest_tracker:
		quest_tracker.setup_with_safety_validation()

func _add_world_info_panel() -> void:
	# Add world info panel
	if world_info_panel:
		world_info_panel.setup_with_safety_validation()

func _setup_quick_actions() -> void:
	# Initialize quick actions panel
	if quick_actions_panel:
		_setup_quick_action_buttons()

func _setup_quick_action_buttons() -> void:
	# Setup quick action buttons following dice system patterns
	pass

func _setup_performance_tracking() -> void:
	# Initialize performance tracking system
	pass

## Signal handlers
func _on_dashboard_panel_changed(panel_type: String) -> void:
	# Handle panel changes
	match panel_type:
		"crew":
			if enhanced_crew_panel:
				enhanced_crew_panel.refresh_display()
		"ship":
			if enhanced_ship_panel:
				enhanced_ship_panel.refresh_display()
		"quests":
			if quest_tracker:
				quest_tracker.refresh_display()
		"world":
			if world_info_panel:
				world_info_panel.refresh_display()

func _on_quick_action_requested(action: String, context: Dictionary) -> void:
	# Handle quick action requests
	match action:
		"start_mission":
			enhanced_signals.emit_safe_signal("mission_started", [context])
		"repair_ship":
			enhanced_signals.emit_safe_signal("ship_repair_requested", [context])
		"heal_crew":
			enhanced_signals.emit_safe_signal("crew_healing_requested", [context])
		"trade":
			enhanced_signals.emit_safe_signal("trade_requested", [context])
		_:
			enhanced_signals.emit_safe_signal("quick_action_requested", [action, context])

func _on_campaign_data_updated(update_type: String, data: Dictionary) -> void:
	# Handle campaign data updates
	match update_type:
		"crew_updated":
			if enhanced_crew_panel:
				enhanced_crew_panel.update_crew_display(data.get("crew", []))
		"ship_updated":
			if enhanced_ship_panel:
				enhanced_ship_panel.display_ship_status(data.get("ship", {}))
		"quests_updated":
			if quest_tracker:
				quest_tracker.update_quest_display(data.get("quests", []))
		"world_updated":
			if world_info_panel:
				world_info_panel.update_world_display(data.get("current_world", "Unknown"))
	
	# Update overall dashboard
	update_dashboard(campaign_data)

## Public API for external access
func get_campaign_data() -> Dictionary:
	return campaign_data

func get_enhanced_crew_panel() -> EnhancedCrewPanel:
	return enhanced_crew_panel

func get_enhanced_ship_panel() -> EnhancedShipPanel:
	return enhanced_ship_panel

func get_quest_tracker() -> QuestTrackerWidget:
	return quest_tracker

func get_world_info_panel() -> WorldInfoPanel:
	return world_info_panel

func refresh_all_panels() -> void:
	update_dashboard(campaign_data)

## Integration with existing systems
func integrate_with_existing_systems() -> void:
	# Integrate with existing campaign systems
	_integrate_with_dice_system()
	_integrate_with_story_track()
	_integrate_with_battle_events()

func _integrate_with_dice_system() -> void:
	# Integrate with Digital Dice System
	enhanced_signals.connect_signal_safely("dice_system_integration", self, "_on_dice_result_for_dashboard")

func _integrate_with_story_track() -> void:
	# Integrate with Story Track System
	enhanced_signals.connect_signal_safely("story_track_updated", self, "_on_story_track_update")

func _integrate_with_battle_events() -> void:
	# Integrate with Battle Events System
	enhanced_signals.connect_signal_safely("battle_event_logged", self, "_on_battle_event_logged")

func _on_dice_result_for_dashboard(dice_result: int, context: String) -> void:
	# Handle dice results in dashboard context
	match context:
		"crew_healing":
			enhanced_crew_panel.refresh_display()
		"ship_repair":
			enhanced_ship_panel.refresh_display()
		"quest_progress":
			quest_tracker.refresh_display()

func _on_story_track_update(story_event: Dictionary) -> void:
	# Handle story track updates
	world_info_panel.refresh_display()

func _on_battle_event_logged(battle_data: Dictionary) -> void:
	# Handle battle event logging
	enhanced_crew_panel.refresh_display()
	enhanced_ship_panel.refresh_display()