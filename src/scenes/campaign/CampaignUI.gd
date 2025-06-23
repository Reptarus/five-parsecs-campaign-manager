# Universal Connection Validation Applied
# Based on proven patterns: Universal Mock Strategy + 7-Stage Methodology
@tool
extends Control
class_name FPCM_CampaignUI

# Safe imports
const UniversalNodeAccess = preload("res://src/utils/UniversalNodeAccess.gd")
const UniversalResourceLoader = preload("res://src/utils/UniversalResourceLoader.gd") 
const UniversalSignalManager = preload("res://src/utils/UniversalSignalManager.gd")
const UniversalDataAccess = preload("res://src/utils/UniversalDataAccess.gd")
const UniversalSceneManager = preload("res://src/utils/UniversalSceneManager.gd")

# Safe dependencies using Universal loading
var FPCM_CampaignResponsiveLayout = null
var CampaignManager = null
var GameCampaignManager = null
const CampaignDashboard = UniversalResourceLoader.load_resource_safe("res://src/ui/screens/campaign/CampaignDashboard.tscn", "PackedScene", "CampaignUI CampaignDashboard")
const CampaignPhaseUI = UniversalResourceLoader.load_resource_safe("res://src/scenes/campaign/components/CampaignPhaseUI.tscn", "PackedScene", "CampaignUI CampaignPhaseUI")
var GameEnums = null
var CampaignPhaseManager = null
var FiveParsecsGameState = null

# Child Nodes using safe access
@onready var dashboard_tab: TabBar = UniversalNodeAccess.get_node_safe(self, "MainContent/HBoxContainer/MainTabs/Dashboard", "CampaignUI dashboard_tab")
@onready var characters_tab: TabBar = UniversalNodeAccess.get_node_safe(self, "MainContent/HBoxContainer/MainTabs/Characters", "CampaignUI characters_tab")
@onready var resources_tab: TabBar = UniversalNodeAccess.get_node_safe(self, "MainContent/HBoxContainer/MainTabs/Resources", "CampaignUI resources_tab")
@onready var events_tab: TabBar = UniversalNodeAccess.get_node_safe(self, "MainContent/HBoxContainer/MainTabs/Events", "CampaignUI events_tab")

@onready var resource_panel: Panel = UniversalNodeAccess.get_node_safe(self, "MainContent/HBoxContainer/Sidebar/ResourcePanel", "CampaignUI resource_panel")
@onready var action_panel: Panel = UniversalNodeAccess.get_node_safe(self, "MainContent/HBoxContainer/Sidebar/ActionPanel", "CampaignUI action_panel")
@onready var phase_indicator: Control = UniversalNodeAccess.get_node_safe(self, "Header/PhaseIndicator", "CampaignUI phase_indicator")
@onready var event_log: Control = UniversalNodeAccess.get_node_safe(self, "MainContent/HBoxContainer/MainTabs/Events/EventLog", "CampaignUI event_log")
@onready var phase_ui: Control = UniversalNodeAccess.get_node_safe(self, "MainContent/HBoxContainer/MainTabs/Phase/CampaignPhaseUI", "CampaignUI phase_ui")
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
	# Load dependencies safely at runtime
	FPCM_CampaignResponsiveLayout = UniversalResourceLoader.load_script_safe("res://src/ui/components/base/CampaignResponsiveLayout.gd", "CampaignUI CampaignResponsiveLayout")
	CampaignManager = UniversalResourceLoader.load_script_safe("res://src/core/managers/CampaignManager.gd", "CampaignUI CampaignManager")
	GameCampaignManager = UniversalResourceLoader.load_script_safe("res://src/core/campaign/GameCampaignManager.gd", "CampaignUI GameCampaignManager")
	GameEnums = UniversalResourceLoader.load_script_safe("res://src/core/systems/GlobalEnums.gd", "CampaignUI GameEnums")
	CampaignPhaseManager = UniversalResourceLoader.load_script_safe("res://src/core/campaign/CampaignPhaseManager.gd", "CampaignUI CampaignPhaseManager")
	FiveParsecsGameState = UniversalResourceLoader.load_script_safe("res://src/core/state/GameState.gd", "CampaignUI GameState")
	
	_validate_universal_connections()
	_initialize_layout()
	_setup_dashboard()
	_connect_signals()
	_setup_ui_components()
	_setup_phase_manager()

func _validate_universal_connections() -> void:
	# Validate UI dependencies
	_validate_ui_connections()
	
func _validate_ui_connections() -> void:
	# Validate required dependencies
	if not GameEnums:
		push_error("UI SYSTEM FAILURE: GameEnums not loaded in CampaignUI")
	
	if not FPCM_CampaignResponsiveLayout:
		push_warning("UI DEPENDENCY MISSING: CampaignResponsiveLayout not loaded")
	
	# Validate autoload connections
	var required_autoloads = ["GameState", "EventBus"]
	for autoload_name in required_autoloads:
		var autoload_node = get_node_or_null("/root/" + autoload_name)
		if not autoload_node:
			push_warning("UI DEPENDENCY MISSING: %s not available (CampaignUI)" % autoload_name)

func _initialize_layout() -> void:
	if not FPCM_CampaignResponsiveLayout:
		push_error("CRASH PREVENTION: Cannot create layout - CampaignResponsiveLayout not loaded")
		return
	
	_layout = FPCM_CampaignResponsiveLayout.new()
	if _layout and _layout.has_method("initialize"):
		_layout.initialize(self)

func _setup_dashboard() -> void:
	if not CampaignDashboard:
		push_error("CRASH PREVENTION: Cannot create dashboard - CampaignDashboard scene not loaded")
		return
		
	if not dashboard_tab:
		push_error("CRASH PREVENTION: Cannot add dashboard - dashboard_tab not found")
		return
	
	dashboard = UniversalSceneManager.instantiate_scene_safe(CampaignDashboard, "CampaignUI dashboard")
	if dashboard:
		UniversalNodeAccess.add_child_safe(dashboard_tab, dashboard, "CampaignUI dashboard to tab")

func _connect_signals() -> void:
	if _campaign_manager:
		UniversalSignalManager.connect_signal_safe(_campaign_manager, "phase_changed", _on_phase_changed, "CampaignUI phase_changed")
		UniversalSignalManager.connect_signal_safe(_campaign_manager, "resource_updated", _on_resource_updated, "CampaignUI resource_updated")
		UniversalSignalManager.connect_signal_safe(_campaign_manager, "event_occurred", _on_event_occurred, "CampaignUI event_occurred")

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
		if phase_ui and phase_ui.has_method("initialize"):
			phase_ui.initialize(_phase_manager)
		UniversalSignalManager.connect_signal_safe(_phase_manager, "phase_changed", _on_phase_changed, "CampaignUI phase_manager phase_changed")

func _update_resource_display(resource_type: GameEnums.ResourceType, _value: int) -> void:
	if not GameEnums:
		push_error("CRASH PREVENTION: Cannot update resource display - GameEnums not available")
		return
		
	if not resource_panel:
		push_warning("UI WARNING: resource_panel not available for resource display update")
		return
	
	var resource_name = GameEnums.ResourceType.keys()[resource_type]
	var resource_label = UniversalNodeAccess.get_node_safe(resource_panel, resource_name.to_lower() + "_label", "CampaignUI resource label")
	if resource_label:
		resource_label.text = "%s: %d" % [resource_name.capitalize(), _value]

func _log_event(event_data: Dictionary) -> void:
	if event_log:
		event_log.add_event(event_data)

func _on_phase_changed(new_phase: GameEnums.CampaignPhase) -> void:
	_current_phase = new_phase
	
	# Update UI
	phase_indicator.set_phase(new_phase)
	
	# Log _phase change
	_log_event({
		"id": "phase_change_%d" % Time.get_unix_time_from_system(),
		"title": "Phase Changed",
		"description": "Campaign _phase changed to %s" % GameEnums.CampaignPhase.keys()[new_phase],
		"category": "campaign",
		"_phase": new_phase
	})
	
	UniversalSignalManager.emit_signal_safe(self, "phase_changed", [new_phase], "CampaignUI phase_changed")

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
		"_value": new_value
	})
	
	UniversalSignalManager.emit_signal_safe(self, "resource_updated", [resource_type, new_value], "CampaignUI resource_updated")

func _on_event_occurred(event_data: Dictionary) -> void:
	_log_event(event_data)
	UniversalSignalManager.emit_signal_safe(self, "event_occurred", [event_data], "CampaignUI event_occurred")

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
	var scene_path = "res://src/scenes/character/CrewCreation.tscn"
	var crew_creation_scene = UniversalResourceLoader.load_resource_safe(scene_path, "PackedScene", "CampaignUI crew creation")
	if crew_creation_scene:
		UniversalSceneManager.change_scene_safe(get_tree(), crew_creation_scene, "CampaignUI crew creation navigation")
	else:
		push_error("CRASH PREVENTION: Could not load crew creation scene")

func _handle_campaign_selection() -> void:
	var scene_path = "res://src/scenes/campaign/CampaignSelection.tscn"
	var campaign_selection_scene = UniversalResourceLoader.load_resource_safe(scene_path, "PackedScene", "CampaignUI campaign selection")
	if campaign_selection_scene:
		UniversalSceneManager.change_scene_safe(get_tree(), campaign_selection_scene, "CampaignUI campaign selection navigation")
	else:
		push_error("CRASH PREVENTION: Could not load campaign selection scene")

func _handle_campaign_start() -> void:
	_phase_manager.advance_phase()

func _handle_upkeep_payment() -> void:
	_campaign_manager.process_upkeep()

func _handle_resource_management() -> void:
	var scene_path = "res://src/scenes/resource/ResourceManagement.tscn"
	var resource_scene = UniversalResourceLoader.load_resource_safe(scene_path, "PackedScene", "CampaignUI resource management")
	if resource_scene:
		UniversalSceneManager.change_scene_safe(get_tree(), resource_scene, "CampaignUI resource management navigation")
	else:
		push_error("CRASH PREVENTION: Could not load resource management scene")

func _handle_crew_status() -> void:
	var scene_path = "res://src/scenes/character/CrewStatus.tscn"
	var crew_status_scene = UniversalResourceLoader.load_resource_safe(scene_path, "PackedScene", "CampaignUI crew status")
	if crew_status_scene:
		UniversalSceneManager.change_scene_safe(get_tree(), crew_status_scene, "CampaignUI crew status navigation")
	else:
		push_error("CRASH PREVENTION: Could not load crew status scene")

func _handle_event_check() -> void:
	_campaign_manager.check_events()

func _handle_story_progress() -> void:
	get_tree().call_deferred("change_scene_to_file", "res://src/scenes/story/StoryProgress.tscn")

func _handle_event_resolution() -> void:
	_campaign_manager.resolve_events()

func _handle_mission_selection() -> void:
	get_tree().call_deferred("change_scene_to_file", "res://src/scenes/mission/MissionSelection.tscn")

func _handle_crew_management() -> void:
	get_tree().call_deferred("change_scene_to_file", "res://src/scenes/character/CrewManagement.tscn")

func _handle_equipment_trade() -> void:
	get_tree().call_deferred("change_scene_to_file", "res://src/scenes/equipment/EquipmentTrade.tscn")

func _handle_battlefield_setup() -> void:
	get_tree().call_deferred("change_scene_to_file", "res://src/scenes/battle/BattlefieldSetup.tscn")

func _handle_crew_deployment() -> void:
	get_tree().call_deferred("change_scene_to_file", "res://src/scenes/battle/CrewDeployment.tscn")

func _handle_battle_start() -> void:
	_campaign_manager.start_battle()

func _handle_combat_resolution() -> void:
	_campaign_manager.resolve_combat()

func _handle_casualty_check() -> void:
	get_tree().call_deferred("change_scene_to_file", "res://src/scenes/battle/CasualtyCheck.tscn")

func _handle_reward_collection() -> void:
	_campaign_manager.collect_rewards()

func _handle_character_advancement() -> void:
	get_tree().call_deferred("change_scene_to_file", "res://src/scenes/character/CharacterAdvancement.tscn")

func _handle_equipment_update() -> void:
	get_tree().call_deferred("change_scene_to_file", "res://src/scenes/equipment/EquipmentUpdate.tscn")

func _handle_turn_end() -> void:
	_phase_manager.advance_phase()

	_phase_manager.advance_phase()