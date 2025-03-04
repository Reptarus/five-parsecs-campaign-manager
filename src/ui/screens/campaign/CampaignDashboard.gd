class_name FPCM_CampaignDashboardUI
extends Control

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const GameState = preload("res://src/core/state/GameState.gd")
const CampaignPhaseManagerScript = preload("res://src/core/campaign/CampaignPhaseManager.gd")

const UpkeepPhasePanel = preload("res://src/ui/screens/campaign/phases/UpkeepPhasePanel.tscn")
const StoryPhasePanel = preload("res://src/ui/screens/campaign/phases/StoryPhasePanel.tscn")
const CampaignPhasePanel = preload("res://src/ui/screens/campaign/phases/CampaignPhasePanel.tscn")
const BattleSetupPhasePanel = preload("res://src/ui/screens/campaign/phases/BattleSetupPhasePanel.tscn")
const BattleResolutionPhasePanel = preload("res://src/ui/screens/campaign/phases/BattleResolutionPhasePanel.tscn")
const AdvancementPhasePanel = preload("res://src/ui/screens/campaign/phases/AdvancementPhasePanel.tscn")
const TradePhasePanel = preload("res://src/ui/screens/campaign/phases/TradePhasePanel.tscn")
const EndPhasePanel = preload("res://src/ui/screens/campaign/phases/EndPhasePanel.tscn")

@onready var phase_label = $MarginContainer/VBoxContainer/Header/HBoxContainer/PhaseLabel
@onready var resources_panel = $MarginContainer/VBoxContainer/Header/HBoxContainer/ResourcesPanel
@onready var credits_label = $MarginContainer/VBoxContainer/Header/HBoxContainer/ResourcesPanel/HBoxContainer/CreditsLabel
@onready var story_points_label = $MarginContainer/VBoxContainer/Header/HBoxContainer/ResourcesPanel/HBoxContainer/StoryPointsLabel
@onready var crew_list = $MarginContainer/VBoxContainer/Content/LeftPanel/CrewPanel/VBoxContainer/CrewList
@onready var ship_info = $MarginContainer/VBoxContainer/Content/LeftPanel/ShipPanel/VBoxContainer/ShipInfo
@onready var phase_content = $MarginContainer/VBoxContainer/Content/RightPanel/PhaseContent/ScrollContainer/VBoxContainer
@onready var next_phase_button = $MarginContainer/VBoxContainer/Footer/HBoxContainer/NextPhaseButton
@onready var manage_crew_button = $MarginContainer/VBoxContainer/Footer/HBoxContainer/ManageCrewButton
@onready var save_button = $MarginContainer/VBoxContainer/Footer/HBoxContainer/SaveButton
@onready var load_button = $MarginContainer/VBoxContainer/Footer/HBoxContainer/LoadButton
@onready var quit_button = $MarginContainer/VBoxContainer/Footer/HBoxContainer/QuitButton
@onready var phase_container = $PhaseContainer

var game_state: GameState
var phase_manager: Node
var current_phase_panel: BasePhasePanel

func _ready() -> void:
	game_state = GameState.new()
	phase_manager = CampaignPhaseManagerScript.new()
	
	# Need to add nodes to scene tree before connecting signals
	game_state.name = "GameState" # Give nodes names to help with debugging
	phase_manager.name = "PhaseManager"
	
	add_child(game_state)
	add_child(phase_manager)
	
	_connect_signals()
	_setup_phase_manager()
	_update_ui()

func _connect_signals() -> void:
	phase_manager.phase_changed.connect(_on_phase_changed)
	phase_manager.phase_completed.connect(_on_phase_completed)
	phase_manager.phase_event_triggered.connect(_on_phase_event)
	
	next_phase_button.pressed.connect(_on_next_phase_pressed)
	manage_crew_button.pressed.connect(_on_manage_crew_pressed)
	save_button.pressed.connect(_on_save_pressed)
	load_button.pressed.connect(_on_load_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _setup_phase_manager() -> void:
	phase_manager.setup(game_state)
	phase_manager.start_phase(GameEnums.CampaignPhase.UPKEEP)

func _on_phase_changed(old_phase: int, new_phase: int) -> void:
	_update_phase_ui(new_phase)
	_load_phase_content(new_phase)

func _on_phase_completed() -> void:
	next_phase_button.disabled = false

func _on_phase_event(event: Dictionary) -> void:
	match event.type:
		"UPKEEP_STARTED":
			_handle_upkeep_event(event)
		"STORY_STARTED":
			_handle_story_event(event)
		"CAMPAIGN_STARTED":
			_handle_campaign_event(event)
		"BATTLE_SETUP_STARTED":
			_handle_battle_setup_event(event)
		"BATTLE_RESOLUTION_STARTED":
			_handle_battle_resolution_event(event)
		"ADVANCEMENT_STARTED":
			_handle_advancement_event(event)
		"TRADE_STARTED":
			_handle_trade_event(event)
		"END_PHASE_STARTED":
			_handle_end_phase_event(event)

func _on_next_phase_pressed() -> void:
	var next_phase = _get_next_phase(phase_manager.current_phase)
	if next_phase != GameEnums.CampaignPhase.NONE:
		phase_manager.start_phase(next_phase)
		next_phase_button.disabled = true

func _update_phase_ui(phase: int) -> void:
	phase_label.text = "Current Phase: " + GameEnums.CampaignPhase.keys()[phase]
	next_phase_button.text = "Next Phase: " + GameEnums.CampaignPhase.keys()[_get_next_phase(phase)]

func _update_ui() -> void:
	if not game_state or not game_state.campaign:
		return
	
	credits_label.text = "Credits: %d" % game_state.campaign.credits
	story_points_label.text = "Story Points: %d" % game_state.campaign.story_points
	
	_update_crew_list()
	_update_ship_info()

func _update_crew_list() -> void:
	crew_list.clear()
	if not game_state.campaign.crew_members:
		crew_list.add_item("No Crew Members")
		return
	
	for member in game_state.campaign.crew_members:
		crew_list.add_item(member.character_name)

func _update_ship_info() -> void:
	if not game_state.campaign.ship:
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

func _create_phase_panel(phase: int) -> BasePhasePanel:
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
func _handle_upkeep_event(event: Dictionary) -> void:
	_update_ui()

func _handle_story_event(event: Dictionary) -> void:
	_update_ui()

func _handle_campaign_event(event: Dictionary) -> void:
	_update_ui()

func _handle_battle_setup_event(event: Dictionary) -> void:
	_update_ui()

func _handle_battle_resolution_event(event: Dictionary) -> void:
	_update_ui()

func _handle_advancement_event(event: Dictionary) -> void:
	_update_ui()

func _handle_trade_event(event: Dictionary) -> void:
	_update_ui()

func _handle_end_phase_event(event: Dictionary) -> void:
	_update_ui()

# Button Event Handlers
func _on_manage_crew_pressed() -> void:
	get_tree().change_scene_to_file("res://src/ui/screens/crew/CrewManagement.tscn")

func _on_save_pressed() -> void:
	game_state.save_campaign()

func _on_load_pressed() -> void:
	get_tree().change_scene_to_file("res://src/ui/screens/campaign/LoadCampaign.tscn")

func _on_quit_pressed() -> void:
	game_state.end_campaign()
	get_tree().change_scene_to_file("res://src/ui/screens/MainMenu.tscn")
