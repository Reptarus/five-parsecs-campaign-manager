@tool
extends Control
class_name CampaignUI

# Dependencies
const CampaignResponsiveLayout = preload("res://src/ui/components/base/CampaignResponsiveLayout.gd")
const CampaignManager = preload("res://src/core/campaign/CampaignManager.gd")
const CampaignDashboard: PackedScene = preload("res://src/scenes/campaign/components/CampaignDashboard.tscn")
const CampaignPhaseUI: PackedScene = preload("res://src/scenes/campaign/components/CampaignPhaseUI.tscn")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const CampaignPhaseManager = preload("res://src/core/managers/CampaignPhaseManager.gd")
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")

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

func _connect_signals() -> void:
	if _campaign_manager:
		_campaign_manager.phase_changed.connect(_on_phase_changed)
		_campaign_manager.resource_updated.connect(_on_resource_updated)
		_campaign_manager.event_occurred.connect(_on_event_occurred)

func _setup_ui_components() -> void:
	# Setup resource panel
	_update_resource_display(GameEnums.ResourceType.CREDITS, 0)
	_update_resource_display(GameEnums.ResourceType.SUPPLIES, 0)
	_update_resource_display(GameEnums.ResourceType.REPUTATION, 0)
	_update_resource_display(GameEnums.ResourceType.TECH_PARTS, 0)

	# Setup phase indicator
	phase_indicator.initialize(_phase_manager)

	# Setup event log
	event_log.clear()

func _setup_phase_manager() -> void:
	if _phase_manager:
		phase_ui.initialize(_phase_manager)
		_phase_manager.phase_changed.connect(_on_phase_changed)

func _update_resource_display(resource_type: GameEnums.ResourceType, value: int) -> void:
	var resource_name = GameEnums.ResourceType.keys()[resource_type]
	var resource_label = resource_panel.get_node_or_null(resource_name.to_lower() + "_label")
	if resource_label:
		resource_label.text = "%s: %d" % [resource_name.capitalize(), value]

func _log_event(event_data: Dictionary) -> void:
	if event_log:
		event_log.add_event(event_data)

func _on_phase_changed(new_phase: GameEnums.CampaignPhase) -> void:
	_current_phase = new_phase
	
	# Update UI
	phase_indicator.set_phase(new_phase)
	
	# Log phase change
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

func _on_phase_action_requested(action_type: String) -> void:
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

# Action handlers
func _handle_crew_creation() -> void:
	get_tree().change_scene_to_file("res://src/scenes/character/CrewCreation.tscn")

func _handle_campaign_selection() -> void:
	get_tree().change_scene_to_file("res://src/scenes/campaign/CampaignSelection.tscn")

func _handle_campaign_start() -> void:
	_phase_manager.advance_phase()

func _handle_upkeep_payment() -> void:
	_campaign_manager.process_upkeep()

func _handle_resource_management() -> void:
	get_tree().change_scene_to_file("res://src/scenes/resource/ResourceManagement.tscn")

func _handle_crew_status() -> void:
	get_tree().change_scene_to_file("res://src/scenes/character/CrewStatus.tscn")

func _handle_event_check() -> void:
	_campaign_manager.check_events()

func _handle_story_progress() -> void:
	get_tree().change_scene_to_file("res://src/scenes/story/StoryProgress.tscn")

func _handle_event_resolution() -> void:
	_campaign_manager.resolve_events()

func _handle_mission_selection() -> void:
	get_tree().change_scene_to_file("res://src/scenes/mission/MissionSelection.tscn")

func _handle_crew_management() -> void:
	get_tree().change_scene_to_file("res://src/scenes/character/CrewManagement.tscn")

func _handle_equipment_trade() -> void:
	get_tree().change_scene_to_file("res://src/scenes/equipment/EquipmentTrade.tscn")

func _handle_battlefield_setup() -> void:
	get_tree().change_scene_to_file("res://src/scenes/battle/BattlefieldSetup.tscn")

func _handle_crew_deployment() -> void:
	get_tree().change_scene_to_file("res://src/scenes/battle/CrewDeployment.tscn")

func _handle_battle_start() -> void:
	_campaign_manager.start_battle()

func _handle_combat_resolution() -> void:
	_campaign_manager.resolve_combat()

func _handle_casualty_check() -> void:
	get_tree().change_scene_to_file("res://src/scenes/battle/CasualtyCheck.tscn")

func _handle_reward_collection() -> void:
	_campaign_manager.collect_rewards()

func _handle_character_advancement() -> void:
	get_tree().change_scene_to_file("res://src/scenes/character/CharacterAdvancement.tscn")

func _handle_equipment_update() -> void:
	get_tree().change_scene_to_file("res://src/scenes/equipment/EquipmentUpdate.tscn")

func _handle_turn_end() -> void:
	_phase_manager.advance_phase()