@tool
extends Control
class_name CampaignUI

# Dependencies
const CampaignResponsiveLayout := preload("res://src/ui/layouts/CampaignResponsiveLayout.gd")
const CampaignManager := preload("res://src/core/campaign/CampaignManager.gd")
const CampaignDashboard := preload("res://src/scenes/campaign/components/CampaignDashboard.tscn")
const CampaignPhaseUI := preload("res://src/scenes/campaign/components/CampaignPhaseUI.tscn")
const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")
const CampaignPhaseManager := preload("res://src/core/managers/CampaignPhaseManager.gd")
const FiveParsecsGameState := preload("res://src/core/state/GameState.gd")

# Child Nodes
@onready var dashboard_tab: TabBar = $MainContent/HBoxContainer/MainTabs/Dashboard
@onready var characters_tab: TabBar = $MainContent/HBoxContainer/MainTabs/Characters
@onready var resources_tab: TabBar = $MainContent/HBoxContainer/MainTabs/Resources
@onready var events_tab: TabBar = $MainContent/HBoxContainer/MainTabs/Events

@onready var resource_panel: Panel = $MainContent/HBoxContainer/Sidebar/ResourcePanel
@onready var action_panel: Panel = $MainContent/HBoxContainer/Sidebar/ActionPanel
@onready var phase_indicator: Control = $Header/PhaseIndicator
@onready var event_log: Control = $MainContent/HBoxContainer/MainTabs/Events/EventLog
@onready var phase_ui: Control = $MainContent/HBoxContainer/MainTabs/Phase/CampaignPhaseUI

# Components
var dashboard: CampaignDashboard

# Signals
signal phase_changed(new_phase: GameEnums.CampaignPhase)
signal resource_updated(resource_type: GameEnums.ResourceType, new_value: int)
signal event_occurred(event_data: Dictionary)

# Internal state
var _current_phase: GameEnums.CampaignPhase = GameEnums.CampaignPhase.SETUP
var _layout: CampaignResponsiveLayout
var _campaign_manager: GameCampaignManager
var _phase_manager: CampaignPhaseManager

func _ready() -> void:
	_initialize_layout()
	_setup_dashboard()
	_connect_signals()
	_setup_ui_components()
	_setup_phase_manager()

func _initialize_layout() -> void:
	_layout = CampaignResponsiveLayout.new()
	_layout.initialize(self)

func _setup_dashboard() -> void:
	dashboard = CampaignDashboard.instantiate()
	dashboard_tab.add_child(dashboard)
	
	# Connect dashboard signals
	dashboard.action_requested.connect(_on_dashboard_action_requested)
	dashboard.crew_management_requested.connect(_on_dashboard_crew_management_requested)
	dashboard.save_requested.connect(_on_dashboard_save_requested)
	dashboard.load_requested.connect(_on_dashboard_load_requested)
	dashboard.quit_requested.connect(_on_dashboard_quit_requested)

func _connect_signals() -> void:
	# Connect to campaign manager signals
	_campaign_manager = get_node("/root/CampaignManager") as GameCampaignManager
	if _campaign_manager:
		_campaign_manager.phase_changed.connect(_on_phase_changed)
		_campaign_manager.resource_updated.connect(_on_resource_updated)
		_campaign_manager.event_occurred.connect(_on_event_occurred)

func _setup_ui_components() -> void:
	_setup_tabs()
	_setup_resource_panel()
	_setup_action_panel()
	_setup_phase_indicator()
	_setup_phase_ui()

func _setup_phase_manager() -> void:
	if _campaign_manager and _campaign_manager.game_state:
		_phase_manager = CampaignPhaseManager.new(_campaign_manager.game_state, _campaign_manager)
		if phase_ui:
			phase_ui.initialize(_phase_manager)

func _setup_tabs() -> void:
	# Initialize tab content and controllers
	if events_tab:
		events_tab.text = "Events"

func _setup_resource_panel() -> void:
	# Initialize resource tracking and display
	if resource_panel:
		resource_panel.resource_clicked.connect(_on_resource_clicked)

func _setup_action_panel() -> void:
	# Setup available actions based on current phase
	if action_panel:
		action_panel.action_selected.connect(_on_action_selected)
		action_panel.action_executed.connect(_on_action_executed)

func _setup_phase_indicator() -> void:
	# Initialize phase tracking and visualization
	if phase_indicator:
		phase_indicator.phase_clicked.connect(_on_phase_clicked)

func _setup_phase_ui() -> void:
	if phase_ui:
		phase_ui.action_requested.connect(_on_phase_action_requested)

# Signal handlers
func _on_phase_changed(new_phase: GameEnums.CampaignPhase) -> void:
	_current_phase = new_phase
	_update_available_actions()
	_update_phase_indicator()
	
	if dashboard:
		dashboard.setup(_campaign_manager.gamestate)
	
	# Log phase change event
	_log_event({
		"id": "phase_change_%d" % Time.get_unix_time_from_system(),
		"title": "Phase Changed",
		"description": "Campaign phase changed to %s" % GameEnums.CampaignPhase.keys()[new_phase],
		"category": "campaign",
		"phase": new_phase
	})
	
	emit_signal("phase_changed", new_phase)

func _on_resource_updated(resource_type: GameEnums.ResourceType, new_value: int) -> void:
	_update_resource_display(resource_type, new_value)
	
	if dashboard:
		dashboard.setup(_campaign_manager.gamestate)
	
	# Log resource update event
	_log_event({
		"id": "resource_update_%d" % Time.get_unix_time_from_system(),
		"title": "%s Updated" % GameEnums.ResourceType.keys()[resource_type],
		"description": "%s changed to %d" % [GameEnums.ResourceType.keys()[resource_type], new_value],
		"category": "campaign",
		"resource": resource_type,
		"value": new_value
	})
	
	emit_signal("resource_updated", resource_type, new_value)

func _on_event_occurred(event_data: Dictionary) -> void:
	_log_event(event_data)
	emit_signal("event_occurred", event_data)

func _on_resource_clicked(resource_name: String, current_value: int) -> void:
	# Handle resource click (e.g., show resource details)
	pass

func _on_action_selected(action_name: String) -> void:
	# Handle action selection
	pass

func _on_action_executed(action_name: String, result: Dictionary) -> void:
	# Log action execution event
	_log_event({
		"id": "action_executed_%d" % Time.get_unix_time_from_system(),
		"title": "Action Executed",
		"description": "Executed action: %s" % action_name,
		"category": "campaign",
		"action": action_name,
		"result": result
	})

func _on_phase_clicked(phase_name: String) -> void:
	# Switch to phase tab when phase indicator is clicked
	if phase_ui:
		var phase_tab = phase_ui.get_parent()
		var tab_bar = phase_tab.get_parent()
		tab_bar.current_tab = tab_bar.get_tab_idx_from_control(phase_tab)

func _on_phase_action_requested(action_type: String) -> void:
	match action_type:
		"pay_upkeep":
			_phase_manager.handle_upkeep_payment()
		"skip_upkeep":
			_phase_manager.skip_upkeep()
		"assign_tasks":
			_phase_manager.handle_task_assignment()
		"view_market":
			_phase_manager.view_market()
		"check_factions":
			_phase_manager.check_factions()
		"start_travel":
			_phase_manager.start_travel()
		"check_invasion":
			_phase_manager.check_invasion()
		"flee_invasion":
			_phase_manager.flee_invasion()
		"view_jobs":
			_phase_manager.view_jobs()
		"check_patrons":
			_phase_manager.check_patrons()
		"skip_patrons":
			_phase_manager.skip_patrons()
		"setup_battle":
			_phase_manager.setup_battle()
		"start_battle":
			_phase_manager.start_battle()
		"retreat":
			_phase_manager.retreat_from_battle()
		"collect_rewards":
			_phase_manager.collect_rewards()
		"check_injuries":
			_phase_manager.check_injuries()
		"process_events":
			_phase_manager.process_events()
		"manage_crew":
			_phase_manager.manage_crew()
		"manage_equipment":
			_phase_manager.manage_equipment()
		"manage_resources":
			_phase_manager.manage_resources()
		"upgrade_ship":
			_phase_manager.upgrade_ship()
		"end_turn":
			_phase_manager.end_turn()

# Dashboard signal handlers
func _on_dashboard_action_requested(action_name: String) -> void:
	if action_name == "next_phase":
		_phase_manager.advance_phase()

func _on_dashboard_crew_management_requested() -> void:
	get_tree().change_scene_to_file("res://src/scenes/character/CrewManagement.tscn")

func _on_dashboard_save_requested() -> void:
	_campaign_manager.save_game()

func _on_dashboard_load_requested() -> void:
	get_tree().change_scene_to_file("res://src/scenes/ui/LoadGameScreen.tscn")

func _on_dashboard_quit_requested() -> void:
	get_tree().change_scene_to_file("res://src/scenes/ui/MainMenu.tscn")

# UI update methods
func _update_available_actions() -> void:
	# Update action panel based on current phase
	if action_panel:
		action_panel.set_phase(_current_phase)

func _update_phase_indicator() -> void:
	# Update phase visualization
	if phase_indicator:
		phase_indicator.set_phase_data(_current_phase)

func _update_resource_display(resource_type: GameEnums.ResourceType, new_value: int) -> void:
	# Update resource panel
	if resource_panel:
		resource_panel.update_resource(resource_type, new_value)

func _log_event(event_data: Dictionary) -> void:
	# Add event to log and update display
	if event_log:
		event_log.add_event(event_data)

# Public methods
func refresh_ui() -> void:
	_update_available_actions()
	_update_phase_indicator()
	if dashboard:
		dashboard.setup(_campaign_manager.gamestate)

func show_campaign_creation_dialog() -> void:
	# Show campaign creation dialog
	pass

func show_event_details(event_id: String) -> void:
	# Show detailed event information
	if event_log:
		events_tab.current_tab = events_tab.get_tab_idx_from_control(event_log)
		event_log.show_event_details(event_id)

func _on_setup_completed() -> void:
	# Change to campaign dashboard
	get_tree().change_scene_to_file("res://src/scenes/campaign/components/CampaignDashboard.tscn")

func _on_campaign_started() -> void:
	# Update UI and game state for campaign start
	get_tree().change_scene_to_file("res://src/scenes/campaign/components/CampaignDashboard.tscn")

func _on_victory_achieved(victory_type: GameEnums.CampaignVictoryType) -> void:
	# Handle campaign victory
	get_tree().change_scene_to_file("res://src/scenes/ui/VictoryScreen.tscn")

func _on_tutorial_completed(tutorial_type: String) -> void:
	# Handle tutorial completion
	if tutorial_type == "basic":
		get_tree().change_scene_to_file("res://src/scenes/campaign/components/CampaignDashboard.tscn")