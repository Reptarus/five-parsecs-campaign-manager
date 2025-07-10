# Universal Connection Validation Applied
# Based on proven patterns: Universal Mock Strategy + 7-Stage Methodology
@tool
extends Control
class_name FPCM_CampaignUI

# Safe imports
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class

# Safe dependencies using Universal loading
@warning_ignore("shadowed_global_identifier")
var FPCM_CampaignResponsiveLayout: Variant = null
var CampaignManager: Variant = null
@warning_ignore("shadowed_global_identifier")
var GameCampaignManager: Variant = null
var CampaignDashboard: Variant = null
var CampaignPhaseUI: Variant = null
var GlobalEnums: Variant = null
var CampaignPhaseManager: Variant = null
var GameState: Variant = null
var SceneRouter: Variant = null

# Child Nodes using safe access
@onready var dashboard_tab: TabBar = get_node("MainContent/HBoxContainer/MainTabs/Dashboard")
@onready var characters_tab: TabBar = get_node("MainContent/HBoxContainer/MainTabs/Characters")
@onready var resources_tab: TabBar = get_node("MainContent/HBoxContainer/MainTabs/Resources")
@onready var events_tab: TabBar = get_node("MainContent/HBoxContainer/MainTabs/Events")

@onready var resource_panel: Control = get_node("MainContent/HBoxContainer/Sidebar/VBoxContainer/ResourcePanel")
@onready var action_panel: Control = get_node("MainContent/HBoxContainer/Sidebar/VBoxContainer/ActionPanel")
@onready var phase_indicator: Control = get_node("Header/PhaseIndicator")
@onready var event_log: Control = get_node("MainContent/HBoxContainer/MainTabs/Events/EventLog")
@onready var phase_ui: Control = get_node("MainContent/HBoxContainer/MainTabs/Phase/CampaignPhaseUI")
# Components
var dashboard: Node # Using Node since CampaignDashboard is a scene

# Signals
signal phase_changed(new_phase: int)
signal resource_updated(resource_type: int, new_value: int)
signal event_occurred(event_data: Dictionary)

# Internal state
var _current_phase: int = 0
var _layout: Node
var _campaign_manager: Node
var _phase_manager: Node

func _ready() -> void:
	# Load dependencies safely at runtime
	FPCM_CampaignResponsiveLayout = load("res://src/ui/components/base/CampaignResponsiveLayout.gd")
	CampaignManager = load("res://src/core/managers/CampaignManager.gd")
	GameCampaignManager = load("res://src/core/campaign/GameCampaignManager.gd")
	GlobalEnums = load("res://src/core/systems/GlobalEnums.gd")
	CampaignPhaseManager = load("res://src/core/campaign/CampaignPhaseManager.gd")
	GameState = load("res://src/core/state/GameState.gd")
	SceneRouter = load("res://src/ui/screens/SceneRouter.gd")

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
	if not GlobalEnums:
		push_error("UI SYSTEM FAILURE: GlobalEnums not loaded in CampaignUI")

	if not FPCM_CampaignResponsiveLayout:
		push_warning("UI DEPENDENCY MISSING: CampaignResponsiveLayout not loaded")

	# Validate autoload connections
	@warning_ignore("untyped_declaration")
	var required_autoloads = ["GameState", "EventBus"]
	@warning_ignore("untyped_declaration")
	for autoload_name in required_autoloads:
		var autoload_node: Node = get_node_or_null("/root/" + str(autoload_name))
		if not autoload_node:
			push_warning("UI DEPENDENCY MISSING: %s not available (CampaignUI)" % autoload_name)

func _initialize_layout() -> void:
	if not FPCM_CampaignResponsiveLayout:
		push_error("CRASH PREVENTION: Cannot create layout - CampaignResponsiveLayout not loaded")
		return

	# Create layout instance from script
	@warning_ignore("unsafe_method_access")
	if FPCM_CampaignResponsiveLayout:
		var layout_script = FPCM_CampaignResponsiveLayout as Script
		if layout_script:
			_layout = layout_script.new()
			if _layout and _layout.has_method("initialize"):
				@warning_ignore("unsafe_method_access")
				_layout.initialize(self)

func _setup_dashboard() -> void:
	if not dashboard_tab:
		push_error("CRASH PREVENTION: Cannot add dashboard - dashboard_tab not found")
		return

	# Load and instantiate the CampaignDashboard scene
	var dashboard_scene = load("res://src/ui/screens/campaign/CampaignDashboard.tscn")
	if dashboard_scene:
		dashboard = dashboard_scene.instantiate()
		if dashboard:
			dashboard_tab.add_child(dashboard)
			if dashboard.has_method("setup"):
				@warning_ignore("unsafe_method_access")
				dashboard.setup(null)  # Pass appropriate game state if needed
	else:
		push_error("CRASH PREVENTION: Could not load CampaignDashboard scene")

func _connect_signals() -> void:
	if _campaign_manager:
		@warning_ignore("unsafe_property_access", "unsafe_method_access")
		_campaign_manager.phase_changed.connect(_on_phase_changed)
		@warning_ignore("unsafe_property_access", "unsafe_method_access")
		_campaign_manager.resource_updated.connect(_on_resource_updated)
		@warning_ignore("unsafe_property_access", "unsafe_method_access")
		_campaign_manager.event_occurred.connect(_on_event_occurred)

func _setup_ui_components() -> void:
	# Setup resource panel
	@warning_ignore("unsafe_call_argument")
	_update_resource_display(GlobalEnums.ResourceType.CREDITS, 0)
	@warning_ignore("unsafe_call_argument")
	_update_resource_display(GlobalEnums.ResourceType.SUPPLIES, 0)
	@warning_ignore("unsafe_call_argument")
	_update_resource_display(GlobalEnums.ResourceType.REPUTATION, 0)
	@warning_ignore("unsafe_call_argument")
	_update_resource_display(GlobalEnums.ResourceType.TECH_PARTS, 0)

	# Setup phase indicator
	if phase_indicator and phase_indicator.has_method("setup"):
		@warning_ignore("unsafe_method_access")
		phase_indicator.setup(_phase_manager)
	elif phase_indicator:
		phase_indicator.visible = true

	# Setup event log
	@warning_ignore("unsafe_method_access")
	if event_log and event_log.has_method("clear"):
		event_log.clear()

func _setup_phase_manager() -> void:
	if _phase_manager:
		if phase_ui and phase_ui.has_method("initialize"):
			@warning_ignore("unsafe_method_access")
			phase_ui.initialize(_phase_manager)
		@warning_ignore("unsafe_property_access", "unsafe_method_access")
		_phase_manager.phase_changed.connect(_on_phase_changed)

func _update_resource_display(resource_type: int, _value: int) -> void:
	if not GlobalEnums:
		push_error("CRASH PREVENTION: Cannot update resource display - GlobalEnums not available")
		return

	if not resource_panel:
		push_warning("UI WARNING: resource_panel not available for resource display update")
		return

	var resource_name: String = "Resource"
	@warning_ignore("unsafe_method_access")
	if GlobalEnums and GlobalEnums.has_method("ResourceType") and GlobalEnums.ResourceType.keys().size() > resource_type:
		@warning_ignore("unsafe_method_access")
		resource_name = GlobalEnums.ResourceType.keys()[resource_type]

	var resource_label: Label = get_node_or_null(resource_name.to_lower() + "_label")
	if resource_label:
		resource_label.text = "%s: %d" % [resource_name.capitalize(), _value]
	else:
		push_warning("UI WARNING: resource_label node not found: %s" % (resource_name.to_lower() + "_label"))

func _log_event(event_data: Dictionary) -> void:
	if event_log:
		@warning_ignore("unsafe_method_access")
		event_log.add_event(event_data)

func _on_phase_changed(new_phase: int) -> void:
	_current_phase = new_phase

	# Update UI
	@warning_ignore("unsafe_method_access")
	phase_indicator.set_phase(new_phase)

	# Log _phase change
	_log_event({
		"id": "phase_change_%d" % Time.get_unix_time_from_system(),
		"title": "Phase Changed",
		"description": "Campaign _phase changed to %s" % GlobalEnums.FiveParsecsCampaignPhase.keys()[new_phase],
		"category": "campaign",
		"_phase": new_phase
	})

	self.phase_changed.emit(new_phase)

func _on_resource_updated(resource_type: int, new_value: int) -> void:
	_update_resource_display(resource_type, new_value)

	if dashboard:
		@warning_ignore("unsafe_property_access", "unsafe_method_access")
		dashboard.setup(_campaign_manager.gamestate)

	# Log resource update event
	_log_event({
		"id": "resource_update_%d" % Time.get_unix_time_from_system(),
		"title": "%s Updated" % GlobalEnums.ResourceType.keys()[resource_type],
		"description": "%s changed to %d" % [GlobalEnums.ResourceType.keys()[resource_type], new_value],
		"category": "campaign",
		"resource": resource_type,
		"_value": new_value
	})

	self.resource_updated.emit(resource_type, new_value)

func _on_event_occurred(event_data: Dictionary) -> void:
	_log_event(event_data)
	self.event_occurred.emit(event_data)

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
	@warning_ignore("untyped_declaration")
	var scene_path = "res://src/scenes/character/CrewCreation.tscn"
	@warning_ignore("unsafe_call_argument", "untyped_declaration")
	var crew_creation_scene = load(scene_path)
	if crew_creation_scene:
		@warning_ignore("unsafe_method_access")
		get_tree().change_scene_to_file(scene_path)
	else:
		push_error("CRASH PREVENTION: Could not load crew creation scene")

func _handle_campaign_selection() -> void:
	@warning_ignore("untyped_declaration")
	var scene_path = "res://src/scenes/campaign/CampaignSelection.tscn"
	@warning_ignore("unsafe_call_argument", "untyped_declaration")
	var campaign_selection_scene = load(scene_path)
	if campaign_selection_scene:
		@warning_ignore("unsafe_method_access")
		get_tree().change_scene_to_file(scene_path)
	else:
		push_error("CRASH PREVENTION: Could not load campaign selection scene")

func _handle_campaign_start() -> void:
	@warning_ignore("unsafe_method_access")
	_phase_manager.advance_phase()

func _handle_upkeep_payment() -> void:
	@warning_ignore("unsafe_method_access")
	_campaign_manager.process_upkeep()

func _handle_resource_management() -> void:
	@warning_ignore("untyped_declaration")
	var scene_path = "res://src/scenes/resource/ResourceManagement.tscn"
	@warning_ignore("unsafe_call_argument", "untyped_declaration")
	var resource_scene = load(scene_path)
	if resource_scene:
		@warning_ignore("unsafe_method_access")
		get_tree().change_scene_to_file(scene_path)
	else:
		push_error("CRASH PREVENTION: Could not load resource management scene")

func _handle_crew_status() -> void:
	@warning_ignore("untyped_declaration")
	var scene_path = "res://src/scenes/character/CrewStatus.tscn"
	@warning_ignore("unsafe_call_argument", "untyped_declaration")
	var crew_status_scene = load(scene_path)
	if crew_status_scene:
		@warning_ignore("unsafe_method_access")
		get_tree().change_scene_to_file(scene_path)
	else:
		push_error("CRASH PREVENTION: Could not load crew status scene")

func _handle_event_check() -> void:
	@warning_ignore("unsafe_method_access")
	_campaign_manager.check_events()

func _handle_story_progress() -> void:
	get_tree().call_deferred("change_scene_to_file", "res://src/scenes/story/StoryProgress.tscn")

func _handle_event_resolution() -> void:
	@warning_ignore("unsafe_method_access")
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
	@warning_ignore("unsafe_method_access")
	_campaign_manager.start_battle()

func _handle_combat_resolution() -> void:
	@warning_ignore("unsafe_method_access")
	_campaign_manager.resolve_combat()

func _handle_casualty_check() -> void:
	get_tree().call_deferred("change_scene_to_file", "res://src/scenes/battle/CasualtyCheck.tscn")

func _handle_reward_collection() -> void:
	@warning_ignore("unsafe_method_access")
	_campaign_manager.collect_rewards()

func _handle_character_advancement() -> void:
	get_tree().call_deferred("change_scene_to_file", "res://src/scenes/character/CharacterAdvancement.tscn")

func _handle_equipment_update() -> void:
	get_tree().call_deferred("change_scene_to_file", "res://src/scenes/equipment/EquipmentUpdate.tscn")

func _handle_turn_end() -> void:
	@warning_ignore("unsafe_method_access")
	_phase_manager.advance_phase()

	@warning_ignore("unsafe_method_access")
	_phase_manager.advance_phase()

## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	@warning_ignore("unsafe_method_access")
	if obj is Object and obj.has_method(method_name):
		@warning_ignore("unsafe_method_access")
		return obj.callv(method_name, args)
	return null
