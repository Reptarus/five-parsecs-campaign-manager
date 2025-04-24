@tool
extends Control
# This file should be referenced via preload
# Use explicit preloads instead of global class names

const Self = preload("res://src/scenes/campaign/CampaignUI.gd")

# Dependencies
const FPCM_CampaignResponsiveLayout = preload("res://src/ui/components/base/CampaignResponsiveLayout.gd")
const CampaignManager = preload("res://src/core/managers/CampaignManager.gd")
const GameCampaignManager = preload("res://src/core/campaign/GameCampaignManager.gd")
const CampaignDashboard: PackedScene = preload("res://src/ui/screens/campaign/CampaignDashboard.tscn")
const CampaignPhaseUI: PackedScene = preload("res://src/scenes/campaign/components/CampaignPhaseUI.tscn")
const GameEnums = preload("res://src/core/enums/GameEnums.gd")
const CampaignPhaseManager = preload("res://src/core/campaign/CampaignPhaseManager.gd")
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")

# Child Nodes
@onready var dashboard_tab: TabBar = $MainContent/HBoxContainer/MainTabs/Dashboard if has_node("MainContent/HBoxContainer/MainTabs/Dashboard") else null
@onready var characters_tab: TabBar = $MainContent/HBoxContainer/MainTabs/Characters if has_node("MainContent/HBoxContainer/MainTabs/Characters") else null
@onready var resources_tab: TabBar = $MainContent/HBoxContainer/MainTabs/Resources if has_node("MainContent/HBoxContainer/MainTabs/Resources") else null
@onready var events_tab: TabBar = $MainContent/HBoxContainer/MainTabs/Events if has_node("MainContent/HBoxContainer/MainTabs/Events") else null

@onready var resource_panel: Panel = $MainContent/HBoxContainer/Sidebar/ResourcePanel if has_node("MainContent/HBoxContainer/Sidebar/ResourcePanel") else null
@onready var action_panel: Panel = $MainContent/HBoxContainer/Sidebar/ActionPanel if has_node("MainContent/HBoxContainer/Sidebar/ActionPanel") else null
@onready var phase_indicator: Control = $Header/PhaseIndicator if has_node("Header/PhaseIndicator") else null
@onready var event_log: Control = $MainContent/HBoxContainer/MainTabs/Events/EventLog if has_node("MainContent/HBoxContainer/MainTabs/Events/EventLog") else null
@onready var phase_ui: Control = $MainContent/HBoxContainer/MainTabs/Phase/CampaignPhaseUI if has_node("MainContent/HBoxContainer/MainTabs/Phase/CampaignPhaseUI") else null
# Components
var dashboard: Node # Using Node since CampaignDashboard is a scene

# Signals
signal phase_changed(new_phase: GameEnums.CampaignPhase)
signal resource_updated(resource_type: GameEnums.ResourceType, new_value: int)
signal event_occurred(event_data: Dictionary)

# Internal state
var _current_phase: GameEnums.CampaignPhase = GameEnums.CampaignPhase.SETUP
var _layout: FPCM_CampaignResponsiveLayout
var _campaign_manager: GameCampaignManager
var _phase_manager: CampaignPhaseManager

func _ready() -> void:
	if not is_inside_tree():
		return
		
	_initialize_layout()
	_setup_dashboard()
	_connect_signals()
	_setup_ui_components()
	_setup_phase_manager()

func _initialize_layout() -> void:
	_layout = FPCM_CampaignResponsiveLayout.new()
	if not _layout:
		push_warning("Failed to create CampaignResponsiveLayout")
		return
		
	_layout.initialize(self)

func _setup_dashboard() -> void:
	if not dashboard_tab:
		push_warning("Cannot setup dashboard: dashboard_tab is null")
		return
		
	var dashboard_instance = CampaignDashboard.instantiate()
	if not dashboard_instance:
		push_warning("Failed to instantiate CampaignDashboard")
		return
		
	dashboard = dashboard_instance
	dashboard_tab.add_child(dashboard)

func _connect_signals() -> void:
	if not _campaign_manager:
		return
		
	if _campaign_manager.has_signal("phase_changed") and not _campaign_manager.phase_changed.is_connected(_on_phase_changed):
		_campaign_manager.phase_changed.connect(_on_phase_changed)
		
	if _campaign_manager.has_signal("resource_updated") and not _campaign_manager.resource_updated.is_connected(_on_resource_updated):
		_campaign_manager.resource_updated.connect(_on_resource_updated)
		
	if _campaign_manager.has_signal("event_occurred") and not _campaign_manager.event_occurred.is_connected(_on_event_occurred):
		_campaign_manager.event_occurred.connect(_on_event_occurred)

func _setup_ui_components() -> void:
	# Setup resource panel
	_update_resource_display(GameEnums.ResourceType.CREDITS, 0)
	_update_resource_display(GameEnums.ResourceType.SUPPLIES, 0)
	_update_resource_display(GameEnums.ResourceType.REPUTATION, 0)
	_update_resource_display(GameEnums.ResourceType.TECH_PARTS, 0)

	# Setup phase indicator
	if phase_indicator and phase_indicator.has_method("initialize"):
		phase_indicator.initialize(_phase_manager)
	else:
		push_warning("Cannot initialize phase indicator: phase_indicator is null or missing initialize method")

	# Setup event log
	if event_log and event_log.has_method("clear"):
		event_log.clear()
	else:
		push_warning("Cannot clear event log: event_log is null or missing clear method")

func _setup_phase_manager() -> void:
	if not _phase_manager:
		push_warning("Cannot setup phase manager: _phase_manager is null")
		return
		
	if phase_ui and phase_ui.has_method("initialize"):
		phase_ui.initialize(_phase_manager)
	else:
		push_warning("Cannot initialize phase UI: phase_ui is null or missing initialize method")
		
	if _phase_manager.has_signal("phase_changed") and not _phase_manager.phase_changed.is_connected(_on_phase_changed):
		_phase_manager.phase_changed.connect(_on_phase_changed)

func _update_resource_display(resource_type: GameEnums.ResourceType, value: int) -> void:
	if not resource_panel:
		push_warning("Cannot update resource display: resource_panel is null")
		return
		
	var resource_name = GameEnums.ResourceType.keys()[resource_type]
	var resource_label = resource_panel.get_node_or_null(resource_name.to_lower() + "_label")
	if resource_label:
		resource_label.text = "%s: %d" % [resource_name.capitalize(), value]

func _log_event(event_data: Dictionary) -> void:
	if not event_log or not event_log.has_method("add_event"):
		push_warning("Cannot log event: event_log is null or missing add_event method")
		return
		
	event_log.add_event(event_data)

func _on_phase_changed(new_phase: GameEnums.CampaignPhase) -> void:
	_current_phase = new_phase
	
	# Update UI
	if phase_indicator and phase_indicator.has_method("set_phase"):
		phase_indicator.set_phase(new_phase)
	
	# Log phase change
	_log_event({
		"id": "phase_change_%d" % Time.get_unix_time_from_system(),
		"title": "Phase Changed",
		"description": "Campaign phase changed to %s" % GameEnums.CampaignPhase.keys()[new_phase],
		"category": "campaign",
		"phase": new_phase
	})
	
	phase_changed.emit(new_phase)

func _on_resource_updated(resource_type: GameEnums.ResourceType, new_value: int) -> void:
	_update_resource_display(resource_type, new_value)
	
	if dashboard and _campaign_manager and _campaign_manager.has("gamestate"):
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
	
	resource_updated.emit(resource_type, new_value)

func _on_event_occurred(event_data: Dictionary) -> void:
	_log_event(event_data)
	event_occurred.emit(event_data)

func _on_phase_action_requested(action_type: String) -> void:
	if action_type.is_empty():
		push_warning("Cannot handle action: action_type is empty")
		return
		
	match action_type:
		"create_crew":
			_handle_crew_creation()
		"select_campaign":
			_handle_campaign_selection()
		"start_campaign":
			_handle_campaign_start()
		"pay_upkeep":
			_handle_upkeep_payment()
		"manage_resources":
			_handle_resource_management()
		"check_crew":
			_handle_crew_status()
		"check_events":
			_handle_event_check()
		"view_story":
			_handle_story_progress()
		"resolve_events":
			_handle_event_resolution()
		"view_missions":
			_handle_mission_selection()
		"manage_crew":
			_handle_crew_management()
		"trade_equipment":
			_handle_equipment_trade()
		"setup_battlefield":
			_handle_battlefield_setup()
		"deploy_crew":
			_handle_crew_deployment()
		"start_battle":
			_handle_battle_start()
		"resolve_combat":
			_handle_combat_resolution()
		"check_casualties":
			_handle_casualty_check()
		"collect_rewards":
			_handle_reward_collection()
		"level_up":
			_handle_character_advancement()
		"update_equipment":
			_handle_equipment_update()
		"end_turn":
			_handle_turn_end()
		_:
			push_warning("Unknown action type: %s" % action_type)

# Action handlers
func _handle_crew_creation() -> void:
	if not get_tree():
		push_warning("Cannot handle crew creation: get_tree() returned null")
		return
		
	get_tree().change_scene_to_file("res://src/scenes/character/CrewCreation.tscn")

func _handle_campaign_selection() -> void:
	if not get_tree():
		push_warning("Cannot handle campaign selection: get_tree() returned null")
		return
		
	get_tree().change_scene_to_file("res://src/scenes/campaign/CampaignSelection.tscn")

func _handle_campaign_start() -> void:
	if not _phase_manager or not _phase_manager.has_method("advance_phase"):
		push_warning("Cannot handle campaign start: _phase_manager is null or missing advance_phase method")
		return
		
	_phase_manager.advance_phase()

func _handle_upkeep_payment() -> void:
	if not _campaign_manager or not _campaign_manager.has_method("process_upkeep"):
		push_warning("Cannot handle upkeep payment: _campaign_manager is null or missing process_upkeep method")
		return
		
	_campaign_manager.process_upkeep()

func _handle_resource_management() -> void:
	if not get_tree():
		push_warning("Cannot handle resource management: get_tree() returned null")
		return
		
	get_tree().change_scene_to_file("res://src/scenes/resource/ResourceManagement.tscn")

func _handle_crew_status() -> void:
	if not get_tree():
		push_warning("Cannot handle crew status: get_tree() returned null")
		return
		
	get_tree().change_scene_to_file("res://src/scenes/character/CrewStatus.tscn")

func _handle_event_check() -> void:
	if not _campaign_manager or not _campaign_manager.has_method("check_events"):
		push_warning("Cannot handle event check: _campaign_manager is null or missing check_events method")
		return
		
	_campaign_manager.check_events()

func _handle_story_progress() -> void:
	if not get_tree():
		push_warning("Cannot handle story progress: get_tree() returned null")
		return
		
	get_tree().change_scene_to_file("res://src/scenes/story/StoryProgress.tscn")

func _handle_event_resolution() -> void:
	if not _campaign_manager or not _campaign_manager.has_method("resolve_events"):
		push_warning("Cannot handle event resolution: _campaign_manager is null or missing resolve_events method")
		return
		
	_campaign_manager.resolve_events()

func _handle_mission_selection() -> void:
	if not get_tree():
		push_warning("Cannot handle mission selection: get_tree() returned null")
		return
		
	get_tree().change_scene_to_file("res://src/scenes/mission/MissionSelection.tscn")

func _handle_crew_management() -> void:
	if not get_tree():
		push_warning("Cannot handle crew management: get_tree() returned null")
		return
		
	get_tree().change_scene_to_file("res://src/scenes/character/CrewManagement.tscn")

func _handle_equipment_trade() -> void:
	if not get_tree():
		push_warning("Cannot handle equipment trade: get_tree() returned null")
		return
		
	get_tree().change_scene_to_file("res://src/scenes/equipment/EquipmentTrade.tscn")

func _handle_battlefield_setup() -> void:
	if not get_tree():
		push_warning("Cannot handle battlefield setup: get_tree() returned null")
		return
		
	get_tree().change_scene_to_file("res://src/scenes/battle/BattlefieldSetup.tscn")

func _handle_crew_deployment() -> void:
	if not get_tree():
		push_warning("Cannot handle crew deployment: get_tree() returned null")
		return
		
	get_tree().change_scene_to_file("res://src/scenes/battle/CrewDeployment.tscn")

func _handle_battle_start() -> void:
	if not _campaign_manager or not _campaign_manager.has_method("start_battle"):
		push_warning("Cannot handle battle start: _campaign_manager is null or missing start_battle method")
		return
		
	_campaign_manager.start_battle()

func _handle_combat_resolution() -> void:
	if not _campaign_manager or not _campaign_manager.has_method("resolve_combat"):
		push_warning("Cannot handle combat resolution: _campaign_manager is null or missing resolve_combat method")
		return
		
	_campaign_manager.resolve_combat()

func _handle_casualty_check() -> void:
	if not get_tree():
		push_warning("Cannot handle casualty check: get_tree() returned null")
		return
		
	get_tree().change_scene_to_file("res://src/scenes/battle/CasualtyCheck.tscn")

func _handle_reward_collection() -> void:
	if not _campaign_manager or not _campaign_manager.has_method("collect_rewards"):
		push_warning("Cannot handle reward collection: _campaign_manager is null or missing collect_rewards method")
		return
		
	_campaign_manager.collect_rewards()

func _handle_character_advancement() -> void:
	if not get_tree():
		push_warning("Cannot handle character advancement: get_tree() returned null")
		return
		
	get_tree().change_scene_to_file("res://src/scenes/character/CharacterAdvancement.tscn")

func _handle_equipment_update() -> void:
	if not get_tree():
		push_warning("Cannot handle equipment update: get_tree() returned null")
		return
		
	get_tree().change_scene_to_file("res://src/scenes/equipment/EquipmentUpdate.tscn")

func _handle_turn_end() -> void:
	if not _phase_manager or not _phase_manager.has_method("advance_phase"):
		push_warning("Cannot handle turn end: _phase_manager is null or missing advance_phase method")
		return
		
	_phase_manager.advance_phase()
