# Universal Connection Validation Applied
# Based on proven patterns: Universal Mock Strategy + 7-Stage Methodology
class_name FPCM_CampaignDashboardUI
extends Control

# Safe imports
const UniversalNodeAccess = preload("res://src/utils/UniversalNodeAccess.gd")
const UniversalResourceLoader = preload("res://src/utils/UniversalResourceLoader.gd")
const UniversalSignalManager = preload("res://src/utils/UniversalSignalManager.gd")
const UniversalDataAccess = preload("res://src/utils/UniversalDataAccess.gd")
const UniversalSceneManager = preload("res://src/utils/UniversalSceneManager.gd")

# Safe dependency loading
var GameEnums = null
var GameState = null
var CampaignPhaseManagerScript = null
var FPCM_BasePhasePanel = null

# Safe scene loading - loaded at runtime in _ready()
var UpkeepPhasePanel: PackedScene = null
var StoryPhasePanel: PackedScene = null
var CampaignPhasePanel: PackedScene = null
var BattleSetupPhasePanel: PackedScene = null
var BattleResolutionPhasePanel: PackedScene = null
var AdvancementPhasePanel: PackedScene = null
var TradePhasePanel: PackedScene = null
var EndPhasePanel: PackedScene = null

# UI Node References using safe access - FIXED TYPE ISSUES
@onready var phase_label: Label = UniversalNodeAccess.get_node_safe(self, "MarginContainer/VBoxContainer/HeaderPanel/HBoxContainer/PhaseLabel", "CampaignDashboard phase_label") as Label
@onready var credits_label: Label = UniversalNodeAccess.get_node_safe(self, "MarginContainer/VBoxContainer/HeaderPanel/HBoxContainer/CreditsLabel", "CampaignDashboard credits_label") as Label
@onready var story_points_label: Label = UniversalNodeAccess.get_node_safe(self, "MarginContainer/VBoxContainer/HeaderPanel/HBoxContainer/StoryPointsLabel", "CampaignDashboard story_points_label") as Label
@onready var crew_list: ItemList = UniversalNodeAccess.get_node_safe(self, "MarginContainer/VBoxContainer/MainContent/LeftPanel/CrewPanel/VBoxContainer/CrewList", "CampaignDashboard crew_list") as ItemList
@onready var ship_info = UniversalNodeAccess.get_node_safe(self, "MarginContainer/VBoxContainer/MainContent/LeftPanel/ShipPanel/VBoxContainer/ShipInfo", "CampaignDashboard ship_info")
@onready var phase_content = UniversalNodeAccess.get_node_safe(self, "MarginContainer/VBoxContainer/MainContent", "CampaignDashboard phase_content")
@onready var next_phase_button: Button = UniversalNodeAccess.get_node_safe(self, "MarginContainer/VBoxContainer/ButtonContainer/ActionButton", "CampaignDashboard next_phase_button") as Button
@onready var manage_crew_button: Button = UniversalNodeAccess.get_node_safe(self, "MarginContainer/VBoxContainer/ButtonContainer/ManageCrewButton", "CampaignDashboard manage_crew_button") as Button
@onready var save_button: Button = UniversalNodeAccess.get_node_safe(self, "MarginContainer/VBoxContainer/ButtonContainer/SaveButton", "CampaignDashboard save_button") as Button
@onready var load_button: Button = UniversalNodeAccess.get_node_safe(self, "MarginContainer/VBoxContainer/ButtonContainer/LoadButton", "CampaignDashboard load_button") as Button
@onready var quit_button: Button = UniversalNodeAccess.get_node_safe(self, "MarginContainer/VBoxContainer/ButtonContainer/QuitButton", "CampaignDashboard quit_button") as Button
# @onready var phase_container = $PhaseContainer # This node doesn't exist in scene

var game_state: GameState
var phase_manager: Node
var current_phase_panel: FPCM_BasePhasePanel

# Manager references (from autoloads)
var alpha_manager: Node = null
var campaign_manager: Node = null

func _ready() -> void:
	# Load dependencies safely at runtime
	GameEnums = UniversalResourceLoader.load_script_safe("res://src/core/systems/GlobalEnums.gd", "CampaignDashboard GameEnums")
	GameState = UniversalResourceLoader.load_script_safe("res://src/core/state/GameState.gd", "CampaignDashboard GameState")
	CampaignPhaseManagerScript = UniversalResourceLoader.load_script_safe("res://src/core/campaign/CampaignPhaseManager.gd", "CampaignDashboard CampaignPhaseManager")
	FPCM_BasePhasePanel = UniversalResourceLoader.load_script_safe("res://src/ui/screens/campaign/phases/BasePhasePanel.gd", "CampaignDashboard BasePhasePanel")
	
	# Load phase panel scenes safely
	UpkeepPhasePanel = UniversalResourceLoader.load_scene_safe("res://src/ui/screens/campaign/phases/UpkeepPhasePanel.tscn", "CampaignDashboard UpkeepPhasePanel")
	StoryPhasePanel = UniversalResourceLoader.load_scene_safe("res://src/ui/screens/campaign/phases/StoryPhasePanel.tscn", "CampaignDashboard StoryPhasePanel")
	CampaignPhasePanel = UniversalResourceLoader.load_scene_safe("res://src/ui/screens/campaign/phases/CampaignPhasePanel.tscn", "CampaignDashboard CampaignPhasePanel")
	BattleSetupPhasePanel = UniversalResourceLoader.load_scene_safe("res://src/ui/screens/campaign/phases/BattleSetupPhasePanel.tscn", "CampaignDashboard BattleSetupPhasePanel")
	BattleResolutionPhasePanel = UniversalResourceLoader.load_scene_safe("res://src/ui/screens/campaign/phases/BattleResolutionPhasePanel.tscn", "CampaignDashboard BattleResolutionPhasePanel")
	AdvancementPhasePanel = UniversalResourceLoader.load_scene_safe("res://src/ui/screens/campaign/phases/AdvancementPhasePanel.tscn", "CampaignDashboard AdvancementPhasePanel")
	TradePhasePanel = UniversalResourceLoader.load_scene_safe("res://src/ui/screens/campaign/phases/TradePhasePanel.tscn", "CampaignDashboard TradePhasePanel")
	EndPhasePanel = UniversalResourceLoader.load_scene_safe("res://src/ui/screens/campaign/phases/EndPhasePanel.tscn", "CampaignDashboard EndPhasePanel")
	
	_initialize_managers()
	_connect_signals()
	_setup_campaign()
	_update_ui()

func _initialize_managers() -> void:
	"""Initialize manager references from autoloads"""
	alpha_manager = get_node("/root/AlphaGameManager") if has_node("/root/AlphaGameManager") else null
	campaign_manager = get_node("/root/CampaignManager") if has_node("/root/CampaignManager") else null
	
	# Use campaign manager if available, otherwise fall back to local implementation
	if campaign_manager:
		print("Using CampaignManager from autoload")
	else:
		# Fallback to autoload implementation
		game_state = get_node("/root/GameState")
		phase_manager = CampaignPhaseManagerScript.new()
		phase_manager.name = "PhaseManager"
		add_child(phase_manager)

func _connect_signals() -> void:
	# Connect to campaign manager signals if available
	if campaign_manager:
		if campaign_manager.has_signal("campaign_updated"):
			campaign_manager.campaign_updated.connect(_on_campaign_updated)
		if campaign_manager.has_signal("phase_changed"):
			campaign_manager.phase_changed.connect(_on_phase_changed)
	
	# Connect to local phase manager if using fallback
	if phase_manager:
		if phase_manager.has_signal("phase_changed"):
			phase_manager.phase_changed.connect(_on_phase_changed)
		if phase_manager.has_signal("phase_completed"):
			phase_manager.phase_completed.connect(_on_phase_completed)
		if phase_manager.has_signal("phase_event_triggered"):
			phase_manager.phase_event_triggered.connect(_on_phase_event)
	
	# Connect button signals with proper validation
	_connect_dashboard_buttons()

func _connect_dashboard_buttons() -> void:
	"""Connect dashboard button signals with validation"""
	if next_phase_button and next_phase_button.has_method("connect"):
		if not next_phase_button.pressed.is_connected(_on_next_phase_pressed):
			next_phase_button.pressed.connect(_on_next_phase_pressed)
	else:
		push_warning("CampaignDashboard: Next phase button not found or invalid")
	
	if manage_crew_button and manage_crew_button.has_method("connect"):
		if not manage_crew_button.pressed.is_connected(_on_manage_crew_pressed):
			manage_crew_button.pressed.connect(_on_manage_crew_pressed)
	else:
		push_warning("CampaignDashboard: Manage crew button not found or invalid")
	
	if save_button and save_button.has_method("connect"):
		if not save_button.pressed.is_connected(_on_save_pressed):
			save_button.pressed.connect(_on_save_pressed)
	else:
		push_warning("CampaignDashboard: Save button not found or invalid")
	
	if load_button and load_button.has_method("connect"):
		if not load_button.pressed.is_connected(_on_load_pressed):
			load_button.pressed.connect(_on_load_pressed)
	else:
		push_warning("CampaignDashboard: Load button not found or invalid")
	
	if quit_button and quit_button.has_method("connect"):
		if not quit_button.pressed.is_connected(_on_quit_pressed):
			quit_button.pressed.connect(_on_quit_pressed)
	else:
		push_warning("CampaignDashboard: Quit button not found or invalid")

func _setup_campaign() -> void:
	"""Setup campaign using manager or fallback"""
	if campaign_manager and campaign_manager.has_method("get_current_campaign"):
		# Use campaign manager
		var campaign_data = campaign_manager.get_current_campaign()
		if campaign_data:
			_load_campaign_data(campaign_data)
		else:
			print("No active campaign found")
	elif phase_manager:
		# Use local fallback
		phase_manager.setup(game_state)
		phase_manager.start_phase(GameEnums.CampaignPhase.UPKEEP)

func _on_phase_changed(old_phase: int, new_phase: int) -> void:
	_update_phase_ui(new_phase)
	_load_phase_content(new_phase)

func _on_phase_completed() -> void:
	if next_phase_button:
		next_phase_button.disabled = false

func _on_phase_event(_event: Dictionary) -> void:
	match _event.type:
		"UPKEEP_STARTED":
			_handle_upkeep_event(_event)
		"STORY_STARTED":
			_handle_story_event(_event)
		"CAMPAIGN_STARTED":
			_handle_campaign_event(_event)
		"BATTLE_SETUP_STARTED":
			_handle_battle_setup_event(_event)
		"BATTLE_RESOLUTION_STARTED":
			_handle_battle_resolution_event(_event)
		"ADVANCEMENT_STARTED":
			_handle_advancement_event(_event)
		"TRADE_STARTED":
			_handle_trade_event(_event)
		"END_PHASE_STARTED":
			_handle_end_phase_event(_event)

func _on_next_phase_pressed() -> void:
	if phase_manager:
		var next_phase = _get_next_phase(phase_manager.current_phase)
		if next_phase != GameEnums.CampaignPhase.NONE:
			phase_manager.start_phase(next_phase)
			if next_phase_button:
				next_phase_button.disabled = true

func _update_phase_ui(phase: int) -> void:
	if phase_label:
		phase_label.text = "Current Phase: " + GameEnums.CampaignPhase.keys()[phase]
	if next_phase_button:
		next_phase_button.text = "Next Phase: " + GameEnums.CampaignPhase.keys()[_get_next_phase(phase)]

func _update_ui() -> void:
	if not game_state or not game_state.campaign:
		return
	
	if credits_label:
		credits_label.text = "Credits: %d" % game_state.campaign.credits
	if story_points_label:
		story_points_label.text = "Story Points: %d" % game_state.campaign.story_points
	
	_update_crew_list()
	_update_ship_info()

func _update_crew_list() -> void:
	if not crew_list:
		return
	crew_list.clear()
	if not game_state or not game_state.campaign or not game_state.campaign.crew_members:
		crew_list.add_item("No Crew Members")
		return
	
	for member in game_state.campaign.crew_members:
		crew_list.add_item(member.character_name)

func _update_ship_info() -> void:
	if not ship_info:
		return
	if not game_state or not game_state.campaign or not game_state.campaign.ship:
		ship_info.text = "No Ship Data"
		return
	
	ship_info.text = game_state.campaign.ship.get_info()

func _load_phase_content(phase: int) -> void:
	if current_phase_panel:
		current_phase_panel.cleanup()
		current_phase_panel.queue_free()
	
	var panel = _create_phase_panel(phase)
	if panel:
		current_phase_panel = panel
		phase_content.add_child(panel)
		panel.setup(game_state, phase_manager)

func _create_phase_panel(phase: int) -> FPCM_BasePhasePanel:
	match phase:
		GameEnums.CampaignPhase.UPKEEP:
			return UpkeepPhasePanel.instantiate()
		GameEnums.CampaignPhase.STORY:
			return StoryPhasePanel.instantiate()
		GameEnums.CampaignPhase.CAMPAIGN:
			return CampaignPhasePanel.instantiate()
		GameEnums.CampaignPhase.BATTLE_SETUP:
			return BattleSetupPhasePanel.instantiate()
		GameEnums.CampaignPhase.BATTLE_RESOLUTION:
			return BattleResolutionPhasePanel.instantiate()
		GameEnums.CampaignPhase.ADVANCEMENT:
			return AdvancementPhasePanel.instantiate()
		GameEnums.CampaignPhase.TRADE:
			return TradePhasePanel.instantiate()
		GameEnums.CampaignPhase.END:
			return EndPhasePanel.instantiate()
		# Add other phase panels here as they are implemented
		_:
			push_warning("No panel implemented for phase: %s" % GameEnums.CampaignPhase.keys()[phase])
			return null
func _get_next_phase(current: int) -> int:
	match current:
		GameEnums.CampaignPhase.SETUP:
			return GameEnums.CampaignPhase.UPKEEP
		GameEnums.CampaignPhase.UPKEEP:
			return GameEnums.CampaignPhase.STORY
		GameEnums.CampaignPhase.STORY:
			return GameEnums.CampaignPhase.CAMPAIGN
		GameEnums.CampaignPhase.CAMPAIGN:
			return GameEnums.CampaignPhase.BATTLE_SETUP
		GameEnums.CampaignPhase.BATTLE_SETUP:
			return GameEnums.CampaignPhase.BATTLE_RESOLUTION
		GameEnums.CampaignPhase.BATTLE_RESOLUTION:
			return GameEnums.CampaignPhase.ADVANCEMENT
		GameEnums.CampaignPhase.ADVANCEMENT:
			return GameEnums.CampaignPhase.TRADE
		GameEnums.CampaignPhase.TRADE:
			return GameEnums.CampaignPhase.END
		GameEnums.CampaignPhase.END:
			return GameEnums.CampaignPhase.UPKEEP
		_:
			return GameEnums.CampaignPhase.NONE

# Event Handlers
func _handle_upkeep_event(_event: Dictionary) -> void:
	_update_ui()

func _handle_story_event(_event: Dictionary) -> void:
	_update_ui()

func _handle_campaign_event(_event: Dictionary) -> void:
	_update_ui()

func _handle_battle_setup_event(_event: Dictionary) -> void:
	_update_ui()

func _handle_battle_resolution_event(_event: Dictionary) -> void:
	_update_ui()

func _handle_advancement_event(_event: Dictionary) -> void:
	_update_ui()

func _handle_trade_event(_event: Dictionary) -> void:
	_update_ui()

func _handle_end_phase_event(_event: Dictionary) -> void:
	_update_ui()

# Button Event Handlers
	
func _on_manage_crew_pressed() -> void:
	get_tree().call_deferred("change_scene_to_file", "res://src/ui/screens/crew/CrewManagement.tscn")

func _on_save_pressed() -> void:
	game_state.save_campaign()

func _on_load_pressed() -> void:
	get_tree().call_deferred("change_scene_to_file", "res://src/ui/screens/campaign/LoadCampaign.tscn")

func _on_quit_pressed() -> void:
	if campaign_manager and campaign_manager.has_method("save_current_campaign"):
		campaign_manager.save_current_campaign()
	elif game_state:
		game_state.end_campaign()
	get_tree().call_deferred("change_scene_to_file", "res://src/ui/screens/MainMenu.tscn")

func _on_campaign_updated() -> void:
	"""Handle campaign data updates from campaign manager"""
	_update_ui()

func _load_campaign_data(campaign_data: Resource) -> void:
	"""Load campaign _data from manager"""
	if campaign_data:
		print("Loading campaign _data: ", campaign_data)
		# TODO: Update UI with campaign _data
		_update_ui()

func setup_phase(campaign_data: Resource) -> void:
	"""Called by MainGameScene when this phase is activated"""
	if campaign_data:
		_load_campaign_data(campaign_data)
